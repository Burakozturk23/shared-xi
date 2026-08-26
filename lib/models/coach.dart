import '../utils/country_names.dart';

/// Teknik direktor — Passaparola / trivia / ileride koc modlari.
class Coach {
  final String id;
  final String name;
  final List<String> countries;
  final List<int> clubIds;
  final List<String> aliases;
  final String? avatarKey;
  final double? rating;

  const Coach({
    required this.id,
    required this.name,
    required this.countries,
    required this.clubIds,
    this.aliases = const [],
    this.avatarKey,
    this.rating,
  });

  factory Coach.fromJson(Map<String, dynamic> json) {
    final countriesJson = json['countries'] as List<dynamic>? ?? [];
    final clubsJson =
        (json['clubIds'] as List<dynamic>?) ?? (json['clubs'] as List<dynamic>?) ?? [];
    final aliasesJson = json['aliases'] as List<dynamic>? ?? [];

    return Coach(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      countries: CountryNames.canonicalList(
        countriesJson.map((e) => e.toString()),
      ),
      clubIds: clubsJson.map((e) => (e as num).toInt()).toList(),
      aliases: aliasesJson.map((e) => e.toString()).toList(),
      avatarKey: json['avatarKey']?.toString(),
      rating: (json['rating'] as num?)?.toDouble(),
    );
  }
}
