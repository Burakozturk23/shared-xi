import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../data/popular_clubs_pool.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../repositories/repository.dart';

/// Rastgele Beş online — path: fiveMatches/{matchId}
class OnlineFiveService {
  OnlineFiveService._();

  static final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static final _rng = Random();

  static DatabaseReference _ref(String matchId) =>
      _db.ref('fiveMatches/$matchId');

  static const int durationSeconds = 90;

  static List<int> _pickClubIds() {
    final clubs = PopularClubs.pickDiverse(
      count: 5,
      maxPerLeague: 1,
      maxPerCountry: 2,
      random: _rng,
    );
    return clubs.map((c) => c.id).toList();
  }

  static Future<String> createMatch({
    required String hostUid,
    required String hostName,
  }) async {
    final matchId = _code();
    final clubIds = _pickClubIds();

    await _ref(matchId).set({
      'matchId': matchId,
      'gameType': 'random_five',
      'status': 'waiting',
      'player1Uid': hostUid,
      'player1Name': hostName,
      'player2Uid': null,
      'player2Name': null,
      'clubIds': clubIds,
      'createdAt': ServerValue.timestamp,
      'game': {
        'scores': {hostUid: 0},
        'usedPlayerIds': <String, dynamic>{},
        'history': <String, dynamic>{}, // uid -> [{playerId, points, name}]
        'startedAt': null,
        'durationSec': durationSeconds,
        'gameOver': false,
        'winnerUid': null,
      },
    });
    return matchId;
  }

  static Future<String> createRankedMatch({
    required String player1Uid,
    required String player1Name,
    required String player2Uid,
    required String player2Name,
  }) async {
    final matchId = _code();
    final clubIds = _pickClubIds();

    await _ref(matchId).set({
      'matchId': matchId,
      'gameType': 'random_five',
      'status': 'playing',
      'ranked': true,
      'player1Uid': player1Uid,
      'player1Name': player1Name,
      'player2Uid': player2Uid,
      'player2Name': player2Name,
      'clubIds': clubIds,
      'createdAt': ServerValue.timestamp,
      'game': {
        'scores': {player1Uid: 0, player2Uid: 0},
        'usedPlayerIds': <String, dynamic>{},
        'history': <String, dynamic>{},
        'startedAt': ServerValue.timestamp,
        'durationSec': durationSeconds,
        'gameOver': false,
        'winnerUid': null,
      },
    });
    return matchId;
  }

  static Future<bool> joinMatch({
    required String matchId,
    required String uid,
    required String displayName,
  }) async {
    final result = await _ref(matchId).runTransaction((current) {
      if (current is! Map) return Transaction.abort();
      final data = Map<String, dynamic>.from(current);
      if (data['status']?.toString() != 'waiting') return Transaction.abort();
      if (data['player2Uid'] != null) return Transaction.abort();
      if (data['player1Uid']?.toString() == uid) return Transaction.abort();

      data['player2Uid'] = uid;
      data['player2Name'] = displayName;
      data['status'] = 'playing';

      final game = Map<String, dynamic>.from(data['game'] as Map? ?? {});
      final scores = Map<String, dynamic>.from(game['scores'] as Map? ?? {});
      scores[uid] = 0;
      game['scores'] = scores;
      game['startedAt'] = ServerValue.timestamp;
      data['game'] = game;
      return Transaction.success(data);
    });
    return result.committed;
  }

  static Stream<DatabaseEvent> watch(String matchId) => _ref(matchId).onValue;

  /// Oyuncu claim — kaç kulübe uyuyorsa o kadar puan.
  static Future<({bool ok, int points, String message})> claimPlayer({
    required String matchId,
    required String uid,
    required Player player,
    required List<int> clubIds,
  }) async {
    final matched = clubIds.where((id) => player.clubs.contains(id)).length;
    if (matched == 0) {
      return (ok: false, points: 0, message: 'Bu 5 kulüpten hiçbirinde yok.');
    }

    final result = await _ref(matchId).runTransaction((current) {
      if (current is! Map) return Transaction.abort();
      final data = Map<String, dynamic>.from(current);
      final game = Map<String, dynamic>.from(data['game'] as Map? ?? {});
      if (game['gameOver'] == true) return Transaction.abort();
      if (data['status']?.toString() != 'playing') return Transaction.abort();

      final used =
          Map<String, dynamic>.from(game['usedPlayerIds'] as Map? ?? {});
      final pidKey = '${player.id}';
      if (used[pidKey] == true) return Transaction.abort();

      used[pidKey] = true;
      final scores = Map<String, dynamic>.from(game['scores'] as Map? ?? {});
      scores[uid] = (int.tryParse('${scores[uid] ?? 0}') ?? 0) + matched;

      final history = Map<String, dynamic>.from(game['history'] as Map? ?? {});
      final mine = List<dynamic>.from(history[uid] as List? ?? []);
      mine.add({
        'playerId': player.id,
        'name': player.name,
        'points': matched,
      });
      history[uid] = mine;

      game['usedPlayerIds'] = used;
      game['scores'] = scores;
      game['history'] = history;
      data['game'] = game;
      return Transaction.success(data);
    });

    if (!result.committed) {
      return (ok: false, points: 0, message: 'Bu oyuncu alınmış veya maç bitti.');
    }
    return (
      ok: true,
      points: matched,
      message: '${player.name}: +$matched puan',
    );
  }

  static Future<void> finishMatch({
    required String matchId,
    required String? winnerUid,
  }) async {
    await _ref(matchId).runTransaction((current) {
      if (current is! Map) return Transaction.abort();
      final data = Map<String, dynamic>.from(current);
      final game = Map<String, dynamic>.from(data['game'] as Map? ?? {});
      if (game['gameOver'] == true) return Transaction.success(data);
      game['gameOver'] = true;
      game['winnerUid'] = winnerUid;
      data['game'] = game;
      data['status'] = 'finished';
      return Transaction.success(data);
    });
  }

  static String _code() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final buf = StringBuffer();
    for (var i = 0; i < 6; i++) {
      buf.write(chars[_rng.nextInt(chars.length)]);
    }
    return buf.toString();
  }
}
