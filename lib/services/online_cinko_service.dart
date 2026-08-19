import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'cinko_puzzle_factory.dart';

/// Online Çinko — path: cinkoMatches/{matchId}
class OnlineCinkoService {
  OnlineCinkoService._();

  static final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static final _rng = Random();
  static const int gridSize = 5;

  static DatabaseReference _ref(String matchId) =>
      _db.ref('cinkoMatches/$matchId');

  static Future<String> createMatch({
    required String hostUid,
    required String hostName,
  }) async {
    final matchId = _code();
    final cells = CinkoPuzzleFactory.generate();
    final seed = CinkoPuzzleFactory.cellsToSeed(cells);

    await _ref(matchId).set({
      'matchId': matchId,
      'gameType': 'cinko',
      'status': 'waiting',
      'player1Uid': hostUid,
      'player1Name': hostName,
      'player2Uid': null,
      'player2Name': null,
      'seed': seed,
      'createdAt': ServerValue.timestamp,
      'game': {
        'turnUid': hostUid,
        'turnDeadline': ServerValue.timestamp,
        'owners': List.filled(gridSize * gridSize, ''), // uid or ''
        'usedPlayerIds': <String, dynamic>{},
        'scores': {hostUid: 0},
        'gameOver': false,
        'winnerUid': null,
        'reason': null, // bingo | score
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
    final cells = CinkoPuzzleFactory.generate();
    final seed = CinkoPuzzleFactory.cellsToSeed(cells);

    await _ref(matchId).set({
      'matchId': matchId,
      'gameType': 'cinko',
      'status': 'playing',
      'ranked': true,
      'player1Uid': player1Uid,
      'player1Name': player1Name,
      'player2Uid': player2Uid,
      'player2Name': player2Name,
      'seed': seed,
      'createdAt': ServerValue.timestamp,
      'game': {
        'turnUid': player1Uid,
        'turnDeadline': ServerValue.timestamp,
        'owners': List.filled(gridSize * gridSize, ''),
        'usedPlayerIds': <String, dynamic>{},
        'scores': {player1Uid: 0, player2Uid: 0},
        'gameOver': false,
        'winnerUid': null,
        'reason': null,
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
      game['turnUid'] = data['player1Uid'];
      game['turnDeadline'] = ServerValue.timestamp;
      data['game'] = game;
      return Transaction.success(data);
    });
    return result.committed;
  }

  static Stream<DatabaseEvent> watch(String matchId) => _ref(matchId).onValue;

  /// Doğru hücreleri boya. indexes: sadece client’ta doğrulanmış eşleşen indeksler.
  static Future<bool> claimCells({
    required String matchId,
    required String uid,
    required String opponentUid,
    required int playerId,
    required List<int> indexes,
  }) async {
    if (indexes.isEmpty) return false;

    final result = await _ref(matchId).runTransaction((current) {
      if (current is! Map) return Transaction.abort();
      final data = Map<String, dynamic>.from(current);
      final game = Map<String, dynamic>.from(data['game'] as Map? ?? {});

      if (game['gameOver'] == true) return Transaction.abort();
      if (game['turnUid']?.toString() != uid) return Transaction.abort();

      final used =
          Map<String, dynamic>.from(game['usedPlayerIds'] as Map? ?? {});
      final pidKey = '$playerId';
      if (used[pidKey] == true) return Transaction.abort();

      final owners = List<dynamic>.from(
        game['owners'] as List? ?? List.filled(gridSize * gridSize, ''),
      );

      var painted = 0;
      for (final i in indexes) {
        if (i < 0 || i >= owners.length) continue;
        if ((owners[i]?.toString() ?? '').isNotEmpty) continue;
        owners[i] = uid;
        painted++;
      }
      if (painted == 0) return Transaction.abort();

      used[pidKey] = true;
      final scores = Map<String, dynamic>.from(game['scores'] as Map? ?? {});
      scores[uid] = (int.tryParse('${scores[uid] ?? 0}') ?? 0) + painted;

      game['owners'] = owners;
      game['usedPlayerIds'] = used;
      game['scores'] = scores;

      if (_hasBingo(owners, uid)) {
        game['gameOver'] = true;
        game['winnerUid'] = uid;
        game['reason'] = 'bingo';
        data['status'] = 'finished';
      } else if (owners.every((o) => (o?.toString() ?? '').isNotEmpty)) {
        game['gameOver'] = true;
        game['reason'] = 'score';
        final s1 = int.tryParse('${scores[uid] ?? 0}') ?? 0;
        final s2 = int.tryParse('${scores[opponentUid] ?? 0}') ?? 0;
        if (s1 > s2) {
          game['winnerUid'] = uid;
        } else if (s2 > s1) {
          game['winnerUid'] = opponentUid;
        } else {
          game['winnerUid'] = null;
        }
        data['status'] = 'finished';
      } else {
        game['turnUid'] = opponentUid;
        game['turnDeadline'] = ServerValue.timestamp;
      }

      data['game'] = game;
      return Transaction.success(data);
    });

    return result.committed;
  }

  static Future<bool> passTurn({
    required String matchId,
    required String uid,
    required String nextUid,
  }) async {
    final result = await _ref(matchId).runTransaction((current) {
      if (current is! Map) return Transaction.abort();
      final data = Map<String, dynamic>.from(current);
      final game = Map<String, dynamic>.from(data['game'] as Map? ?? {});
      if (game['gameOver'] == true) return Transaction.abort();
      if (game['turnUid']?.toString() != uid) return Transaction.abort();
      game['turnUid'] = nextUid;
      game['turnDeadline'] = ServerValue.timestamp;
      data['game'] = game;
      return Transaction.success(data);
    });
    return result.committed;
  }

  /// 5x5 satır / sütun / 2 çapraz
  static bool _hasBingo(List<dynamic> owners, String uid) {
    const n = gridSize;
    // rows
    for (var r = 0; r < n; r++) {
      if (List.generate(n, (c) => r * n + c)
          .every((i) => owners[i]?.toString() == uid)) {
        return true;
      }
    }
    // cols
    for (var c = 0; c < n; c++) {
      if (List.generate(n, (r) => r * n + c)
          .every((i) => owners[i]?.toString() == uid)) {
        return true;
      }
    }
    // diag
    if (List.generate(n, (i) => i * n + i)
        .every((i) => owners[i]?.toString() == uid)) {
      return true;
    }
    if (List.generate(n, (i) => i * n + (n - 1 - i))
        .every((i) => owners[i]?.toString() == uid)) {
      return true;
    }
    return false;
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
