import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/cinko_models.dart';
import '../models/cinko_state.dart';
import '../models/player.dart';
import '../services/cinko_bot_session.dart';
import '../services/search_service.dart';
import 'vs_bot_controller.dart';

enum VsBotCinkoTurn { user, bot, gameOver }

enum CinkoMatchPhase { loading, ready, playing, paused, finished, error }

enum CinkoEndReason { boardCompleted, noMoves }

class CinkoMove {
  const CinkoMove({
    required this.byUser,
    this.player,
    this.correct = const [],
    this.wrong = const [],
  });
  final bool byUser;
  final Player? player;
  final List<int> correct, wrong;
  bool get passed => player == null;
  int get points => correct.length - wrong.length;
}

/// Human and bot share the same answer index, used-player set and connection rule.
class VsBotCinkoController extends ChangeNotifier {
  VsBotCinkoController({
    this.gridSize = defaultGrid,
    CinkoBotSessionLoader? loadSession,
    Random? random,
    this.difficulty = VsBotDifficulty.medium,
  }) : assert(gridSize >= 2 && gridSize <= 6),
       _loadSession = loadSession ?? CinkoBotSession.load,
       _random = random ?? Random();

  static const int defaultGrid = 5;
  static const int revealMs = 1100;
  final int gridSize;
  final CinkoBotSessionLoader _loadSession;
  final Random _random;
  VsBotDifficulty difficulty;
  CinkoBotSession? session;
  CinkoMatchPhase phase = CinkoMatchPhase.loading;
  CinkoEndReason? endReason;
  String? errorMessage;
  CinkoState _state = const CinkoState();
  CinkoState get state => _state;
  List<Player> suggestions = const [];
  VsBotCinkoTurn turn = VsBotCinkoTurn.user;
  int userScore = 0, botScore = 0;
  final List<CinkoMove> _moves = [];
  List<CinkoMove> get moves => List.unmodifiable(_moves);
  CinkoMove? get lastMove => _moves.isEmpty ? null : _moves.last;
  final Map<int, Player> claimedByPlayer = {};
  Set<int> _playableCells = {};
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;

  bool get isInMatch =>
      phase == CinkoMatchPhase.playing || phase == CinkoMatchPhase.paused;
  bool get canChoosePlayer =>
      phase == CinkoMatchPhase.playing &&
      turn == VsBotCinkoTurn.user &&
      state.phase == CinkoPhase.enterPlayer;
  bool get canSelect =>
      phase == CinkoMatchPhase.playing &&
      turn == VsBotCinkoTurn.user &&
      state.phase == CinkoPhase.selecting;
  bool get canPass => canChoosePlayer || canSelect;
  int get remainingPlayableCells => _playableCells.length;
  bool isCellPlayable(int index) => _playableCells.contains(index);

  Future<void> initialize() async {
    if (_disposed) return;
    final generation = ++_generation;
    _timer?.cancel();
    phase = CinkoMatchPhase.loading;
    endReason = null;
    errorMessage = null;
    session = null;
    _state = const CinkoState();
    turn = VsBotCinkoTurn.user;
    userScore = botScore = 0;
    suggestions = const [];
    _moves.clear();
    claimedByPlayer.clear();
    _playableCells = {};
    notifyListeners();
    try {
      final loaded = await _loadSession(gridSize);
      if (_disposed || generation != _generation) return;
      if (!loaded.isPlayable(gridSize))
        throw StateError('Eksik Çinko tahtası.');
      session = loaded;
      _state = CinkoState(cells: loaded.cells, isLoading: false);
      _refreshPlayableCells();
      phase = CinkoMatchPhase.ready;
    } catch (error) {
      if (_disposed || generation != _generation) return;
      phase = CinkoMatchPhase.error;
      _state = _state.copyWith(isLoading: false);
      errorMessage = 'Tahta hazırlanamadı. Yeniden deneyebilirsin.';
      if (kDebugMode) debugPrint('[Cinko] $error');
    }
    notifyListeners();
  }

  void setDifficulty(VsBotDifficulty value) {
    if (_disposed || phase != CinkoMatchPhase.ready) return;
    difficulty = value;
    notifyListeners();
  }

  void begin() {
    if (_disposed || phase != CinkoMatchPhase.ready) return;
    phase = CinkoMatchPhase.playing;
    notifyListeners();
  }

  void pause() {
    if (_disposed || phase != CinkoMatchPhase.playing) return;
    _timer?.cancel();
    phase = CinkoMatchPhase.paused;
    notifyListeners();
  }

  void resume() {
    if (_disposed || phase != CinkoMatchPhase.paused) return;
    phase = CinkoMatchPhase.playing;
    if (state.phase == CinkoPhase.revealing) {
      _scheduleReveal();
    } else if (turn == VsBotCinkoTurn.bot) {
      _scheduleBot();
    }
    notifyListeners();
  }

  void updateSuggestions(String query) {
    if (_disposed || !canChoosePlayer) return;
    suggestions = SearchService.suggestions(
      players: session!.players,
      query: query,
      excludedPlayerIds: state.usedPlayerIds,
      useGlobalIndex: false,
    ).where((player) => session!.playersById.containsKey(player.id)).toList();
    notifyListeners();
  }

  bool submitPlayerName(String raw) {
    if (_disposed || !canChoosePlayer || raw.trim().isEmpty) return false;
    final resolved = SearchService.resolve(
      players: session!.players,
      answer: raw,
    );
    if (!resolved.isFound) {
      suggestions = resolved.status == ResolveStatus.ambiguous
          ? resolved.candidates
          : const [];
      _feedback(
        resolved.status == ResolveStatus.ambiguous
            ? 'Birden fazla oyuncu var. Listeden seç.'
            : 'Oyuncu bulunamadı. Adını düzenleyebilirsin.',
        false,
      );
      return false;
    }
    return submitResolvedPlayer(resolved.player!);
  }

  bool submitResolvedPlayer(Player player) {
    if (_disposed || !canChoosePlayer) return false;
    // Resolve by ID; an injected object's club fields cannot alter validation.
    final found = session!.playersById[player.id];
    if (found == null) {
      _feedback('Bu oyuncu kullanılamıyor.', false);
      return false;
    }
    if (state.usedPlayerIds.contains(found.id)) {
      _feedback('Bu oyuncu bu maçta zaten kullanıldı.', false);
      return false;
    }
    if (!_playableCells.any((i) => _matches(found.id, i))) {
      _feedback(
        'Bu oyuncuya uyan açık kutu kalmadı. Başka bir oyuncu seç.',
        false,
      );
      return false;
    }
    suggestions = const [];
    _state = state.copyWith(
      currentPlayer: found,
      phase: CinkoPhase.selecting,
      clearFeedback: true,
    );
    notifyListeners();
    return true;
  }

  bool toggleCell(int index) {
    if (_disposed || !canSelect || index < 0 || index >= state.cells.length)
      return false;
    final cell = state.cells[index];
    if (cell.status == CinkoCellStatus.correct ||
        !_playableCells.contains(index))
      return false;
    final selected = selectedIndexes.toSet();
    if (cell.status == CinkoCellStatus.selected) {
      selected.remove(index);
    } else {
      selected.add(index);
    }
    if (selected.isNotEmpty &&
        _largestComponent(selected).length != selected.length) {
      _feedback(
        'Kutular yan yana veya üst üste bağlı kalmalı. Çapraz bağlantı sayılmaz.',
        false,
      );
      return false;
    }
    final cells = List<CinkoCell>.of(state.cells);
    cells[index] = cell.copyWith(
      status: selected.contains(index)
          ? CinkoCellStatus.selected
          : CinkoCellStatus.open,
    );
    _state = state.copyWith(cells: cells, clearFeedback: true);
    notifyListeners();
    return true;
  }

  List<int> get selectedIndexes => [
    for (var i = 0; i < state.cells.length; i++)
      if (state.cells[i].status == CinkoCellStatus.selected) i,
  ];

  void cancelSelection() {
    if (_disposed || !canSelect) return;
    _clearSelection();
    notifyListeners();
  }

  bool confirmSelection() {
    if (_disposed || !canSelect || state.currentPlayer == null) return false;
    final selected = selectedIndexes;
    if (selected.isEmpty) {
      _feedback('Önce en az bir kutu seç.', false);
      return false;
    }
    _applySelection(state.currentPlayer!, selected, byUser: true);
    return true;
  }

  void pass() {
    if (_disposed || !canPass) return;
    _clearSelection();
    _moves.add(const CinkoMove(byUser: true));
    turn = VsBotCinkoTurn.bot;
    _state = state.copyWith(
      feedback: 'Pas geçtin. Sıra botta.',
      feedbackIsSuccess: true,
    );
    _scheduleBot();
    notifyListeners();
  }

  void _clearSelection() {
    suggestions = const [];
    _state = state.copyWith(
      cells: state.cells
          .map(
            (c) => c.status == CinkoCellStatus.selected
                ? c.copyWith(status: CinkoCellStatus.open)
                : c,
          )
          .toList(),
      phase: CinkoPhase.enterPlayer,
      clearPlayer: true,
      clearFeedback: true,
    );
  }

  bool _matches(int playerId, int cell) =>
      session!.validPlayerIdsByCell[cell]?.contains(playerId) ?? false;

  void _applySelection(
    Player player,
    List<int> indexes, {
    required bool byUser,
  }) {
    final cells = List<CinkoCell>.of(state.cells);
    final correct = <int>[], wrong = <int>[];
    for (final index in indexes) {
      final valid = _matches(player.id, index);
      (valid ? correct : wrong).add(index);
      cells[index] = cells[index].copyWith(
        status: valid ? CinkoCellStatus.correct : CinkoCellStatus.wrongFlash,
        owner: valid ? (byUser ? 1 : 2) : 0,
      );
      if (valid) claimedByPlayer[index] = player;
    }
    final move = CinkoMove(
      byUser: byUser,
      player: player,
      correct: List.unmodifiable(correct),
      wrong: List.unmodifiable(wrong),
    );
    _moves.add(move);
    if (byUser) {
      userScore += move.points;
    } else {
      botScore += move.points;
    }
    // Lock before notifying listeners or scheduling a handover.
    _state = state.copyWith(
      cells: cells,
      score: userScore,
      phase: CinkoPhase.revealing,
      usedPlayerIds: {...state.usedPlayerIds, player.id},
      clearPlayer: true,
      clearFeedback: true,
    );
    suggestions = const [];
    _refreshPlayableCells();
    _scheduleReveal();
    notifyListeners();
  }

  void _scheduleReveal() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: revealMs), _finishReveal);
  }

  void _finishReveal() {
    if (_disposed ||
        phase != CinkoMatchPhase.playing ||
        state.phase != CinkoPhase.revealing)
      return;
    _state = state.copyWith(
      cells: state.cells
          .map(
            (cell) => cell.status == CinkoCellStatus.wrongFlash
                ? cell.copyWith(status: CinkoCellStatus.open)
                : cell,
          )
          .toList(),
      phase: CinkoPhase.enterPlayer,
    );
    if (_finishIfNoMoves()) return;
    turn = lastMove!.byUser ? VsBotCinkoTurn.bot : VsBotCinkoTurn.user;
    if (turn == VsBotCinkoTurn.bot) _scheduleBot();
    notifyListeners();
  }

  void _refreshPlayableCells() {
    _playableCells = {
      for (var i = 0; i < state.cells.length; i++)
        if (state.cells[i].status != CinkoCellStatus.correct &&
            (session!.validPlayerIdsByCell[i] ?? const <int>{}).any(
              (id) => !state.usedPlayerIds.contains(id),
            ))
          i,
    };
  }

  bool _finishIfNoMoves() {
    if (state.allPainted || _playableCells.isEmpty) {
      _timer?.cancel();
      endReason = state.allPainted
          ? CinkoEndReason.boardCompleted
          : CinkoEndReason.noMoves;
      phase = CinkoMatchPhase.finished;
      turn = VsBotCinkoTurn.gameOver;
      _state = state.copyWith(phase: CinkoPhase.gameOver, clearFeedback: true);
      notifyListeners();
      return true;
    }
    return false;
  }

  void _scheduleBot() {
    _timer?.cancel();
    _timer = Timer(
      Duration(milliseconds: 850 + _random.nextInt(450)),
      _botPlay,
    );
  }

  void _botPlay() {
    if (_disposed ||
        phase != CinkoMatchPhase.playing ||
        turn != VsBotCinkoTurn.bot)
      return;
    if (_finishIfNoMoves()) return;
    final matches = <int, Set<int>>{};
    for (final cell in _playableCells) {
      for (final id in session!.validPlayerIdsByCell[cell]!) {
        if (!state.usedPlayerIds.contains(id)) {
          matches.putIfAbsent(id, () => <int>{}).add(cell);
        }
      }
    }
    final cap = switch (difficulty) {
      VsBotDifficulty.easy => 1,
      VsBotDifficulty.medium => 3,
      VsBotDifficulty.hard => state.totalCells,
    };
    Player? chosen;
    List<int> best = [];
    var ties = 0;
    // Rank connected components, not the total number of scattered matches.
    for (final entry in matches.entries) {
      final connected = _largestComponent(entry.value).take(cap).toList();
      if (connected.length > best.length) {
        best = connected;
        chosen = session!.playersById[entry.key];
        ties = 1;
      } else if (connected.length == best.length &&
          _random.nextInt(++ties) == 0) {
        best = connected;
        chosen = session!.playersById[entry.key];
      }
    }
    if (chosen != null) _applySelection(chosen, best, byUser: false);
  }

  Iterable<int> _neighbors(int index) sync* {
    final row = index ~/ gridSize, col = index % gridSize;
    if (row > 0) yield index - gridSize;
    if (row < gridSize - 1) yield index + gridSize;
    if (col > 0) yield index - 1;
    if (col < gridSize - 1) yield index + 1;
  }

  List<int> _largestComponent(Set<int> indexes) {
    final remaining = indexes.toSet();
    List<int> best = [];
    while (remaining.isNotEmpty) {
      final component = [remaining.first];
      remaining.remove(component.first);
      for (var cursor = 0; cursor < component.length; cursor++) {
        for (final neighbor in _neighbors(component[cursor])) {
          if (remaining.remove(neighbor)) component.add(neighbor);
        }
      }
      if (component.length > best.length) best = component;
    }
    return best;
  }

  void _feedback(String message, bool success) {
    _state = state.copyWith(feedback: message, feedbackIsSuccess: success);
    notifyListeners();
  }

  void restart() => unawaited(initialize());

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
