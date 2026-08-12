import 'match_entity.dart';
import 'player.dart';
import 'football_calendar_theme.dart';

class DailyChallengeState {
  final bool isLoading;
  final MatchEntity? entity1;
  final MatchEntity? entity2;
  final String label;
  final FootballCalendarTheme? theme;

  final List<Player> matchingPlayers;
  final List<Player> foundPlayers;
  final Set<int> foundPlayerIds;
  final Set<String> wrongAttempts;
  final List<Player> suggestions;

  final int score;
  final int secondsLeft;
  final int livesLeft;
  final int streak;
  final bool isFinished;
  final bool alreadyPlayedToday;

  final String? feedback;
  final bool feedbackIsSuccess;

  const DailyChallengeState({
    this.isLoading = true,
    this.entity1,
    this.entity2,
    this.label = '',
    this.theme,
    this.matchingPlayers = const [],
    this.foundPlayers = const [],
    this.foundPlayerIds = const {},
    this.wrongAttempts = const {},
    this.suggestions = const [],
    this.score = 0,
    this.secondsLeft = 60,
    this.livesLeft = 3,
    this.streak = 0,
    this.isFinished = false,
    this.alreadyPlayedToday = false,
    this.feedback,
    this.feedbackIsSuccess = true,
  });

  double get successRate {
    if (matchingPlayers.isEmpty) return 0;
    final target = theme?.targetFinds ?? matchingPlayers.length;
    final denom = target.clamp(1, matchingPlayers.length);
    return (foundPlayers.length / denom).clamp(0.0, 1.0);
  }

  bool get earnedDerbyBadge => successRate >= 0.80;

  DailyChallengeState copyWith({
    bool? isLoading,
    MatchEntity? entity1,
    MatchEntity? entity2,
    String? label,
    FootballCalendarTheme? theme,
    List<Player>? matchingPlayers,
    List<Player>? foundPlayers,
    Set<int>? foundPlayerIds,
    Set<String>? wrongAttempts,
    List<Player>? suggestions,
    int? score,
    int? secondsLeft,
    int? livesLeft,
    int? streak,
    bool? isFinished,
    bool? alreadyPlayedToday,
    String? feedback,
    bool? feedbackIsSuccess,
  }) {
    return DailyChallengeState(
      isLoading: isLoading ?? this.isLoading,
      entity1: entity1 ?? this.entity1,
      entity2: entity2 ?? this.entity2,
      label: label ?? this.label,
      theme: theme ?? this.theme,
      matchingPlayers: matchingPlayers ?? this.matchingPlayers,
      foundPlayers: foundPlayers ?? this.foundPlayers,
      foundPlayerIds: foundPlayerIds ?? this.foundPlayerIds,
      wrongAttempts: wrongAttempts ?? this.wrongAttempts,
      suggestions: suggestions ?? this.suggestions,
      score: score ?? this.score,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      livesLeft: livesLeft ?? this.livesLeft,
      streak: streak ?? this.streak,
      isFinished: isFinished ?? this.isFinished,
      alreadyPlayedToday: alreadyPlayedToday ?? this.alreadyPlayedToday,
      feedback: feedback,
      feedbackIsSuccess: feedbackIsSuccess ?? this.feedbackIsSuccess,
    );
  }
}