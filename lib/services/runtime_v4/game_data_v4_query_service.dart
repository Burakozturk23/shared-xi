import 'package:flutter/foundation.dart';

import '../../models/club.dart';
import '../../models/match_entity.dart';
import '../../models/player.dart';
import '../../utils/country_names.dart';
import 'game_data_v4_database.dart';
import 'game_data_v4_legacy_bridge.dart';

/// Canonical V4 query/object gateway.
///
/// The SQLite package is the single source of truth. Legacy model objects are
/// hydrated only for rows requested by the current screen/mode and cached for
/// reuse. This avoids constructing the complete 30K Player universe at app
/// startup.
class GameDataV4QueryService {
  GameDataV4QueryService._();

  static final GameDataV4QueryService instance = GameDataV4QueryService._();

  final Map<int, Player> _playerCache = <int, Player>{};
  final Map<int, Club> _clubCache = <int, Club>{};

  List<Club>? _allClubsCache;
  List<Club>? _sharedXiClubCatalogCache;
  List<String>? _countriesCache;
  bool _clubQualityAuditDone = false;

  GameDataV4Database get _source => GameDataV4Database.instance;

  Future<void> initialize() => _source.initialize();

  Future<List<Player>> playersByIds(Iterable<int> ids) async {
    await initialize();

    const remaps = <int, int>{34601: 631002, 111961: 1650};

    final requested = <int>[];
    final seen = <int>{};
    for (final rawId in ids) {
      final id = remaps[rawId] ?? rawId;
      if (id > 0 && seen.add(id)) requested.add(id);
    }

    final missing = <int>[
      for (final id in requested)
        if (!_playerCache.containsKey(id)) id,
    ];

    if (missing.isNotEmpty) {
      final hydrated = await GameDataV4LegacyBridge.loadPlayersByIds(missing);
      for (final player in hydrated) {
        _playerCache[player.id] = player;
      }
    }

    return <Player>[
      for (final id in requested)
        if (_playerCache[id] != null) _playerCache[id]!,
    ];
  }

  Future<Player?> playerById(int id) async {
    final rows = await playersByIds(<int>[id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Club>> clubsByIds(Iterable<int> ids) async {
    await initialize();

    final requested = <int>[];
    final seen = <int>{};
    for (final id in ids) {
      if (id > 0 && seen.add(id)) requested.add(id);
    }

    final missing = <int>[
      for (final id in requested)
        if (!_clubCache.containsKey(id)) id,
    ];

    if (missing.isNotEmpty) {
      final hydrated = await GameDataV4LegacyBridge.loadClubsByIds(missing);
      for (final club in hydrated) {
        _clubCache[club.id] = club;
      }
    }

    return <Club>[
      for (final id in requested)
        if (_clubCache[id] != null) _clubCache[id]!,
    ];
  }

  Future<Club?> clubById(int id) async {
    final rows = await clubsByIds(<int>[id]);
    return rows.isEmpty ? null : rows.first;
  }

  /// Lightweight club catalog used by Shared XI discovery screens.
  ///
  /// Only clubs connected to the ranked 30K core are loaded by default.
  /// Transfer/career-only clubs stay in the canonical V4 database and are
  /// still reachable through [clubById]/[clubsByIds]; they simply do not make
  /// the discovery list unnecessarily large.
  ///
  /// [includeIds] is used for curated/popular matchups and prefilled clubs so
  /// those entries remain visible even if they sit outside the ranked core.
  Future<List<Club>> sharedXiClubCatalog({
    Iterable<int> includeIds = const <int>[],
  }) async {
    await initialize();

    var core = _sharedXiClubCatalogCache;
    if (core == null) {
      final queryWatch = Stopwatch()..start();

      // Start from the small club table and stop at the first ranked-core
      // player relation for each club. `player_clubs` has a club-leading
      // index, so this avoids scanning + DISTINCT/GROUP BY over the complete
      // relation table on every cold catalog load.
      //
      // Hydrate the Club objects directly from the same result set as well;
      // doing a second 2K-id IN query only duplicated SQLite work.
      final rows = await _source.database.rawQuery('''
        SELECT
          c.id,
          c.name,
          c.country,
          c.competition,
          c.badge_key,
          c.color
        FROM clubs c
        WHERE TRIM(c.name) <> ''
          AND LOWER(TRIM(c.name)) NOT LIKE 'club %'
          AND LOWER(c.name) NOT LIKE '% u16%'
          AND LOWER(c.name) NOT LIKE '% u17%'
          AND LOWER(c.name) NOT LIKE '% u18%'
          AND LOWER(c.name) NOT LIKE '% u19%'
          AND LOWER(c.name) NOT LIKE '% u20%'
          AND LOWER(c.name) NOT LIKE '% u21%'
          AND LOWER(c.name) NOT LIKE '% u23%'
          AND LOWER(c.name) NOT LIKE '%under 16%'
          AND LOWER(c.name) NOT LIKE '%under 17%'
          AND LOWER(c.name) NOT LIKE '%under 18%'
          AND LOWER(c.name) NOT LIKE '%under 19%'
          AND LOWER(c.name) NOT LIKE '%under 20%'
          AND LOWER(c.name) NOT LIKE '%under 21%'
          AND LOWER(c.name) NOT LIKE '%under 23%'
          AND LOWER(c.name) NOT LIKE '%youth%'
          AND LOWER(c.name) NOT LIKE '%academy%'
          AND LOWER(c.name) NOT LIKE '%juvenil%'
          AND LOWER(c.name) NOT LIKE '%primavera%'
          AND LOWER(c.name) NOT LIKE '%next gen%'
          AND LOWER(c.name) NOT LIKE '%reserve%'
          AND LOWER(c.name) NOT LIKE '%reserves%'
          AND LOWER(c.name) NOT LIKE '% b team%'
          AND LOWER(c.name) NOT LIKE '% b-team%'
          AND LOWER(TRIM(c.name)) NOT LIKE '% ii'
          AND LOWER(COALESCE(c.entity_type, '')) NOT IN (
            'youth', 'academy', 'reserve', 'reserves', 'development'
          )
          AND EXISTS (
            SELECT 1
            FROM player_clubs pc
            JOIN players p
              ON p.id = pc.player_id
            WHERE pc.club_id = c.id
              AND p.selection_rank BETWEEN 1 AND 30000
            LIMIT 1
          )
        ORDER BY
          c.popularity_seed DESC,
          c.name COLLATE NOCASE,
          c.id
      ''');

      queryWatch.stop();

      final hydrateWatch = Stopwatch()..start();
      final clubs = <Club>[];
      for (final row in rows) {
        final club = Club.fromJson({
          'id': row['id'],
          'name': row['name'],
          'league': row['competition']?.toString() ?? '',
          'country': row['country']?.toString() ?? '',
          'logo': '',
          'badgeKey': row['badge_key']?.toString() ?? '',
          'color': row['color'],
        });
        _clubCache[club.id] = club;
        clubs.add(club);
      }
      hydrateWatch.stop();

      core = List<Club>.unmodifiable(clubs);
      _sharedXiClubCatalogCache = core;

      if (kDebugMode) {
        debugPrint(
          '[V4Catalog] SharedXI core clubs '
          'count=${core.length} '
          'query=${queryWatch.elapsedMilliseconds}ms '
          'hydrate=${hydrateWatch.elapsedMilliseconds}ms',
        );
      }
    }

    final wanted = <int>{
      for (final id in includeIds)
        if (id > 0) id,
    };

    if (wanted.isEmpty) return core;

    final present = <int>{for (final club in core) club.id};
    final missing = <int>[
      for (final id in wanted)
        if (!present.contains(id)) id,
    ];

    if (missing.isEmpty) return core;

    final extras = await clubsByIds(missing);
    if (extras.isEmpty) return core;

    if (kDebugMode) {
      debugPrint(
        '[V4Catalog] SharedXI forced clubs '
        'requested=${wanted.length} added=${extras.length}',
      );
    }

    return List<Club>.unmodifiable(<Club>[...core, ...extras]);
  }

  /// Debug-only audit for club master quality.
  ///
  /// `player_clubs` is only one relation source. A club can still be required
  /// by career spells, transfers, stats, or curated club pools. This audit
  /// therefore distinguishes core gameplay clubs, history-required clubs, and
  /// rows that are orphaned from the V4 relational graph.
  ///
  /// Nothing is deleted here. `dbSafeOrphan` still needs a source-code pin
  /// audit before the compiler is allowed to physically remove that club ID.
  Future<void> debugAuditClubQuality({int sampleLimit = 10}) async {
    if (!kDebugMode || _clubQualityAuditDone) return;
    _clubQualityAuditDone = true;

    await initialize();

    try {
      // V4 production packages intentionally do not guarantee that every
      // historical compiler-side helper table is shipped. In particular,
      // `club_pools` is optional and is absent from the current production DB.
      // Build the audit CTE from the schema that actually exists instead of
      // making a debug-only audit crash gameplay.
      final schemaRows = await _source.database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final tableNames = <String>{
        for (final row in schemaRows) row['name']?.toString() ?? '',
      }..remove('');

      final hasClubPools = tableNames.contains('club_pools');
      final poolRefsSql = hasClubPools
          ? 'SELECT DISTINCT club_id AS id FROM club_pools'
          : 'SELECT CAST(NULL AS INTEGER) AS id WHERE 0';
      final optionalPoolUnion = hasClubPools
          ? '\n        UNION SELECT club_id AS id FROM club_pools'
          : '';

      if (kDebugMode && !hasClubPools) {
        debugPrint(
          '[V4ClubAudit2] club_pools absent; continuing with shipped V4 relations.',
        );
      }

      const badNamePredicate = r'''(
      TRIM(c.name) = ''
      OR LOWER(TRIM(c.name)) LIKE 'club %'
      OR LOWER(c.name) LIKE '% u16%'
      OR LOWER(c.name) LIKE '% u17%'
      OR LOWER(c.name) LIKE '% u18%'
      OR LOWER(c.name) LIKE '% u19%'
      OR LOWER(c.name) LIKE '% u20%'
      OR LOWER(c.name) LIKE '% u21%'
      OR LOWER(c.name) LIKE '% u23%'
      OR LOWER(c.name) LIKE '%under 16%'
      OR LOWER(c.name) LIKE '%under 17%'
      OR LOWER(c.name) LIKE '%under 18%'
      OR LOWER(c.name) LIKE '%under 19%'
      OR LOWER(c.name) LIKE '%under 20%'
      OR LOWER(c.name) LIKE '%under 21%'
      OR LOWER(c.name) LIKE '%under 23%'
      OR LOWER(c.name) LIKE '%youth%'
      OR LOWER(c.name) LIKE '%academy%'
      OR LOWER(c.name) LIKE '%juvenil%'
      OR LOWER(c.name) LIKE '%primavera%'
      OR LOWER(c.name) LIKE '%next gen%'
      OR LOWER(c.name) LIKE '%reserve%'
      OR LOWER(c.name) LIKE '%reserves%'
      OR LOWER(c.name) LIKE '% b team%'
      OR LOWER(c.name) LIKE '% b-team%'
      OR LOWER(TRIM(c.name)) LIKE '% ii'
      OR LOWER(COALESCE(c.entity_type, '')) IN (
        'youth', 'academy', 'reserve', 'reserves', 'development'
      )
    )''';

      final summaryRows = await _source.database.rawQuery('''
      WITH
      player_refs AS (
        SELECT DISTINCT club_id AS id FROM player_clubs
      ),
      career_refs AS (
        SELECT DISTINCT club_id AS id FROM career_spells
      ),
      transfer_refs AS (
        SELECT DISTINCT from_club_id AS id
        FROM transfers
        WHERE from_club_id IS NOT NULL
        UNION
        SELECT DISTINCT to_club_id AS id
        FROM transfers
        WHERE to_club_id IS NOT NULL
      ),
      stat_refs AS (
        SELECT DISTINCT club_id AS id FROM player_club_stats
      ),
      pool_refs AS (
        $poolRefsSql
      ),
      any_refs AS (
        SELECT id FROM player_refs
        UNION SELECT id FROM career_refs
        UNION SELECT id FROM transfer_refs
        UNION SELECT id FROM stat_refs
        UNION SELECT id FROM pool_refs
      ),
      core_refs AS (
        SELECT DISTINCT pc.club_id AS id
        FROM player_clubs pc
        JOIN players p ON p.id = pc.player_id
        WHERE p.selection_rank BETWEEN 1 AND 30000
      )
      SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN $badNamePredicate THEN 1 ELSE 0 END)
          AS development_or_placeholder,
        SUM(CASE WHEN pr.id IS NOT NULL THEN 1 ELSE 0 END)
          AS player_referenced,
        SUM(CASE WHEN cr.id IS NOT NULL THEN 1 ELSE 0 END)
          AS career_referenced,
        SUM(CASE WHEN tr.id IS NOT NULL THEN 1 ELSE 0 END)
          AS transfer_referenced,
        SUM(CASE WHEN sr.id IS NOT NULL THEN 1 ELSE 0 END)
          AS stats_referenced,
        SUM(CASE WHEN por.id IS NOT NULL THEN 1 ELSE 0 END)
          AS pool_referenced,
        SUM(CASE WHEN ar.id IS NOT NULL THEN 1 ELSE 0 END)
          AS any_referenced,
        SUM(CASE WHEN cor.id IS NOT NULL THEN 1 ELSE 0 END)
          AS core_gameplay,
        SUM(CASE WHEN ar.id IS NOT NULL AND cor.id IS NULL THEN 1 ELSE 0 END)
          AS history_required,
        SUM(CASE WHEN ar.id IS NULL THEN 1 ELSE 0 END)
          AS db_safe_orphan,
        SUM(CASE WHEN $badNamePredicate AND ar.id IS NOT NULL THEN 1 ELSE 0 END)
          AS development_referenced,
        SUM(CASE WHEN $badNamePredicate AND ar.id IS NULL THEN 1 ELSE 0 END)
          AS development_safe_orphan,
        SUM(CASE WHEN NOT $badNamePredicate AND ar.id IS NULL THEN 1 ELSE 0 END)
          AS senior_named_safe_orphan,

        -- Development rows are often present only because the transfer graph
        -- contains youth/reserve movements. Distinguish those from clubs that
        -- are structurally required by playable-player, career, stats, or pool
        -- relations. Only transfer-only development clubs are candidates for a
        -- future compiler prune, and even those are NOT deleted by this audit.
        SUM(CASE WHEN $badNamePredicate AND cor.id IS NOT NULL THEN 1 ELSE 0 END)
          AS development_core_gameplay,
        SUM(CASE WHEN $badNamePredicate AND pr.id IS NOT NULL THEN 1 ELSE 0 END)
          AS development_player_referenced,
        SUM(CASE WHEN $badNamePredicate AND cr.id IS NOT NULL THEN 1 ELSE 0 END)
          AS development_career_referenced,
        SUM(CASE WHEN $badNamePredicate AND sr.id IS NOT NULL THEN 1 ELSE 0 END)
          AS development_stats_referenced,
        SUM(CASE WHEN $badNamePredicate AND por.id IS NOT NULL THEN 1 ELSE 0 END)
          AS development_pool_referenced,
        SUM(CASE WHEN $badNamePredicate AND tr.id IS NOT NULL THEN 1 ELSE 0 END)
          AS development_transfer_referenced,
        SUM(CASE WHEN
              $badNamePredicate
              AND tr.id IS NOT NULL
              AND pr.id IS NULL
              AND cr.id IS NULL
              AND sr.id IS NULL
              AND por.id IS NULL
            THEN 1 ELSE 0 END)
          AS development_transfer_only,
        SUM(CASE WHEN
              $badNamePredicate
              AND (pr.id IS NOT NULL OR cr.id IS NOT NULL OR sr.id IS NOT NULL OR por.id IS NOT NULL)
            THEN 1 ELSE 0 END)
          AS development_structural
      FROM clubs c
      LEFT JOIN player_refs pr ON pr.id = c.id
      LEFT JOIN career_refs cr ON cr.id = c.id
      LEFT JOIN transfer_refs tr ON tr.id = c.id
      LEFT JOIN stat_refs sr ON sr.id = c.id
      LEFT JOIN pool_refs por ON por.id = c.id
      LEFT JOIN any_refs ar ON ar.id = c.id
      LEFT JOIN core_refs cor ON cor.id = c.id
    ''');

      final safeOrphanSamples = await _source.database.rawQuery(
        '''
      WITH any_refs AS (
        SELECT club_id AS id FROM player_clubs
        UNION SELECT club_id AS id FROM career_spells
        UNION SELECT from_club_id AS id FROM transfers WHERE from_club_id IS NOT NULL
        UNION SELECT to_club_id AS id FROM transfers WHERE to_club_id IS NOT NULL
        UNION SELECT club_id AS id FROM player_club_stats
        $optionalPoolUnion
      )
      SELECT c.id, c.name, c.country, c.competition, c.entity_type
      FROM clubs c
      LEFT JOIN any_refs ar ON ar.id = c.id
      WHERE ar.id IS NULL
      ORDER BY
        CASE WHEN $badNamePredicate THEN 0 ELSE 1 END,
        c.name COLLATE NOCASE,
        c.id
      LIMIT ?
      ''',
        <Object?>[sampleLimit.clamp(1, 30).toInt()],
      );

      final requiredDevelopmentSamples = await _source.database.rawQuery(
        '''
      WITH any_refs AS (
        SELECT club_id AS id FROM player_clubs
        UNION SELECT club_id AS id FROM career_spells
        UNION SELECT from_club_id AS id FROM transfers WHERE from_club_id IS NOT NULL
        UNION SELECT to_club_id AS id FROM transfers WHERE to_club_id IS NOT NULL
        UNION SELECT club_id AS id FROM player_club_stats
        $optionalPoolUnion
      )
      SELECT c.id, c.name, c.country, c.competition, c.entity_type
      FROM clubs c
      JOIN any_refs ar ON ar.id = c.id
      WHERE $badNamePredicate
      ORDER BY c.name COLLATE NOCASE, c.id
      LIMIT ?
      ''',
        <Object?>[sampleLimit.clamp(1, 30).toInt()],
      );

      final transferOnlyDevelopmentSamples = await _source.database.rawQuery(
        '''
      WITH
      player_refs AS (SELECT DISTINCT club_id AS id FROM player_clubs),
      career_refs AS (SELECT DISTINCT club_id AS id FROM career_spells),
      transfer_refs AS (
        SELECT DISTINCT from_club_id AS id FROM transfers WHERE from_club_id IS NOT NULL
        UNION
        SELECT DISTINCT to_club_id AS id FROM transfers WHERE to_club_id IS NOT NULL
      ),
      stat_refs AS (SELECT DISTINCT club_id AS id FROM player_club_stats),
      pool_refs AS ($poolRefsSql)
      SELECT
        c.id, c.name, c.country, c.competition, c.entity_type,
        (SELECT COUNT(*) FROM transfers t
          WHERE t.from_club_id = c.id OR t.to_club_id = c.id) AS transfer_rows
      FROM clubs c
      JOIN transfer_refs tr ON tr.id = c.id
      LEFT JOIN player_refs pr ON pr.id = c.id
      LEFT JOIN career_refs cr ON cr.id = c.id
      LEFT JOIN stat_refs sr ON sr.id = c.id
      LEFT JOIN pool_refs por ON por.id = c.id
      WHERE $badNamePredicate
        AND pr.id IS NULL
        AND cr.id IS NULL
        AND sr.id IS NULL
        AND por.id IS NULL
      ORDER BY transfer_rows DESC, c.name COLLATE NOCASE, c.id
      LIMIT ?
      ''',
        <Object?>[sampleLimit.clamp(1, 30).toInt()],
      );

      final summary = summaryRows.isEmpty
          ? const <String, Object?>{}
          : summaryRows.first;

      debugPrint(
        '[V4ClubAudit2] total=${summary['total'] ?? 0} '
        'development/placeholder=${summary['development_or_placeholder'] ?? 0} '
        'coreGameplay=${summary['core_gameplay'] ?? 0} '
        'historyRequired=${summary['history_required'] ?? 0} '
        'dbSafeOrphan=${summary['db_safe_orphan'] ?? 0}',
      );

      debugPrint(
        '[V4ClubAudit2] refs '
        'player=${summary['player_referenced'] ?? 0} '
        'career=${summary['career_referenced'] ?? 0} '
        'transfer=${summary['transfer_referenced'] ?? 0} '
        'stats=${summary['stats_referenced'] ?? 0} '
        'pool=${summary['pool_referenced'] ?? 0} '
        'any=${summary['any_referenced'] ?? 0}',
      );

      debugPrint(
        '[V4ClubAudit2] cleanupCandidates '
        'developmentSafeOrphan=${summary['development_safe_orphan'] ?? 0} '
        'seniorNamedSafeOrphan=${summary['senior_named_safe_orphan'] ?? 0} '
        'developmentReferenced=${summary['development_referenced'] ?? 0}',
      );

      debugPrint(
        '[V4ClubAudit3] developmentBreakdown '
        'core=${summary['development_core_gameplay'] ?? 0} '
        'player=${summary['development_player_referenced'] ?? 0} '
        'career=${summary['development_career_referenced'] ?? 0} '
        'stats=${summary['development_stats_referenced'] ?? 0} '
        'pool=${summary['development_pool_referenced'] ?? 0} '
        'transfer=${summary['development_transfer_referenced'] ?? 0} '
        'structural=${summary['development_structural'] ?? 0} '
        'transferOnly=${summary['development_transfer_only'] ?? 0}',
      );

      for (final row in transferOnlyDevelopmentSamples) {
        debugPrint(
          '[V4ClubAudit3] transferOnlyDevSample id=${row['id']} '
          'name=${row['name']} country=${row['country']} '
          'competition=${row['competition']} type=${row['entity_type']} '
          'transferRows=${row['transfer_rows']}',
        );
      }

      for (final row in safeOrphanSamples) {
        debugPrint(
          '[V4ClubAudit2] orphanSample id=${row['id']} '
          'name=${row['name']} country=${row['country']} '
          'competition=${row['competition']} type=${row['entity_type']}',
        );
      }

      for (final row in requiredDevelopmentSamples) {
        debugPrint(
          '[V4ClubAudit2] requiredDevSample id=${row['id']} '
          'name=${row['name']} country=${row['country']} '
          'competition=${row['competition']} type=${row['entity_type']}',
        );
      }
    } catch (e, st) {
      // This is diagnostic-only. Audit failures must never break a playable
      // V4 mode or fall the controller back to the full legacy Repository.
      debugPrint('[V4ClubAudit2] audit failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<List<Club>> allClubs() async {
    final cached = _allClubsCache;
    if (cached != null) return cached;

    await initialize();
    final clubs = await GameDataV4LegacyBridge.loadClubs();
    for (final club in clubs) {
      _clubCache[club.id] = club;
    }
    _allClubsCache = List<Club>.unmodifiable(clubs);
    return _allClubsCache!;
  }

  Future<List<String>> countries() async {
    final cached = _countriesCache;
    if (cached != null) return cached;

    await initialize();

    final rows = await _source.database.rawQuery('''
      SELECT country
      FROM (
        SELECT country FROM player_countries
        UNION
        SELECT country FROM players
      )
      WHERE country IS NOT NULL
        AND TRIM(country) <> ''
      ORDER BY country COLLATE NOCASE
    ''');

    final seen = <String>{};
    final out = <String>[];
    for (final row in rows) {
      final raw = row['country']?.toString() ?? '';
      final value = CountryNames.canonical(raw);
      if (value.isNotEmpty && seen.add(value.toLowerCase())) {
        out.add(value);
      }
    }
    out.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    _countriesCache = List<String>.unmodifiable(out);
    return _countriesCache!;
  }

  /// Lightweight V4-backed player search used by modes that no longer keep
  /// the complete Repository player universe in memory.
  Future<List<Player>> searchPlayers(String query, {int limit = 24}) async {
    await initialize();

    final q = query.trim();
    if (q.length < 2) return const <Player>[];

    final safeLimit = limit.clamp(1, 60).toInt();
    final like = '%$q%';

    final rows = await _source.database.rawQuery(
      '''
      SELECT DISTINCT p.id
      FROM players p
      LEFT JOIN player_aliases pa
        ON pa.player_id = p.id
      WHERE p.selection_rank BETWEEN 1 AND 30000
        AND (
          p.name LIKE ? COLLATE NOCASE
          OR pa.alias LIKE ? COLLATE NOCASE
        )
      ORDER BY p.selection_rank, p.id
      LIMIT ?
      ''',
      <Object?>[like, like, safeLimit],
    );

    return playersByIds(rows.map((row) => (row['id'] as num).toInt()));
  }

  Future<bool> hasClubClubMatch(int clubId1, int clubId2) async {
    if (clubId1 <= 0 || clubId2 <= 0 || clubId1 == clubId2) return false;

    await initialize();

    final rows = await _source.database.rawQuery(
      '''
      SELECT 1
      FROM player_clubs a
      JOIN player_clubs b
        ON b.player_id = a.player_id
      WHERE a.club_id = ?
        AND b.club_id = ?
      LIMIT 1
      ''',
      <Object?>[clubId1, clubId2],
    );

    return rows.isNotEmpty;
  }

  Future<bool> hasClubCountryMatch(int clubId, String country) async {
    if (clubId <= 0) return false;

    final canonicalCountry = CountryNames.canonical(country);
    if (canonicalCountry.isEmpty) return false;

    await initialize();

    final rows = await _source.database.rawQuery(
      '''
      SELECT 1
      FROM players p
      JOIN player_clubs pc
        ON pc.player_id = p.id
      WHERE pc.club_id = ?
        AND (
          p.country = ? COLLATE NOCASE
          OR EXISTS (
            SELECT 1
            FROM player_countries pn
            WHERE pn.player_id = p.id
              AND pn.country = ? COLLATE NOCASE
          )
        )
      LIMIT 1
      ''',
      <Object?>[clubId, canonicalCountry, canonicalCountry],
    );

    return rows.isNotEmpty;
  }

  Future<List<Player>> matchingPlayers({
    required MatchEntity entity1,
    required MatchEntity entity2,
  }) async {
    await initialize();

    final args = <Object?>[];
    final first = _entityPredicate(entity1, 1, args);
    final second = _entityPredicate(entity2, 2, args);

    final rows = await _source.database.rawQuery('''
      SELECT p.id
      FROM players p
      WHERE TRIM(p.name) <> ''
        AND $first
        AND $second
      ORDER BY
        p.selection_rank IS NULL,
        p.selection_rank,
        p.id
      ''', args);

    final ids = rows
        .map((row) => (row['id'] as num).toInt())
        .toList(growable: false);

    return playersByIds(ids);
  }

  String _entityPredicate(MatchEntity entity, int slot, List<Object?> args) {
    switch (entity.type) {
      case MatchEntityType.club:
        final clubId = entity.clubId;
        if (clubId == null) return '0 = 1';
        args.add(clubId);
        return '''
          EXISTS (
            SELECT 1
            FROM player_clubs pc$slot
            WHERE pc$slot.player_id = p.id
              AND pc$slot.club_id = ?
          )
        ''';

      case MatchEntityType.country:
        final country = CountryNames.canonical(entity.countryName ?? '');
        if (country.isEmpty) return '0 = 1';
        args.add(country);
        args.add(country);
        return '''
          (
            p.country = ? COLLATE NOCASE
            OR EXISTS (
              SELECT 1
              FROM player_countries pn$slot
              WHERE pn$slot.player_id = p.id
                AND pn$slot.country = ? COLLATE NOCASE
            )
          )
        ''';
    }
  }
}
