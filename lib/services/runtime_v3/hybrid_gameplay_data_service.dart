import 'package:flutter/foundation.dart';

import '../../models/club.dart';
import '../../models/match_entity.dart';
import '../../models/player.dart';
import '../../data/chain_pool.dart';
import '../../repositories/repository.dart';

import '../game_service.dart';
import '../runtime_v4/game_data_v4_database.dart';
import '../runtime_v4/game_data_v4_query_service.dart';

class HybridGameplayDataService {
  HybridGameplayDataService._();

  static final HybridGameplayDataService instance =
      HybridGameplayDataService._();

  GameDataV4Database get _v4 => GameDataV4Database.instance;

  GameDataV4QueryService get _query => GameDataV4QueryService.instance;

  // V4 is now the canonical gameplay source.
  //
  // Public methods initialize the database lazily,
  // so this no longer depends on RuntimeV3 startup state.
  bool get isGameplayEnabled => true;

  // ---------------------------------------------------------
  // Legacy pool names are NOT datasets anymore.
  //
  // They are translated into universal V4 capability /
  // difficulty tags.
  // ---------------------------------------------------------

  List<String> _requiredTags(String poolName) {
    final value = poolName
        .trim()
        .toLowerCase();

    final tags = <String>{};

    // Difficulty / quality bands.
    if (value.contains('casual') ||
        value.contains('beginner')) {
      tags.add('casual');
    }

    if (value.contains('normal')) {
      tags.add('normal');
    }

    if (value.contains('hard') ||
        value.contains('legend')) {
      tags.add('hard');
    }

    if (value.contains('visual')) {
      tags.add('visual');
    }

    // Capability filters.
    if (value.contains('career')) {
      tags.add('career');
    }

    if (value.contains('transfer')) {
      tags.add('transfer');
    }

    if (value.contains('answer') ||
        value.contains('question') ||
        value.contains('shared_xi') ||
        value.contains('grid')) {
      tags.add('answer');
    }

    // Explicitly playable or unknown legacy pool:
    // use the universal gameplay universe.
    if (tags.isEmpty) {
      tags.add('playable');
    }

    return tags.toList();
  }

  String _tagPredicate(
    String playerIdExpression,
    List<String> tags,
  ) {
    // Legacy pool names are now only selection rules over the single V4
    // player universe. No physical per-mode pool/table is required.
    final clauses = <String>[];

    for (final tag in tags) {
      switch (tag) {
        case 'casual':
          clauses.add('p.selection_rank IS NOT NULL AND p.selection_rank <= 2000');
          break;
        case 'normal':
          clauses.add('p.selection_rank IS NOT NULL AND p.selection_rank <= 6000');
          break;
        case 'hard':
          clauses.add('p.selection_rank IS NOT NULL AND p.selection_rank <= 12000');
          break;
        case 'visual':
          clauses.add('p.selection_rank IS NOT NULL AND p.selection_rank <= 3000');
          break;
        case 'career':
          clauses.add(
            'EXISTS (SELECT 1 FROM career_spells cs_pool '
            'WHERE cs_pool.player_id = $playerIdExpression)',
          );
          break;
        case 'transfer':
          clauses.add(
            'EXISTS (SELECT 1 FROM transfers tr_pool '
            'WHERE tr_pool.player_id = $playerIdExpression)',
          );
          break;
        case 'answer':
        case 'playable':
          clauses.add('p.selection_rank IS NOT NULL');
          break;
      }
    }

    if (clauses.isEmpty) {
      return 'p.selection_rank IS NOT NULL';
    }

    return clauses.join(' AND ');
  }

  // ---------------------------------------------------------
  // Compatibility object conversion.
  //
  // IDs are hydrated lazily from the canonical V4 SQLite package and cached.
  // Full Repository hydration is only an emergency fallback for legacy modes.
  // ---------------------------------------------------------

  Future<List<Player>> _playersFromIds(Iterable<int> ids) async {
    return _query.playersByIds(ids);
  }

  Future<List<Club>> _clubsFromIds(Iterable<int> ids) async {
    return _query.clubsByIds(ids);
  }

  Future<void> _ensureReady() async {
    await _v4.initialize();
  }

  // =========================================================
  // Shared XI
  // =========================================================

  Future<List<Player>> sharedXiMatchingPlayers({
    required MatchEntity entity1,
    required MatchEntity entity2,
    required bool allowSqlite,
  }) async {
    await _ensureReady();

    try {
      final players = await _query.matchingPlayers(
        entity1: entity1,
        entity2: entity2,
      );

      if (kDebugMode) {
        debugPrint(
          '[HybridV4] SharedXI ${entity1.displayName} x ${entity2.displayName}: '
          '${players.length} players (allowSqlite=$allowSqlite)',
        );
      }

      return players;
    } catch (e) {
      debugPrint('[HybridV4] SharedXI query failed: $e');

      // Transitional emergency fallback only if a legacy mode already loaded
      // Repository. HybridV4 itself never triggers full Repository hydration.
      if (Repository.instance.isInitialized) {
        return GameService.matchingPlayers(
          players: Repository.instance.players,
          entity1: entity1,
          entity2: entity2,
        );
      }
      rethrow;
    }
  }

  // =========================================================
  // Universal player selection
  // =========================================================

  Future<List<Player>> playersInPool(
    String poolName,
  ) async {
    await _ensureReady();

    try {
      final tags =
          _requiredTags(poolName);

      final args = <Object?>[];

      final predicate =
          _tagPredicate(
        'p.id',
        tags,
      );

      final rows =
          await _v4.database.rawQuery(
        '''
        SELECT
          p.id
        FROM players p
        WHERE $predicate
        ORDER BY
          p.selection_rank IS NULL,
          p.selection_rank,
          p.id
        ''',
        args,
      );

      final ids = rows
          .map(
            (row) =>
                (row['id'] as num).toInt(),
          )
          .toList();

      if (kDebugMode) {
        debugPrint(
          '[HybridV4] playersInPool '
          '$poolName -> tags=$tags '
          'count=${ids.length}',
        );
      }

      return _playersFromIds(ids);
    } catch (e) {
      debugPrint(
        '[HybridV4] playersInPool('
        '$poolName) fallback: $e',
      );

      if (Repository.instance.isInitialized) {
        return Repository.instance.players;
      }
      return const <Player>[];
    }
  }

  // =========================================================
  // Club → players
  // =========================================================

  Future<List<Player>> playersForClub(
    int clubId, {
    String? playerPool,
  }) async {
    await _ensureReady();

    try {
      final tags =
          playerPool == null
              ? <String>['playable']
              : _requiredTags(
                  playerPool,
                );

      final args = <Object?>[
        clubId,
      ];

      final predicate =
          _tagPredicate(
        'p.id',
        tags,
      );

      final rows =
          await _v4.database.rawQuery(
        '''
        SELECT DISTINCT
          p.id
        FROM players p
        JOIN player_clubs pc
          ON pc.player_id = p.id
        WHERE pc.club_id = ?
          AND $predicate
        ORDER BY
          p.selection_rank IS NULL,
          p.selection_rank,
          p.id
        ''',
        args,
      );

      final ids = rows
          .map(
            (row) =>
                (row['id'] as num).toInt(),
          )
          .toList();

      return _playersFromIds(ids);
    } catch (e) {
      debugPrint(
        '[HybridV4] playersForClub('
        '$clubId) fallback: $e',
      );

      if (Repository.instance.isInitialized) {
        return Repository.instance.players
            .where((player) => player.clubs.contains(clubId))
            .toList();
      }
      return const <Player>[];
    }
  }

  // =========================================================
  // Player → club relations
  // =========================================================

  Future<Map<int, List<int>>>
      playerClubIdsForPool(
    String poolName,
  ) async {
    await _ensureReady();

    try {
      final tags =
          _requiredTags(poolName);

      final args = <Object?>[];

      final predicate =
          _tagPredicate(
        'p.id',
        tags,
      );

      final rows =
          await _v4.database.rawQuery(
        '''
        SELECT
          p.id AS player_id,
          pc.club_id
        FROM players p
        JOIN player_clubs pc
          ON pc.player_id = p.id
        WHERE $predicate
        ORDER BY
          p.id,
          pc.club_id
        ''',
        args,
      );

      final result =
          <int, List<int>>{};

      for (final row in rows) {
        final playerId =
            (row['player_id'] as num)
                .toInt();

        final clubId =
            (row['club_id'] as num)
                .toInt();

        result
            .putIfAbsent(
              playerId,
              () => <int>[],
            )
            .add(clubId);
      }

      return result;
    } catch (e) {
      debugPrint(
        '[HybridV4] playerClubIdsForPool('
        '$poolName) fallback: $e',
      );

      return const {};
    }
  }

  // =========================================================
  // Universal gameplay clubs
  // =========================================================

  Future<List<Club>> topGameplayClubs({
    int limit = 400,
  }) async {
    await _ensureReady();

    try {
      final rows =
          await _v4.database.rawQuery(
        '''
        SELECT
          c.id,
          COUNT(DISTINCT pc.player_id)
              AS playable_players
        FROM clubs c
        JOIN player_clubs pc
          ON pc.club_id = c.id
        JOIN players p
          ON p.id = pc.player_id
        WHERE p.selection_rank IS NOT NULL
        GROUP BY c.id
        ORDER BY
          c.gameplay_eligible DESC,
          c.popularity_seed DESC,
          playable_players DESC,
          c.name,
          c.id
        LIMIT ?
        ''',
        [limit],
      );

      final ids = rows
          .map(
            (row) =>
                (row['id'] as num).toInt(),
          )
          .toList();

      return _clubsFromIds(ids);
    } catch (e) {
      debugPrint(
        '[HybridV4] topGameplayClubs '
        'fallback: $e',
      );

      return const [];
    }
  }

  Future<List<Club>> clubsInPool(
    String poolName,
  ) async {
    await _ensureReady();

    try {
      final tags =
          _requiredTags(poolName);

      final args = <Object?>[];

      final predicate =
          _tagPredicate(
        'p.id',
        tags,
      );

      final rows =
          await _v4.database.rawQuery(
        '''
        SELECT
          c.id,
          COUNT(DISTINCT p.id)
              AS matching_players
        FROM clubs c
        JOIN player_clubs pc
          ON pc.club_id = c.id
        JOIN players p
          ON p.id = pc.player_id
        WHERE $predicate
        GROUP BY c.id
        ORDER BY
          c.gameplay_eligible DESC,
          c.popularity_seed DESC,
          matching_players DESC,
          c.name,
          c.id
        ''',
        args,
      );

      final ids = rows
          .map(
            (row) =>
                (row['id'] as num).toInt(),
          )
          .toList();

      if (kDebugMode) {
        debugPrint(
          '[HybridV4] clubsInPool '
          '$poolName -> tags=$tags '
          'count=${ids.length}',
        );
      }

      return _clubsFromIds(ids);
    } catch (e) {
      debugPrint(
        '[HybridV4] clubsInPool('
        '$poolName) fallback: $e',
      );

      return const [];
    }
  }

  // =========================================================
  // Facts
  // =========================================================

  Future<Map<int, Map<String, Object?>>>
      playerFactsForPool(
    String poolName,
  ) async {
    await _ensureReady();

    try {
      final tags =
          _requiredTags(poolName);

      final args = <Object?>[];

      final predicate =
          _tagPredicate(
        'p.id',
        tags,
      );

      final rows =
          await _v4.database.rawQuery(
        '''
        SELECT
          p.id AS player_id,
          p.name,
          p.country,
          p.position,
          p.selection_score,
          p.selection_rank,
          p.market_value,
          p.peak_market_value,
          p.career_goals,

          pr.birth_year,
          pr.citizenship,
          pr.position_group,
          pr.detailed_position,
          pr.foot,
          pr.height_cm,
          pr.international_caps,
          pr.international_goals,

          ps.appearances,
          ps.goals,
          ps.assists,
          ps.minutes,
          ps.ucl_appearances,
          ps.big5_appearances,
          ps.top_competition_appearances,
          ps.coverage_first_year,
          ps.coverage_last_year,
          ps.coverage_class

        FROM players p

        LEFT JOIN profiles pr
          ON pr.player_id = p.id

        LEFT JOIN player_stats ps
          ON ps.player_id = p.id

        WHERE $predicate

        ORDER BY
          p.selection_rank IS NULL,
          p.selection_rank,
          p.id
        ''',
        args,
      );

      final result =
          <int, Map<String, Object?>>{};

      for (final row in rows) {
        final playerId =
            (row['player_id'] as num)
                .toInt();

        final item =
            Map<String, Object?>.from(
          row,
        );

        // Transitional camelCase aliases.
        //
        // Existing controllers may use either
        // database-style or model-style field names.
        item['selectionRank'] =
            row['selection_rank'];

        item['selectionScore'] =
            row['selection_score'];

        item['marketValue'] =
            row['market_value'];

        item['peakMarketValue'] =
            row['peak_market_value'];

        item['careerGoals'] =
            row['career_goals'];

        item['birthYear'] =
            row['birth_year'];

        item['positionGroup'] =
            row['position_group'];

        item['detailedPosition'] =
            row['detailed_position'];

        item['heightCm'] =
            row['height_cm'];

        item['internationalCaps'] =
            row['international_caps'];

        item['internationalGoals'] =
            row['international_goals'];

        result[playerId] = item;
      }

      if (kDebugMode) {
        debugPrint(
          '[HybridV4] playerFactsForPool '
          '$poolName -> tags=$tags '
          'count=${result.length}',
        );
      }

      return result;
    } catch (e) {
      debugPrint(
        '[HybridV4] playerFactsForPool('
        '$poolName) fallback: $e',
      );

      return const {};
    }
  }

  // =========================================================
  // Shared XI answer IDs
  // =========================================================

  Future<List<int>> sharedXiAnswerIds(
    int clubIdA,
    int clubIdB, {
    String playerPool = 'grid_answer',
  }) async {
    await _ensureReady();

    try {
      final tags =
          _requiredTags(playerPool);

      final args = <Object?>[
        clubIdA,
        clubIdB,
      ];

      final predicate =
          _tagPredicate(
        'p.id',
        tags,
      );

      final rows =
          await _v4.database.rawQuery(
        '''
        SELECT DISTINCT
          p.id
        FROM players p
        JOIN player_clubs a
          ON a.player_id = p.id
        JOIN player_clubs b
          ON b.player_id = p.id
        WHERE a.club_id = ?
          AND b.club_id = ?
          AND $predicate
        ORDER BY
          p.selection_rank IS NULL,
          p.selection_rank,
          p.id
        ''',
        args,
      );

      return rows
          .map(
            (row) =>
                (row['id'] as num).toInt(),
          )
          .toList();
    } catch (e) {
      debugPrint(
        '[HybridV4] sharedXiAnswerIds('
        '$clubIdA,$clubIdB,$playerPool) '
        'fallback: $e',
      );

      return const [];
    }
  }

  // =========================================================
  // Career
  // =========================================================

  Future<List<Map<String, Object?>>>
      careerTimeline(
    int playerId,
  ) async {
    await _ensureReady();

    try {
      final rows =
          await _v4.database.rawQuery(
        '''
        SELECT
          cs.player_id,
          cs.sequence,
          cs.club_id,
          cs.club_id AS exposed_club_id,
          cs.start_date,
          cs.end_date,
          cs.confidence,
          cs.appearances,

          c.name AS club_name,
          c.country AS club_country,
          c.competition AS club_competition

        FROM career_spells cs
        JOIN clubs c
          ON c.id = cs.club_id

        WHERE cs.player_id = ?

        ORDER BY cs.sequence
        ''',
        [playerId],
      );

      return rows
          .map(
            (row) =>
                Map<String, Object?>.from(
              row,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint(
        '[HybridV4] careerTimeline('
        '$playerId) fallback: $e',
      );

      return const [];
    }
  }

  // =========================================================
  // Transfer Detective
  // =========================================================

  List<Map<String, Object?>>? _transferDetectiveCache;

  Future<List<Map<String, Object?>>>
      transferDetectiveEvents({int limit = 1600}) async {
    await _ensureReady();

    try {
      final cached = _transferDetectiveCache;
      if (cached != null && cached.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            '[HybridV4] transferDetectiveEvents '
            'count=${cached.length} query=0ms cache=true',
          );
        }
        return cached;
      }

      // STEP 08D.7P.1:
      // Do NOT bind the ~261 curated club ids twice inside SQLite. On Android
      // that 500+ parameter IN/IN query is slower than scanning the already
      // pruned transfer table through the ranked-player relation.
      //
      // SQLite only builds a small high-recognition candidate envelope. The
      // curated club membership test is then an O(1) Dart Set lookup.
      final safeLimit = limit.clamp(500, 2400).toInt();
      final candidateLimit = (safeLimit * 2).clamp(2400, 4800).toInt();
      final knownClubIds = chainClubPool.toSet();

      if (knownClubIds.isEmpty) return const [];

      final watch = Stopwatch()..start();

      final rows = await _v4.database.rawQuery(
        '''
        SELECT
          t.event_id,
          t.player_id,
          t.transfer_date,
          t.transfer_year,
          t.from_club_id,
          t.to_club_id,
          t.trust,
          p.selection_rank
        FROM players p
        JOIN transfers t
          ON t.player_id = p.id
        WHERE p.selection_rank BETWEEN 1 AND 3500
          AND t.transfer_year >= 1990
          AND t.from_club_id <> t.to_club_id
        ORDER BY
          p.selection_rank,
          t.transfer_year DESC,
          t.event_id
        LIMIT ?
        ''',
        [candidateLimit],
      );

      watch.stop();

      final filterWatch = Stopwatch()..start();
      final selected = <Map<String, Object?>>[];

      for (final row in rows) {
        final fromClubId = (row['from_club_id'] as num?)?.toInt();
        final toClubId = (row['to_club_id'] as num?)?.toInt();

        if (fromClubId == null || toClubId == null) continue;
        if (!knownClubIds.contains(fromClubId) ||
            !knownClubIds.contains(toClubId)) {
          continue;
        }

        selected.add(Map<String, Object?>.from(row));
        if (selected.length >= safeLimit) break;
      }

      filterWatch.stop();

      // The top-ranked envelope should comfortably contain >400 globally
      // recognizable transfers. If it does not, use the best available rows
      // rather than falling back to full Repository hydration.
      final result = selected.length >= 400
          ? selected
          : rows
              .take(safeLimit)
              .map((row) => Map<String, Object?>.from(row))
              .toList(growable: false);

      _transferDetectiveCache =
          List<Map<String, Object?>>.unmodifiable(result);

      if (kDebugMode) {
        debugPrint(
          '[HybridV4] transferDetectiveEvents '
          'count=${result.length} candidates=${rows.length} '
          'query=${watch.elapsedMilliseconds}ms '
          'filter=${filterWatch.elapsedMilliseconds}ms '
          'limit=$safeLimit candidateLimit=$candidateLimit '
          'knownClubs=${knownClubIds.length} dartKnownFilter=true',
        );
      }

      return _transferDetectiveCache!;
    } catch (e) {
      debugPrint(
        '[HybridV4] transferDetectiveEvents '
        'fallback: $e',
      );

      return const [];
    }
  }

  // =========================================================
  // Gameplay club metadata
  // =========================================================

  Future<List<Map<String, Object?>>>
      existingGameplayClubMetadata() async {
    await _ensureReady();

    try {
      // Despite the legacy method name, V4 deliberately
      // exposes ONE canonical club namespace.
      //
      // Therefore this returns every club reachable by
      // playable players, regardless of whether its
      // canonical key originated from existing: or tm:.
      final rows =
          await _v4.database.rawQuery(
        '''
        SELECT DISTINCT
          c.id,
          c.id AS exposed_club_id,
          c.canonical_key,
          c.name,
          c.country,
          c.competition,
          c.entity_type,
          c.popularity_seed,
          c.gameplay_eligible,
          c.gameplay_pool,
          c.badge_key,
          c.color

        FROM clubs c

        JOIN player_clubs pc
          ON pc.club_id = c.id

        JOIN players p
          ON p.id = pc.player_id

        WHERE p.selection_rank IS NOT NULL

        ORDER BY
          c.gameplay_eligible DESC,
          c.popularity_seed DESC,
          c.name,
          c.id
        ''',
      );

      return rows
          .map(
            (row) =>
                Map<String, Object?>.from(
              row,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint(
        '[HybridV4] '
        'existingGameplayClubMetadata '
        'fallback: $e',
      );

      return const [];
    }
  }
}