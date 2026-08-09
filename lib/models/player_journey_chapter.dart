import 'player_journey.dart';

class PlayerJourneyChapter {
  final String id;
  final int number;
  final String title;
  final String subtitle;
  final bool available;
  final List<PlayerJourneyDefinition> journeys;

  const PlayerJourneyChapter({
    required this.id,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.available,
    required this.journeys,
  });
}