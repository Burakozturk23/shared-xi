import 'player.dart';
import 'player_journey.dart';

class PlayerJourneyState {
  final bool isLoading;
  final PlayerJourneyDefinition? journey;
  final int currentStageIndex;
  final List<List<Player>> foundPerStage;
  final bool isJourneyComplete;

  final String? feedback;
  final bool feedbackSuccess;

  const PlayerJourneyState({
    this.isLoading = true,
    this.journey,
    this.currentStageIndex = 0,
    this.foundPerStage = const [],
    this.isJourneyComplete = false,
    this.feedback,
    this.feedbackSuccess = true,
  });

  PlayerJourneyState copyWith({
    bool? isLoading,
    PlayerJourneyDefinition? journey,
    int? currentStageIndex,
    List<List<Player>>? foundPerStage,
    bool? isJourneyComplete,
    String? feedback,
    bool? feedbackSuccess,
  }) {
    return PlayerJourneyState(
      isLoading: isLoading ?? this.isLoading,
      journey: journey ?? this.journey,
      currentStageIndex: currentStageIndex ?? this.currentStageIndex,
      foundPerStage: foundPerStage ?? this.foundPerStage,
      isJourneyComplete: isJourneyComplete ?? this.isJourneyComplete,
      feedback: feedback,
      feedbackSuccess: feedbackSuccess ?? this.feedbackSuccess,
    );
  }
}