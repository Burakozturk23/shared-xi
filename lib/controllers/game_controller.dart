import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/game_state.dart';
import '../models/match_entity.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/game_service.dart';

class GameController extends ChangeNotifier {
  final MatchEntity entity1;
  final MatchEntity entity2;

  GameController({
    required this.entity1,
    required this.entity2,
  });

  GameState _state = const GameState();

  GameState get state => _state;

  Timer? _feedbackTimer;

  void initialize() {
    final players = Repository.instance.players;

    final matchingPlayers = GameService.matchingPlayers(
      players: players,
      entity1: entity1,
      entity2: entity2,
    );

    _state = _state.copyWith(
      isLoading: false,
      matchingPlayers: matchingPlayers,
    );

    notifyListeners();
  }

  void disposeController() {
    _feedbackTimer?.cancel();
  }

  void finishManually() {
    _state = _state.copyWith(isCompleted: true);
    notifyListeners();
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

  Player? findPlayer(String answer) {
    return GameService.findPlayer(
      matchingPlayers: _state.matchingPlayers,
      answer: answer,
    );
  }

  bool _alreadyFound(Player player) {
    return _state.foundPlayerIds.contains(player.id);
  }

  bool _alreadyTried(String answer) {
    return _state.wrongAttempts.contains(answer);
  }

  void _feedback(String message, bool success) {
    _feedbackTimer?.cancel();

    _state = _state.copyWith(feedback: message, feedbackIsSuccess: success);
    notifyListeners();

    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      _state = _state.copyWith(feedback: null);
      notifyListeners();
    });
  }

  void _correctAnswer(Player player) {
    final foundPlayers = List<Player>.from(_state.foundPlayers)..add(player);
    final ids = Set<int>.from(_state.foundPlayerIds)..add(player.id);

    final completed = ids.length >= _state.matchingPlayers.length;

    _state = _state.copyWith(
      score: _state.score + 1,
      foundPlayers: foundPlayers,
      foundPlayerIds: ids,
      suggestions: const [],
      isCompleted: completed,
    );

    _feedback(completed ? "Tüm oyuncular bulundu! 🎉" : "Doğru!", true);
  }

  void _wrongAnswer(String answer) {
    final attempts = Set<String>.from(_state.wrongAttempts)..add(answer);

    _state = _state.copyWith(
      wrongAttempts: attempts,
      suggestions: const [],
    );

    _feedback("Yanlış cevap.", false);
  }

  void submitAnswer(String answer) {
    final player = findPlayer(answer);

    if (player == null) {
      if (_alreadyTried(answer)) {
        _feedback("Bu tahmini zaten yaptın.", false);
        return;
      }

      _wrongAnswer(answer);
      return;
    }

    if (_alreadyFound(player)) {
      _feedback("Bu oyuncuyu zaten buldun.", false);
      return;
    }

    _correctAnswer(player);
  }
}