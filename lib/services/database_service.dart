import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/club.dart';
import '../models/famous_transfer.dart';
import '../models/player.dart';

class DatabaseService {
  DatabaseService._();

  static List<Club>? _clubsCache;
  static List<Player>? _playersCache;
  static List<FamousTransfer>? _famousTransfersCache;

  static Future<List<Club>> loadClubs() async {
    if (_clubsCache != null) {
      return _clubsCache!;
    }

    final rawJson = await rootBundle.loadString(
      'assets/data/clubs.json',
    );

    final List<dynamic> data =
        jsonDecode(rawJson) as List<dynamic>;

    _clubsCache = data
        .map((e) => Club.fromJson(e as Map<String, dynamic>))
        .toList();

    return _clubsCache!;
  }

  static Future<List<Player>> loadPlayers() async {
    if (_playersCache != null) {
      return _playersCache!;
    }

    final rawJson = await rootBundle.loadString(
      'assets/data/players.json',
    );

    final List<dynamic> data =
        jsonDecode(rawJson) as List<dynamic>;

    _playersCache = data
        .map((e) => Player.fromJson(e as Map<String, dynamic>))
        .toList();

    return _playersCache!;
  }

  static Future<List<FamousTransfer>> loadFamousTransfers() async {
    if (_famousTransfersCache != null) {
      return _famousTransfersCache!;
    }

    final rawJson = await rootBundle.loadString(
      'assets/data/famous_transfers.json',
    );

    final List<dynamic> data = jsonDecode(rawJson) as List<dynamic>;

    _famousTransfersCache = data
        .map((e) => FamousTransfer.fromJson(e as Map<String, dynamic>))
        .toList();

    return _famousTransfersCache!;
  }

  static void clearCache() {
    _clubsCache = null;
    _playersCache = null;
    _famousTransfersCache = null;
  }
}