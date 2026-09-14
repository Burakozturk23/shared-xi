import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/club.dart';
import '../models/player.dart';
import '../services/search_service.dart';
import '../services/team_race_session.dart';
import 'vs_bot_controller.dart';

enum TeamRacePhase {
  loading,
  countdown,
  racing,
  paused,
  roundOver,
  finished,
  error,
}

/// State machine for Botla Oyna > Takım Yarışı.
///
/// The round is intentionally self-contained: both sides use the same V4
/// player list, a found player can only be claimed once, and the bot timer is
/// cancelled whenever the route is paused or disposed.
class TeamRaceController extends ChangeNotifier {
  TeamRaceController({
    required this.userClub,
    this.difficulty = VsBotDifficulty.medium,
    TeamRaceSessionLoader? loadSession,
    Random? random,
  })  : loadSession = loadSession ?? TeamRaceSession.load,
        _random = random ?? Random();

  final Club userClub;
  final VsBotDifficulty difficulty;
  final TeamRaceSessionLoader loadSession;
  final Random _random;

  TeamRaceSession? session;
  TeamRacePhase phase = TeamRacePhase.loading;
  int countdownLeft = 3;
  int userScore = 0;
  int botScore = 0;
  int userRoundWins = 0;
  int botRoundWins = 0;
  String? feedback;
  bool feedbackOk = true;
  String? errorMessage;

  final Set<int> _foundByUser = <int>{};
  final Set<int> _foundByBot = <int>{};
  final List<Player> _userFound = <Player>[];
  final List<Player> _botFound = <Player>[];
  List<Player> suggestions = const <Player>[];

  Timer? _countdownTimer;
  Timer? _botTimer;
  Timer? _feedbackTimer;
  TeamRacePhase? _pausedFrom;
  int _generation = 0;
  bool _preparing = false;
  bool _disposed = false;

  List<Player> get matchingPlayers =>
      session?.matchingPlayers ?? const <Player>[];
  List<Player> get userFound => List.unmodifiable(_userFound);
  List<Player> get botFound => List.unmodifiable(_botFound);
  Set<int> get foundByUser => Set.unmodifiable(_foundByUser);
  Set<int> get foundByBot => Set.unmodifiable(_foundByBot);
  Set<int> get allFoundIds => <int>{..._foundByUser, ..._foundByBot};
  int get remainingCount =>
      matchingPlayers.where((p) => !allFoundIds.contains(p.id)).length;
  bool get isInRound =>
      phase == TeamRacePhase.countdown ||
      phase == TeamRacePhase.racing ||
      phase == TeamRacePhase.paused;

  Future<void> prepare({bool resetSeries = false}) async {
    if (_disposed || _preparing) return;
    _preparing = true;
    final generation = ++_generation;
    _cancelTimers();
    _resetRound();
    if (resetSeries) {
      userRoundWins = 0;
      botRoundWins = 0;
    }
    phase = TeamRacePhase.loading;
    errorMessage = null;
    feedback = null;
    notifyListeners();

    try {
      final loaded = await loadSession(userClub);
      if (_disposed || generation != _generation) return;
      if (loaded.matchingPlayers.length < 3) {
        throw StateError('Bu eşleşmede en az üç ortak oyuncu bulunmalı.');
      }
      session = loaded;
      countdownLeft = 3;
      phase = TeamRacePhase.countdown;
      notifyListeners();
      _startCountdown(generation);
    } catch (error) {
      if (_disposed || generation != _generation) return;
      phase = TeamRacePhase.error;
      errorMessage = 'Uygun bir ortak oyuncu turu hazırlanamadı.';
      if (kDebugMode) debugPrint('[TeamRace] $error');
      notifyListeners();
    } finally {
      if (generation == _generation) _preparing = false;
    }
  }

  void pause() {
    if (_disposed || (phase != TeamRacePhase.countdown && phase != TeamRacePhase.racing)) {
      return;
    }
    _pausedFrom = phase;
    _cancelTimers();
    phase = TeamRacePhase.paused;
    notifyListeners();
  }

  void resume() {
    if (_disposed || phase != TeamRacePhase.paused) return;
    final restore = _pausedFrom ?? TeamRacePhase.racing;
    _pausedFrom = null;
    phase = restore;
    notifyListeners();
    if (restore == TeamRacePhase.countdown) {
      _startCountdown(_generation);
    } else {
      _scheduleBotMove();
    }
  }

  void updateSuggestions(String query) {
    if (_disposed || phase != TeamRacePhase.racing) {
      suggestions = const <Player>[];
      notifyListeners();
      return;
    }
    suggestions = SearchService.suggestions(
      players: matchingPlayers,
      query: query,
      excludedPlayerIds: allFoundIds,
    );
    notifyListeners();
  }

  void clearSuggestions() {
    if (suggestions.isEmpty) return;
    suggestions = const <Player>[];
    notifyListeners();
  }

  bool submitPlayer(Player player) {
    if (_disposed || phase != TeamRacePhase.racing) return false;
    if (!matchingPlayers.any((candidate) => candidate.id == player.id)) {
      _setFeedback('Bu oyuncu bu eşleşmeye uymuyor.', false);
      return false;
    }
    if (allFoundIds.contains(player.id)) {
      _setFeedback('Bu oyuncu zaten bulundu.', false);
      return false;
    }

    suggestions = const <Player>[];
    _foundByUser.add(player.id);
    _userFound.add(player);
    userScore++;
    _setFeedback('Doğru! ${player.name} · +1', true);
    _checkRoundEnd();
    return true;
  }

  bool submitAnswer(String answer) {
    if (_disposed || phase != TeamRacePhase.racing) return false;
    final resolved = SearchService.resolve(
      players: matchingPlayers,
      answer: answer,
      excludedPlayerIds: allFoundIds,
    );
    if (resolved.status == ResolveStatus.ambiguous) {
      _setFeedback(resolved.message, false);
      return false;
    }
    if (!resolved.isFound) {
      _setFeedback('Yanlış veya geçersiz oyuncu.', false);
      return false;
    }
    return submitPlayer(resolved.player!);
  }

  void nextRound() {
    if (_disposed || phase != TeamRacePhase.roundOver) return;
    unawaited(prepare());
  }

  void rematch() {
    if (_disposed || phase != TeamRacePhase.finished) return;
    unawaited(prepare(resetSeries: true));
  }

  void retry() => unawaited(prepare());

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _cancelTimers();
    super.dispose();
  }

  void _startCountdown(int generation) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed || generation != _generation || phase != TeamRacePhase.countdown) {
        timer.cancel();
        return;
      }
      if (countdownLeft <= 1) {
        timer.cancel();
        countdownLeft = 0;
        phase = TeamRacePhase.racing;
        notifyListeners();
        _scheduleBotMove();
        return;
      }
      countdownLeft--;
      notifyListeners();
    });
  }

  void _scheduleBotMove() {
    if (_disposed || phase != TeamRacePhase.racing || remainingCount <= 0) return;
    _botTimer?.cancel();
    final (minMs, maxMs) = _botDelayRange;
    _botTimer = Timer(
      Duration(milliseconds: minMs + _random.nextInt(maxMs - minMs + 1)),
      _botClaim,
    );
  }

  void _botClaim() {
    if (_disposed || phase != TeamRacePhase.racing) return;
    final remaining = matchingPlayers
        .where((player) => !allFoundIds.contains(player.id))
        .toList();
    if (remaining.isEmpty) {
      _checkRoundEnd();
      return;
    }

    if (_random.nextDouble() > _botAccuracy) {
      _setFeedback('Bot pas geçti.', false);
      _scheduleBotMove();
      return;
    }

    final player = remaining[_random.nextInt(remaining.length)];
    _foundByBot.add(player.id);
    _botFound.add(player);
    botScore++;
    _setFeedback('Bot buldu: ${player.name}', false);
    _checkRoundEnd();
    if (phase == TeamRacePhase.racing) _scheduleBotMove();
  }

  void _checkRoundEnd() {
    if (remainingCount > 0) return;
    _botTimer?.cancel();

    if (userScore > botScore) {
      userRoundWins++;
    } else if (botScore > userScore) {
      botRoundWins++;
    }
    final matchOver = userRoundWins >= 3 || botRoundWins >= 3;
    phase = matchOver ? TeamRacePhase.finished : TeamRacePhase.roundOver;
    notifyListeners();
  }

  void _resetRound() {
    countdownLeft = 3;
    userScore = 0;
    botScore = 0;
    _foundByUser.clear();
    _foundByBot.clear();
    _userFound.clear();
    _botFound.clear();
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
    _countdownTimer?.cancel();
    _botTimer?.cancel();
    _feedbackTimer?.cancel();
    _countdownTimer = null;
    _botTimer = null;
    _feedbackTimer = null;
  }

  (int, int) get _botDelayRange => switch (difficulty) {
        VsBotDifficulty.easy => (6500, 9500),
        VsBotDifficulty.medium => (4200, 7000),
        VsBotDifficulty.hard => (2600, 4600),
      };

  double get _botAccuracy => switch (difficulty) {
        VsBotDifficulty.easy => .55,
        VsBotDifficulty.medium => .72,
        VsBotDifficulty.hard => .88,
      };
}
