import 'match_entity.dart';
import 'player.dart';

class StreakState {
  final int streak;
  final int lives;
  final int hintsLeft;
  final int secondsLeft;

  final bool isLoading;
  final bool isGameOver;

  final MatchEntity? entity1;
  final MatchEntity? entity2;

  final List<Player> matchingPlayers;
  final List<Player> suggestions;
  final Set<String> wrongAttempts;

  final String? feedback;
  final bool feedbackIsSuccess;

  const StreakState({
    this.streak = 0,
    this.lives = 3,
    this.hintsLeft = 3,
    this.secondsLeft = 20,
    this.isLoading = true,
    this.isGameOver = false,
    this.entity1,
    this.entity2,
    this.matchingPlayers = const [],
    this.suggestions = const [],
    this.wrongAttempts = const {},
    this.feedback,
    this.feedbackIsSuccess = true,
  });

  StreakState copyWith({
    int? streak,
    int? lives,
    int? hintsLeft,
    int? secondsLeft,
    bool? isLoading,
    bool? isGameOver,
    MatchEntity? entity1,
    MatchEntity? entity2,
    List<Player>? matchingPlayers,
    List<Player>? suggestions,
    Set<String>? wrongAttempts,
    String? feedback,
    bool? feedbackIsSuccess,
  }) {
    return StreakState(
      streak: streak ?? this.streak,
      lives: lives ?? this.lives,
      hintsLeft: hintsLeft ?? this.hintsLeft,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      isLoading: isLoading ?? this.isLoading,
      isGameOver: isGameOver ?? this.isGameOver,
      entity1: entity1 ?? this.entity1,
      entity2: entity2 ?? this.entity2,
      matchingPlayers: matchingPlayers ?? this.matchingPlayers,
      suggestions: suggestions ?? this.suggestions,
      wrongAttempts: wrongAttempts ?? this.wrongAttempts,
      feedback: feedback,
      feedbackIsSuccess: feedbackIsSuccess ?? this.feedbackIsSuccess,
    );
  }
}