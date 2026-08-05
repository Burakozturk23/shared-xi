import 'club.dart';
import 'player.dart';

class GuessThePlayerState {
  final bool isLoading;
  final Club? club;
  final List<Player> foundPlayers;
  final Set<int> usedPlayerIds;

  final String? feedback;
  final bool feedbackSuccess;

  const GuessThePlayerState({
    this.isLoading = true,
    this.club,
    this.foundPlayers = const [],
    this.usedPlayerIds = const {},
    this.feedback,
    this.feedbackSuccess = true,
  });

  int get totalScore => foundPlayers.length;

  GuessThePlayerState copyWith({
    bool? isLoading,
    Club? club,
    List<Player>? foundPlayers,
    Set<int>? usedPlayerIds,
    String? feedback,
    bool? feedbackSuccess,
  }) {
    return GuessThePlayerState(
      isLoading: isLoading ?? this.isLoading,
      club: club ?? this.club,
      foundPlayers: foundPlayers ?? this.foundPlayers,
      usedPlayerIds: usedPlayerIds ?? this.usedPlayerIds,
      feedback: feedback,
      feedbackSuccess: feedbackSuccess ?? this.feedbackSuccess,
    );
  }
}