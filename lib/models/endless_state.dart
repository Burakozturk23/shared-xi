import 'match_entity.dart';
import 'player.dart';

class EndlessState {
  final int streak;
  final double score;
  final int bestScore;
  final int lives;
  final int secondsLeft;
  final int skipsLeft;

  final bool isLoading;
  final bool isGameOver;

  final MatchEntity? entity1;
  final MatchEntity? entity2;

  final List<Player> matchingPlayers;
  final List<Player> suggestions;
  final List<Player> foundPlayers;
  final Set<int> foundPlayerIds;
  final Set<String> wrongAttempts;

  final String? feedback;
  final bool feedbackIsSuccess;

  const EndlessState({
    this.streak = 0,
    this.score = 0,
    this.bestScore = 0,
    this.lives = 5,
    this.secondsLeft = 60,
    this.skipsLeft = 2,
    this.isLoading = true,
    this.isGameOver = false,
    this.entity1,
    this.entity2,
    this.matchingPlayers = const [],
    this.suggestions = const [],
    this.foundPlayers = const [],
    this.foundPlayerIds = const {},
    this.wrongAttempts = const {},
    this.feedback,
    this.feedbackIsSuccess = true,
  });

  double get multiplier => 1.0 + 0.5 * (streak ~/ 5);

  EndlessState copyWith({
    int? streak,
    double? score,
    int? bestScore,
    int? lives,
    int? secondsLeft,
    int? skipsLeft,
    bool? isLoading,
    bool? isGameOver,
    MatchEntity? entity1,
    MatchEntity? entity2,
    List<Player>? matchingPlayers,
    List<Player>? suggestions,
    List<Player>? foundPlayers,
    Set<int>? foundPlayerIds,
    Set<String>? wrongAttempts,
    String? feedback,
    bool? feedbackIsSuccess,
  }) {
    return EndlessState(
      streak: streak ?? this.streak,
      score: score ?? this.score,
      bestScore: bestScore ?? this.bestScore,
      lives: lives ?? this.lives,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      skipsLeft: skipsLeft ?? this.skipsLeft,
      isLoading: isLoading ?? this.isLoading,
      isGameOver: isGameOver ?? this.isGameOver,
      entity1: entity1 ?? this.entity1,
      entity2: entity2 ?? this.entity2,
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