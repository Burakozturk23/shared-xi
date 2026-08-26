import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/club.dart';
import '../models/coach.dart';
import '../models/famous_transfer.dart';
import '../models/player.dart';

/// Veri yukleme.
///
/// Oncelik:
/// 1) meta.json icinde "preferMin": true ise *_min.json
/// 2) Aksi halde eski clubs.json / players.json (modlar kirilmasin)
/// 3) Min dosyalar her zaman ornek/pipeline icin assets'te durabilir
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

  static Future<bool> _useMin() async {
    final meta = await loadMeta();
    return meta['preferMin'] == true;
  }

  static Future<String> _loadAsset(String path) async {
    return rootBundle.loadString(path);
  }

  static Future<List<Club>> loadClubs() async {
    if (_clubsCache != null) return _clubsCache!;

    final preferMin = await _useMin();
    List<dynamic> data;

    if (preferMin) {
      final raw = await _loadAsset('assets/data/clubs_min.json');
      data = jsonDecode(raw) as List<dynamic>;
    } else {
      try {
        final raw = await _loadAsset('assets/data/clubs.json');
        data = jsonDecode(raw) as List<dynamic>;
      } catch (_) {
        final raw = await _loadAsset('assets/data/clubs_min.json');
        data = jsonDecode(raw) as List<dynamic>;
      }
    }

    _clubsCache =
        data.map((e) => Club.fromJson(e as Map<String, dynamic>)).toList();
    return _clubsCache!;
  }

  static Future<List<Player>> loadPlayers() async {
    if (_playersCache != null) return _playersCache!;

    final preferMin = await _useMin();
    List<dynamic> data;

    if (preferMin) {
      final raw = await _loadAsset('assets/data/players_min.json');
      data = jsonDecode(raw) as List<dynamic>;
    } else {
      try {
        final raw = await _loadAsset('assets/data/players.json');
        data = jsonDecode(raw) as List<dynamic>;
      } catch (_) {
        final raw = await _loadAsset('assets/data/players_min.json');
        data = jsonDecode(raw) as List<dynamic>;
      }
    }

    _playersCache =
        data.map((e) => Player.fromJson(e as Map<String, dynamic>)).toList();
    return _playersCache!;
  }

  static Future<List<Coach>> loadCoaches() async {
    if (_coachesCache != null) return _coachesCache!;
    try {
      final raw = await _loadAsset('assets/data/coaches_min.json');
      final data = jsonDecode(raw) as List<dynamic>;
      _coachesCache =
          data.map((e) => Coach.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      _coachesCache = const [];
    }
    return _coachesCache!;
  }

  static Future<List<FamousTransfer>> loadFamousTransfers() async {
    if (_famousTransfersCache != null) return _famousTransfersCache!;
    try {
      final raw = await _loadAsset('assets/data/famous_transfers.json');
      final data = jsonDecode(raw) as List<dynamic>;
      _famousTransfersCache = data
          .map((e) => FamousTransfer.fromJson(e as Map<String, dynamic>))
          .toList();
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
