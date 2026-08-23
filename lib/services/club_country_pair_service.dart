import 'dart:math';

import '../models/club.dart';
import '../repositories/repository.dart';
import '../utils/country_names.dart';
import 'team_pair_service.dart';

class ClubCountryPair {
  final Club club;
  final String country;
  final List<int> commonPlayerIds;

  const ClubCountryPair({
    required this.club,
    required this.country,
    required this.commonPlayerIds,
  });
}

/// Kulüp × ülke kesişimi (ortak oyuncu garantili).
class ClubCountryPairService {
  ClubCountryPairService._();

  static final _random = Random();

  static ClubCountryPair? pickValidPair({
    int minCommon = 4,
    int preferredCommon = 8,
    int maxAttempts = 250,
  }) {
    final clubs = Repository.instance.clubs;
    final players = Repository.instance.players;
    if (clubs.isEmpty || players.isEmpty) return null;

    final popular = clubs.where(TeamPairService.isPopular).toList();
    final pool = popular.length >= 8 ? popular : List<Club>.from(clubs);

    // Ülke frekansı
    final countryCount = <String, int>{};
    for (final p in players) {
      for (final c in p.countries) {
        final name = CountryNames.canonical(c);
        if (name.isEmpty) continue;
        countryCount[name] = (countryCount[name] ?? 0) + 1;
      }
    }
    final countries = countryCount.entries
        .where((e) => e.value >= minCommon)
        .map((e) => e.key)
        .toList();
    if (countries.isEmpty) return null;

    ClubCountryPair? best;
    var bestCount = 0;

    for (var i = 0; i < maxAttempts; i++) {
      final club = pool[_random.nextInt(pool.length)];
      final country = countries[_random.nextInt(countries.length)];
      final common = <int>[];
      for (final p in players) {
        if (p.name.trim().isEmpty) continue;
        if (!p.clubs.contains(club.id)) continue;
        final hasCountry = p.countries.any(
          (c) => CountryNames.canonical(c) == country,
        );
        if (hasCountry) common.add(p.id);
      }
      if (common.length < minCommon) continue;
      if (common.length >= preferredCommon) {
        return ClubCountryPair(
          club: club,
          country: country,
          commonPlayerIds: common,
        );
      }
      if (common.length > bestCount) {
        bestCount = common.length;
        best = ClubCountryPair(
          club: club,
          country: country,
          commonPlayerIds: common,
        );
      }
    }

    if (best != null) return best;

    for (var i = 0; i < 80; i++) {
      final club = pool[_random.nextInt(pool.length)];
      final country = countries[_random.nextInt(countries.length)];
      final common = <int>[];
      for (final p in players) {
        if (p.name.trim().isEmpty) continue;
        if (!p.clubs.contains(club.id)) continue;
        final hasCountry = p.countries.any(
          (c) => CountryNames.canonical(c) == country,
        );
        if (hasCountry) common.add(p.id);
      }
      if (common.length >= 3) {
        return ClubCountryPair(
          club: club,
          country: country,
          commonPlayerIds: common,
        );
      }
    }
    return null;
  }
}
