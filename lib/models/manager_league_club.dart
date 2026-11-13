import 'club.dart';

/// A real club of the solo Club Manager league (lib/data/manager_league_clubs.dart).
class ManagerLeagueClub {
  const ManagerLeagueClub({
    required this.id,
    required this.name,
    required this.league,
    this.badgeKey,
    this.color,
    required this.rating,
    this.forwards = const [],
    this.midfielders = const [],
  });

  final int id;
  final String name, league;
  final String? badgeKey;
  final int? color;

  /// Average gameplay rating of the club's best known XI, every era.
  final double rating;

  /// Its best known forwards and midfielders: the scorers in a match report.
  final List<String> forwards, midfielders;

  Club get club => Club(
    id: id,
    name: name,
    league: league,
    country: '',
    logo: '',
    badgeKey: badgeKey,
    color: color,
  );
}
