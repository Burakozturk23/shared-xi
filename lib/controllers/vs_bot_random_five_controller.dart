import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/club.dart';
import '../models/player.dart';
import '../services/random_five_session.dart';
import '../services/search_service.dart';
import 'vs_bot_controller.dart' show VsBotDifficulty;

enum VsBotRandomFiveTurn { user, bot, gameOver }

enum FiveMatchPhase {
  loading,
  ready,
  playing,
  roundResult,
  paused,
  finished,
  error,
}

class FiveMove {
  FiveMove({this.player, List<Club> matchedClubs = const []})
    : matchedClubs = List.unmodifiable(matchedClubs);
  final Player? player;
  final List<Club> matchedClubs;
  bool get passed => player == null;
  int get score => matchedClubs.length;
}

class FiveRoundResult {
  const FiveRoundResult({
    required this.board,
    required this.user,
    required this.bot,
  });
  final FiveRound board;
  final FiveMove user, bot;
}

/// Five shared boards, two turns per board and one canonical used-player set.
class VsBotRandomFiveController extends ChangeNotifier {
  VsBotRandomFiveController({
    RandomFiveSessionLoader? loadSession,
    Random? random,
    this.difficulty = VsBotDifficulty.medium,
  }) : _loadSession = loadSession ?? RandomFiveSession.load,
       _random = random ?? Random();

  static const maxTurnsEach = 5;
  final RandomFiveSessionLoader _loadSession;
  final Random _random;
  RandomFiveSession? session;
  List<FiveRound> _rounds = const [];
  final List<FiveRoundResult> _history = [];
  final Set<int> _usedPlayerIds = {};
  List<FiveRoundResult> get history => List.unmodifiable(_history);
  Set<int> get usedPlayerIds => Set.unmodifiable(_usedPlayerIds);
  List<Player> suggestions = const [];
  FiveMatchPhase phase = FiveMatchPhase.loading;
  VsBotRandomFiveTurn turn = VsBotRandomFiveTurn.user;
  VsBotDifficulty difficulty;
  int roundIndex = 0;
  int get roundNumber => roundIndex + 1;
  FiveRound? get board => _rounds.isEmpty ? null : _rounds[roundIndex];
  List<Club> get clubs => board?.clubs ?? const [];
  FiveMove? userMove, botMove;
  String? feedback;
  bool feedbackSuccess = true;
  Timer? _botTimer;
  int _generation = 0;
  bool _disposed = false;

  int get userScore =>
      _history.fold<int>(0, (s, e) => s + e.user.score) +
      (phase == FiveMatchPhase.roundResult || phase == FiveMatchPhase.finished
          ? 0
          : userMove?.score ?? 0);
  int get botScore => _history.fold(0, (s, e) => s + e.bot.score);
  bool get isInMatch =>
      phase == FiveMatchPhase.playing ||
      phase == FiveMatchPhase.paused ||
      phase == FiveMatchPhase.roundResult;
  bool get canAnswer =>
      !_disposed &&
      phase == FiveMatchPhase.playing &&
      turn == VsBotRandomFiveTurn.user;

  Future<void> initialize() async {
    if (_disposed) return;
    final generation = ++_generation;
    _botTimer?.cancel();
    phase = FiveMatchPhase.loading;
    session = null;
    _rounds = const [];
    _history.clear();
    _usedPlayerIds.clear();
    suggestions = const [];
    roundIndex = 0;
    userMove = botMove = null;
    feedback = null;
    feedbackSuccess = true;
    turn = VsBotRandomFiveTurn.user;
    notifyListeners();
    try {
      final loaded = await _loadSession();
      if (_disposed || generation != _generation) return;
      final rounds = <FiveRound>[];
      for (var i = 0; i < maxTurnsEach; i++) {
        rounds.add(
          loaded.createRound(
            random: _random,
            previous: rounds.isEmpty
                ? const {}
                : rounds.last.clubs.map((c) => c.id).toSet(),
          ),
        );
        // Yield between boards so loading and disposal remain responsive.
        await Future<void>.delayed(Duration.zero);
        if (_disposed || generation != _generation) return;
      }
      session = loaded;
      _rounds = List.unmodifiable(rounds);
      phase = FiveMatchPhase.ready;
    } catch (error, stack) {
      if (_disposed || generation != _generation) return;
      phase = FiveMatchPhase.error;
      feedback = 'Kulüpler hazırlanamadı. Yeniden deneyebilirsin.';
      if (kDebugMode) debugPrint('[RandomFive] $error\n$stack');
    }
    notifyListeners();
  }

  void setDifficulty(VsBotDifficulty value) {
    if (_disposed || phase != FiveMatchPhase.ready) return;
    difficulty = value;
    notifyListeners();
  }

  void begin() {
    if (_disposed || phase != FiveMatchPhase.ready) return;
    phase = FiveMatchPhase.playing;
    notifyListeners();
  }

  void updateSuggestions(String query) {
    if (!canAnswer) return;
    suggestions = SearchService.suggestions(
      players: session!.players,
      query: query,
      excludedPlayerIds: _usedPlayerIds,
      useGlobalIndex: false,
    );
    feedback = null;
    notifyListeners();
  }

  bool submitGuess(String answer) {
    if (!canAnswer || answer.trim().isEmpty) return false;
    final resolved = SearchService.resolve(
      players: session!.players,
      answer: answer,
    );
    if (!resolved.isFound) {
      suggestions = resolved.status == ResolveStatus.ambiguous
          ? resolved.candidates
          : const [];
      _reject(
        resolved.status == ResolveStatus.ambiguous
            ? 'Birden fazla oyuncu var. Listeden seç.'
            : 'Oyuncu bulunamadı. Adını düzenleyebilirsin.',
      );
      return false;
    }
    return submitPlayer(resolved.player!);
  }

  bool submitPlayer(Player player) {
    if (!canAnswer) return false;
    final canonical = session!.playersById[player.id];
    if (canonical == null) {
      _reject('Bu oyuncu cevap havuzunda bulunamadı.');
      return false;
    }
    if (_usedPlayerIds.contains(canonical.id)) {
      _reject('Bu oyuncu bu maçta zaten kullanıldı. Başka bir isim seç.');
      return false;
    }
    final matched = board!.matchedClubs(canonical.id);
    if (matched.isEmpty) {
      _reject(
        '${canonical.name} bu beş kulübe uymuyor. Başka bir isim deneyebilirsin.',
      );
      return false;
    }
    _usedPlayerIds.add(canonical.id);
    _finishUserTurn(FiveMove(player: canonical, matchedClubs: matched));
    return true;
  }

  void _reject(String message) {
    feedback = message;
    feedbackSuccess = false;
    notifyListeners();
  }

  bool pass() {
    if (!canAnswer) return false;
    _finishUserTurn(FiveMove());
    return true;
  }

  void _finishUserTurn(FiveMove move) {
    // Lock before notifying: a listener or double tap cannot spend another turn.
    turn = VsBotRandomFiveTurn.bot;
    userMove = move;
    suggestions = const [];
    feedback = null;
    feedbackSuccess = true;
    _scheduleBot();
    notifyListeners();
  }

  void _scheduleBot() {
    _botTimer?.cancel();
    _botTimer = Timer(
      Duration(milliseconds: 900 + _random.nextInt(500)),
      _botPlay,
    );
  }

  void _botPlay() {
    if (_disposed ||
        phase != FiveMatchPhase.playing ||
        turn != VsBotRandomFiveTurn.bot)
      return;
    final candidates = board!.matches.keys
        .where((id) => !_usedPlayerIds.contains(id))
        .toList();
    final preferredLimit = switch (difficulty) {
      VsBotDifficulty.easy => 2,
      VsBotDifficulty.medium => 3,
      VsBotDifficulty.hard => 5,
    };
    final preferred = candidates
        .where((id) => board!.matches[id]!.length <= preferredLimit)
        .toList();
    // Count every real match, never truncate a player's earned points.
    final available = preferred.isNotEmpty ? preferred : candidates;
    if (available.isEmpty) {
      botMove = FiveMove();
    } else {
      final scores = available.map((id) => board!.matches[id]!.length);
      final target = preferred.isNotEmpty
          ? scores.reduce(max)
          : scores.reduce(min);
      final tied = available
          .where((id) => board!.matches[id]!.length == target)
          .toList();
      final id = tied[_random.nextInt(tied.length)];
      botMove = FiveMove(
        player: session!.playersById[id]!,
        matchedClubs: board!.matchedClubs(id),
      );
      _usedPlayerIds.add(id);
    }
    _history.add(
      FiveRoundResult(board: board!, user: userMove!, bot: botMove!),
    );
    phase = FiveMatchPhase.roundResult;
    notifyListeners();
  }

  void nextRound() {
    if (_disposed || phase != FiveMatchPhase.roundResult) return;
    if (_history.length == maxTurnsEach) {
      phase = FiveMatchPhase.finished;
      turn = VsBotRandomFiveTurn.gameOver;
    } else {
      roundIndex++;
      userMove = botMove = null;
      feedback = null;
      suggestions = const [];
      phase = FiveMatchPhase.playing;
      turn = VsBotRandomFiveTurn.user;
    }
    notifyListeners();
  }

  void pause() {
    if (_disposed || phase != FiveMatchPhase.playing) return;
    _botTimer?.cancel();
    phase = FiveMatchPhase.paused;
    notifyListeners();
  }

  void resume() {
    if (_disposed || phase != FiveMatchPhase.paused) return;
    phase = FiveMatchPhase.playing;
    if (turn == VsBotRandomFiveTurn.bot) _scheduleBot();
    notifyListeners();
  }

  void newMatch() => unawaited(initialize());

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _botTimer?.cancel();
    super.dispose();
  }
}
