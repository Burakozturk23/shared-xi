import 'club.dart';

enum MatchEntityType { club, country }

class MatchEntity {
  final MatchEntityType type;
  final String displayName;

  final int? clubId;
  final String? logoUrl;

  final String? countryName;

  const MatchEntity._({
    required this.type,
    required this.displayName,
    this.clubId,
    this.logoUrl,
    this.countryName,
  });

  factory MatchEntity.club(Club club) {
    return MatchEntity._(
      type: MatchEntityType.club,
      displayName: club.name,
      clubId: club.id,
      logoUrl: club.logo,
    );
  }

  factory MatchEntity.country(String name) {
    return MatchEntity._(
      type: MatchEntityType.country,
      displayName: name,
      countryName: name,
    );
  }
}