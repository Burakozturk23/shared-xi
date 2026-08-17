import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class RoomService {
  static final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static final DatabaseReference _roomsRef = _database.ref('rooms');

  static const int defaultDurationSeconds = 90;
  static const int maxPlayers = 2;

  static String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(
      6,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  static DatabaseReference _roomRef(String roomCode) =>
      _roomsRef.child(roomCode.trim().toUpperCase());

  static DatabaseReference _gameRef(String roomCode) =>
      _roomRef(roomCode).child('game');

  static Future<String> createRoom({
    required String playerName,
  }) async {
    final name = playerName.trim();
    if (name.isEmpty) {
      throw ArgumentError('Oyuncu adı boş olamaz.');
    }

    String roomCode = _generateRoomCode();
    while ((await _roomsRef.child(roomCode).get()).exists) {
      roomCode = _generateRoomCode();
    }

    await _roomsRef.child(roomCode).set({
      'host': name,
      'status': 'waiting',
      'createdAt': ServerValue.timestamp,
      'players': {
        name: {
          'teamId': null,
          'score': 0,
          'lives': 3,
          'ready': false,
          'rematchReady': false,
        },
      },
    });

    return roomCode;
  }

  static Future<bool> joinRoom({
    required String roomCode,
    required String playerName,
  }) async {
    final code = roomCode.trim().toUpperCase();
    final name = playerName.trim();

    if (code.isEmpty || name.isEmpty) return false;

    final roomSnapshot = await _roomsRef.child(code).get();
    if (!roomSnapshot.exists || roomSnapshot.value == null) {
      return false;
    }

    final roomData = Map<String, dynamic>.from(roomSnapshot.value as Map);

    if (roomData['status'] != 'waiting') return false;

    final players = roomData['players'] is Map
        ? Map<String, dynamic>.from(roomData['players'] as Map)
        : <String, dynamic>{};

    // Aynı isimle yeniden bağlanma (reconnect)
    if (players.containsKey(name)) {
      return true;
    }

    if (players.length >= maxPlayers) return false;

    await _roomsRef.child(code).child('players').child(name).set({
      'teamId': null,
      'score': 0,
      'lives': 3,
      'ready': false,
      'rematchReady': false,
    });

    return true;
  }

  static Stream<DatabaseEvent> watchGame(String roomCode) =>
      _gameRef(roomCode).onValue;

  static Stream<DatabaseEvent> watchPlayers(String roomCode) =>
      _roomRef(roomCode).child('players').onValue;

  static Stream<DatabaseEvent> watchRoomStatus(String roomCode) =>
      _roomRef(roomCode).child('status').onValue;

  static Future<Map<String, dynamic>?> getRoom(String roomCode) async {
    final snapshot = await _roomRef(roomCode).get();
    if (!snapshot.exists || snapshot.value == null) return null;
    return Map<String, dynamic>.from(snapshot.value as Map);
  }

  static Future<Map<String, dynamic>?> getGame(String roomCode) async {
    final snapshot = await _gameRef(roomCode).get();
    if (!snapshot.exists || snapshot.value == null) return null;
    return Map<String, dynamic>.from(snapshot.value as Map);
  }

  static Future<Map<String, dynamic>?> getPlayer({
    required String roomCode,
    required String playerName,
  }) async {
    final snapshot =
        await _roomRef(roomCode).child('players').child(playerName).get();
    if (!snapshot.exists || snapshot.value == null) return null;
    return Map<String, dynamic>.from(snapshot.value as Map);
  }

  static Future<int> getServerTimeOffset() async {
    try {
      final snapshot = await _database.ref('.info/serverTimeOffset').get();
      return int.tryParse(snapshot.value?.toString() ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Mevcut startedAt ASLA ezilmez.
  static Future<void> initializeGameForRoom(String roomCode) async {
    final snapshot = await _gameRef(roomCode).get();

    if (!snapshot.exists || snapshot.value == null) {
      await _gameRef(roomCode).set({
        'startedAt': ServerValue.timestamp,
        'durationSeconds': defaultDurationSeconds,
        'gameOver': false,
        'gameOverReason': null,
        'winner': null,
        'foundPlayerIds': <String, dynamic>{},
        'foundBy': <String, dynamic>{},
        'updatedAt': ServerValue.timestamp,
      });
      return;
    }

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final updates = <String, dynamic>{};

    if (!data.containsKey('startedAt') || data['startedAt'] == null) {
      updates['startedAt'] = ServerValue.timestamp;
    }
    if (!data.containsKey('durationSeconds')) {
      updates['durationSeconds'] = defaultDurationSeconds;
    }
    if (!data.containsKey('gameOver')) {
      updates['gameOver'] = false;
    }
    if (data['foundPlayerIds'] is! Map) {
      updates['foundPlayerIds'] = <String, dynamic>{};
    }
    if (data['foundBy'] is! Map) {
      updates['foundBy'] = <String, dynamic>{};
    }

    if (updates.isNotEmpty) {
      updates['updatedAt'] = ServerValue.timestamp;
      await _gameRef(roomCode).update(updates);
    }
  }

  /// foundPlayerIds + foundBy tek transaction → skor race biter.
  static Future<bool> addFoundPlayer({
    required String roomCode,
    required String playerName,
    required int playerId,
  }) async {
    final gameRef = _gameRef(roomCode);
    final key = playerId.toString();

    final result = await gameRef.runTransaction((current) {
      if (current is! Map) {
        return Transaction.abort();
      }

      final data = Map<String, dynamic>.from(current);

      if (data['gameOver'] == true) {
        return Transaction.abort();
      }

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
      foundBy[key] = playerName;

      data['foundPlayerIds'] = foundIds;
      data['foundBy'] = foundBy;
      data['updatedAt'] = ServerValue.timestamp;

      return Transaction.success(data);
    });

    if (!result.committed) return false;

    final scoreRef =
        _roomRef(roomCode).child('players').child(playerName).child('score');
    await scoreRef.runTransaction((current) {
      final score = int.tryParse(current?.toString() ?? '') ?? 0;
      return Transaction.success(score + 1);
    });

    return true;
  }

  static Future<int> decrementPlayerLife({
    required String roomCode,
    required String playerName,
  }) async {
    final ref =
        _roomRef(roomCode).child('players').child(playerName).child('lives');

    final result = await ref.runTransaction((current) {
      final lives = int.tryParse(current?.toString() ?? '') ?? 3;
      return Transaction.success((lives - 1).clamp(0, 3));
    });

    return int.tryParse(result.snapshot.value?.toString() ?? '') ?? 0;
  }

  static Future<void> finishGame({
    required String roomCode,
    required String reason,
    required String winner,
  }) async {
    final gameRef = _gameRef(roomCode);

    await gameRef.runTransaction((current) {
      if (current is! Map) {
        return Transaction.abort();
      }

      final data = Map<String, dynamic>.from(current);

      if (data['gameOver'] == true) {
        return Transaction.abort();
      }

      data['gameOver'] = true;
      data['gameOverReason'] = reason;
      data['winner'] = winner;
      data['updatedAt'] = ServerValue.timestamp;

      return Transaction.success(data);
    });

    await _roomRef(roomCode).child('status').set('finished');
  }

  static Future<void> resetGame(String roomCode) async {
    await _gameRef(roomCode).set({
      'startedAt': ServerValue.timestamp,
      'durationSeconds': defaultDurationSeconds,
      'gameOver': false,
      'gameOverReason': null,
      'winner': null,
      'foundPlayerIds': <String, dynamic>{},
      'foundBy': <String, dynamic>{},
      'updatedAt': ServerValue.timestamp,
    });

    final snapshot = await _roomRef(roomCode).child('players').get();
    if (snapshot.value is! Map) return;

    final players = Map<String, dynamic>.from(snapshot.value as Map);
    for (final name in players.keys) {
      await _roomRef(roomCode).child('players').child(name).update({
        'score': 0,
        'lives': 3,
        'ready': true,
      });
    }

    await _roomRef(roomCode).child('status').set('starting');
  }

  static Future<void> setReady({
    required String roomCode,
    required String playerName,
    required bool ready,
  }) async {
    await _roomRef(roomCode)
        .child('players')
        .child(playerName)
        .child('ready')
        .set(ready);
  }

  static Future<void> setPlayerTeam({
    required String roomCode,
    required String playerName,
    required int teamId,
  }) async {
    await _roomRef(roomCode).child('players').child(playerName).update({
      'teamId': teamId,
      'ready': false,
    });
  }

  static Future<bool> areAllPlayersReady(String roomCode) async {
    final snapshot = await _roomRef(roomCode).child('players').get();
    if (!snapshot.exists || snapshot.value == null) return false;

    final players = Map<String, dynamic>.from(snapshot.value as Map);
    if (players.length < maxPlayers) return false;

    for (final player in players.values) {
      if (player is! Map) return false;
      final playerData = Map<String, dynamic>.from(player);
      if (playerData['ready'] != true) return false;
      if (playerData['teamId'] == null) return false;
    }
    return true;
  }


  /// Yeniden oyna isteği (aynı oda, yeni takımlar).
  static Future<void> requestRematch({
    required String roomCode,
    required String playerName,
  }) async {
    await _roomRef(roomCode)
        .child('players')
        .child(playerName)
        .child('rematchReady')
        .set(true);
  }

  static Future<bool> areAllRematchReady(String roomCode) async {
    final snapshot = await _roomRef(roomCode).child('players').get();
    if (!snapshot.exists || snapshot.value == null) return false;
    final players = Map<String, dynamic>.from(snapshot.value as Map);
    if (players.length < maxPlayers) return false;
    for (final player in players.values) {
      if (player is! Map) return false;
      final data = Map<String, dynamic>.from(player);
      if (data['rematchReady'] != true) return false;
    }
    return true;
  }

  /// İkisi de kabul ettiyse odayı setup moduna alır (takımlar sıfırlanır).
  static Future<bool> prepareRematch(String roomCode) async {
    if (!await areAllRematchReady(roomCode)) return false;

    final statusSnap = await _roomRef(roomCode).child('status').get();
    // finished veya starting sonrası yeniden
    final status = statusSnap.value?.toString();
    if (status != 'finished' && status != 'starting') {
      // zaten waiting ise yine de temizle
    }

    final snapshot = await _roomRef(roomCode).child('players').get();
    if (snapshot.value is! Map) return false;
    final players = Map<String, dynamic>.from(snapshot.value as Map);

    for (final name in players.keys) {
      await _roomRef(roomCode).child('players').child(name).update({
        'teamId': null,
        'score': 0,
        'lives': 3,
        'ready': false,
        'rematchReady': false,
      });
    }

    await _gameRef(roomCode).remove();

    await _roomRef(roomCode).update({
      'status': 'waiting',
    });

    return true;
  }

  static Future<void> startRoom(String roomCode) async {
    if (!await areAllPlayersReady(roomCode)) return;

    final statusRef = _roomRef(roomCode).child('status');
    final statusSnapshot = await statusRef.get();
    if (statusSnapshot.value != 'waiting') return;

    await _roomRef(roomCode).update({
      'status': 'starting',
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

  /// Oyun bitmeden oda silinmez.
  static Future<void> leaveRoom({
    required String roomCode,
    required String playerName,
    bool deleteRoomIfEmpty = false,
  }) async {
    await _roomRef(roomCode).child('players').child(playerName).remove();

    if (!deleteRoomIfEmpty) return;

    final snapshot = await _roomRef(roomCode).child('players').get();
    if (!snapshot.exists || snapshot.value == null) {
      await _roomRef(roomCode).remove();
    }
  }

  // ── Faz 2: Presence ──────────────────────────────────────────────

  static const int reconnectWindowSeconds = 20;

  static DatabaseReference _playerRef(String roomCode, String playerName) =>
      _roomRef(roomCode).child('players').child(playerName);

  /// Oyuncu maça girdi / yeniden bağlandı.
  static Future<void> markPlayerConnected({
    required String roomCode,
    required String playerName,
  }) async {
    final ref = _playerRef(roomCode, playerName);
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
    required String roomCode,
    required String playerName,
  }) async {
    await _playerRef(roomCode, playerName).update({
      'connected': true,
      'lastSeen': ServerValue.timestamp,
    });
  }

  static Future<void> markPlayerDisconnected({
    required String roomCode,
    required String playerName,
  }) async {
    try {
      await _playerRef(roomCode, playerName).onDisconnect().cancel();
    } catch (_) {}
    await _playerRef(roomCode, playerName).update({
      'connected': false,
      'disconnectedAt': ServerValue.timestamp,
    });
  }

}