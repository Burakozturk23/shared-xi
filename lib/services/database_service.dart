import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/club.dart';
import '../models/coach.dart';
import '../models/famous_transfer.dart';
import '../models/player.dart';

/// Veri yukleme — min/legacy + isolate parse (buyuk players_min).
class DatabaseService {
  DatabaseService._();

  static List<Club>? _clubsCache;
  static List<Player>? _playersCache;
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

  static Future<bool> _useMin() async {
    final meta = await loadMeta();
    return meta['preferMin'] == true;
  }

  static Future<List<Club>> loadClubs() async {
    if (_clubsCache != null) return _clubsCache!;
    final preferMin = await _useMin();
    final path = preferMin
        ? 'assets/data/clubs_min.json'
        : 'assets/data/clubs.json';
    String raw;
    try {
      raw = await rootBundle.loadString(path);
    } catch (_) {
      raw = await rootBundle.loadString('assets/data/clubs_min.json');
    }
    _clubsCache = await compute(_parseClubs, raw);
    return _clubsCache!;
  }

  static Future<List<Player>> loadPlayers() async {
    if (_playersCache != null) return _playersCache!;
    final preferMin = await _useMin();
    final path = preferMin
        ? 'assets/data/players_min.json'
        : 'assets/data/players.json';
    String raw;
    try {
      raw = await rootBundle.loadString(path);
    } catch (_) {
      raw = await rootBundle.loadString('assets/data/players_min.json');
    }
    _playersCache = await compute(_parsePlayers, raw);
    return _playersCache!;
  }

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
      final raw =
          await rootBundle.loadString('assets/data/famous_transfers.json');
      _famousTransfersCache = await compute(_parseFamous, raw);
    } catch (_) {
      _famousTransfersCache = const [];
    }
    return _famousTransfersCache!;
  }

  static void clearCache() {
    _clubsCache = null;
    _playersCache = null;
    _coachesCache = null;
    _famousTransfersCache = null;
    _metaCache = null;
  }
}

// --- isolate entry points (top-level) ---

List<Club> _parseClubs(String raw) {
  final data = jsonDecode(raw) as List<dynamic>;
  return data.map((e) => Club.fromJson(e as Map<String, dynamic>)).toList();
}

List<Player> _parsePlayers(String raw) {
  final data = jsonDecode(raw) as List<dynamic>;
  return data.map((e) => Player.fromJson(e as Map<String, dynamic>)).toList();
}

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
