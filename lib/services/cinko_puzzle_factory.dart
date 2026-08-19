import 'dart:math';

import '../data/cinko_pool.dart';
import '../data/popular_clubs_pool.dart';
import '../models/cinko_models.dart';
import '../models/club.dart';

class CinkoPuzzleFactory {
  CinkoPuzzleFactory._();

  static final _rng = Random();
  static const int gridSize = 5;

  static List<CinkoCell> generate({int size = gridSize}) {
    final n = size * size;
    final clubs = PopularClubs.resolveAll();
    final countries = List<String>.from(cinkoFamousCountries);
    final leagues = List<String>.from(cinkoFamousLeagues);

    clubs.shuffle(_rng);
    countries.shuffle(_rng);
    leagues.shuffle(_rng);

    final clubCount = (n * 0.60).round().clamp(1, clubs.length);
    final countryCount = (n * 0.20).round().clamp(0, countries.length);
    var leagueCount = n - clubCount - countryCount;
    if (leagueCount > leagues.length) leagueCount = leagues.length;

    final cells = <CinkoCell>[];
    final usedLabels = <String>{};

    void addClub(Club c) {
      final key = 'club_${c.id}';
      if (usedLabels.contains(key)) return;
      usedLabels.add(key);
      cells.add(CinkoCell(
        id: key,
        type: CinkoCellType.club,
        label: c.name,
        logoUrl: c.logo,
        clubId: c.id,
      ));
    }

    void addCountry(String name) {
      final key = 'country_$name';
      if (usedLabels.contains(key)) return;
      usedLabels.add(key);
      cells.add(CinkoCell(
        id: key,
        type: CinkoCellType.country,
        label: name,
      ));
    }

    void addLeague(String name) {
      final key = 'league_$name';
      if (usedLabels.contains(key)) return;
      usedLabels.add(key);
      cells.add(CinkoCell(
        id: key,
        type: CinkoCellType.league,
        label: name,
      ));
    }

    for (var i = 0; i < clubCount && i < clubs.length; i++) {
      addClub(clubs[i]);
    }
    for (var i = 0; i < countryCount && i < countries.length; i++) {
      addCountry(countries[i]);
    }
    for (var i = 0; i < leagueCount && i < leagues.length; i++) {
      addLeague(leagues[i]);
    }
    var ci = clubCount;
    while (cells.length < n && ci < clubs.length) {
      addClub(clubs[ci]);
      ci++;
    }
    cells.shuffle(_rng);
    return cells.take(n).toList();
  }

  static List<Map<String, dynamic>> cellsToSeed(List<CinkoCell> cells) =>
      cells.map((c) {
        return {
          'id': c.id,
          'type': c.type.name,
          'label': c.label,
          if (c.logoUrl != null) 'logoUrl': c.logoUrl,
          if (c.clubId != null) 'clubId': c.clubId,
        };
      }).toList();

  static List<CinkoCell> cellsFromSeed(List<dynamic> raw) {
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final typeName = m['type']?.toString() ?? 'club';
      final type = CinkoCellType.values.firstWhere(
        (t) => t.name == typeName,
        orElse: () => CinkoCellType.club,
      );
      return CinkoCell(
        id: m['id']?.toString() ?? '',
        type: type,
        label: m['label']?.toString() ?? '',
        logoUrl: m['logoUrl']?.toString(),
        clubId: (m['clubId'] as num?)?.toInt(),
      );
    }).toList();
  }
}
