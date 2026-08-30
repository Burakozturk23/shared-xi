import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../repositories/repository.dart';
import 'runtime_v3_database.dart';
import 'runtime_v3_flags.dart';

enum RuntimeV3Status {
  disabled,
  unsupportedPlatform,
  ready,
  failed,
}

class RuntimeV3Service {
  RuntimeV3Service._();

  static final RuntimeV3Service instance = RuntimeV3Service._();

  final RuntimeV3Database _db = RuntimeV3Database.instance;

  RuntimeV3Status _status = RuntimeV3Status.disabled;
  Object? _lastError;
  Map<String, Object?>? _lastParityReport;

  RuntimeV3Status get status => _status;
  bool get isReady => _status == RuntimeV3Status.ready;
  Object? get lastError => _lastError;
  Map<String, Object?>? get lastParityReport => _lastParityReport;
  RuntimeV3Database get database => _db;

  Future<void> initializeIfEnabled() async {
    if (!RuntimeV3Flags.enabled) {
      _status = RuntimeV3Status.disabled;
      return;
    }

    if (!_db.isSupported) {
      _status = RuntimeV3Status.unsupportedPlatform;
      debugPrint(
        '[RuntimeV3] Unsupported platform. JSON runtime remains active.',
      );
      return;
    }

    try {
      await _db.initialize();
      _status = RuntimeV3Status.ready;
      _lastError = null;
      debugPrint(
        '[RuntimeV3] READY metadata=${jsonEncode(await _db.metadata())}',
      );
    } catch (e, st) {
      _status = RuntimeV3Status.failed;
      _lastError = e;
      debugPrint('[RuntimeV3] FAILED: $e');
      debugPrintStack(stackTrace: st);
      // Sidecar failure must never block the current JSON app.
    }
  }

  Future<void> runParityAudit(Repository repository) async {
    if (!isReady || !RuntimeV3Flags.parityLog) return;

    final sqlitePlayerIds = (await _db.allPlayerIds()).toSet();
    final sqliteExistingClubIds = (await _db.existingClubIds()).toSet();

    final jsonPlayerIds = repository.players.map((p) => p.id).toSet();
    final jsonClubIds = repository.clubs.map((c) => c.id).toSet();

    final pairDeltas = <Map<String, Object?>>[];
    const pairs = <List<int>>[
      [418, 131],
      [985, 31],
      [141, 36],
      [141, 114],
      [5, 46],
      [631, 11],
    ];

    for (final pair in pairs) {
      final a = pair[0];
      final b = pair[1];
      final sqlite = (await _db.sharedXiPlayerIds(a, b)).toSet();
      final json = repository.players
          .where((p) => p.clubs.contains(a) && p.clubs.contains(b))
          .map((p) => p.id)
          .toSet();

      pairDeltas.add({
        'clubA': a,
        'clubB': b,
        'jsonCount': json.length,
        'sqliteCount': sqlite.length,
        'onlyJson': json.difference(sqlite).length,
        'onlySqlite': sqlite.difference(json).length,
      });
    }

    final report = <String, Object?>{
      'mode': 'SIDECAR_ONLY_NO_GAMEPLAY_SWITCH',
      'repository': {
        'playersDeduped': repository.playerCount,
        'playersRaw': repository.rawPlayerCount,
        'clubs': repository.clubCount,
      },
      'sqlite': await _db.tableCounts(),
      'identityCoverage': {
        'sqlitePlayersMissingInJson':
            sqlitePlayerIds.difference(jsonPlayerIds).length,
        'jsonPlayersMissingInSqlite':
            jsonPlayerIds.difference(sqlitePlayerIds).length,
        'existingClubsMissingInJson':
            sqliteExistingClubIds.difference(jsonClubIds).length,
        'jsonClubsMissingInSqlite':
            jsonClubIds.difference(sqliteExistingClubIds).length,
      },
      'sharedXiPairDeltas': pairDeltas,
    };

    _lastParityReport = report;
    debugPrint('[RuntimeV3] PARITY ${jsonEncode(report)}');
  }
}
