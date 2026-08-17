import 'dart:async';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'auth_service.dart';
import 'match_service.dart';
import 'team_pair_service.dart';

enum MatchmakingStatus {
  idle,
  searching,
  matched,
  cancelled,
  timeout,
  error,
}

class MatchmakingState {
  final MatchmakingStatus status;
  final String? matchId;
  final String? message;
  final int? team1Id;
  final int? team2Id;
  final String? team1Name;
  final String? team2Name;
  final String? opponentName;

  const MatchmakingState({
    this.status = MatchmakingStatus.idle,
    this.matchId,
    this.message,
    this.team1Id,
    this.team2Id,
    this.team1Name,
    this.team2Name,
    this.opponentName,
  });

  MatchmakingState copyWith({
    MatchmakingStatus? status,
    String? matchId,
    String? message,
    int? team1Id,
    int? team2Id,
    String? team1Name,
    String? team2Name,
    String? opponentName,
  }) {
    return MatchmakingState(
      status: status ?? this.status,
      matchId: matchId ?? this.matchId,
      message: message ?? this.message,
      team1Id: team1Id ?? this.team1Id,
      team2Id: team2Id ?? this.team2Id,
      team1Name: team1Name ?? this.team1Name,
      team2Name: team2Name ?? this.team2Name,
      opponentName: opponentName ?? this.opponentName,
    );
  }
}

class MatchmakingService {
  MatchmakingService._();

  static final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static DatabaseReference get _queueRef => _db.ref('matchmaking/queue');

  static const int queueTimeoutSeconds = 60;
  static const int pollIntervalMs = 1200;

  static StreamSubscription<DatabaseEvent>? _selfSub;
  static Timer? _pollTimer;
  static Timer? _timeoutTimer;
  static bool _claimInFlight = false;
  static bool _matchedHandled = false;
  static String? _activeUid;

  static Future<void> startSearch({
    required void Function(MatchmakingState state) onUpdate,
    String? displayName,
  }) async {
    await cancelSearch(silent: true);
    _matchedHandled = false;

    final user = await AuthService.ensureSignedIn(displayName: displayName);
    final uid = user.uid;
    _activeUid = uid;
    final name = user.displayName ?? displayName ?? 'Oyuncu';

    onUpdate(const MatchmakingState(
      status: MatchmakingStatus.searching,
      message: 'Rakip aranıyor…',
    ));

    await _queueRef.child(uid).set({
      'uid': uid,
      'displayName': name,
      'status': 'waiting',
      'joinedAt': ServerValue.timestamp,
      'matchId': null,
    });

    _selfSub = _queueRef.child(uid).onValue.listen((event) async {
      if (_matchedHandled) return;
      final v = event.snapshot.value;
      if (v is! Map) return;
      final data = Map<String, dynamic>.from(v);
      if (data['status'] == 'matched' && data['matchId'] != null) {
        final matchId = data['matchId'].toString();
        await _onMatched(matchId: matchId, onUpdate: onUpdate);
      }
    });

    _pollTimer = Timer.periodic(
      const Duration(milliseconds: pollIntervalMs),
      (_) => _tryClaimOpponent(uid: uid, displayName: name, onUpdate: onUpdate),
    );

    await _tryClaimOpponent(uid: uid, displayName: name, onUpdate: onUpdate);

    _timeoutTimer =
        Timer(const Duration(seconds: queueTimeoutSeconds), () async {
      if (_matchedHandled) return;
      await cancelSearch(silent: true);
      onUpdate(const MatchmakingState(
        status: MatchmakingStatus.timeout,
        message: 'Rakip bulunamadı. Tekrar dene.',
      ));
    });
  }

  static Future<void> _tryClaimOpponent({
    required String uid,
    required String displayName,
    required void Function(MatchmakingState state) onUpdate,
  }) async {
    if (_claimInFlight || _matchedHandled) return;
    _claimInFlight = true;
    try {
      final selfSnap = await _queueRef.child(uid).get();
      if (!selfSnap.exists || selfSnap.value is! Map) return;
      final self = Map<String, dynamic>.from(selfSnap.value as Map);
      if (self['status'] != 'waiting') return;

      final allSnap = await _queueRef.get();
      if (!allSnap.exists || allSnap.value is! Map) return;
      final all = Map<String, dynamic>.from(allSnap.value as Map);

      String? bestUid;
      int? bestJoined;
      String opponentName = 'Rakip';

      for (final entry in all.entries) {
        final otherUid = entry.key;
        if (otherUid == uid) continue;
        if (entry.value is! Map) continue;
        final o = Map<String, dynamic>.from(entry.value as Map);
        if (o['status'] != 'waiting') continue;
        final joined = int.tryParse(o['joinedAt']?.toString() ?? '') ?? 0;
        if (bestJoined == null || joined < bestJoined) {
          bestJoined = joined;
          bestUid = otherUid;
          opponentName = o['displayName']?.toString() ?? 'Rakip';
        }
      }

      if (bestUid == null) return;

      // Deterministik: sadece lexicographically büyük uid claim eder.
      // Böylece iki taraf aynı anda claim etmez.
      if (uid.compareTo(bestUid) < 0) {
        return;
      }

      final pair = TeamPairService.pickValidPair();
      if (pair == null) {
        onUpdate(const MatchmakingState(
          status: MatchmakingStatus.error,
          message: 'Geçerli takım çifti bulunamadı.',
        ));
        return;
      }

      // Sabit matchId (random yok) → iki taraf aynı id'yi görür
      final matchId = _stableMatchId(uid, bestUid);

      // 1) ÖNCE maç dokümanını yaz (rakip dinleyicisi null görmesin)
      await MatchService.createMatch(
        matchId: matchId,
        player1Uid: uid,
        player1Name: displayName,
        player2Uid: bestUid,
        player2Name: opponentName,
        team1Id: pair.team1.id,
        team1Name: pair.team1.name,
        team2Id: pair.team2.id,
        team2Name: pair.team2.name,
        commonPlayerIds: pair.commonPlayerIds,
      );

      // 2) Rakibi claim et
      final claim = await _queueRef.child(bestUid).runTransaction((current) {
        if (current is! Map) return Transaction.abort();
        final data = Map<String, dynamic>.from(current);
        if (data['status'] != 'waiting') return Transaction.abort();
        data['status'] = 'matched';
        data['matchId'] = matchId;
        data['claimedBy'] = uid;
        return Transaction.success(data);
      });

      if (!claim.committed) {
        // Rakip kaçtı / başkası aldı — maçı silmeye gerek yok, orphan kalabilir
        return;
      }

      // 3) Kendini matched yap
      await _queueRef.child(uid).update({
        'status': 'matched',
        'matchId': matchId,
      });

      await _onMatched(matchId: matchId, onUpdate: onUpdate);
    } catch (_) {
      // bir sonraki poll
    } finally {
      _claimInFlight = false;
    }
  }

  static Future<void> _onMatched({
    required String matchId,
    required void Function(MatchmakingState state) onUpdate,
  }) async {
    if (_matchedHandled) return;
    _matchedHandled = true;
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();

    // Maç dokümanı gecikmeli yazılmış olabilir → retry
    Map<String, dynamic>? match;
    for (var i = 0; i < 15; i++) {
      match = await MatchService.getMatch(matchId);
      if (match != null) break;
      await Future.delayed(Duration(milliseconds: 150 + i * 50));
    }

    if (match == null) {
      _matchedHandled = false;
      onUpdate(MatchmakingState(
        status: MatchmakingStatus.error,
        message: 'Maç yüklenemedi. Tekrar dene.',
        matchId: matchId,
      ));
      return;
    }

    onUpdate(MatchmakingState(
      status: MatchmakingStatus.matched,
      matchId: matchId,
      message: 'Rakip bulundu!',
      team1Id: int.tryParse(match['team1Id']?.toString() ?? ''),
      team2Id: int.tryParse(match['team2Id']?.toString() ?? ''),
      team1Name: match['team1Name']?.toString(),
      team2Name: match['team2Name']?.toString(),
      opponentName: _opponentName(match),
    ));

    // Kuyruk kaydını temizle (opsiyonel)
    final uid = _activeUid;
    if (uid != null) {
      try {
        await _queueRef.child(uid).remove();
      } catch (_) {}
    }
  }

  static String? _opponentName(Map<String, dynamic> match) {
    final uid = AuthService.uid;
    if (uid == null) return null;
    if (match['player1Uid'] == uid) return match['player2Name']?.toString();
    return match['player1Name']?.toString();
  }

  /// Random yok — aynı iki uid her zaman aynı prefix.
  static String _stableMatchId(String a, String b) {
    final sorted = [a, b]..sort();
    final t = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    return '${sorted[0]}_${sorted[1]}_$t';
  }

  static Future<void> cancelSearch({bool silent = false}) async {
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();
    await _selfSub?.cancel();
    _selfSub = null;
    _claimInFlight = false;
    _matchedHandled = false;

    final uid = AuthService.uid ?? _activeUid;
    if (uid != null) {
      try {
        final snap = await _queueRef.child(uid).get();
        if (snap.exists && snap.value is Map) {
          final data = Map<String, dynamic>.from(snap.value as Map);
          if (data['status'] == 'waiting') {
            await _queueRef.child(uid).remove();
          }
        }
      } catch (_) {}
    }
    _activeUid = null;
  }
}