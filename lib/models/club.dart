import '../utils/country_names.dart';
class Club {
  final int id;
  final String name;
  final String league;
  final String country;
  final String logo;

  const Club({
    required this.id,
    required this.name,
    required this.league,
    required this.country,
    required this.logo,
  });

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      league: json['league']?.toString() ?? '',
      country: CountryNames.canonical(json['country']?.toString() ?? ''),
      logo: json['logo']?.toString() ?? '',
    );
  }
}