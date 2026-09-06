import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

class GameDataV4Database {
  GameDataV4Database._();

  static final GameDataV4Database instance =
      GameDataV4Database._();

  static const String _dbAsset =
      'assets/runtime/linkball_game_data_v4.sqlite';

  static const String _manifestAsset =
      'assets/runtime/linkball_game_data_v4_manifest.json';

  Database? _db;
  Future<void>? _initializeFuture;

  Map<String, dynamic>? _manifest;
  Map<String, String>? _metadata;

  bool get isOpen => _db?.isOpen == true;

  Database get database {
    final db = _db;

    if (db == null || !db.isOpen) {
      throw StateError(
        'GameData V4 database is not initialized.',
      );
    }

    return db;
  }

  Map<String, dynamic>? get manifest => _manifest;

  Map<String, String> get metadata =>
      Map.unmodifiable(_metadata ?? const {});

  Future<void> initialize() async {
    if (isOpen) return;

    final inFlight = _initializeFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = _initializeInternal();
    _initializeFuture = future;

    try {
      await future;
    } finally {
      if (identical(_initializeFuture, future)) {
        _initializeFuture = null;
      }
    }
  }

  Future<void> _initializeInternal() async {
    if (isOpen) return;

    final totalWatch = Stopwatch()..start();

    // -------------------------------------------------------
    // Manifest
    // -------------------------------------------------------

    final manifestRaw =
        await rootBundle.loadString(_manifestAsset);

    final decoded = jsonDecode(manifestRaw);

    if (decoded is! Map<String, dynamic>) {
      throw StateError(
        'Invalid V4 manifest.',
      );
    }

    _manifest = decoded;

    final databaseInfo = decoded['database'];

    if (databaseInfo is! Map<String, dynamic>) {
      throw StateError(
        'V4 manifest database section missing.',
      );
    }

    final expectedBytes =
        (databaseInfo['bytes'] as num?)?.toInt();

    final expectedSha =
        databaseInfo['sha256']?.toString();

    if (expectedBytes == null ||
        expectedBytes <= 0 ||
        expectedSha == null ||
        expectedSha.isEmpty) {
      throw StateError(
        'V4 manifest database metadata invalid.',
      );
    }

    // -------------------------------------------------------
    // Device DB path
    // -------------------------------------------------------

    final dbDir = await getDatabasesPath();

    await Directory(dbDir).create(
      recursive: true,
    );

    // Hash changes => new immutable database filename.
    //
    // This means normal launches do NOT recopy the 37 MB DB.
    final shortSha = expectedSha.substring(
      0,
      expectedSha.length >= 12
          ? 12
          : expectedSha.length,
    );

    final target = File(
  '$dbDir${Platform.pathSeparator}'
  'linkball_game_data_v4_$shortSha.sqlite',
);

    bool mustCopy = !await target.exists();

    if (!mustCopy) {
      final stat = await target.stat();

      mustCopy = stat.size != expectedBytes;
    }

    var copyMs = 0;

    if (mustCopy) {
      final copyWatch = Stopwatch()..start();

      final data = await rootBundle.load(
        _dbAsset,
      );

      if (data.lengthInBytes != expectedBytes) {
        throw StateError(
          'V4 asset size mismatch: '
          '${data.lengthInBytes} != $expectedBytes',
        );
      }

      final tmp = File(
        '${target.path}.tmp',
      );

      if (await tmp.exists()) {
        await tmp.delete();
      }

      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      await tmp.writeAsBytes(
        bytes,
        flush: true,
      );

      if (await target.exists()) {
        await target.delete();
      }

      await tmp.rename(
        target.path,
      );

      copyWatch.stop();
      copyMs = copyWatch.elapsedMilliseconds;
    }

    // -------------------------------------------------------
    // SQLite open
    // -------------------------------------------------------

    final openWatch = Stopwatch()..start();

    _db = await openDatabase(
      target.path,
      readOnly: true,
      singleInstance: true,
    );

    openWatch.stop();

    // -------------------------------------------------------
    // Metadata
    // -------------------------------------------------------

    final rows = await database.query(
      'metadata',
      columns: const [
        'key',
        'value',
      ],
    );

    _metadata = {
      for (final row in rows)
        row['key'].toString():
            row['value'].toString(),
    };

    if (_metadata!['schema_version'] != '4') {
      await close();

      throw StateError(
        'Unexpected V4 schema: '
        '${_metadata!['schema_version']}',
      );
    }

    // Cheap startup smoke query.
    final countRows = await database.rawQuery(
      'SELECT COUNT(*) AS c FROM players',
    );

    final playerCount =
        (countRows.first['c'] as num).toInt();

    if (playerCount != 30135) {
      await close();

      throw StateError(
        'Unexpected V4 player count: '
        '$playerCount',
      );
    }

    totalWatch.stop();

    debugPrint(
      '[V4Perf] initialize '
      '${totalWatch.elapsedMilliseconds}ms '
      'copied=$mustCopy '
      'copy=${copyMs}ms '
      'open=${openWatch.elapsedMilliseconds}ms '
      'players=$playerCount',
    );
  }

  Future<Map<String, String>> metadataSnapshot() async {
    await initialize();

    return Map.unmodifiable(
      _metadata ?? const {},
    );
  }

  Future<int> playerCount() async {
    await initialize();

    final rows = await database.rawQuery(
      'SELECT COUNT(*) AS c FROM players',
    );

    return (rows.first['c'] as num).toInt();
  }

  Future<int> clubCount() async {
    await initialize();

    final rows = await database.rawQuery(
      'SELECT COUNT(*) AS c FROM clubs',
    );

    return (rows.first['c'] as num).toInt();
  }

  Future<void> close() async {
    final db = _db;

    _db = null;
    _metadata = null;

    if (db != null && db.isOpen) {
      await db.close();
    }
  }
}