import '../utils/country_names.dart';
import 'career_stop.dart';

class Player {
  final int id;
  final String name;
  final List<String> countries;
  final String position;
  final String detailedPosition;

  final List<int> clubs;
  final List<int> nationalTeams;
  final int? primaryNationalTeamId;

  final List<String> aliases;

  final String normalizedName;
  final List<String> normalizedAliases;

  final double marketValue;
  final double peakMarketValue;
  final int careerGoals;
  final List<CareerStop> careerTimeline;

  const Player({
    required this.id,
    required this.name,
    required this.countries,
    required this.position,
    required this.detailedPosition,
    required this.clubs,
    required this.nationalTeams,
    required this.primaryNationalTeamId,
    required this.aliases,
    required this.normalizedName,
    required this.normalizedAliases,
    required this.marketValue,
    required this.peakMarketValue,
    required this.careerGoals,
    required this.careerTimeline,
  });

  String get countryLabel => countries.join(', ');

  factory Player.fromJson(Map<String, dynamic> json) {
    final clubsJson = json['clubs'] as List<dynamic>? ?? [];
    final nationalJson = json['nationalTeams'] as List<dynamic>? ?? [];
    final aliasesJson = json['aliases'] as List<dynamic>? ?? [];
    final countriesJson = json['countries'] as List<dynamic>? ?? [];
    final normalizedAliasesJson =
        json['normalizedAliases'] as List<dynamic>? ?? [];
    final timelineJson = json['careerTimeline'] as List<dynamic>? ?? [];

    return Player(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      countries: CountryNames.canonicalList(
        countriesJson.map((e) => e.toString()),
      ),
      position: json['position']?.toString() ?? '',
      detailedPosition: json['detailedPosition']?.toString() ?? '',

      // clubs + careerTimeline birleşimi (eksik kulüp ID kaybını önler)
      clubs: {
        for (final e in clubsJson) (e as num).toInt(),
        for (final e in timelineJson)
          if (e is Map && e['clubId'] != null) (e['clubId'] as num).toInt(),
      }.toList(),
      nationalTeams: nationalJson.map((e) => (e as num).toInt()).toList(),
      primaryNationalTeamId: (json['primaryNationalTeamId'] as num?)?.toInt(),

      aliases: aliasesJson.map((e) => e.toString()).toList(),

      normalizedName: json['normalizedName']?.toString() ?? '',
      normalizedAliases:
          normalizedAliasesJson.map((e) => e.toString()).toList(),

      marketValue: (json['marketValue'] as num?)?.toDouble() ?? 0,
      peakMarketValue: (json['peakMarketValue'] as num?)?.toDouble() ?? 0,
      careerGoals: (json['careerGoals'] as num?)?.toInt() ?? 0,

      careerTimeline: timelineJson
          .map((e) => CareerStop.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}