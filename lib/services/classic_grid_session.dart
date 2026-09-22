import 'dart:math';

import '../data/grid_country_pool.dart';
import '../models/club.dart';
import '../models/grid_criterion.dart';
import '../models/player.dart';
import 'runtime_v4/game_data_v4_query_service.dart';

typedef ClassicGridSessionLoader = Future<ClassicGridSession> Function();

/// V4 puzzle and scoped answer pool for the Botla Oyna classic grid.
class ClassicGridSession {
  const ClassicGridSession({
    required this.rows,
    required this.cols,
    required this.players,
    required this.validPlayerIdsByCell,
  });

  final List<GridCriterion> rows;
  final List<GridCriterion> cols;
  final List<Player> players;
  final Map<int, Set<int>> validPlayerIdsByCell;

  static Future<ClassicGridSession> load({
    Random? random,
    int maxAttempts = 36,
  }) async {
    final rng = random ?? Random();
    final query = GameDataV4QueryService.instance;
    final allClubs = await query.sharedXiClubCatalog();
    final clubs = allClubs.take(160).toList();
    if (clubs.length < 6) {
      throw StateError('Classic Grid için yeterli kulüp yok.');
    }

    final playersByClub = <int, List<Player>>{};
    Future<List<Player>> playersFor(Club club) async {
      final cached = playersByClub[club.id];
      if (cached != null) return cached;
      final loaded = await query.playersForClub(club.id);
      playersByClub[club.id] = loaded;
      return loaded;
    }

    final columnCandidates = <GridCriterion>[
      for (final country in gridCountryPool) GridCriterion.country(country),
      for (final position in gridPositions)
        GridCriterion.position(position.value, position.label),
      for (final club in clubs) GridCriterion.club(club),
    ];

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final shuffled = List<Club>.from(clubs)..shuffle(rng);
      final rowClubs = shuffled.take(3).toList(growable: false);
      final rowPlayers = <int, Player>{};
      for (final club in rowClubs) {
        for (final player in await playersFor(club)) {
          rowPlayers[player.id] = player;
        }
      }
      if (rowPlayers.length < 24) continue;

      final candidates = List<GridCriterion>.from(columnCandidates)
        ..shuffle(rng);
      final cols = _pickColumns(
        rows: rowClubs.map(GridCriterion.club).toList(growable: false),
        candidates: candidates,
        players: rowPlayers.values.toList(growable: false),
        random: rng,
      );
      if (cols == null) continue;

      final rows = rowClubs.map(GridCriterion.club).toList(growable: false);
      final valid = _validPlayersByCell(rows, cols, rowPlayers.values);
      if (!_hasPerfectAssignment(valid)) continue;

      return ClassicGridSession(
        rows: List.unmodifiable(rows),
        cols: List.unmodifiable(cols),
        players: List.unmodifiable(rowPlayers.values),
        validPlayerIdsByCell: {
          for (final entry in valid.entries)
            entry.key: Set.unmodifiable(entry.value),
        },
      );
    }

    throw StateError('Classic Grid için çözülebilir tahta üretilemedi.');
  }

  static List<GridCriterion>? _pickColumns({
    required List<GridCriterion> rows,
    required List<GridCriterion> candidates,
    required List<Player> players,
    required Random random,
  }) {
    // Do the cheap row-by-row intersection first. Without this filter a
    // random club column would almost always be unrelated to the three row
    // clubs, causing an otherwise valid puzzle to be discarded.
    final rowClubIds = {
      for (final row in rows)
        if (row.type == GridCriterionType.club && row.clubId != null)
          row.clubId,
    };
    final viable = candidates.where((criterion) {
      // Prefer different clubs on each axis; fall back to them only when the
      // data set has too few distinct crossovers.
      if (criterion.type == GridCriterionType.club &&
          rowClubIds.contains(criterion.clubId)) {
        return false;
      }
      return rows.every(
        (row) => players.any(
          (player) => row.matches(player) && criterion.matches(player),
        ),
      );
    }).toList();
    final pool = viable.length >= 3
        ? viable
        : candidates
              .where(
                (criterion) => rows.every(
                  (row) => players.any(
                    (player) =>
                        row.matches(player) && criterion.matches(player),
                  ),
                ),
              )
              .toList();
    if (pool.length < 3) return null;

    for (var attempt = 0; attempt < 240; attempt++) {
      final shuffled = List<GridCriterion>.from(pool)..shuffle(random);
      final picked = shuffled.take(3).toList(growable: false);
      if (picked.length != 3) continue;
      final valid = _validPlayersByCell(rows, picked, players);
      if (valid.values.every((ids) => ids.isNotEmpty)) return picked;
    }
    return null;
  }

  static Map<int, Set<int>> _validPlayersByCell(
    List<GridCriterion> rows,
    List<GridCriterion> cols,
    Iterable<Player> players,
  ) {
    final result = <int, Set<int>>{};
    for (var row = 0; row < rows.length; row++) {
      for (var col = 0; col < cols.length; col++) {
        final index = row * 3 + col;
        result[index] = {
          for (final player in players)
            if (rows[row].matches(player) && cols[col].matches(player))
              player.id,
        };
      }
    }
    return result;
  }

  /// Ensures the generated board has nine distinct valid answers available.
  static bool _hasPerfectAssignment(Map<int, Set<int>> valid) {
    final owner = <int, int>{};
    bool assign(int cell, Set<int> visited) {
      final candidates = valid[cell] ?? const <int>{};
      for (final playerId in candidates) {
        if (!visited.add(playerId)) continue;
        final previousCell = owner[playerId];
        if (previousCell == null || assign(previousCell, visited)) {
          owner[playerId] = cell;
          return true;
        }
      }
      return false;
    }

    final cells = valid.keys.toList()
      ..sort((a, b) => valid[a]!.length.compareTo(valid[b]!.length));
    return cells.every((cell) => assign(cell, <int>{}));
  }
}
