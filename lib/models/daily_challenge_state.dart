import 'match_entity.dart';
import 'player.dart';

class DailyChallengeState {
  final int score;
  final int secondsLeft;

  final bool isLoading;
  final bool isFinished;

  final MatchEntity? entity1;
  final MatchEntity? entity2;
  final String label;

  final List<Player> matchingPlayers;
  final List<Player> suggestions;
  final List<Player> foundPlayers;
  final Set<int> foundPlayerIds;
  final Set<String> wrongAttempts;

  final String? feedback;
  final bool feedbackIsSuccess;

  final int streak;

  const DailyChallengeState({
    this.score = 0,
    this.secondsLeft = 90,
    this.isLoading = true,
    this.isFinished = false,
    this.entity1,
    this.entity2,
    this.label = '',
    this.matchingPlayers = const [],
    this.suggestions = const [],
    this.foundPlayers = const [],
    this.foundPlayerIds = const {},
    this.wrongAttempts = const {},
    this.feedback,
    this.feedbackIsSuccess = true,
    this.streak = 0,
  });

  DailyChallengeState copyWith({
    int? score,
    int? secondsLeft,
    bool? isLoading,
    bool? isFinished,
    MatchEntity? entity1,
    MatchEntity? entity2,
    String? label,
    List<Player>? matchingPlayers,
    List<Player>? suggestions,
    List<Player>? foundPlayers,
    Set<int>? foundPlayerIds,
    Set<String>? wrongAttempts,
    String? feedback,
    bool? feedbackIsSuccess,
    int? streak,
  }) {
    return DailyChallengeState(
      score: score ?? this.score,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      isLoading: isLoading ?? this.isLoading,
      isFinished: isFinished ?? this.isFinished,
      entity1: entity1 ?? this.entity1,
      entity2: entity2 ?? this.entity2,
      label: label ?? this.label,
      matchingPlayers: matchingPlayers ?? this.matchingPlayers,
      suggestions: suggestions ?? this.suggestions,
      foundPlayers: foundPlayers ?? this.foundPlayers,
      foundPlayerIds: foundPlayerIds ?? this.foundPlayerIds,
      wrongAttempts: wrongAttempts ?? this.wrongAttempts,
      feedback: feedback,
      feedbackIsSuccess: feedbackIsSuccess ?? this.feedbackIsSuccess,
      streak: streak ?? this.streak,
    );
  }
}