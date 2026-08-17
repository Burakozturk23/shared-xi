import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// Rastgele maç oturumu — rooms ile paralel, path: matches/{matchId}
class MatchService {
  MatchService._();

  static const int defaultDurationSeconds = 90;

  static final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static DatabaseReference _matchRef(String matchId) =>
      _db.ref('matches/$matchId');

  static DatabaseReference _gameRef(String matchId) =>
      _matchRef(matchId).child('game');

  static Future<void> createMatch({
    required String matchId,
    required String player1Uid,
    required String player1Name,
    required String player2Uid,
    required String player2Name,
    required int team1Id,
    required String team1Name,
    required int team2Id,
    required String team2Name,
    required List<int> commonPlayerIds,
  }) async {
    final existing = await _matchRef(matchId).get();
    if (existing.exists) return;

    final commonMap = <String, dynamic>{
      for (final id in commonPlayerIds) id.toString(): true,
    };

    await _matchRef(matchId).set({
      'player1Uid': player1Uid,
      'player2Uid': player2Uid,
      'player1Name': player1Name,
      'player2Name': player2Name,
      'team1Id': team1Id,
      'team2Id': team2Id,
      'team1Name': team1Name,
      'team2Name': team2Name,
      'commonPlayerIds': commonMap,
      'status': 'ready',
      'createdAt': ServerValue.timestamp,
      'players': {
        player1Uid: {
          'displayName': player1Name,
          'score': 0,
          'lives': 3,
        },
        player2Uid: {
          'displayName': player2Name,
          'score': 0,
          'lives': 3,
        },
      },
      'game': {
        'startedAt': ServerValue.timestamp,
        'durationSeconds': defaultDurationSeconds,
        'gameOver': false,
        'gameOverReason': null,
        'winner': null,
        'foundPlayerIds': <String, dynamic>{},
        'foundBy': <String, dynamic>{},
        'updatedAt': ServerValue.timestamp,
      },
    });
  }

  static Future<Map<String, dynamic>?> getMatch(String matchId) async {
    final snap = await _matchRef(matchId).get();
    if (!snap.exists || snap.value == null) return null;
    return Map<String, dynamic>.from(snap.value as Map);
  }

  static Stream<DatabaseEvent> watchGame(String matchId) =>
      _gameRef(matchId).onValue;

  static Stream<DatabaseEvent> watchPlayers(String matchId) =>
      _matchRef(matchId).child('players').onValue;

  static Stream<DatabaseEvent> watchMatch(String matchId) =>
      _matchRef(matchId).onValue;

  static Future<int> getServerTimeOffset() async {
    try {
      final snapshot = await _db.ref('.info/serverTimeOffset').get();
      return int.tryParse(snapshot.value?.toString() ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> ensureGame(String matchId) async {
    final snap = await _gameRef(matchId).get();
    if (snap.exists && snap.value != null) return;
    await _gameRef(matchId).set({
      'startedAt': ServerValue.timestamp,
      'durationSeconds': defaultDurationSeconds,
      'gameOver': false,
      'gameOverReason': null,
      'winner': null,
      'foundPlayerIds': <String, dynamic>{},
      'foundBy': <String, dynamic>{},
      'updatedAt': ServerValue.timestamp,
    });
  }

  static Future<bool> addFoundPlayer({
    required String matchId,
    required String playerUid,
    required int playerId,
  }) async {
    final gameRef = _gameRef(matchId);
    final key = playerId.toString();

    final result = await gameRef.runTransaction((current) {
      if (current is! Map) return Transaction.abort();
      final data = Map<String, dynamic>.from(current);
      if (data['gameOver'] == true) return Transaction.abort();

      final foundIds = data['foundPlayerIds'] is Map
          ? Map<String, dynamic>.from(data['foundPlayerIds'] as Map)
          : <String, dynamic>{};
      final foundBy = data['foundBy'] is Map
          ? Map<String, dynamic>.from(data['foundBy'] as Map)
          : <String, dynamic>{};

      if (foundIds.containsKey(key) || foundBy.containsKey(key)) {
        return Transaction.abort();
      }

      foundIds[key] = true;
      foundBy[key] = playerUid;
      data['foundPlayerIds'] = foundIds;
      data['foundBy'] = foundBy;
      data['updatedAt'] = ServerValue.timestamp;
      return Transaction.success(data);
    });

    if (!result.committed) return false;

    await _matchRef(matchId)
        .child('players')
        .child(playerUid)
        .child('score')
        .runTransaction((current) {
      final score = int.tryParse(current?.toString() ?? '') ?? 0;
      return Transaction.success(score + 1);
    });

    return true;
  }

  static Future<int> decrementPlayerLife({
    required String matchId,
    required String playerUid,
  }) async {
    final ref =
        _matchRef(matchId).child('players').child(playerUid).child('lives');
    final result = await ref.runTransaction((current) {
      final lives = int.tryParse(current?.toString() ?? '') ?? 3;
      return Transaction.success((lives - 1).clamp(0, 3));
    });
    return int.tryParse(result.snapshot.value?.toString() ?? '') ?? 0;
  }

  static Future<void> finishGame({
    required String matchId,
    required String reason,
    required String winner,
  }) async {
    await _gameRef(matchId).runTransaction((current) {
      if (current is! Map) return Transaction.abort();
      final data = Map<String, dynamic>.from(current);
      if (data['gameOver'] == true) return Transaction.abort();
      data['gameOver'] = true;
      data['gameOverReason'] = reason;
      data['winner'] = winner;
      data['updatedAt'] = ServerValue.timestamp;
      return Transaction.success(data);
    });
    await _matchRef(matchId).child('status').set('finished');
  }

  static Future<void> resetMatch(String matchId) async {
    await _gameRef(matchId).set({
      'startedAt': ServerValue.timestamp,
      'durationSeconds': defaultDurationSeconds,
      'gameOver': false,
      'gameOverReason': null,
      'winner': null,
      'foundPlayerIds': <String, dynamic>{},
      'foundBy': <String, dynamic>{},
      'updatedAt': ServerValue.timestamp,
    });

    final snap = await _matchRef(matchId).child('players').get();
    if (snap.value is! Map) return;
    final players = Map<String, dynamic>.from(snap.value as Map);
    for (final uid in players.keys) {
      await _matchRef(matchId).child('players').child(uid).update({
        'score': 0,
        'lives': 3,
      });
    }
    await _matchRef(matchId).child('status').set('ready');
  }

  // ── Faz 2: Presence ──────────────────────────────────────────────

  static const int reconnectWindowSeconds = 20;

  static DatabaseReference _playerRef(String matchId, String playerUid) =>
      _matchRef(matchId).child('players').child(playerUid);

  static Future<void> markPlayerConnected({
    required String matchId,
    required String playerUid,
  }) async {
    final ref = _playerRef(matchId, playerUid);
    await ref.update({
      'connected': true,
      'lastSeen': ServerValue.timestamp,
      'disconnectedAt': null,
    });
    await ref.onDisconnect().update({
      'connected': false,
      'disconnectedAt': ServerValue.timestamp,
    });
  }

  static Future<void> playerHeartbeat({
    required String matchId,
    required String playerUid,
  }) async {
    await _playerRef(matchId, playerUid).update({
      'connected': true,
      'lastSeen': ServerValue.timestamp,
    });
  }

  static Future<void> markPlayerDisconnected({
    required String matchId,
    required String playerUid,
  }) async {
    try {
      await _playerRef(matchId, playerUid).onDisconnect().cancel();
    } catch (_) {}
    await _playerRef(matchId, playerUid).update({
      'connected': false,
      'disconnectedAt': ServerValue.timestamp,
    });
  }

}