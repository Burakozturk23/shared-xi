import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/history_record.dart';

abstract class HistoryRepository {
  Future<List<HistoryRecord>> browse({required bool squads, required HistoryScope scope, String query = '', int offset = 0});
  Future<HistoryDetail> detail(String id, {required bool squads});
  Future<HistoryDetail> selectionDetail(String id);
  Future<List<HistoryRecord>> selections();
}

/// Only opens the requested pack; never modifies the canonical V4 database.
class SqliteHistoryRepository implements HistoryRepository {
  SqliteHistoryRepository._();
  static final instance = SqliteHistoryRepository._();
  static const pageSize = 40;
  static const _lineupSelectionIds = <int>{18236, 18242, 18245, 22912, 3750201, 3750235, 3752619};
  final Map<String, Future<Database>> _opening = {};

  Future<Database> _database(String pack) async {
    if (kIsWeb) throw UnsupportedError('Historical archive requires a native app.');
    final pending = _opening.putIfAbsent(pack, () => _open(pack));
    try {
      return await pending;
    } catch (_) {
      if (identical(_opening[pack], pending)) _opening.remove(pack);
      rethrow;
    }
  }

  Future<Database> _open(String pack) async {
    final manifest = jsonDecode(await rootBundle.loadString('assets/history/manifest.json')) as Map<String, dynamic>;
    if (manifest['schema_version'] != 1) throw StateError('Unsupported historical schema');
    final info = (manifest['packs'] as Map<String, dynamic>)[pack] as Map<String, dynamic>;
    final directory = await getDatabasesPath();
    await Directory(directory).create(recursive: true);
    final target = '$directory/linkball_history_${pack}_${info['sha256']}.sqlite';
    // Decompression and hashing run off the UI isolate, including cache validation.
    final file = File(target);
    final cached = await compute(_validCache, {'path': target, 'bytes': info['bytes'], 'sha256': info['sha256']});
    if (!cached) {
      final chunks = <Uint8List>[];
      for (final part in info['parts'] as List<dynamic>) {
        final asset = await rootBundle.load(part['asset'] as String);
        chunks.add(asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes));
      }
      await compute(_installPack, {
        'path': target, 'info': info,
        'compressed': chunks,
      });
    }
    final db = await openDatabase(file.path, readOnly: true);
    try {
      final version = await db.rawQuery('PRAGMA user_version');
      if (version.single.values.single != 1) throw StateError('Historical schema mismatch');
      // Remove only prior versions owned by this pack after the new copy opens.
      try {
        await for (final entry in Directory(directory).list()) {
          final name = entry.path.split(Platform.pathSeparator).last;
          if (entry is File && entry.path != target && RegExp('^linkball_history_${pack}_[a-f0-9]{64}\\.sqlite\$').hasMatch(name)) {
            await entry.delete();
          }
        }
      } on FileSystemException {
        // Cleanup failure must not make a valid archive unavailable.
      }
      return db;
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  @override
  Future<List<HistoryRecord>> browse({required bool squads, required HistoryScope scope, String query = '', int offset = 0}) async {
    if (offset < 0) throw ArgumentError.value(offset, 'offset');
    final db = await _database(squads ? 'squads' : 'matches');
    final statement = historyBrowseQuery(squads: squads, scope: scope, query: query, offset: offset);
    return (await db.rawQuery(statement.sql, statement.arguments)).map(HistoryRecord.new).toList();
  }

  @override
  Future<List<HistoryRecord>> selections() async {
    final db = await _database('matches');
    final rows = await db.rawQuery('SELECT * FROM selections ORDER BY date,id');
    final result = <HistoryRecord>[];
    for (final row in rows) {
      final id = (row['id'] as num).toInt();
      final lineup = await _loadLineups(id);
      result.add(HistoryRecord({...row, 'lineup_entries': lineup.length}));
    }
    return result;
  }

  @override
  Future<HistoryDetail> detail(String id, {required bool squads}) async {
    final db = await _database(squads ? 'squads' : 'matches');
    if (squads) {
      final rows = await db.rawQuery('SELECT r.*, t.name AS team FROM rosters r JOIN teams t ON t.id=r.team_id WHERE r.id=?', [id]);
      if (rows.isEmpty) throw StateError('Roster not found');
      final players = await db.rawQuery("SELECT * FROM squad_entries WHERE roster_id=? ORDER BY CASE status WHEN 'listed' THEN 0 ELSE 1 END,id", [id]);
      final sources = await db.rawQuery('SELECT s.* FROM sources s JOIN rosters r ON r.source_id=s.id WHERE r.id=?', [id]);
      return HistoryDetail(record: HistoryRecord(rows.single), players: players.map(HistoryRecord.new).toList(), sources: sources.map(HistoryRecord.new).toList());
    }
    final rows = await db.rawQuery('''SELECT m.*, h.name AS home, a.name AS away, w.name AS shootout_winner
      FROM matches m JOIN teams h ON h.id=m.home_id JOIN teams a ON a.id=m.away_id
      LEFT JOIN teams w ON w.id=m.shootout_winner_id WHERE m.id=?''', [id]);
    if (rows.isEmpty) throw StateError('Match not found');
    final goals = await db.rawQuery('SELECT g.*, t.name AS team FROM goals g JOIN teams t ON t.id=g.team_id WHERE match_id=? ORDER BY CAST(minute AS INTEGER),g.id', [id]);
    final selection = await db.rawQuery('SELECT id FROM selections WHERE match_id=?', [id]);
    final lineups = selection.isEmpty ? const <HistoryRecord>[] : await _loadLineups((selection.single['id'] as num).toInt());
    final sources = await db.rawQuery('SELECT DISTINCT s.* FROM sources s JOIN match_sources ms ON ms.source_id=s.id WHERE ms.match_id=? ORDER BY s.name', [id]);
    final sourceRecords = sources.map(HistoryRecord.new).toList();
    if (lineups.isNotEmpty && sourceRecords.every((source) => source.text('id') != 'statsbomb')) {
      sourceRecords.add(_statsBombSource);
    }
    return HistoryDetail(record: HistoryRecord(rows.single), goals: goals.map(HistoryRecord.new).toList(), lineups: lineups, sources: sourceRecords);
  }

  @override
  Future<HistoryDetail> selectionDetail(String id) async {
    final db = await _database('matches');
    // The distributed production pack intentionally keeps the verified first
    // elevens as small JSON sidecars. Do not query the optional importer-only
    // `lineup_entries` table here: older packs (including the shipped pack)
    // remain fully compatible and get their count from the same sidecar used
    // to render the lineup.
    final rows = await db.rawQuery('SELECT s.* FROM selections s WHERE s.id=?', [id]);
    if (rows.isEmpty) throw StateError('Selection not found');
    final lineups = await _loadLineups(int.parse(id));
    final record = HistoryRecord({...rows.single, 'lineup_entries': lineups.length});
    final sources = await db.rawQuery('SELECT * FROM sources WHERE id=?', ['statsbomb']);
    final sourceRecords = sources.map(HistoryRecord.new).toList();
    if (lineups.isNotEmpty && sourceRecords.every((source) => source.text('id') != 'statsbomb')) sourceRecords.add(_statsBombSource);
    return HistoryDetail(record: record, lineups: lineups, sources: sourceRecords);
  }

  Future<List<HistoryRecord>> _loadLineups(int selectionId) async {
    if (!_lineupSelectionIds.contains(selectionId)) return const [];
    try {
      final raw = await rootBundle.loadString('assets/history/lineups/$selectionId.json');
      final teams = jsonDecode(raw);
      if (teams is! List) return const [];
      final result = <HistoryRecord>[];
      for (final team in teams) {
        if (team is! Map) continue;
        final teamId = team['team_id'];
        final teamName = team['team_name']?.toString() ?? '';
        final players = team['lineup'];
        if (teamId is! num || players is! List) continue;
        for (var order = 0; order < players.length; order++) {
          final player = players[order];
          if (player is! Map) continue;
          final positions = player['positions'];
          final firstPosition = positions is List && positions.isNotEmpty && positions.first is Map ? positions.first as Map : const <String, dynamic>{};
          final country = player['country'];
          result.add(HistoryRecord({
            'team_id': teamId,
            'team_name': teamName,
            'player_id': player['player_id'],
            'player_name': player['player_name'],
            'player_nickname': player['player_nickname'],
            'jersey_number': player['jersey_number'],
            'country': country is Map ? country['name'] : null,
            'position': firstPosition['position'],
            'starter': positions is List && positions.any((p) => p is Map && p['start_reason'] == 'Starting XI') ? 1 : 0,
            'position_order': order,
          }));
        }
      }
      return result;
    } on FlutterError {
      return const [];
    } on FormatException {
      return const [];
    }
  }

  static final _statsBombSource = HistoryRecord({
    'id': 'statsbomb',
    'name': 'StatsBomb Open Data lineups',
    'license': 'StatsBomb Open Data License',
    'url': 'https://github.com/hudl/open-data/tree/master/data/lineups',
  });
}

class HistoryQuery {
  const HistoryQuery(this.sql, this.arguments);
  final String sql;
  final List<Object?> arguments;
}

/// Values are always bound; SQL wildcard characters in user input are literal.
HistoryQuery historyBrowseQuery({required bool squads, required HistoryScope scope, String query = '', int offset = 0}) {
  final escaped = query.trim().replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
  final args = <Object?>[];
  final conditions = <String>[];
  String sql;
  if (squads) {
    sql = 'SELECT r.*, t.name AS team FROM rosters r JOIN teams t ON t.id=r.team_id';
    if (scope == HistoryScope.international) conditions.add("t.kind='international'");
    if (scope == HistoryScope.championsLeague) conditions.add("t.kind='club'");
    if (escaped.isNotEmpty) {
      conditions.add("(t.name LIKE ? ESCAPE '\\' OR r.context LIKE ? ESCAPE '\\' OR r.season LIKE ? ESCAPE '\\')");
      args.addAll(List.filled(3, '%$escaped%'));
    }
  } else {
    sql = 'SELECT m.*, h.name AS home, a.name AS away FROM matches m JOIN teams h ON h.id=m.home_id JOIN teams a ON a.id=m.away_id';
    if (scope == HistoryScope.international) conditions.add("m.kind='international'");
    if (scope == HistoryScope.championsLeague) conditions.add("m.competition='uefa.champions'");
    if (escaped.isNotEmpty) {
      conditions.add("(h.name LIKE ? ESCAPE '\\' OR a.name LIKE ? ESCAPE '\\' OR m.competition LIKE ? ESCAPE '\\' OR m.season LIKE ? ESCAPE '\\')");
      args.addAll(List.filled(4, '%$escaped%'));
    }
  }
  if (conditions.isNotEmpty) sql += ' WHERE ${conditions.join(' AND ')}';
  sql += squads ? ' ORDER BY r.season DESC,r.id' : ' ORDER BY m.date DESC,m.id';
  sql += ' LIMIT ? OFFSET ?';
  args.addAll([SqliteHistoryRepository.pageSize, offset]);
  return HistoryQuery(sql, args);
}

Future<bool> _validCache(Map<String, Object?> args) async {
  final file = File(args['path'] as String);
  if (!await file.exists() || await file.length() != args['bytes']) return false;
  return (await sha256.bind(file.openRead()).first).toString() == args['sha256'];
}

Future<void> _installPack(Map<String, Object?> args) async {
  final info = args['info'] as Map<String, dynamic>;
  final compressed = args['compressed'] as List<Uint8List>;
  final parts = info['parts'] as List<dynamic>;
  for (var i = 0; i < compressed.length; i++) {
    if (compressed[i].length != parts[i]['bytes'] || sha256.convert(compressed[i]).toString() != parts[i]['sha256']) {
      throw StateError('Historical asset part integrity failure');
    }
  }
  if (compressed.fold<int>(0, (sum, part) => sum + part.length) != info['compressed_bytes'] || (await sha256.bind(Stream<List<int>>.fromIterable(compressed)).first).toString() != info['compressed_sha256']) {
    throw StateError('Historical asset integrity failure');
  }
  final target = args['path'] as String;
  final temporary = File('$target.tmp');
  try {
    final sink = temporary.openWrite();
    try {
      await sink.addStream(gzip.decoder.bind(Stream<List<int>>.fromIterable(compressed)));
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (!await _validCache({'path': temporary.path, 'bytes': info['bytes'], 'sha256': info['sha256']})) {
      throw StateError('Historical database integrity failure');
    }
    if (await File(target).exists()) await File(target).delete();
    await temporary.rename(target);
  } finally {
    if (await temporary.exists()) await temporary.delete();
  }
}
