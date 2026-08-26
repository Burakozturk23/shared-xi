import '../utils/country_names.dart';

class Club {
  final int id;
  final String name;
  final String league;
  final String country;

  /// Eski alan — min şemada bos. UI logo URL kullanmamali.
  final String logo;

  /// Ileride assets/badges/{badgeKey}.webp
  final String? badgeKey;

  /// Monogram rengi 0xAARRGGBB (ornek: 0xFFFEBE10)
  final int? color;

  const Club({
    required this.id,
    required this.name,
    required this.league,
    required this.country,
    this.logo = '',
    this.badgeKey,
    this.color,
  });

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      league: json['league']?.toString() ?? '',
      country: CountryNames.canonical(json['country']?.toString() ?? ''),
      logo: json['logo']?.toString() ?? '',
      badgeKey: json['badgeKey']?.toString(),
      color: (json['color'] as num?)?.toInt(),
    );
  }
}
