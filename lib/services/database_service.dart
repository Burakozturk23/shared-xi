import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/coach.dart';
import '../models/famous_transfer.dart';

/// Small legacy JSON loader for metadata, coaches and famous transfers.
class DatabaseService {
  DatabaseService._();

  static List<Coach>? _coachesCache;
  static List<FamousTransfer>? _famousTransfersCache;
  static Map<String, dynamic>? _metaCache;

  static Future<Map<String, dynamic>> loadMeta() async {
    if (_metaCache != null) return _metaCache!;
    try {
      final raw = await rootBundle.loadString('assets/data/meta.json');
      _metaCache = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      _metaCache = {
        'schemaVersion': 0,
        'dataVersion': 'legacy',
        'preferMin': false,
      };
    }
    return _metaCache!;
  }

  static String get dataVersion =>
      _metaCache?['dataVersion']?.toString() ?? '—';

  static Future<List<Coach>> loadCoaches() async {
    if (_coachesCache != null) return _coachesCache!;
    try {
      final raw = await rootBundle.loadString('assets/data/coaches_min.json');
      _coachesCache = await compute(_parseCoaches, raw);
    } catch (_) {
      _coachesCache = const [];
    }
    return _coachesCache!;
  }

  static Future<List<FamousTransfer>> loadFamousTransfers() async {
    if (_famousTransfersCache != null) return _famousTransfersCache!;
    try {
      final raw = await rootBundle.loadString(
        'assets/data/famous_transfers.json',
      );
      _famousTransfersCache = await compute(_parseFamous, raw);
    } catch (_) {
      _famousTransfersCache = const [];
    }
    return _famousTransfersCache!;
  }

  static void clearCache() {
    _coachesCache = null;
    _famousTransfersCache = null;
    _metaCache = null;
  }
}

// --- isolate entry points (top-level) ---

List<Coach> _parseCoaches(String raw) {
  final data = jsonDecode(raw) as List<dynamic>;
  return data.map((e) => Coach.fromJson(e as Map<String, dynamic>)).toList();
}

List<FamousTransfer> _parseFamous(String raw) {
  final data = jsonDecode(raw) as List<dynamic>;
  return data
      .map((e) => FamousTransfer.fromJson(e as Map<String, dynamic>))
      .toList();
}
