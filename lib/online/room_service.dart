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
    required String team1,
    required String team2,
  }) async {
    String roomCode = _generateRoomCode();

    while ((await _roomsRef.child(roomCode).get()).exists) {
      roomCode = _generateRoomCode();
    }

    await _roomsRef.child(roomCode).set({
      'host': playerName,
      'status': 'waiting',
      'team1': team1,
      'team2': team2,
      'createdAt': ServerValue.timestamp,
      'players': {
        playerName: {
          'score': 0,
          'lives': 3,
          'ready': false,
        }
      }
    });

    return roomCode;
  }
}