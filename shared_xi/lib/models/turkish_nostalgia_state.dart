import 'player.dart';

class TurkishNostalgiaState {
  final bool isLoading;
  final int currentChapterIndex;
  final int currentSceneIndex;

  final List<Player> foundThisScene;
  final Set<String> matchedAnswersThisScene;

  final bool isComplete;

  final String? feedback;
  final bool feedbackSuccess;

  const TurkishNostalgiaState({
    this.isLoading = true,
    this.currentChapterIndex = 0,
    this.currentSceneIndex = 0,
    this.foundThisScene = const [],
    this.matchedAnswersThisScene = const {},
    this.isComplete = false,
    this.feedback,
    this.feedbackSuccess = true,
  });

  TurkishNostalgiaState copyWith({
    bool? isLoading,
    int? currentChapterIndex,
    int? currentSceneIndex,
    List<Player>? foundThisScene,
    Set<String>? matchedAnswersThisScene,
    bool? isComplete,
    String? feedback,
    bool? feedbackSuccess,
  }) {
    return TurkishNostalgiaState(
      isLoading: isLoading ?? this.isLoading,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      currentSceneIndex: currentSceneIndex ?? this.currentSceneIndex,
      foundThisScene: foundThisScene ?? this.foundThisScene,
      matchedAnswersThisScene:
          matchedAnswersThisScene ?? this.matchedAnswersThisScene,
      isComplete: isComplete ?? this.isComplete,
      feedback: feedback,
      feedbackSuccess: feedbackSuccess ?? this.feedbackSuccess,
    );
  }
}