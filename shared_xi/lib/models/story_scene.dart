enum StorySceneType { commonPlayers, namedAnswer }

class StoryScene {
  final String title;
  final String taskDescription;
  final StorySceneType type;

  final String? sceneNarrative;
  final String? matchLabel;

  final int? clubIdA;
  final List<int> clubIdBOptions;
  final int requiredFinds;

  final List<String> correctAnswers;

  const StoryScene._({
    required this.title,
    required this.taskDescription,
    required this.type,
    this.sceneNarrative,
    this.matchLabel,
    this.clubIdA,
    this.clubIdBOptions = const [],
    this.requiredFinds = 1,
    this.correctAnswers = const [],
  });

  factory StoryScene.commonPlayers({
    required String title,
    required String taskDescription,
    required int clubIdA,
    required List<int> clubIdBOptions,
    int requiredFinds = 1,
    String? sceneNarrative,
    String? matchLabel,
  }) {
    return StoryScene._(
      title: title,
      taskDescription: taskDescription,
      type: StorySceneType.commonPlayers,
      clubIdA: clubIdA,
      clubIdBOptions: clubIdBOptions,
      requiredFinds: requiredFinds,
      sceneNarrative: sceneNarrative,
      matchLabel: matchLabel,
    );
  }

  factory StoryScene.namedAnswer({
    required String title,
    required String taskDescription,
    required List<String> correctAnswers,
    String? sceneNarrative,
    String? matchLabel,
  }) {
    return StoryScene._(
      title: title,
      taskDescription: taskDescription,
      type: StorySceneType.namedAnswer,
      correctAnswers: correctAnswers,
      requiredFinds: correctAnswers.length,
      sceneNarrative: sceneNarrative,
      matchLabel: matchLabel,
    );
  }
}

class StoryChapter {
  final int number;
  final String title;
  final String narrative;
  final String? matchLabel;
  final List<StoryScene> scenes;

  const StoryChapter({
    required this.number,
    required this.title,
    required this.narrative,
    this.matchLabel,
    required this.scenes,
  });
}