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

  /// Autocomplete listesi
  final List<Player> suggestions;

  /// 0 = hiç, 1 = ülke, 2 = mevki, 3 = baş harfler
  final int hintsUsed;

  /// İpucu verilen (henüz bulunmamış) hedef oyuncu
  final Player? hintTarget;

  const PlayerJourneyState({
    this.isLoading = true,
    this.journey,
    this.currentStageIndex = 0,
    this.foundPerStage = const [],
    this.isJourneyComplete = false,
    this.feedback,
    this.feedbackSuccess = true,
    this.suggestions = const [],
    this.hintsUsed = 0,
    this.hintTarget,
  });

  PlayerJourneyState copyWith({
    bool? isLoading,
    PlayerJourneyDefinition? journey,
    int? currentStageIndex,
    List<List<Player>>? foundPerStage,
    bool? isJourneyComplete,
    String? feedback,
    bool? feedbackSuccess,
    List<Player>? suggestions,
    int? hintsUsed,
    Player? hintTarget,
    bool clearHintTarget = false,
    bool clearFeedback = false,
  }) {
    return PlayerJourneyState(
      isLoading: isLoading ?? this.isLoading,
      journey: journey ?? this.journey,
      currentStageIndex: currentStageIndex ?? this.currentStageIndex,
      foundPerStage: foundPerStage ?? this.foundPerStage,
      isJourneyComplete: isJourneyComplete ?? this.isJourneyComplete,
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      feedbackSuccess: feedbackSuccess ?? this.feedbackSuccess,
      suggestions: suggestions ?? this.suggestions,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      hintTarget:
          clearHintTarget ? null : (hintTarget ?? this.hintTarget),
    );
  }
}