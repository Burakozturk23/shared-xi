import 'dart:math';

import '../data/popular_clubs_pool.dart' show popularClubIds;
import '../models/club.dart';
import '../models/player.dart';
import 'runtime_v4/game_data_v4_database.dart';
import 'runtime_v4/game_data_v4_query_service.dart';

typedef RandomFiveSessionLoader = Future<RandomFiveSession> Function();

/// One immutable board, shared by the human and bot for the entire round.
class FiveRound {
  FiveRound({required List<Club> clubs, required Map<int, Set<int>> matches})
    : clubs = List.unmodifiable(clubs),
      matches = Map.unmodifiable({
        for (final entry in matches.entries)
          entry.key: Set<int>.unmodifiable(entry.value),
      });

  final List<Club> clubs;
  final Map<int, Set<int>> matches;

  List<Club> matchedClubs(int playerId) => [
    for (final club in clubs)
      if (matches[playerId]?.contains(club.id) ?? false) club,
  ];
}

/// Lightweight V4 identities and relations; no global Repository hydration.
class RandomFiveSession {
  RandomFiveSession({
    required List<Club> clubs,
    required List<Player> players,
    required Map<int, Set<int>> clubIdsByPlayer,
  }) : clubs = List.unmodifiable(clubs),
       players = List.unmodifiable(players),
       playersById = Map.unmodifiable({for (final p in players) p.id: p}),
       clubIdsByPlayer = Map.unmodifiable({
         for (final entry in clubIdsByPlayer.entries)
           entry.key: Set<int>.unmodifiable(entry.value),
       });

  final List<Club> clubs;
  final List<Player> players;
  final Map<int, Player> playersById;
  final Map<int, Set<int>> clubIdsByPlayer;

  static Future<RandomFiveSession> load() async {
    final query = GameDataV4QueryService.instance;
    final catalog = await query.sharedXiClubCatalog();
    final popular = popularClubIds.toSet();
    final clubs = catalog.where((c) => popular.contains(c.id)).toList();
    if (clubs.length < 5) throw StateError('Beşler için yeterli kulüp yok.');
    final db = GameDataV4Database.instance.database;
    final identities = await db.rawQuery('''
      SELECT id, name, country, position, avatar_key FROM players
      WHERE answer_eligible = 1 AND TRIM(name) <> ''
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
    final relations = <int, Set<int>>{};
    final marks = List.filled(clubs.length, '?').join(',');
    for (final row in await db.rawQuery('''
      SELECT pc.player_id, pc.club_id FROM player_clubs pc
      JOIN players p ON p.id = pc.player_id
      WHERE p.answer_eligible = 1 AND pc.club_id IN ($marks)
    ''', clubs.map((c) => c.id).toList())) {
      relations
          .putIfAbsent((row['player_id'] as num).toInt(), () => <int>{})
          .add((row['club_id'] as num).toInt());
    }
    final players = <Player>[];
    for (final row in identities) {
      final id = (row['id'] as num).toInt();
      players.add(
        Player.fromJson({
          'id': id,
          'name': row['name'],
          'countries':
              countries[id] ?? <String>[row['country']?.toString() ?? ''],
          'position': row['position'],
          'aliases': aliases[id] ?? const <String>[],
          'avatarKey': row['avatar_key'],
        }),
      );
    }
    return RandomFiveSession(
      clubs: clubs,
      players: players,
      clubIdsByPlayer: relations,
    );
  }

  /// Ten initial answers guarantee two remain after at most eight used players
  /// in the final round. Prefer disjoint club sets and rich career overlaps.
  FiveRound createRound({
    required Random random,
    Set<int> previous = const {},
  }) {
    final byClub = <int, Set<int>>{for (final c in clubs) c.id: <int>{}};
    for (final entry in clubIdsByPlayer.entries) {
      if (!playersById.containsKey(entry.key)) continue;
      for (final id in entry.value) {
        byClub[id]?.add(entry.key);
      }
    }
    final pool = clubs.where((c) => byClub[c.id]!.length >= 2).toList();
    final poolIds = pool.map((c) => c.id).toSet();
    final seeds = [
      for (final e in clubIdsByPlayer.entries)
        if (playersById.containsKey(e.key) &&
            e.value.intersection(poolIds).length >= 3)
          e.value.intersection(poolIds).toList(),
    ]..shuffle(random);
    FiveRound? best;
    var bestQuality = -1;
    for (final avoidPrevious in [true, false]) {
      for (final seed in seeds.take(64)) {
        final core =
            seed
                .where((id) => !avoidPrevious || !previous.contains(id))
                .toList()
              ..shuffle(random);
        if (core.length < 3) continue;
        final selected = core
            .take(core.length >= 4 && random.nextBool() ? 4 : 3)
            .toList();
        final counts = <int, int>{};
        void include(int clubId) {
          for (final playerId in byClub[clubId]!) {
            counts[playerId] = (counts[playerId] ?? 0) + 1;
          }
        }

        selected.forEach(include);
        while (selected.length < 5) {
          final ranked = <({int id, int quality})>[];
          for (final club in pool) {
            if (selected.contains(club.id) ||
                (avoidPrevious && previous.contains(club.id)))
              continue;
            var quality = 0;
            for (final playerId in byClub[club.id]!) {
              final overlap = counts[playerId] ?? 0;
              if (overlap > 0) quality += overlap >= 2 ? 5 : 1;
            }
            if (quality > 0) ranked.add((id: club.id, quality: quality));
          }
          if (ranked.isEmpty) break;
          ranked.shuffle(random);
          ranked.sort((a, b) => b.quality.compareTo(a.quality));
          final next = ranked[random.nextInt(min(5, ranked.length))].id;
          selected.add(next);
          include(next);
        }
        if (selected.length != 5 || counts.length < 10) continue;
        if (previous.length == 5 &&
            selected.every(previous.contains) &&
            pool.length > 5)
          continue;
        final triples = counts.values.where((n) => n >= 3).length;
        final doubles = counts.values.where((n) => n >= 2).length;
        final quality = triples * 5 + doubles;
        if (quality <= bestQuality) continue;
        bestQuality = quality;
        selected.shuffle(random);
        final picked = selected.toSet();
        best = FiveRound(
          clubs: [
            for (final id in selected) pool.firstWhere((c) => c.id == id),
          ],
          matches: {
            for (final id in counts.keys)
              id: clubIdsByPlayer[id]!.intersection(picked),
          },
        );
        if (triples >= 10 && doubles >= 15) return best;
      }
      if (best != null) return best;
    }
    throw StateError('Beşler için yeterli bağlantısı olan tahta üretilemedi.');
  }
}
