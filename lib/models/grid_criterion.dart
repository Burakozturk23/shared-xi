import 'club.dart';
import 'player.dart';

enum GridCriterionType { club, country, position, goals }

class GridCriterion {
  final GridCriterionType type;
  final String label;

  final int? clubId;
  final String? countryName;
  final String? position;
  final int? minGoals;

  const GridCriterion._({
    required this.type,
    required this.label,
    this.clubId,
    this.countryName,
    this.position,
    this.minGoals,
  });

  factory GridCriterion.club(Club club) => GridCriterion._(
        type: GridCriterionType.club,
        label: club.name,
        clubId: club.id,
      );

  factory GridCriterion.country(String country) => GridCriterion._(
        type: GridCriterionType.country,
        label: country,
        countryName: country,
      );

  factory GridCriterion.position(String position, String label) =>
      GridCriterion._(
        type: GridCriterionType.position,
        label: label,
        position: position,
      );

  factory GridCriterion.goals(int minGoals) => GridCriterion._(
        type: GridCriterionType.goals,
        label: '$minGoals+ Kariyer Golü',
        minGoals: minGoals,
      );

  bool matches(Player player) {
    switch (type) {
      case GridCriterionType.club:
        return player.clubs.contains(clubId);
      case GridCriterionType.country:
        return player.countries.contains(countryName);
      case GridCriterionType.position:
        return player.position == position;
      case GridCriterionType.goals:
        return player.careerGoals >= (minGoals ?? 0);
    }
  }
}

const List<({String value, String label})> gridPositions = [
  (value: 'Goalkeeper', label: 'Kaleci'),
  (value: 'Defender', label: 'Defans'),
  (value: 'Midfield', label: 'Orta Saha'),
  (value: 'Attack', label: 'Forvet'),
];

const List<int> gridGoalThresholds = [50, 100, 150, 200];