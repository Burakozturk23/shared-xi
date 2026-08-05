import 'club.dart';
import 'player.dart';

class RandomFiveEntry {
  final Player player;
  final List<Club> matchedClubs;

  const RandomFiveEntry({required this.player, required this.matchedClubs});

  int get score => matchedClubs.length;
}

class RandomFiveState {
  final bool isLoading;
  final List<Club> clubs;
  final List<RandomFiveEntry> history;
  final Set<int> usedPlayerIds;

  final String? feedback;
  final bool feedbackSuccess;

  const RandomFiveState({
    this.isLoading = true,
    this.clubs = const [],
    this.history = const [],
    this.usedPlayerIds = const {},
    this.feedback,
    this.feedbackSuccess = true,
  });

  int get totalScore => history.fold(0, (sum, e) => sum + e.score);

  int get bestSingleScore =>
      history.isEmpty ? 0 : history.map((e) => e.score).reduce((a, b) => a > b ? a : b);

  RandomFiveState copyWith({
    bool? isLoading,
    List<Club>? clubs,
    List<RandomFiveEntry>? history,
    Set<int>? usedPlayerIds,
    String? feedback,
    bool? feedbackSuccess,
  }) {
    return RandomFiveState(
      isLoading: isLoading ?? this.isLoading,
      clubs: clubs ?? this.clubs,
      history: history ?? this.history,
      usedPlayerIds: usedPlayerIds ?? this.usedPlayerIds,
      feedback: feedback,
      feedbackSuccess: feedbackSuccess ?? this.feedbackSuccess,
    );
  }
}