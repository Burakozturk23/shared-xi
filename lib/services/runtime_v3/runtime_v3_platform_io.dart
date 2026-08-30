import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'runtime_v3_platform_base.dart';

RuntimeV3Platform createRuntimeV3Platform() => _IoRuntimeV3Platform();

class _IoRuntimeV3Platform implements RuntimeV3Platform {
  static const _dbAsset = 'assets/runtime/linkball_runtime_v3.sqlite';
  static const _manifestAsset = 'assets/runtime/runtime_manifest_v3.json';
  static const _tmClubOffset = 1000000000;

  Database? _db;

  @override
  bool get isSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  @override
  bool get isOpen => _db?.isOpen == true;

  Database get _database {
    final db = _db;
    if (db == null || !db.isOpen) {
      throw StateError('Runtime V3 database is not initialized.');
    }
    return db;
  }

  @override
  Future<void> initialize() async {
    if (!isSupported || isOpen) return;

    final manifestRaw = await rootBundle.loadString(_manifestAsset);
    final manifest = jsonDecode(manifestRaw) as Map<String, dynamic>;
    final dbMeta = manifest['database'] as Map<String, dynamic>;
    final expectedBytes = (dbMeta['bytes'] as num).toInt();
    final sha = dbMeta['sha256']!.toString();

    final databasesPath = await getDatabasesPath();
    final target = File(
      '$databasesPath${Platform.pathSeparator}'
      'linkball_runtime_v3_${sha.substring(0, 12)}.sqlite',
    );

    var mustCopy = !await target.exists();
    if (!mustCopy) {
      mustCopy = (await target.stat()).size != expectedBytes;
    }

    if (mustCopy) {
      await Directory(databasesPath).create(recursive: true);
      final data = await rootBundle.load(_dbAsset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      if (bytes.length != expectedBytes) {
        throw StateError(
          'Runtime V3 asset size mismatch: ${bytes.length} != $expectedBytes',
        );
      }

      final temp = File('${target.path}.tmp');
      if (await temp.exists()) await temp.delete();
      await temp.writeAsBytes(bytes);
      if (await target.exists()) await target.delete();
      await temp.rename(target.path);
    }

    _db = await openDatabase(target.path, readOnly: true, singleInstance: true);

    // STEP 07A.8: full integrity_check cost ~2.8s in the measured
    // release profile. Validate only a freshly copied/version-changed DB and
    // use SQLite quick_check. Cached DBs go straight to schema metadata.
    if (mustCopy) {
      final integrity = await _database.rawQuery('PRAGMA quick_check');
      final value = integrity.isEmpty
          ? ''
          : integrity.first.values.first?.toString();

      if (value != 'ok') {
        await close();
        try {
          if (await target.exists()) {
            await target.delete();
          }
        } catch (_) {}

        throw StateError('Runtime V3 quick_check failed: $value');
      }
    }

    final meta = await metadata();
    if (meta['schema_version'] != '3-preview') {
      await close();
      throw StateError(
        'Unexpected Runtime V3 schema: ${meta['schema_version']}',
      );
    }
  }

  int _exposedClubId(String canonicalKey, int internalId) {
    if (canonicalKey.startsWith('existing:')) {
      return int.tryParse(canonicalKey.substring(9)) ?? internalId;
    }
    if (canonicalKey.startsWith('tm:')) {
      final sourceId = int.tryParse(canonicalKey.substring(3));
      if (sourceId != null) return _tmClubOffset + sourceId;
    }
    return 2000000000 + internalId;
  }

  Future<int?> _internalClubId(int exposedId) async {
    String? key;
    if (exposedId > 0 && exposedId < _tmClubOffset) {
      key = 'existing:$exposedId';
    } else if (exposedId >= _tmClubOffset && exposedId < 2000000000) {
      key = 'tm:${exposedId - _tmClubOffset}';
    }
    if (key == null) return null;

    final rows = await _database.query(
      'clubs',
      columns: const ['id'],
      where: 'canonical_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['id'] as num).toInt();
  }

  @override
  Future<Map<String, String>> metadata() async {
    final rows = await _database.query('metadata');
    return {
      for (final row in rows) row['key']!.toString(): row['value']!.toString(),
    };
  }

  @override
  Future<Map<String, int>> tableCounts() async {
    const tables = [
      'players',
      'clubs',
      'player_clubs',
      'profiles',
      'player_stats',
      'career_spells',
      'transfers',
      'player_pools',
      'club_pools',
      'event_pools',
    ];
    final out = <String, int>{};
    for (final table in tables) {
      final rows = await _database.rawQuery('SELECT COUNT(*) AS c FROM $table');
      out[table] = (rows.first['c'] as num).toInt();
    }
    return out;
  }

  @override
  Future<List<int>> allPlayerIds() async {
    final rows = await _database.query(
      'players',
      columns: const ['id'],
      orderBy: 'id',
    );
    return rows.map((r) => (r['id'] as num).toInt()).toList();
  }

  @override
  Future<List<int>> existingClubIds() async {
    final rows = await _database.rawQuery(
      "SELECT id, canonical_key FROM clubs "
      "WHERE canonical_key LIKE 'existing:%'",
    );
    return rows.map((r) {
      return _exposedClubId(
        r['canonical_key']!.toString(),
        (r['id'] as num).toInt(),
      );
    }).toList();
  }

  @override
  Future<List<int>> playerIdsInPool(String poolName) async {
    final rows = await _database.rawQuery(
      '''
      SELECT pp.player_id
      FROM player_pools pp
      JOIN players p ON p.id = pp.player_id
      WHERE pp.pool_name = ?
        AND p.is_shadow = 0
      ORDER BY
        CASE WHEN p.selection_rank IS NULL THEN 1 ELSE 0 END,
        p.selection_rank,
        pp.player_id
      ''',
      [poolName],
    );
    return rows.map((r) => (r['player_id'] as num).toInt()).toList();
  }

  @override
  Future<List<int>> clubIdsInPool(String poolName) async {
    final rows = await _database.rawQuery(
      '''
      SELECT c.id, c.canonical_key
      FROM club_pools cp
      JOIN clubs c ON c.id = cp.club_id
      WHERE cp.pool_name = ?
      ORDER BY
        c.popularity_seed DESC,
        c.id
      ''',
      [poolName],
    );
    return rows.map((r) {
      return _exposedClubId(
        r['canonical_key']!.toString(),
        (r['id'] as num).toInt(),
      );
    }).toList();
  }

  @override
  Future<List<int>> playersForClub(
    int exposedClubId, {
    String? playerPool,
  }) async {
    final clubId = await _internalClubId(exposedClubId);
    if (clubId == null) return const [];

    if (playerPool == null || playerPool.isEmpty) {
      final rows = await _database.rawQuery(
        '''
        SELECT pc.player_id
        FROM player_clubs pc
        JOIN players p ON p.id = pc.player_id
        WHERE pc.club_id = ?
          AND p.is_shadow = 0
        ORDER BY
          CASE WHEN p.selection_rank IS NULL THEN 1 ELSE 0 END,
          p.selection_rank,
          pc.player_id
        ''',
        [clubId],
      );
      return rows.map((r) => (r['player_id'] as num).toInt()).toList();
    }

    final rows = await _database.rawQuery(
      '''
      SELECT pc.player_id
      FROM player_clubs pc
      JOIN player_pools pp ON pp.player_id = pc.player_id
      JOIN players p ON p.id = pc.player_id
      WHERE pc.club_id = ?
        AND pp.pool_name = ?
        AND p.is_shadow = 0
      ORDER BY
        CASE WHEN p.selection_rank IS NULL THEN 1 ELSE 0 END,
        p.selection_rank,
        pc.player_id
      ''',
      [clubId, playerPool],
    );
    return rows.map((r) => (r['player_id'] as num).toInt()).toList();
  }

  @override
  Future<List<int>> clubIdsForPlayer(int playerId) async {
    final rows = await _database.rawQuery(
      '''
      SELECT c.id, c.canonical_key
      FROM player_clubs pc
      JOIN clubs c ON c.id = pc.club_id
      WHERE pc.player_id = ?
        AND c.gameplay_eligible = 1
        AND c.entity_type = 'SENIOR'
      ORDER BY c.popularity_seed DESC, c.id
      ''',
      [playerId],
    );
    return rows.map((r) {
      return _exposedClubId(
        r['canonical_key']!.toString(),
        (r['id'] as num).toInt(),
      );
    }).toList();
  }

  @override
  Future<Map<int, List<int>>> playerClubIdsForPool(String poolName) async {
    final rows = await _database.rawQuery(
      '''
      SELECT
        pc.player_id,
        c.id,
        c.canonical_key
      FROM player_pools pp
      JOIN player_clubs pc ON pc.player_id = pp.player_id
      JOIN clubs c ON c.id = pc.club_id
      WHERE pp.pool_name = ?
        AND c.gameplay_eligible = 1
        AND c.entity_type = 'SENIOR'
        AND c.canonical_key LIKE 'existing:%'
      ORDER BY pc.player_id, c.popularity_seed DESC, c.id
      ''',
      [poolName],
    );

    final out = <int, List<int>>{};
    for (final row in rows) {
      final playerId = (row['player_id'] as num).toInt();
      final exposedId = _exposedClubId(
        row['canonical_key']!.toString(),
        (row['id'] as num).toInt(),
      );
      out.putIfAbsent(playerId, () => <int>[]).add(exposedId);
    }
    return out;
  }

  @override
  Future<List<int>> topGameplayClubIds({int limit = 400}) async {
    final safeLimit = limit.clamp(20, 2000);
    final rows = await _database.rawQuery(
      '''
      SELECT id, canonical_key
      FROM clubs
      WHERE gameplay_eligible = 1
        AND entity_type = 'SENIOR'
        AND canonical_key LIKE 'existing:%'
      ORDER BY popularity_seed DESC, id
      LIMIT ?
      ''',
      [safeLimit],
    );

    return rows.map((r) {
      return _exposedClubId(
        r['canonical_key']!.toString(),
        (r['id'] as num).toInt(),
      );
    }).toList();
  }

  @override
  Future<List<int>> sharedXiPlayerIds(
    int exposedClubIdA,
    int exposedClubIdB, {
    String playerPool = 'shared_xi_answer',
  }) async {
    final a = await _internalClubId(exposedClubIdA);
    final b = await _internalClubId(exposedClubIdB);
    if (a == null || b == null) return const [];

    final rows = await _database.rawQuery(
      '''
      SELECT x.player_id
      FROM player_clubs x
      JOIN player_clubs y ON y.player_id = x.player_id
      JOIN player_pools pp ON pp.player_id = x.player_id
      JOIN players p ON p.id = x.player_id
      WHERE x.club_id = ?
        AND y.club_id = ?
        AND pp.pool_name = ?
        AND p.is_shadow = 0
      ORDER BY
        CASE WHEN p.selection_rank IS NULL THEN 1 ELSE 0 END,
        p.selection_rank,
        x.player_id
      ''',
      [a, b, playerPool],
    );
    return rows.map((r) => (r['player_id'] as num).toInt()).toList();
  }

  @override
  Future<Map<int, Map<String, Object?>>> playerFactsForPool(
    String poolName,
  ) async {
    final rows = await _database.rawQuery(
      """
      SELECT
        p.id AS player_id,
        p.selection_rank,
        p.selection_score,
        p.country,
        p.position,
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
      FROM player_pools pp
      JOIN players p ON p.id = pp.player_id
      LEFT JOIN profiles pr ON pr.player_id = p.id
      LEFT JOIN player_stats ps ON ps.player_id = p.id
      WHERE pp.pool_name = ?
        AND p.is_shadow = 0
      ORDER BY
        CASE WHEN p.selection_rank IS NULL THEN 1 ELSE 0 END,
        p.selection_rank,
        p.id
      """,
      [poolName],
    );

    final result = <int, Map<String, Object?>>{};
    for (final row in rows) {
      final playerId = (row['player_id'] as num).toInt();
      result[playerId] = Map<String, Object?>.from(row);
    }
    return result;
  }

  @override
  Future<List<Map<String, Object?>>> transferDetectiveEvents() async {
    return _database.rawQuery("""
      SELECT
        t.event_id,
        t.player_id,
        t.transfer_year,
        t.transfer_date,
        CAST(substr(fc.canonical_key, 10) AS INTEGER) AS from_club_id,
        CAST(substr(tc.canonical_key, 10) AS INTEGER) AS to_club_id,
        t.trust,
        p.selection_rank
      FROM event_pools ep
      JOIN transfers t ON t.event_id = ep.event_id
      JOIN players p ON p.id = t.player_id
      JOIN clubs fc ON fc.id = t.from_club_id
      JOIN clubs tc ON tc.id = t.to_club_id
      WHERE ep.pool_name = 'transfer_detective_normal_v3'
        AND p.is_shadow = 0
        AND fc.canonical_key LIKE 'existing:%'
        AND tc.canonical_key LIKE 'existing:%'
      ORDER BY
        CASE WHEN p.selection_rank IS NULL THEN 1 ELSE 0 END,
        p.selection_rank,
        t.transfer_year DESC,
        t.event_id
      """);
  }

  @override
  Future<List<Map<String, Object?>>> existingGameplayClubMetadata() async {
    return _database.rawQuery("""
      SELECT
        CAST(substr(canonical_key, 10) AS INTEGER) AS exposed_club_id,
        name,
        country,
        competition,
        popularity_seed
      FROM clubs
      WHERE gameplay_eligible = 1
        AND entity_type = 'SENIOR'
        AND canonical_key LIKE 'existing:%'
      ORDER BY popularity_seed DESC, id
      """);
  }

  @override
  Future<List<Map<String, Object?>>> careerTimeline(int playerId) async {
    return _database.rawQuery(
      '''
      SELECT
        cs.sequence,
        c.canonical_key,
        c.name AS club_name,
        CASE
          WHEN c.canonical_key LIKE 'existing:%'
          THEN CAST(substr(c.canonical_key, 10) AS INTEGER)
          ELSE NULL
        END AS exposed_club_id,
        cs.start_date,
        cs.end_date,
        cs.confidence,
        cs.appearances
      FROM career_spells cs
      JOIN clubs c ON c.id = cs.club_id
      WHERE cs.player_id = ?
      ORDER BY cs.sequence
      ''',
      [playerId],
    );
  }

  @override
  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null && db.isOpen) await db.close();
  }
}
