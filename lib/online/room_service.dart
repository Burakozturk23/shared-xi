import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class RoomService {
  static final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static final DatabaseReference _roomsRef =
      _database.ref('rooms');

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

  if (code.isEmpty || name.isEmpty) {
    return false;
  }

  final roomSnapshot = await _roomsRef.child(code).get();

  if (!roomSnapshot.exists || roomSnapshot.value == null) {
    return false;
  }

  final roomData = Map<String, dynamic>.from(
    roomSnapshot.value as Map,
  );

  final status = roomData['status'];

  if (status != 'waiting') {
    return false;
  }

  final players = roomData['players'] != null
      ? Map<String, dynamic>.from(
          roomData['players'] as Map,
        )
      : <String, dynamic>{};

  if (players.length >= 2) {
    return false;
  }

  if (players.containsKey(name)) {
    return false;
  }

  await _roomsRef
      .child(code)
      .child('players')
      .child(name)
      .set({
    'teamId': null,
    'score': 0,
    'lives': 3,
    'ready': false,
  });

  return true;
}

static DatabaseReference _gameRef(String roomCode) {
  return _roomsRef.child(roomCode).child('game');
}
  static Future<void> finishGame({
    required String roomCode,
    required String reason,
    required String winner,
  }) async {
    final ref = _gameRef(roomCode);

    await ref.runTransaction((current) {
      if (current is Map) {
        final data = Map<String, dynamic>.from(current);
        if (data['gameOver'] == true) {
          return Transaction.abort();
        }
        data['gameOver'] = true;
        data['gameOverReason'] = reason;
        data['winner'] = winner;
        data['updatedAt'] = ServerValue.timestamp;
        return Transaction.success(data);
      }

      return Transaction.success({
        'foundPlayerIds': <String, dynamic>{},
        'foundBy': <String, dynamic>{},
        'gameOver': true,
        'gameOverReason': reason,
        'winner': winner,
        'updatedAt': ServerValue.timestamp,
      });
    });
  }
  static Future<void> resetGame(String roomCode) async {
    await _gameRef(roomCode).set({
      'foundPlayerIds': <String, dynamic>{},
      'foundBy': <String, dynamic>{},
      'gameOver': false,
      'gameOverReason': null,
      'winner': null,
      'startedAt': ServerValue.timestamp,
      'durationSeconds': 60,
      'updatedAt': ServerValue.timestamp,
    });

    final playersSnapshot =
        await _roomsRef.child(roomCode).child('players').get();

    if (playersSnapshot.value is Map) {
      final players = Map<String, dynamic>.from(playersSnapshot.value as Map);
      final updates = <String, dynamic>{};

      for (final name in players.keys) {
        updates['$name/lives'] = 3;
        updates['$name/score'] = 0;
      }

      if (updates.isNotEmpty) {
        await _roomsRef.child(roomCode).child('players').update(updates);
      }
    }
  }


  static Future<void> leaveRoom({
    required String roomCode,
    required String playerName,
  }) async {
    final roomRef = _roomsRef.child(roomCode);
    final playerRef = roomRef.child('players').child(playerName);

    // Önce oyuncuyu odadan çıkar.
    await playerRef.remove();

    // Kalan oyuncu yoksa odayı tamamen temizle.
    final snapshot = await roomRef.child('players').get();
    if (!snapshot.exists || snapshot.value == null) {
      await roomRef.remove();
    }
  }




static Stream<DatabaseEvent> watchGame(String roomCode) {
  return _gameRef(roomCode).onValue;
}

static Future<void> initializeGameForRoom(String roomCode) async {
  final snapshot = await _gameRef(roomCode).get();
  if (!snapshot.exists) {
    await _gameRef(roomCode).set({
      'foundPlayerIds': <String, dynamic>{},
      'foundBy': <String, dynamic>{},
      'startedAt': null,
      'durationSeconds': 60,
      'gameOver': false,
        'gameOverReason': null,
        'winner': null,
        'updatedAt': ServerValue.timestamp,
    });
  }
}

static Future<bool> addFoundPlayer({
  required String roomCode,
  required String playerName,
  required int playerId,
}) async {
  final foundRef = _gameRef(roomCode).child('foundPlayerIds');
  final result = await foundRef.child(playerId.toString()).runTransaction((current) {
    if (current != null) return Transaction.abort();
    return Transaction.success(true);
  });
  if (!result.committed) return false;

  await _gameRef(roomCode)
      .child('foundBy')
      .child(playerId.toString())
      .set(playerName);

  // Keep the player score in Firebase for compatibility with the lobby and
  // older code. Online GameController does NOT use this value for display.
  final scoreRef = _roomsRef
      .child(roomCode)
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
  final livesRef = _roomsRef
      .child(roomCode)
      .child('players')
      .child(playerName)
      .child('lives');

  final result = await livesRef.runTransaction((current) {
    final currentLives =
        int.tryParse(current?.toString() ?? '') ?? 3;

    if (currentLives <= 0) {
      return Transaction.success(0);
    }

    return Transaction.success(currentLives - 1);
  });

  if (!result.committed) {
    return 0;
  }

  return int.tryParse(result.snapshot.value?.toString() ?? '0') ?? 0;
}

static Future<int> getServerTimeOffset() async {
  final snapshot = await _database.ref('.info/serverTimeOffset').get();
  return int.tryParse(snapshot.value?.toString() ?? '0') ?? 0;
}

static Stream<DatabaseEvent> watchPlayers(String roomCode) {
  return _roomsRef
      .child(roomCode)
      .child('players')
      .onValue;
}
static Future<void> setReady({
  required String roomCode,
  required String playerName,
  required bool ready,
}) async {
  await _roomsRef
      .child(roomCode)
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
  await _roomsRef
      .child(roomCode)
      .child('players')
      .child(playerName)
      .update({
    'teamId': teamId,
    'ready': false,
  });
}

static Future<bool> areAllPlayersReady(String roomCode) async {
  final snapshot = await _roomsRef
      .child(roomCode)
      .child('players')
      .get();

  if (!snapshot.exists || snapshot.value == null) {
    return false;
  }

  final players = Map<String, dynamic>.from(
    snapshot.value as Map,
  );

  if (players.length < 2) {
    return false;
  }

  for (final player in players.values) {
    final playerData = Map<String, dynamic>.from(
      player as Map,
    );

    if (playerData['ready'] != true) {
      return false;
    }
  }

  return true;
}
static Future<void> startRoom(String roomCode) async {
  final ready = await areAllPlayersReady(roomCode);

  if (!ready) {
    return;
  }

  final statusSnapshot =
      await _roomsRef.child(roomCode).child('status').get();

  if (statusSnapshot.value == 'waiting') {
    await _roomsRef.child(roomCode).update({
      'status': 'starting',
      'game': {
        'foundPlayerIds': <String, dynamic>{},
        'foundBy': <String, dynamic>{},
        'startedAt': ServerValue.timestamp,
        'durationSeconds': 60,
        'updatedAt': ServerValue.timestamp,
      },
    });
  }
}
static Stream<DatabaseEvent> watchRoomStatus(String roomCode) {
  return _roomsRef
      .child(roomCode)
      .child('status')
      .onValue;
}
static Future<Map<String, dynamic>?> getRoom(
  String roomCode,
) async {
  final snapshot = await _roomsRef
      .child(roomCode)
      .get();

  if (!snapshot.exists || snapshot.value == null) {
    return null;
  }

  return Map<String, dynamic>.from(
    snapshot.value as Map,
  );
}
static Future<Map<String, dynamic>?> getPlayer({
  required String roomCode,
  required String playerName,
}) async {
  final snapshot = await _roomsRef
      .child(roomCode)
      .child('players')
      .child(playerName)
      .get();

  if (!snapshot.exists || snapshot.value == null) {
    return null;
  }

  return Map<String, dynamic>.from(
    snapshot.value as Map,
  );
}
  
}