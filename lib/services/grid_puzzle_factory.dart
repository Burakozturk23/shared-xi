import 'dart:math';

import '../data/popular_clubs_pool.dart';
import '../models/club.dart';
import '../models/grid_criterion.dart';
import '../models/grid_sub_type.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import 'search_service.dart';

/// Klasik / rastgele / ters grid seed üretimi.
class GridPuzzleFactory {
  GridPuzzleFactory._();

  static final _random = Random();

  // ─── CLASSIC ───────────────────────────────────────────

  static ({List<GridCriterion> rows, List<GridCriterion> cols}) generateClassic({
    int maxAttempts = 40,
  }) {
    final clubs = PopularClubs.resolveAll();
    final players = Repository.instance.players;
    final popularCountriesList = List<String>.from(popularCountries);

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final shuffledClubs = List<Club>.from(clubs)..shuffle(_random);
      if (shuffledClubs.length < 6) break;

      final rowClubs = shuffledClubs.take(3).toList();
      final rows = rowClubs.map(GridCriterion.club).toList();
      final remainingClubs = shuffledClubs.skip(3).toList()..shuffle(_random);
      final cols = _generateColumnCriteria(remainingClubs, popularCountriesList);

      var valid = true;
      for (final row in rows) {
        for (final col in cols) {
          if (!players.any((p) => row.matches(p) && col.matches(p))) {
            valid = false;
            break;
          }
        }
        if (!valid) break;
      }
      if (valid) return (rows: rows, cols: cols);
    }

    final fallback = List<Club>.from(clubs)..shuffle(_random);
    return (
      rows: fallback.take(3).map(GridCriterion.club).toList(),
      cols: fallback.skip(3).take(3).map(GridCriterion.club).toList(),
    );
  }

  static List<GridCriterion> _generateColumnCriteria(
    List<Club> availableClubs,
    List<String> countries,
  ) {
    final c = List<String>.from(countries)..shuffle(_random);
    final goals = List<int>.from(gridGoalThresholds)..shuffle(_random);
    final positions = List.from(gridPositions)..shuffle(_random);
    final clubs = List<Club>.from(availableClubs);

    final pickers = <GridCriterion Function()>[
      () => GridCriterion.club(clubs.removeLast()),
      () => GridCriterion.country(c.removeLast()),
      () {
        final picked = positions.removeLast();
        return GridCriterion.position(picked.value, picked.label);
      },
      () => GridCriterion.goals(goals.removeLast()),
    ];

    final result = <GridCriterion>[];
    while (result.length < 3) {
      try {
        result.add(pickers[_random.nextInt(pickers.length)]());
      } catch (_) {
        if (clubs.isNotEmpty) {
          result.add(GridCriterion.club(clubs.removeLast()));
        } else {
          break;
        }
      }
    }
    while (result.length < 3 && clubs.isNotEmpty) {
      result.add(GridCriterion.club(clubs.removeLast()));
    }
    return result;
  }

  static Map<String, dynamic> classicSeed({
    required List<GridCriterion> rows,
    required List<GridCriterion> cols,
  }) =>
      {
        'subType': GridSubType.classic.id,
        'rows': rows.map((e) => e.toMap()).toList(),
        'cols': cols.map((e) => e.toMap()).toList(),
      };

  // ─── RANDOM: 5 raund kulüp çifti ───────────────────────

  /// Her raund: iki kulüp (ortak oyuncu garantili).
  static List<Map<String, dynamic>> generateRandomRounds({int rounds = 5}) {
    final players = Repository.instance.players;
    final result = <Map<String, dynamic>>[];
    final usedClubIds = <int>{};

    for (var r = 0; r < rounds; r++) {
      final pair = _pickConnectedPair(players, usedClubIds);
      if (pair == null) break;
      usedClubIds.add(pair.$1.id);
      usedClubIds.add(pair.$2.id);
      result.add({
        'clubAId': pair.$1.id,
        'clubAName': pair.$1.name,
        'clubBId': pair.$2.id,
        'clubBName': pair.$2.name,
      });
    }
    return result;
  }

  static (Club, Club)? _pickConnectedPair(
    List<Player> players,
    Set<int> exclude,
  ) {
    final pool = PopularClubs.resolveAll()
        .where((c) => !exclude.contains(c.id))
        .toList()
      ..shuffle(_random);
    if (pool.length < 2) return null;

    for (var attempt = 0; attempt < 50; attempt++) {
      final a = pool[_random.nextInt(pool.length)];
      final b = pool[_random.nextInt(pool.length)];
      if (a.id == b.id) continue;
      final ok = players.any(
        (p) =>
            p.name.trim().isNotEmpty &&
            p.clubs.contains(a.id) &&
            p.clubs.contains(b.id),
      );
      if (ok) return (a, b);
    }
    return (pool[0], pool[1]);
  }

  static Map<String, dynamic> randomSeed(List<Map<String, dynamic>> rounds) => {
        'subType': GridSubType.random.id,
        'rounds': rounds,
      };

  // ─── REVERSE: 9 oyuncu + gizli eksen cevapları ─────────

  /// cellPlayerIds[9], rowAnswers[3], colAnswers[3] (görünen label).
  static Map<String, dynamic>? generateReverse({int maxAttempts = 30}) {
    final clubs = PopularClubs.resolveAll();
    final players = Repository.instance.players;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final shuffled = List<Club>.from(clubs)..shuffle(_random);
      if (shuffled.length < 6) return null;

      final rowClubs = shuffled.take(3).toList();
      final colClubs = shuffled.skip(3).take(3).toList();
      final rows = rowClubs.map(GridCriterion.club).toList();
      final cols = colClubs.map(GridCriterion.club).toList();

      final cellIds = <int>[];
      var ok = true;
      final used = <int>{};

      for (var r = 0; r < 3 && ok; r++) {
        for (var c = 0; c < 3 && ok; c++) {
          final candidates = players
              .where(
                (p) =>
                    !used.contains(p.id) &&
                    p.name.trim().isNotEmpty &&
                    rows[r].matches(p) &&
                    cols[c].matches(p),
              )
              .toList();
          if (candidates.isEmpty) {
            ok = false;
            break;
          }
          candidates.shuffle(_random);
          final pick = candidates.first;
          used.add(pick.id);
          cellIds.add(pick.id);
        }
      }
      if (!ok || cellIds.length != 9) continue;

      return {
        'subType': GridSubType.reverse.id,
        'cellPlayerIds': cellIds,
        'rowAnswers': rowClubs.map((c) => c.name).toList(),
        'colAnswers': colClubs.map((c) => c.name).toList(),
        // İsteğe bağlı: client ipucu için id
        'rowClubIds': rowClubs.map((c) => c.id).toList(),
        'colClubIds': colClubs.map((c) => c.id).toList(),
      };
    }
    return null;
  }

  static Map<String, dynamic> seedFor(GridSubType type) {
    switch (type) {
      case GridSubType.classic:
        final g = generateClassic();
        return classicSeed(rows: g.rows, cols: g.cols);
      case GridSubType.random:
        return randomSeed(generateRandomRounds());
      case GridSubType.reverse:
        return generateReverse() ??
            classicSeed(
              rows: generateClassic().rows,
              cols: generateClassic().cols,
            );
    }
  }

  static ({List<GridCriterion> rows, List<GridCriterion> cols}) fromSeedMap(
    Map<String, dynamic> m,
  ) =>
      classicFromSeed(m);

  static ({List<GridCriterion> rows, List<GridCriterion> cols}) classicFromSeed(
    Map<String, dynamic> m,
  ) {
    final rows = (m['rows'] as List? ?? [])
        .map((e) => GridCriterion.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    final cols = (m['cols'] as List? ?? [])
        .map((e) => GridCriterion.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    return (rows: rows, cols: cols);
  }
}
