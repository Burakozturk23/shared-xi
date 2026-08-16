import 'package:flutter/foundation.dart';

import 'player.dart';

@immutable
class GameState {
  final int score;
  final int opponentScore;
  final int remainingSeconds;
  final int lives;
  final int totalFoundCount;

  final bool isLoading;
  final bool isCompleted;
  final bool gameOver;

  final String? gameOverReason;
  final String? finalWinner;

  final List<Player> matchingPlayers;
  final List<Player> suggestions;
  final List<Player> foundPlayers;
  final Set<int> foundPlayerIds;
  final Set<String> wrongAttempts;

  final String? feedback;
  final bool feedbackIsSuccess;

  const GameState({
    this.score = 0,
    this.opponentScore = 0,
    this.remainingSeconds = 60,
    this.lives = 3,
    this.totalFoundCount = 0,
    this.isLoading = true,
    this.isCompleted = false,
    this.gameOver = false,
    this.gameOverReason,
    this.finalWinner,
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
    int? opponentScore,
    int? remainingSeconds,
    int? lives,
    int? totalFoundCount,
    bool? isLoading,
    bool? isCompleted,
    bool? gameOver,
    String? gameOverReason,
    String? finalWinner,
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
      opponentScore: opponentScore ?? this.opponentScore,
      remainingSeconds:
          remainingSeconds ?? this.remainingSeconds,
      lives: lives ?? this.lives,
      totalFoundCount: totalFoundCount ?? this.totalFoundCount,
      isLoading: isLoading ?? this.isLoading,
      isCompleted: isCompleted ?? this.isCompleted,
      gameOver: gameOver ?? this.gameOver,
      gameOverReason:
          gameOverReason ?? this.gameOverReason,
      finalWinner: finalWinner ?? this.finalWinner,
      matchingPlayers:
          matchingPlayers ?? this.matchingPlayers,
      suggestions: suggestions ?? this.suggestions,
      foundPlayers: foundPlayers ?? this.foundPlayers,
      foundPlayerIds:
          foundPlayerIds ?? this.foundPlayerIds,
      wrongAttempts:
          wrongAttempts ?? this.wrongAttempts,
      feedback: feedback,
      feedbackIsSuccess:
          feedbackIsSuccess ?? this.feedbackIsSuccess,
    );
  }
}
