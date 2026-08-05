import 'package:flutter/foundation.dart';

import 'player.dart';

@immutable
class GameState {
  final int score;

  final bool isLoading;
  final bool isCompleted;

  final List<Player> matchingPlayers;
  final List<Player> suggestions;
  final List<Player> foundPlayers;
  final Set<int> foundPlayerIds;
  final Set<String> wrongAttempts;

  final String? feedback;
  final bool feedbackIsSuccess;

  const GameState({
    this.score = 0,
    this.isLoading = true,
    this.isCompleted = false,
    this.matchingPlayers = const [],
    this.suggestions = const [],
    this.foundPlayers = const [],
    this.foundPlayerIds = const {},
    this.wrongAttempts = const {},
    this.feedback,
    this.feedbackIsSuccess = true,
  });

  GameState copyWith({
    int? score,
    bool? isLoading,
    bool? isCompleted,
    List<Player>? matchingPlayers,
    List<Player>? suggestions,
    List<Player>? foundPlayers,
    Set<int>? foundPlayerIds,
    Set<String>? wrongAttempts,
    String? feedback,
    bool? feedbackIsSuccess,
  }) {
    return GameState(
      score: score ?? this.score,
      isLoading: isLoading ?? this.isLoading,
      isCompleted: isCompleted ?? this.isCompleted,
      matchingPlayers: matchingPlayers ?? this.matchingPlayers,
      suggestions: suggestions ?? this.suggestions,
      foundPlayers: foundPlayers ?? this.foundPlayers,
      foundPlayerIds: foundPlayerIds ?? this.foundPlayerIds,
      wrongAttempts: wrongAttempts ?? this.wrongAttempts,
      feedback: feedback,
      feedbackIsSuccess: feedbackIsSuccess ?? this.feedbackIsSuccess,
    );
  }
}