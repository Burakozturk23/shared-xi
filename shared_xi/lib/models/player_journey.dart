import 'player.dart';

class PlayerJourneyStage {
  final String title;
  final String subtitle;
  final String narrative;
  final String taskDescription;
  final int requiredFinds;
  final bool Function(Player candidate) isValidTeammate;

  const PlayerJourneyStage({
    required this.title,
    required this.subtitle,
    required this.narrative,
    required this.taskDescription,
    required this.requiredFinds,
    required this.isValidTeammate,
  });
}

class PlayerJourneyDefinition {
  final String id;
  final String subjectName;
  final int subjectPlayerId;
  final bool available;
  final List<PlayerJourneyStage> stages;

  const PlayerJourneyDefinition({
    required this.id,
    required this.subjectName,
    required this.subjectPlayerId,
    required this.available,
    required this.stages,
  });
}