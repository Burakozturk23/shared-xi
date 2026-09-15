import 'dart:math';

import '../data/cinko_pool.dart';
import '../models/cinko_models.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../utils/country_names.dart';
import 'runtime_v4/game_data_v4_database.dart';
import 'runtime_v4/game_data_v4_query_service.dart';

typedef CinkoBotSessionLoader = Future<CinkoBotSession> Function(int gridSize);

/// Board answers and lightweight search identities from the same V4 snapshot.
/// Career objects and the global legacy Repository are not needed for Çinko.
class CinkoBotSession {
  CinkoBotSession({
    required List<CinkoCell> cells,
    required List<Player> players,
    required Map<int, Set<int>> validPlayerIdsByCell,
    Map<int, Club> clubs = const {},
  }) : cells = List.unmodifiable(cells),
       players = List.unmodifiable(players),
       playersById = Map.unmodifiable({for (final p in players) p.id: p}),
       clubs = Map.unmodifiable(clubs),
       validPlayerIdsByCell = Map.unmodifiable({
         for (final e in validPlayerIdsByCell.entries)
           e.key: Set<int>.unmodifiable(e.value),
       });

  final List<CinkoCell> cells;
  final List<Player> players;
  final Map<int, Player> playersById;
  final Map<int, Club> clubs;
  final Map<int, Set<int>> validPlayerIdsByCell;

  /// A distinct answer for every cell is sufficient even if every turn claims
  /// only one cell. Later mistakes can exhaust answers; the controller handles it.
  bool isPlayable(int gridSize) {
    if (cells.length != gridSize * gridSize ||
        cells.map((cell) => cell.id).toSet().length != cells.length ||
        cells.any((cell) => cell.status != CinkoCellStatus.open) ||
        validPlayerIdsByCell.values.any(
          (ids) => ids.any((id) => !playersById.containsKey(id)),
        )) {
      return false;
    }
    final assigned = <int, int>{};
    bool assign(int cell, Set<int> seen) {
      for (final id in validPlayerIdsByCell[cell] ?? const <int>{}) {
        if (!playersById.containsKey(id) || !seen.add(id)) continue;
        final previous = assigned[id];
        if (previous == null || assign(previous, seen)) {
          assigned[id] = cell;
          return true;
        }
      }
      return false;
    }

    return List.generate(
      cells.length,
      (i) => i,
    ).every((cell) => assign(cell, <int>{}));
  }

  static Future<CinkoBotSession> load(int gridSize, {Random? random}) async {
    final rng = random ?? Random();
    final query = GameDataV4QueryService.instance;
    final catalog = await query.sharedXiClubCatalog();
    final db = GameDataV4Database.instance.database;
    final count = gridSize * gridSize;

    // Include all answer-eligible names in search, not just this board's answers.
    // That preserves the knowledge challenge and accepts accented names/aliases.
    final playerRows = await db.rawQuery('''
      SELECT id, name, country, position, avatar_key
      FROM players WHERE answer_eligible = 1 AND TRIM(name) <> ''
      ORDER BY selection_rank IS NULL, selection_rank, id
    ''');
    final aliases = <int, List<String>>{};
    for (final row in await db.rawQuery('''
      SELECT a.player_id, a.alias FROM player_aliases a
      JOIN players p ON p.id = a.player_id WHERE p.answer_eligible = 1
      ORDER BY a.player_id, a.ord
    ''')) {
      aliases
          .putIfAbsent((row['player_id'] as num).toInt(), () => [])
          .add(row['alias'] as String);
    }
    final countries = <int, List<String>>{};
    for (final row in await db.rawQuery('''
      SELECT c.player_id, c.country FROM player_countries c
      JOIN players p ON p.id = c.player_id WHERE p.answer_eligible = 1
      ORDER BY c.player_id, c.ord
    ''')) {
      countries
          .putIfAbsent((row['player_id'] as num).toInt(), () => [])
          .add(row['country'] as String);
    }
    final players = [
      for (final row in playerRows)
        Player.fromJson({
          'id': row['id'],
          'name': row['name'],
          'countries':
              countries[(row['id'] as num).toInt()] ??
              [(row['country'] as String?) ?? ''],
          'position': row['position'],
          'aliases': aliases[(row['id'] as num).toInt()] ?? const <String>[],
          'avatarKey': row['avatar_key'],
        }),
    ];

    final famousIds = cinkoFamousClubIds.toSet();
    final clubs = catalog.where((c) => famousIds.contains(c.id)).toList()
      ..shuffle(rng);
    final countryLabels =
        cinkoFamousCountries.map(CountryNames.canonical).toSet().toList()
          ..shuffle(rng);
    // Exact league names only: Bundesliga must not include 2. Bundesliga.
    final leagueNames = cinkoFamousLeagues.map((s) => s.toLowerCase()).toSet();
    final leagues =
        (await query.allClubs())
            .map((c) => c.league)
            .where((name) => leagueNames.contains(name.toLowerCase()))
            .toSet()
            .toList()
          ..shuffle(rng);

    final cells = <CinkoCell>[];
    final answersById = <String, Set<int>>{};
    Future<void> add(CinkoCell cell) async {
      if (answersById.containsKey(cell.id)) return;
      if (cell.type == CinkoCellType.country) {
        final ids = {
          for (final player in players)
            if (player.countries.any(
              (country) => CountryNames.same(country, cell.label),
            ))
              player.id,
        };
        if (ids.length < 2) return;
        answersById[cell.id] = ids;
        cells.add(cell);
        return;
      }
      final (predicate, args) = switch (cell.type) {
        CinkoCellType.club => (
          'EXISTS (SELECT 1 FROM player_clubs pc '
              'WHERE pc.player_id = p.id AND pc.club_id = ?)',
          <Object?>[cell.clubId],
        ),
        CinkoCellType.country => throw StateError('Country handled above.'),
        CinkoCellType.league => (
          'EXISTS (SELECT 1 FROM player_clubs pc JOIN clubs c ON c.id = pc.club_id '
              'WHERE pc.player_id = p.id AND c.competition = ? COLLATE NOCASE)',
          <Object?>[cell.label],
        ),
      };
      final rows = await db.rawQuery('''
        SELECT p.id FROM players p
        WHERE p.answer_eligible = 1 AND TRIM(p.name) <> '' AND $predicate
      ''', args);
      if (rows.length < 2) return;
      answersById[cell.id] = {
        for (final row in rows) (row['id'] as num).toInt(),
      };
      cells.add(cell);
    }

    final clubCount = (count * .70).round();
    final countryCount = (count * .15).round();
    for (final club in clubs) {
      if (cells.length >= clubCount) break;
      await add(
        CinkoCell(
          id: 'club_${club.id}',
          type: CinkoCellType.club,
          label: club.name,
          clubId: club.id,
        ),
      );
    }
    for (final country in countryLabels) {
      if (cells.length >= clubCount + countryCount) break;
      await add(
        CinkoCell(
          id: 'country_$country',
          type: CinkoCellType.country,
          label: country,
        ),
      );
    }
    for (final league in leagues) {
      if (cells.length >= count) break;
      await add(
        CinkoCell(
          id: 'league_$league',
          type: CinkoCellType.league,
          label: league,
        ),
      );
    }
    for (final club in clubs) {
      if (cells.length >= count) break;
      await add(
        CinkoCell(
          id: 'club_${club.id}',
          type: CinkoCellType.club,
          label: club.name,
          clubId: club.id,
        ),
      );
    }
    cells.shuffle(rng);
    final session = CinkoBotSession(
      cells: cells,
      players: players,
      clubs: {for (final club in clubs) club.id: club},
      validPlayerIdsByCell: {
        for (var i = 0; i < cells.length; i++) i: answersById[cells[i].id]!,
      },
    );
    if (!session.isPlayable(gridSize)) {
      throw StateError('Çinko için yeterli farklı cevap bulunamadı.');
    }
    return session;
  }
}
