import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/daily_challenge_state.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/daily_challenge_service.dart';
import '../services/game_service.dart';

class DailyChallengeController extends ChangeNotifier {
  static const int _roundSeconds = 90;

  DailyChallengeState _state = const DailyChallengeState();
  DailyChallengeState get state => _state;

  Timer? _clockTimer;
  Timer? _feedbackTimer;

  void initialize() {
    final matchup = DailyChallengeService.getTodayMatchup();

    final players = Repository.instance.players;
    final matchingPlayers = GameService.matchingPlayers(
      players: players,
      entity1: matchup.entity1,
      entity2: matchup.entity2,
    );

    _state = _state.copyWith(
      isLoading: false,
      entity1: matchup.entity1,
      entity2: matchup.entity2,
      label: matchup.label,
      matchingPlayers: matchingPlayers,
      secondsLeft: _roundSeconds,
    );

    notifyListeners();
    _startClock();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _startClock() {
    _clockTimer?.cancel();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state.isFinished) return;

      if (_state.secondsLeft <= 1) {
        _finish();
        return;
      }

      _state = _state.copyWith(secondsLeft: _state.secondsLeft - 1);
      notifyListeners();
    });
  }

  void updateSuggestions(String query) {
    final suggestions = GameService.suggestions(
      matchingPlayers: _state.matchingPlayers,
      query: query,
      foundIds: _state.foundPlayerIds,
    );

    _state = _state.copyWith(suggestions: suggestions);
    notifyListeners();
  }

  bool _alreadyFound(Player player) =>
      _state.foundPlayerIds.contains(player.id);

  bool _alreadyTried(String answer) => _state.wrongAttempts.contains(answer);

  void _feedback(String message, bool success) {
    _feedbackTimer?.cancel();

    _state = _state.copyWith(feedback: message, feedbackIsSuccess: success);
    notifyListeners();

    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      _state = _state.copyWith(feedback: null);
      notifyListeners();
    });
  }

  void submitAnswer(String answer) {
    if (_state.isFinished) return;

    final player = GameService.findPlayer(
      matchingPlayers: _state.matchingPlayers,
      answer: answer,
    );

    if (player == null) {
      if (_alreadyTried(answer)) {
        _feedback('Bu tahmini zaten yaptın.', false);
        return;
      }

      final attempts = Set<String>.from(_state.wrongAttempts)..add(answer);
      _state =
          _state.copyWith(wrongAttempts: attempts, suggestions: const []);
      _feedback('Yanlış cevap.', false);
      return;
    }

    if (_alreadyFound(player)) {
      _feedback('Bu oyuncuyu zaten buldun.', false);
      return;
    }

    final foundPlayers = List<Player>.from(_state.foundPlayers)..add(player);
    final ids = Set<int>.from(_state.foundPlayerIds)..add(player.id);

    final completed = ids.length >= _state.matchingPlayers.length;

    _state = _state.copyWith(
      score: _state.score + 1,
      foundPlayers: foundPlayers,
      foundPlayerIds: ids,
      suggestions: const [],
    );

    _feedback(completed ? 'Tüm oyuncular bulundu! 🎉' : 'Doğru!', true);

    if (completed) {
      _finish();
    }
  }

  Future<void> _finish() async {
    _clockTimer?.cancel();

    final streak = await DailyChallengeService.recordCompletion(_state.score);

    _state = _state.copyWith(isFinished: true, streak: streak);
    notifyListeners();
  }
}