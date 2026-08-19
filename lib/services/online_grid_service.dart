import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/grid_sub_type.dart';
import 'grid_puzzle_factory.dart';

/// Birleşik Online Grid — path: gridMatches/{matchId}
/// subType: classic | random | reverse
class OnlineGridService {
  OnlineGridService._();

  static final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static final _rng = Random();

  static DatabaseReference _ref(String matchId) =>
      _db.ref('gridMatches/$matchId');

  static Map<String, dynamic> _baseGame({
    required String p1,
    String? p2,
  }) {
    final scores = <String, dynamic>{p1: 0};
    if (p2 != null) scores[p2] = 0;
    return {
      'turnUid': p1,
      'turnDeadline': ServerValue.timestamp,
      'turnSeconds': 45,
      'owners': List.filled(9, ''),
      'cellPlayerIds': List.filled(9, 0),
      'usedPlayerIds': <String, dynamic>{},
      'scores': scores,
      'gameOver': false,
      'winnerUid': null,
      'reason': null,
      'roundIndex': 0,
      'axisOwners': <String, dynamic>{},
    };
  }

  static Future<String> createMatch({
    required String hostUid,
    required String hostName,
    required GridSubType subType,
  }) async {
    final matchId = _code();
    final seed = GridPuzzleFactory.seedFor(subType);

    await _ref(matchId).set({
      'matchId': matchId,
      'gameType': 'grid',
      'subType': subType.id,
      'status': 'waiting',
      'hostUid': hostUid,
      'player1Uid': hostUid,
      'player1Name': hostName,
      'player2Uid': null,
      'player2Name': null,
      'seed': seed,
      'createdAt': ServerValue.timestamp,
      'game': _baseGame(p1: hostUid),
    });
    return matchId;
  }

  static Future<String> createRankedMatch({
    required String player1Uid,
    required String player1Name,
    required String player2Uid,
    required String player2Name,
    required GridSubType subType,
  }) async {
    final matchId = _code();
    final seed = GridPuzzleFactory.seedFor(subType);

    await _ref(matchId).set({
      'matchId': matchId,
      'gameType': 'grid',
      'subType': subType.id,
      'status': 'playing',
      'ranked': true,
      'hostUid': player1Uid,
      'player1Uid': player1Uid,
      'player1Name': player1Name,
      'player2Uid': player2Uid,
      'player2Name': player2Name,
      'seed': seed,
      'createdAt': ServerValue.timestamp,
      'game': _baseGame(p1: player1Uid, p2: player2Uid),
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

  // ─── CLASSIC claim cell ────────────────────────────────

  static Future<bool> claimClassicCell({
    required String matchId,
    required String uid,
    required String opponentUid,
    required int cellIndex,
    required int playerId,
  }) async {
    if (cellIndex < 0 || cellIndex > 8) return false;

    final result = await _ref(matchId).runTransaction((current) {
      if (current is! Map) return Transaction.abort();
      final data = Map<String, dynamic>.from(current);
      if (data['subType']?.toString() != 'classic' &&
          data['subType'] != null &&
          data['subType'].toString().isNotEmpty &&
          data['subType'].toString() != GridSubType.classic.id) {
        // allow missing subType as classic (eski maçlar)
      }
      final game = Map<String, dynamic>.from(data['game'] as Map? ?? {});
      if (game['gameOver'] == true) return Transaction.abort();
      if (game['turnUid']?.toString() != uid) return Transaction.abort();

      final owners =
          List<dynamic>.from(game['owners'] as List? ?? List.filled(9, ''));
      final cellPlayers = List<dynamic>.from(
          game['cellPlayerIds'] as List? ?? List.filled(9, 0));
      final used =
          Map<String, dynamic>.from(game['usedPlayerIds'] as Map? ?? {});

      if ((owners[cellIndex]?.toString() ?? '').isNotEmpty) {
        return Transaction.abort();
      }
      if (used['$playerId'] == true) return Transaction.abort();

      owners[cellIndex] = uid;
      cellPlayers[cellIndex] = playerId;
      used['$playerId'] = true;

      final scores = Map<String, dynamic>.from(game['scores'] as Map? ?? {});
      scores[uid] = (int.tryParse('${scores[uid] ?? 0}') ?? 0) + 1;

      game['owners'] = owners;
      game['cellPlayerIds'] = cellPlayers;
      game['usedPlayerIds'] = used;
      game['scores'] = scores;

      if (_hasLine(owners, uid)) {
        game['gameOver'] = true;
        game['winnerUid'] = uid;
        game['reason'] = 'line';
        data['status'] = 'finished';
      } else if (owners.every((o) => (o?.toString() ?? '').isNotEmpty)) {
        _finishByScore(game, data, uid, opponentUid, scores);
      } else {
        game['turnUid'] = opponentUid;
        game['turnDeadline'] = ServerValue.timestamp;
      }

      data['game'] = game;
      return Transaction.success(data);
    });
    return result.committed;
  }


  /// Eski isim (controller uyumu) → claimClassicCell
  static Future<bool> claimCell({
    required String matchId,
    required String uid,
    required String opponentUid,
    required int cellIndex,
    required int playerId,
  }) =>
      claimClassicCell(
        matchId: matchId,
        uid: uid,
        opponentUid: opponentUid,
        cellIndex: cellIndex,
        playerId: playerId,
      );

  // ─── RANDOM: doğru ortak oyuncu ────────────────────────

  static Future<bool> claimRandomRound({
    required String matchId,
    required String uid,
    required String opponentUid,
    required int playerId,
    required int expectedRoundIndex,
  }) async {
    final result = await _ref(matchId).runTransaction((current) {
      if (current is! Map) return Transaction.abort();
      final data = Map<String, dynamic>.from(current);
      if (data['subType']?.toString() != GridSubType.random.id) {
        return Transaction.abort();
      }
      final game = Map<String, dynamic>.from(data['game'] as Map? ?? {});
      if (game['gameOver'] == true) return Transaction.abort();
      if (game['turnUid']?.toString() != uid) return Transaction.abort();

      final roundIndex = int.tryParse('${game['roundIndex'] ?? 0}') ?? 0;
      if (roundIndex != expectedRoundIndex) return Transaction.abort();

      final seed = data['seed'];
      final rounds = seed is Map ? (seed['rounds'] as List? ?? []) : [];
      if (roundIndex >= rounds.length) return Transaction.abort();

      final used =
          Map<String, dynamic>.from(game['usedPlayerIds'] as Map? ?? {});
      if (used['$playerId'] == true) return Transaction.abort();
      used['$playerId'] = true;

      final scores = Map<String, dynamic>.from(game['scores'] as Map? ?? {});
      scores[uid] = (int.tryParse('${scores[uid] ?? 0}') ?? 0) + 1;

      final nextRound = roundIndex + 1;
      game['usedPlayerIds'] = used;
      game['scores'] = scores;
      game['roundIndex'] = nextRound;

      if (nextRound >= rounds.length) {
        _finishByScore(game, data, uid, opponentUid, scores);
      } else {
        game['turnUid'] = opponentUid;
        game['turnDeadline'] = ServerValue.timestamp;
      }

      data['game'] = game;
      return Transaction.success(data);
    });
    return result.committed;
  }

  // ─── REVERSE: eksen tahmini (r0..r2 / c0..c2) ───────────

  static Future<bool> claimReverseAxis({
    required String matchId,
    required String uid,
    required String opponentUid,
    required String axisKey, // r0, c1, ...
  }) async {
    final result = await _ref(matchId).runTransaction((current) {
      if (current is! Map) return Transaction.abort();
      final data = Map<String, dynamic>.from(current);
      if (data['subType']?.toString() != GridSubType.reverse.id) {
        return Transaction.abort();
      }
      final game = Map<String, dynamic>.from(data['game'] as Map? ?? {});
      if (game['gameOver'] == true) return Transaction.abort();
      if (game['turnUid']?.toString() != uid) return Transaction.abort();

      final axisOwners =
          Map<String, dynamic>.from(game['axisOwners'] as Map? ?? {});
      if ((axisOwners[axisKey]?.toString() ?? '').isNotEmpty) {
        return Transaction.abort();
      }
      axisOwners[axisKey] = uid;

      final scores = Map<String, dynamic>.from(game['scores'] as Map? ?? {});
      scores[uid] = (int.tryParse('${scores[uid] ?? 0}') ?? 0) + 1;

      game['axisOwners'] = axisOwners;
      game['scores'] = scores;

      // 6 eksenin hepsi dolu veya bir oyuncu 4+ eksen
      final claimed = axisOwners.length;
      final myAxes =
          axisOwners.values.where((v) => v?.toString() == uid).length;
      if (myAxes >= 4) {
        game['gameOver'] = true;
        game['winnerUid'] = uid;
        game['reason'] = 'axes';
        data['status'] = 'finished';
      } else if (claimed >= 6) {
        _finishByScore(game, data, uid, opponentUid, scores);
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

  static void _finishByScore(
    Map<String, dynamic> game,
    Map<String, dynamic> data,
    String uid,
    String opponentUid,
    Map<String, dynamic> scores,
  ) {
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
  }

  static bool _hasLine(List<dynamic> owners, String uid) {
    const lines = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];
    for (final line in lines) {
      if (line.every((i) => owners[i]?.toString() == uid)) return true;
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
