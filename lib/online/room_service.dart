import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class RoomService {
  static final FirebaseDatabase _database =
      FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static final DatabaseReference _roomsRef = _database.ref('rooms');

  static String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();

    return List.generate(
      6,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

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

    final roomData =
        Map<String, dynamic>.from(roomSnapshot.value as Map);

    if (roomData['status'] != 'waiting') return false;

    final players = roomData['players'] is Map
        ? Map<String, dynamic>.from(roomData['players'] as Map)
        : <String, dynamic>{};

    if (players.length >= 2 || players.containsKey(name)) {
      return false;
    }

    await _roomsRef.child(code).child('players').child(name).set({
      'teamId': null,
      'score': 0,
      'lives': 3,
      'ready': false,
    });

    return true;
  }

  static DatabaseReference _roomRef(String roomCode) =>
      _roomsRef.child(roomCode);

  static DatabaseReference _gameRef(String roomCode) =>
      _roomRef(roomCode).child('game');

  static Stream<DatabaseEvent> watchGame(String roomCode) =>
      _gameRef(roomCode).onValue;

  static Stream<DatabaseEvent> watchPlayers(String roomCode) =>
      _roomRef(roomCode).child('players').onValue;

  static Future<Map<String, dynamic>?> getRoom(
    String roomCode,
  ) async {
    final snapshot = await _roomRef(roomCode).get();

    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }

    return Map<String, dynamic>.from(snapshot.value as Map);
  }

  static Future<Map<String, dynamic>?> getPlayer({
    required String roomCode,
    required String playerName,
  }) async {
    final snapshot =
        await _roomRef(roomCode).child('players').child(playerName).get();

    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }

    return Map<String, dynamic>.from(snapshot.value as Map);
  }

  static Future<int> getServerTimeOffset() async {
    final snapshot = await _database.ref('.info/serverTimeOffset').get();

    return int.tryParse(snapshot.value?.toString() ?? '') ?? 0;
  }

  static Future<void> initializeGameForRoom(String roomCode) async {
    final snapshot = await _gameRef(roomCode).get();

    if (!snapshot.exists || snapshot.value == null) {
      await _gameRef(roomCode).set({
        'startedAt': ServerValue.timestamp,
        'durationSeconds': 60,
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

    // Keep the current game. Older rooms without these fields get them once.
    final updates = <String, dynamic>{};

    if (!data.containsKey('startedAt') ||
        data['startedAt'] == null) {
      updates['startedAt'] = ServerValue.timestamp;
    }
    if (!data.containsKey('durationSeconds')) {
      updates['durationSeconds'] = 60;
    }
    if (!data.containsKey('gameOver')) {
      updates['gameOver'] = false;
    }
    if (!data.containsKey('foundPlayerIds')) {
      updates['foundPlayerIds'] = <String, dynamic>{};
    }
    if (!data.containsKey('foundBy')) {
      updates['foundBy'] = <String, dynamic>{};
    }

    if (updates.isNotEmpty) {
      updates['updatedAt'] = ServerValue.timestamp;
      await _gameRef(roomCode).update(updates);
    }
  }

  static Future<bool> addFoundPlayer({
    required String roomCode,
    required String playerName,
    required int playerId,
  }) async {
    final gameRef = _gameRef(roomCode);
    final foundRef = gameRef.child('foundPlayerIds');

    final result =
        await foundRef.child(playerId.toString()).runTransaction((current) {
      if (current != null) {
        return Transaction.abort();
      }

      return Transaction.success(true);
    });

    if (!result.committed) return false;

    await gameRef.child('foundBy').child(playerId.toString()).set(
          playerName,
        );

    // Kept for backward compatibility with the lobby/older code.
    final scoreRef = _roomRef(roomCode)
        .child('players')
        .child(playerName)
        .child('score');

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
    final ref = _roomRef(roomCode)
        .child('players')
        .child(playerName)
        .child('lives');

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
  }

  static Future<void> resetGame(String roomCode) async {
    await _gameRef(roomCode).set({
      'startedAt': ServerValue.timestamp,
      'durationSeconds': 60,
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
  }

  static Future<void> leaveRoom({
    required String roomCode,
    required String playerName,
  }) async {
    await _roomRef(roomCode).child('players').child(playerName).remove();

    final snapshot = await _roomRef(roomCode).child('players').get();

    if (!snapshot.exists || snapshot.value == null) {
      await _roomRef(roomCode).remove();
    }
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

    final players =
        Map<String, dynamic>.from(snapshot.value as Map);

    if (players.length < 2) return false;

    for (final player in players.values) {
      if (player is! Map) return false;

      final playerData = Map<String, dynamic>.from(player);

      if (playerData['ready'] != true) {
        return false;
      }
    }

    return true;
  }

  static Future<void> startRoom(String roomCode) async {
    if (!await areAllPlayersReady(roomCode)) return;

    final statusRef = _roomRef(roomCode).child('status');
    final statusSnapshot = await statusRef.get();

    if (statusSnapshot.value != 'waiting') return;

    // The server timestamp is created exactly when the room
    // transitions to starting. Both phones read the same value.
    await _roomRef(roomCode).update({
      'status': 'starting',
      'game': {
        'startedAt': ServerValue.timestamp,
        'durationSeconds': 60,
        'gameOver': false,
        'gameOverReason': null,
        'winner': null,
        'foundPlayerIds': <String, dynamic>{},
        'foundBy': <String, dynamic>{},
        'updatedAt': ServerValue.timestamp,
      },
    });
  }

  static Stream<DatabaseEvent> watchRoomStatus(String roomCode) =>
      _roomRef(roomCode).child('status').onValue;
}
