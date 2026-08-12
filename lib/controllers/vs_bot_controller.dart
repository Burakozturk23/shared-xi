import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/club.dart';
import '../models/match_entity.dart';
import '../models/player.dart';
import '../models/vs_bot_state.dart';
import '../repositories/repository.dart';
import '../services/game_service.dart';
import '../services/search_service.dart';

enum VsBotDifficulty {
  easy,
  medium,
  hard,
}

class VsBotController extends ChangeNotifier {
  static const int _minShared = 3;
  static const int _maxPickAttempts = 50;
  static const int _roundsToWin = 3;

  final Club userClub;
  final VsBotDifficulty difficulty;
  final Random _random = Random();

  VsBotController({
    required this.userClub,
    this.difficulty = VsBotDifficulty.medium,
  });

  VsBotState _state = const VsBotState();
  VsBotState get state => _state;

  List<Player> suggestions = const [];

  Timer? _countdownTimer;
  Timer? _botTimer;
  Timer? _feedbackTimer;

  Future<void> initialize() async {
    _state = _state.copyWith(userClub: userClub, isLoading: true);
    notifyListeners();
    _startNewRound();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _botTimer?.cancel();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  (int minMs, int maxMs) get _botDelayRange {
    switch (difficulty) {
      case VsBotDifficulty.easy:
        return (7000, 14000);
      case VsBotDifficulty.medium:
        return (4000, 9000);
      case VsBotDifficulty.hard:
        return (2000, 5000);
    }
  }

  Club? _pickOpponent() {
    final clubs = Repository.instance.clubs;
    final players = Repository.instance.players;
    final entity1 = MatchEntity.club(userClub);

    Club? best;
    var bestCount = 0;

    for (var i = 0; i < _maxPickAttempts; i++) {
      final candidate = clubs[_random.nextInt(clubs.length)];
      if (candidate.id == userClub.id) continue;

      final matching = GameService.matchingPlayers(
        players: players,
        entity1: entity1,
        entity2: MatchEntity.club(candidate),
      );

      if (matching.length >= _minShared) {
        return candidate;
      }
      if (matching.length > bestCount) {
        bestCount = matching.length;
        best = candidate;
      }
    }

    return best;
  }

  void _startNewRound() {
    _botTimer?.cancel();
    _countdownTimer?.cancel();

    final opponent = _pickOpponent();
    if (opponent == null) {
      _state = _state.copyWith(
        isLoading: false,
        phase: VsBotPhase.matchOver,
        feedback: 'Uygun rakip kulüp bulunamadı.',
        feedbackIsSuccess: false,
      );
      notifyListeners();
      return;
    }

    final matching = GameService.matchingPlayers(
      players: Repository.instance.players,
      entity1: MatchEntity.club(userClub),
      entity2: MatchEntity.club(opponent),
    );

    matching.shuffle(_random);

    _state = _state.copyWith(
      isLoading: false,
      opponentClub: opponent,
      matchingPlayers: matching,
      foundByUser: const {},
      foundByBot: const {},
      userFoundList: const [],
      botFoundList: const [],
      userScore: 0,
      botScore: 0,
      countdownLeft: 3,
      phase: VsBotPhase.countdown,
      clearFeedback: true,
      clearLastBotFind: true,
    );
    notifyListeners();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_state.countdownLeft <= 1) {
        t.cancel();
        _state = _state.copyWith(countdownLeft: 0, phase: VsBotPhase.racing);
        notifyListeners();
        _scheduleBotMove();
        return;
      }
      _state = _state.copyWith(countdownLeft: _state.countdownLeft - 1);
      notifyListeners();
    });
  }

  void _scheduleBotMove() {
    _botTimer?.cancel();
    if (_state.phase != VsBotPhase.racing) return;
    if (_state.remainingCount <= 0) return;

    final range = _botDelayRange;
    final delay = range.$1 + _random.nextInt(range.$2 - range.$1 + 1);

    _botTimer = Timer(Duration(milliseconds: delay), _botClaim);
  }

  void _botClaim() {
    if (_state.phase != VsBotPhase.racing) return;

    final remaining = _state.matchingPlayers
        .where((p) => !_state.allFoundIds.contains(p.id))
        .toList();
    if (remaining.isEmpty) return;

    final pick = remaining[_random.nextInt(remaining.length)];
    final botFound = Set<int>.from(_state.foundByBot)..add(pick.id);
    final botList = List<Player>.from(_state.botFoundList)..add(pick);
    final botScore = _state.botScore + 1;

    _state = _state.copyWith(
      foundByBot: botFound,
      botFoundList: botList,
      botScore: botScore,
      lastBotFind: pick.name,
    );
    _feedback('Bot buldu: ${pick.name}', false);
    notifyListeners();

    _checkRoundEnd();
    if (_state.phase == VsBotPhase.racing) {
      _scheduleBotMove();
    }
  }

  
  void updateSuggestions(String query) {
    if (_state.phase != VsBotPhase.racing) {
      suggestions = const [];
      notifyListeners();
      return;
    }
    suggestions = SearchService.suggestions(
      players: _state.matchingPlayers.isNotEmpty
          ? _state.matchingPlayers
          : Repository.instance.players,
      query: query,
      excludedPlayerIds: _state.allFoundIds,
    );
    notifyListeners();
  }

  void clearSuggestions() {
    if (suggestions.isEmpty) return;
    suggestions = const [];
    notifyListeners();
  }

  void submitPlayer(Player player) {
    suggestions = const [];
    submitAnswer(player.name);
  }

void submitAnswer(String answer) {
    if (_state.phase != VsBotPhase.racing) return;

    final resolved = SearchService.resolve(
      players: Repository.instance.players,
      answer: answer,
      excludedPlayerIds: _state.allFoundIds,
    );

    if (resolved.status == ResolveStatus.ambiguous) {
      _feedback(resolved.message, false);
      return;
    }

    if (!resolved.isFound) {
      _feedback('Yanlış veya geçersiz.', false);
      return;
    }

    final player = resolved.player!;

    if (!_state.matchingPlayers.any((p) => p.id == player.id)) {
      _feedback('${player.name} bu eşleşmeye uymuyor.', false);
      return;
    }

    if (_state.allFoundIds.contains(player.id)) {
      _feedback('Bu oyuncu zaten bulundu.', false);
      return;
    }

    final userFound = Set<int>.from(_state.foundByUser)..add(player.id);
    final userList = List<Player>.from(_state.userFoundList)..add(player);
    final userScore = _state.userScore + 1;

    _state = _state.copyWith(
      foundByUser: userFound,
      userFoundList: userList,
      userScore: userScore,
    );
    _feedback('Doğru! ${player.name}', true);
    notifyListeners();

    _checkRoundEnd();
  }

  void _checkRoundEnd() {
    if (_state.remainingCount > 0) return;

    _botTimer?.cancel();

    final userWonRound = _state.userScore > _state.botScore;
    final draw = _state.userScore == _state.botScore;

    var userRoundWins = _state.userRoundWins;
    var botRoundWins = _state.botRoundWins;

    if (userWonRound) {
      userRoundWins++;
    } else if (!draw) {
      botRoundWins++;
    }

    final matchOver =
        userRoundWins >= _roundsToWin || botRoundWins >= _roundsToWin;

    _state = _state.copyWith(
      userRoundWins: userRoundWins,
      botRoundWins: botRoundWins,
      phase: matchOver ? VsBotPhase.matchOver : VsBotPhase.roundOver,
    );
    notifyListeners();
  }

  void nextRound() {
    if (_state.phase == VsBotPhase.matchOver) return;
    _startNewRound();
  }

  void rematch() {
    _state = const VsBotState();
    _state = _state.copyWith(userClub: userClub);
    notifyListeners();
    _startNewRound();
  }

  void _feedback(String message, bool success) {
    _feedbackTimer?.cancel();
    _state = _state.copyWith(feedback: message, feedbackIsSuccess: success);
    notifyListeners();
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      _state = _state.copyWith(clearFeedback: true);
      notifyListeners();
    });
  }
}