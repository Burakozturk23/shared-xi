import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/match_entity.dart';
import '../models/streak_state.dart';
import '../repositories/repository.dart';
import '../services/game_service.dart';
import '../services/high_score_service.dart';

class StreakController extends ChangeNotifier {
  static const int _roundSeconds = 20;
  static const String highScoreKey = "streak_high_score";

  StreakState _state = const StreakState();
  StreakState get state => _state;

  final Random _random = Random();

  Timer? _timer;
  Timer? _feedbackTimer;

  void initialize() {
    _nextRound(resetLivesAndStreak: true);
  }

  void disposeController() {
    _timer?.cancel();
    _feedbackTimer?.cancel();
  }

  void _nextRound({bool resetLivesAndStreak = false}) {
    final clubs = Repository.instance.clubs;
    final players = Repository.instance.players;

    var attempts = 0;

    while (attempts < 300) {
      attempts++;

      final club1 = clubs[_random.nextInt(clubs.length)];
      final club2 = clubs[_random.nextInt(clubs.length)];

      if (club1.id == club2.id) continue;

      final entity1 = MatchEntity.club(club1);
      final entity2 = MatchEntity.club(club2);

      final found = GameService.matchingPlayers(
        players: players,
        entity1: entity1,
        entity2: entity2,
      );

      if (found.isNotEmpty) {
        _timer?.cancel();

        _state = _state.copyWith(
          isLoading: false,
          streak: resetLivesAndStreak ? 0 : _state.streak,
          lives: resetLivesAndStreak ? 3 : _state.lives,
          hintsLeft: resetLivesAndStreak ? 3 : _state.hintsLeft,
          isGameOver: false,
          entity1: entity1,
          entity2: entity2,
          matchingPlayers: found,
          suggestions: const [],
          wrongAttempts: const {},
          secondsLeft: _roundSeconds,
        );

        _startTimer();
        notifyListeners();
        return;
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state.isGameOver) return;

      if (_state.secondsLeft <= 1) {
        _timeUp();
        return;
      }

      _state = _state.copyWith(secondsLeft: _state.secondsLeft - 1);
      notifyListeners();
    });
  }

  void _timeUp() {
    final lives = _state.lives - 1;
    _state = _state.copyWith(lives: lives);

    if (lives <= 0) {
      _finishGame();
      return;
    }

    _feedback("Süre doldu!", false);
    _nextRound();
  }

  Future<void> _finishGame() async {
    _timer?.cancel();

    _state = _state.copyWith(isGameOver: true);
    notifyListeners();

    await HighScoreService.saveHighScore(_state.streak, key: highScoreKey);
  }

  void updateSuggestions(String query) {
    final suggestions = GameService.suggestions(
      matchingPlayers: _state.matchingPlayers,
      query: query,
      foundIds: const {},
    );

    _state = _state.copyWith(suggestions: suggestions);
    notifyListeners();
  }

  void _feedback(String message, bool success) {
    _feedbackTimer?.cancel();

    _state = _state.copyWith(feedback: message, feedbackIsSuccess: success);
    notifyListeners();

    _feedbackTimer = Timer(const Duration(milliseconds: 1200), () {
      _state = _state.copyWith(feedback: null);
      notifyListeners();
    });
  }

  void submitAnswer(String answer) {
    if (_state.isGameOver) return;

    final player = GameService.findPlayer(
      matchingPlayers: _state.matchingPlayers,
      answer: answer,
    );

    if (player == null) {
      if (_state.wrongAttempts.contains(answer)) {
        _feedback("Bu tahmini zaten yaptın.", false);
        return;
      }

      final attempts = Set<String>.from(_state.wrongAttempts)..add(answer);
      final lives = _state.lives - 1;

      _state = _state.copyWith(
        lives: lives,
        wrongAttempts: attempts,
        suggestions: const [],
      );

      _feedback("Yanlış cevap.", false);

      if (lives <= 0) {
        _finishGame();
      }
      return;
    }

    final streak = _state.streak + 1;
    _state = _state.copyWith(streak: streak);
    _feedback("Doğru! Seri: $streak", true);
    _nextRound();
  }

  void useHint() {
    if (_state.isLoading || _state.isGameOver || _state.hintsLeft <= 0) return;

    final player = GameService.hint(
      matchingPlayers: _state.matchingPlayers,
      foundIds: const {},
    );

    if (player == null) return;

    final firstLetter =
        player.name.trim().isNotEmpty ? player.name.trim()[0] : '?';

    _state = _state.copyWith(hintsLeft: _state.hintsLeft - 1);
    _feedback("İpucu: $firstLetter ile başlıyor.", true);
  }
}