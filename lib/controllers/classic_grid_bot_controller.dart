import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/grid_criterion.dart';
import '../models/player.dart';
import '../services/classic_grid_session.dart';
import '../services/search_service.dart';
import 'vs_bot_controller.dart';

enum ClassicGridPhase { loading, ready, playing, paused, finished, error }

enum ClassicGridTurn { user, bot }

/// State machine for the classic 3×3 Botla Oyna grid.
///
/// The board is generated and validated by [ClassicGridSession]. This wrapper
/// only owns turn order, one-player-per-cell rules, bot decisions and route
/// lifecycle timers.
class ClassicGridBotController extends ChangeNotifier {
  ClassicGridBotController({
    ClassicGridSessionLoader? loadSession,
    Random? random,
    this.difficulty = VsBotDifficulty.medium,
  }) : loadSession = loadSession ?? ClassicGridSession.load,
       _random = random ?? Random();

  final ClassicGridSessionLoader loadSession;
  final Random _random;
  final VsBotDifficulty difficulty;

  ClassicGridSession? session;
  ClassicGridPhase phase = ClassicGridPhase.loading;
  ClassicGridTurn turn = ClassicGridTurn.user;
  final List<int> owners = List<int>.filled(9, 0);
  final List<Player?> cells = List<Player?>.filled(9, null);
  int? selectedIndex;
  int userScore = 0;
  int botScore = 0;
  int lineWinner = 0;
  String? feedback;
  bool feedbackOk = true;
  String? errorMessage;
  List<Player> suggestions = const <Player>[];

  Timer? _botTimer;
  Timer? _feedbackTimer;
  ClassicGridPhase? _pausedFrom;
  int _generation = 0;
  bool _preparing = false;
  bool _disposed = false;

  List<GridCriterion> get rows => session?.rows ?? const <GridCriterion>[];
  List<GridCriterion> get cols => session?.cols ?? const <GridCriterion>[];
  List<Player> get availablePlayers => session?.players ?? const <Player>[];
  Set<int> get usedPlayerIds => {
    for (final player in cells)
      if (player != null) player.id,
  };
  bool get isInMatch =>
      phase == ClassicGridPhase.ready ||
      phase == ClassicGridPhase.playing ||
      phase == ClassicGridPhase.paused;

  Future<void> prepare() async {
    if (_disposed || _preparing) return;
    _preparing = true;
    final generation = ++_generation;
    _cancelTimers();
    _resetBoard();
    phase = ClassicGridPhase.loading;
    turn = ClassicGridTurn.user;
    selectedIndex = null;
    feedback = null;
    errorMessage = null;
    notifyListeners();

    try {
      final loaded = await loadSession();
      if (_disposed || generation != _generation) return;
      if (loaded.rows.length != 3 ||
          loaded.cols.length != 3 ||
          loaded.players.isEmpty ||
          loaded.validPlayerIdsByCell.length != 9) {
        throw StateError('Eksik Classic Grid oturumu.');
      }
      session = loaded;
      phase = ClassicGridPhase.ready;
      notifyListeners();
    } catch (error) {
      if (_disposed || generation != _generation) return;
      phase = ClassicGridPhase.error;
      errorMessage = 'Çözülebilir bir grid tahtası hazırlanamadı.';
      if (kDebugMode) debugPrint('[ClassicGrid] $error');
      notifyListeners();
    } finally {
      if (generation == _generation) _preparing = false;
    }
  }

  void begin() {
    if (_disposed || phase != ClassicGridPhase.ready) return;
    phase = ClassicGridPhase.playing;
    turn = ClassicGridTurn.user;
    notifyListeners();
  }

  void pause() {
    if (_disposed || phase != ClassicGridPhase.playing) return;
    _pausedFrom = phase;
    _cancelTimers();
    phase = ClassicGridPhase.paused;
    notifyListeners();
  }

  void resume() {
    if (_disposed || phase != ClassicGridPhase.paused) return;
    final restore = _pausedFrom ?? ClassicGridPhase.playing;
    _pausedFrom = null;
    phase = restore;
    notifyListeners();
    if (turn == ClassicGridTurn.bot) _scheduleBotMove();
  }

  void openCell(int index) {
    if (_disposed ||
        phase != ClassicGridPhase.playing ||
        turn != ClassicGridTurn.user ||
        index < 0 ||
        index >= 9 ||
        owners[index] != 0) {
      return;
    }
    selectedIndex = index;
    suggestions = const <Player>[];
    notifyListeners();
  }

  void cancelSelection() {
    if (_disposed) return;
    selectedIndex = null;
    suggestions = const <Player>[];
    notifyListeners();
  }

  void updateSuggestions(String query) {
    if (_disposed ||
        phase != ClassicGridPhase.playing ||
        turn != ClassicGridTurn.user) {
      suggestions = const <Player>[];
      notifyListeners();
      return;
    }
    suggestions = SearchService.suggestions(
      players: availablePlayers,
      query: query,
      excludedPlayerIds: usedPlayerIds,
    );
    notifyListeners();
  }

  bool submitPlayer(Player player) {
    final index = selectedIndex;
    if (index == null) return false;
    return submitPlayerForCell(index, player);
  }

  bool submitPlayerForCell(int index, Player player) {
    if (_disposed ||
        phase != ClassicGridPhase.playing ||
        turn != ClassicGridTurn.user ||
        index < 0 ||
        index >= 9 ||
        owners[index] != 0) {
      return false;
    }
    if (!availablePlayers.any((candidate) => candidate.id == player.id) ||
        usedPlayerIds.contains(player.id)) {
      _setFeedback('Bu oyuncu bu turda kullanılamaz.', false);
      _passToBot();
      return false;
    }
    final valid = session?.validPlayerIdsByCell[index] ?? const <int>{};
    if (!valid.contains(player.id)) {
      _setFeedback('Bu oyuncu iki kritere uymuyor.', false);
      _passToBot();
      return false;
    }

    _claim(index, player, owner: 1);
    _setFeedback('Doğru! +1', true);
    _checkFinished();
    if (phase == ClassicGridPhase.playing) _passToBot();
    return true;
  }

  bool submitAnswer(String answer) {
    final index = selectedIndex;
    if (index == null ||
        _disposed ||
        phase != ClassicGridPhase.playing ||
        turn != ClassicGridTurn.user) {
      return false;
    }
    final resolved = SearchService.resolve(
      players: availablePlayers,
      answer: answer,
      excludedPlayerIds: usedPlayerIds,
    );
    if (!resolved.isFound) {
      _setFeedback(
        resolved.status == ResolveStatus.ambiguous
            ? resolved.message
            : 'Oyuncu bulunamadı.',
        false,
      );
      _passToBot();
      return false;
    }
    return submitPlayerForCell(index, resolved.player!);
  }

  void retry() => unawaited(prepare());

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _cancelTimers();
    super.dispose();
  }

  void _claim(int index, Player player, {required int owner}) {
    selectedIndex = null;
    suggestions = const <Player>[];
    owners[index] = owner;
    cells[index] = player;
    if (owner == 1) {
      userScore++;
    } else {
      botScore++;
    }
    notifyListeners();
  }

  void _passToBot() {
    if (_disposed || phase != ClassicGridPhase.playing) return;
    selectedIndex = null;
    suggestions = const <Player>[];
    turn = ClassicGridTurn.bot;
    notifyListeners();
    _scheduleBotMove();
  }

  void _scheduleBotMove() {
    if (_disposed ||
        phase != ClassicGridPhase.playing ||
        turn != ClassicGridTurn.bot ||
        owners.every((owner) => owner != 0)) {
      return;
    }
    _botTimer?.cancel();
    final (minMs, maxMs) = _botDelayRange;
    _botTimer = Timer(
      Duration(milliseconds: minMs + _random.nextInt(maxMs - minMs + 1)),
      _botMove,
    );
  }

  void _botMove() {
    if (_disposed ||
        phase != ClassicGridPhase.playing ||
        turn != ClassicGridTurn.bot) {
      return;
    }
    final empty = [
      for (var index = 0; index < 9; index++)
        if (owners[index] == 0) index,
    ];
    if (empty.isEmpty) {
      _finish();
      return;
    }
    if (_random.nextDouble() > _botAccuracy) {
      _setFeedback('Bot pas geçti.', false);
      turn = ClassicGridTurn.user;
      notifyListeners();
      return;
    }

    int? chosenIndex;
    Player? chosenPlayer;
    for (final index in _prioritizedCells(empty, owner: 2)) {
      final player = _anyValidPlayer(index);
      if (player != null) {
        chosenIndex = index;
        chosenPlayer = player;
        break;
      }
    }
    if (chosenIndex == null) {
      for (final index in _prioritizedCells(empty, owner: 1)) {
        final player = _anyValidPlayer(index);
        if (player != null) {
          chosenIndex = index;
          chosenPlayer = player;
          break;
        }
      }
    }
    if (chosenIndex == null) {
      final shuffled = List<int>.from(empty)..shuffle(_random);
      for (final index in shuffled) {
        final player = _anyValidPlayer(index);
        if (player != null) {
          chosenIndex = index;
          chosenPlayer = player;
          break;
        }
      }
    }

    if (chosenIndex == null || chosenPlayer == null) {
      _setFeedback('Bot pas geçti.', false);
      turn = ClassicGridTurn.user;
      notifyListeners();
      return;
    }

    _claim(chosenIndex, chosenPlayer, owner: 2);
    _setFeedback('Bot doldurdu: ${chosenPlayer.name}', false);
    _checkFinished();
    if (phase == ClassicGridPhase.playing) {
      turn = ClassicGridTurn.user;
      notifyListeners();
    }
  }

  List<int> _prioritizedCells(List<int> empty, {required int owner}) {
    final winning = empty.where((index) => _wouldCompleteLine(index, owner));
    final rest =
        empty.where((index) => !_wouldCompleteLine(index, owner)).toList()
          ..shuffle(_random);
    return [...winning, ...rest];
  }

  Player? _anyValidPlayer(int index) {
    final valid = session?.validPlayerIdsByCell[index] ?? const <int>{};
    final candidates = availablePlayers
        .where((player) => valid.contains(player.id))
        .where((player) => !usedPlayerIds.contains(player.id))
        .toList();
    if (candidates.isEmpty) return null;
    return candidates[_random.nextInt(candidates.length)];
  }

  void _checkFinished() {
    if (_hasLine(1)) {
      lineWinner = 1;
      _finish();
    } else if (_hasLine(2)) {
      lineWinner = 2;
      _finish();
    } else if (owners.every((owner) => owner != 0)) {
      _finish();
    }
  }

  void _finish() {
    _botTimer?.cancel();
    phase = ClassicGridPhase.finished;
    selectedIndex = null;
    suggestions = const <Player>[];
    notifyListeners();
  }

  bool _hasLine(int owner) =>
      _lines.any((line) => line.every((index) => owners[index] == owner));

  bool _wouldCompleteLine(int index, int owner) => _lines.any((line) {
    if (!line.contains(index)) return false;
    return line
        .where((cell) => cell != index)
        .every((cell) => owners[cell] == owner);
  });

  void _resetBoard() {
    for (var index = 0; index < owners.length; index++) {
      owners[index] = 0;
      cells[index] = null;
    }
    selectedIndex = null;
    userScore = 0;
    botScore = 0;
    lineWinner = 0;
    suggestions = const <Player>[];
  }

  void _setFeedback(String message, bool success) {
    if (_disposed) return;
    _feedbackTimer?.cancel();
    feedback = message;
    feedbackOk = success;
    notifyListeners();
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      if (_disposed) return;
      feedback = null;
      notifyListeners();
    });
  }

  void _cancelTimers() {
    _botTimer?.cancel();
    _feedbackTimer?.cancel();
    _botTimer = null;
    _feedbackTimer = null;
  }

  (int, int) get _botDelayRange => switch (difficulty) {
    VsBotDifficulty.easy => (900, 1500),
    VsBotDifficulty.medium => (700, 1200),
    VsBotDifficulty.hard => (500, 900),
  };

  double get _botAccuracy => switch (difficulty) {
    VsBotDifficulty.easy => .60,
    VsBotDifficulty.medium => .78,
    VsBotDifficulty.hard => .92,
  };

  static const List<List<int>> _lines = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6],
  ];
}
