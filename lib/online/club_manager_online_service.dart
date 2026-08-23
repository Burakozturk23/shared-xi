import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// Club Manager online oda state (Firebase RTDB).
/// Mevcut RoomService odalarının yanına `mode` + `game/clubManager` yazar.
class ClubManagerOnlineService {
  ClubManagerOnlineService._();
  static final ClubManagerOnlineService instance = ClubManagerOnlineService._();

  static FirebaseDatabase get _db => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
      );

  static DatabaseReference _room(String code) =>
      _db.ref('rooms').child(code.trim().toUpperCase());

  static DatabaseReference _cm(String code) =>
      _room(code).child('game').child('clubManager');

  static String _code() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(5, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// Oda kur: mode=clubManager, budget, poolSeed.
  Future<String> createRoom({
    required String playerName,
    required int budgetLink,
  }) async {
    final name = playerName.trim();
    if (name.isEmpty) throw ArgumentError('İsim boş');

    var code = _code();
    while ((await _room(code).get()).exists) {
      code = _code();
    }

    final seed = Random().nextInt(1 << 30);

    await _room(code).set({
      'host': name,
      'status': 'waiting',
      'mode': 'clubManager',
      'createdAt': ServerValue.timestamp,
      'players': {
        name: {
          'ready': false,
          'score': 0,
        },
      },
      'game': {
        'clubManager': {
          'budgetLink': budgetLink,
          'poolSeed': seed,
          'matchSeed': seed ^ 0x5f3759df,
          'status': 'lobby', // lobby | squad | match | done
          'lineups': {},
          'tactics': {},
          'result': null,
        },
      },
    });

    return code;
  }

  Future<bool> joinRoom({
    required String roomCode,
    required String playerName,
  }) async {
    final code = roomCode.trim().toUpperCase();
    final name = playerName.trim();
    final snap = await _room(code).get();
    if (!snap.exists || snap.value == null) return false;
    final data = Map<String, dynamic>.from(snap.value as Map);
    if (data['mode'] != null && data['mode'] != 'clubManager') return false;
    if (data['status'] != 'waiting' && data['status'] != 'squad') return false;

    final players = data['players'] is Map
        ? Map<String, dynamic>.from(data['players'] as Map)
        : <String, dynamic>{};
    if (players.containsKey(name)) return true;
    if (players.length >= 2) return false;

    await _room(code).child('players').child(name).set({
      'ready': false,
      'score': 0,
    });
    return true;
  }

  Stream<DatabaseEvent> watchRoom(String code) => _room(code).onValue;

  Stream<DatabaseEvent> watchClubManager(String code) => _cm(code).onValue;

  Future<void> setStatus(String code, String status) async {
    await _room(code).child('status').set(status);
    await _cm(code).child('status').set(status);
  }

  /// XI + taktik gönder, ready=true.
  Future<void> submitLineup({
    required String roomCode,
    required String playerName,
    required List<int> playerIds,
    required String formationId,
    required Map<String, double> tactics,
    required int spentLink,
  }) async {
    final code = roomCode.trim().toUpperCase();
    final name = playerName.trim();
    await _cm(code).child('lineups').child(name).set({
      'playerIds': playerIds,
      'formationId': formationId,
      'spentLink': spentLink,
      'submittedAt': ServerValue.timestamp,
    });
    await _cm(code).child('tactics').child(name).set(tactics);
    await _room(code).child('players').child(name).child('ready').set(true);
  }

  Future<void> setUnready(String code, String playerName) async {
    await _room(code)
        .child('players')
        .child(playerName.trim())
        .child('ready')
        .set(false);
  }

  /// Host: iki taraf ready ise sonucu yaz.
  Future<void> publishResult({
    required String roomCode,
    required Map<String, dynamic> result,
  }) async {
    final code = roomCode.trim().toUpperCase();
    await _cm(code).child('result').set(result);
    await _cm(code).child('status').set('done');
    await _room(code).child('status').set('finished');
  }

  Future<Map<String, dynamic>?> loadClubManager(String code) async {
    final snap = await _cm(code).get();
    if (!snap.exists || snap.value == null) return null;
    return Map<String, dynamic>.from(snap.value as Map);
  }
}
