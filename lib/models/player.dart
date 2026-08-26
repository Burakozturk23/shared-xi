import '../utils/country_names.dart';
import 'career_stop.dart';

class Player {
  final int id;
  final String name;
  final List<String> countries;
  final String position;
  final String detailedPosition;

  /// Kariyer kulup id listesi (Shared XI / eslesme icin kritik)
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

  /// Ileride assets/avatars/{avatarKey}.webp
  final String? avatarKey;

  /// PlayerElo vb. — yoksa null. marketValue bos ise UI rating kullanabilir.
  final double? rating;

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
    this.avatarKey,
    this.rating,
  });

  String get countryLabel => countries.join(', ');

  /// Min sema uyumu
  List<int> get clubIds => clubs;

  factory Player.fromJson(Map<String, dynamic> json) {
    // min: clubIds | legacy: clubs (+ timeline)
    final clubsJson =
        (json['clubIds'] as List<dynamic>?) ?? (json['clubs'] as List<dynamic>?) ?? [];
    final nationalJson = json['nationalTeams'] as List<dynamic>? ?? [];
    final aliasesJson = json['aliases'] as List<dynamic>? ?? [];
    final countriesJson = json['countries'] as List<dynamic>? ?? [];
    final normalizedAliasesJson =
        json['normalizedAliases'] as List<dynamic>? ?? [];
    final timelineJson = json['careerTimeline'] as List<dynamic>? ?? [];

    final name = json['name']?.toString() ?? '';
    final position = json['position']?.toString() ?? '';
    final detailed = json['detailedPosition']?.toString() ?? '';
    final rating = (json['rating'] as num?)?.toDouble();
    final market = (json['marketValue'] as num?)?.toDouble() ?? 0;
    final peak = (json['peakMarketValue'] as num?)?.toDouble() ?? 0;

    final clubSet = <int>{
      for (final e in clubsJson) (e as num).toInt(),
      for (final e in timelineJson)
        if (e is Map && e['clubId'] != null) (e['clubId'] as num).toInt(),
    };

    final aliases = aliasesJson.map((e) => e.toString()).toList();
    final normalizedName = json['normalizedName']?.toString() ??
        name.toLowerCase().trim();
    final normalizedAliases = normalizedAliasesJson.isNotEmpty
        ? normalizedAliasesJson.map((e) => e.toString()).toList()
        : aliases.map((a) => a.toLowerCase().trim()).toList();

    return Player(
      id: (json['id'] as num).toInt(),
      name: name,
      countries: CountryNames.canonicalList(
        countriesJson.map((e) => e.toString()),
      ),
      position: position,
      detailedPosition: detailed.isNotEmpty ? detailed : position,
      clubs: clubSet.toList(),
      nationalTeams: nationalJson.map((e) => (e as num).toInt()).toList(),
      primaryNationalTeamId: (json['primaryNationalTeamId'] as num?)?.toInt(),
      aliases: aliases,
      normalizedName: normalizedName,
      normalizedAliases: normalizedAliases,
      // rating varsa ve market yoksa soft bridge (Higher/Lower kirilmasin)
      marketValue: market > 0 ? market : (rating ?? 0),
      peakMarketValue: peak > 0 ? peak : (rating ?? 0),
      careerGoals: (json['careerGoals'] as num?)?.toInt() ?? 0,
      careerTimeline: timelineJson
          .whereType<Map>()
          .map((e) => CareerStop.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      avatarKey: json['avatarKey']?.toString(),
      rating: rating,
    );
  }
}
