import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'auth_service.dart';
import 'online_five_service.dart';

enum FiveMmStatus { idle, searching, matched, cancelled, timeout, error }

class FiveMmState {
  final FiveMmStatus status;
  final String? matchId;
  final String? message;
  final String? opponentName;

  const FiveMmState({
    this.status = FiveMmStatus.idle,
    this.matchId,
    this.message,
    this.opponentName,
  });

  FiveMmState copyWith({
    FiveMmStatus? status,
    String? matchId,
    String? message,
    String? opponentName,
  }) =>
      FiveMmState(
        status: status ?? this.status,
        matchId: matchId ?? this.matchId,
        message: message ?? this.message,
        opponentName: opponentName ?? this.opponentName,
      );
}

class FiveMatchmakingService {
  FiveMatchmakingService._();

  static final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static DatabaseReference get _queueRef => _db.ref('matchmaking/fiveQueue');
  static const int queueTimeoutSeconds = 60;

  static StreamSubscription<DatabaseEvent>? _selfSub;
  static Timer? _pollTimer;
  static Timer? _timeoutTimer;
  static bool _claimInFlight = false;
  static bool _matchedHandled = false;
  static String? _activeUid;

  static Future<void> startSearch({
    required void Function(FiveMmState) onUpdate,
    String? displayName,
  }) async {
    await cancelSearch(silent: true);
    _matchedHandled = false;

    final user = await AuthService.ensureSignedIn(displayName: displayName);
    final uid = user.uid;
    _activeUid = uid;
    final name = user.displayName ?? displayName ?? 'Oyuncu';

    onUpdate(const FiveMmState(
      status: FiveMmStatus.searching,
      message: 'Rakip aranıyor…',
    ));

    await _queueRef.child(uid).set({
      'uid': uid,
      'displayName': name,
      'status': 'waiting',
      'joinedAt': ServerValue.timestamp,
      'matchId': null,
      'mode': 'random_five',
    });

    _selfSub = _queueRef.child(uid).onValue.listen((event) async {
      if (_matchedHandled) return;
      final v = event.snapshot.value;
      if (v is! Map) return;
      final data = Map<String, dynamic>.from(v);
      if (data['status'] == 'matched' && data['matchId'] != null) {
        await _onMatched(
          matchId: data['matchId'].toString(),
          opponentName: data['opponentName']?.toString(),
          onUpdate: onUpdate,
        );
      }
    });

    _pollTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      _tryClaim(uid, name, onUpdate);
    });

    _timeoutTimer = Timer(const Duration(seconds: queueTimeoutSeconds), () async {
      if (_matchedHandled) return;
      await cancelSearch(silent: true);
      onUpdate(const FiveMmState(
        status: FiveMmStatus.timeout,
        message: 'Rakip bulunamadı. Tekrar dene.',
      ));
    });
  }

  static Future<void> _tryClaim(
    String uid,
    String myName,
    void Function(FiveMmState) onUpdate,
  ) async {
    if (_claimInFlight || _matchedHandled) return;
    _claimInFlight = true;
    try {
      final selfSnap = await _queueRef.child(uid).get();
      if (!selfSnap.exists) return;
      final self = Map<String, dynamic>.from(selfSnap.value as Map);
      if (self['status'] == 'matched') return;

      final allSnap = await _queueRef.get();
      if (!allSnap.exists || allSnap.value is! Map) return;
      final all = Map<String, dynamic>.from(allSnap.value as Map);

      String? bestUid;
      String? bestName;
      int? bestJoined;
      for (final e in all.entries) {
        if (e.key == uid) continue;
        if (e.value is! Map) continue;
        final o = Map<String, dynamic>.from(e.value as Map);
        if (o['status']?.toString() != 'waiting') continue;
        final joined = int.tryParse('${o['joinedAt'] ?? 0}') ?? 0;
        if (bestJoined == null || joined < bestJoined) {
          bestJoined = joined;
          bestUid = e.key;
          bestName = o['displayName']?.toString() ?? 'Rakip';
        }
      }
      if (bestUid == null) return;

      final claim = await _queueRef.child(bestUid).runTransaction((current) {
        if (current is! Map) return Transaction.abort();
        final data = Map<String, dynamic>.from(current);
        if (data['status']?.toString() != 'waiting') return Transaction.abort();
        data['status'] = 'matched';
        data['claimedBy'] = uid;
        return Transaction.success(data);
      });
      if (!claim.committed) return;

      final matchId = await OnlineFiveService.createRankedMatch(
        player1Uid: uid,
        player1Name: myName,
        player2Uid: bestUid,
        player2Name: bestName ?? 'Rakip',
      );

      await _queueRef.child(bestUid).update({
        'status': 'matched',
        'matchId': matchId,
        'opponentName': myName,
      });
      await _queueRef.child(uid).update({
        'status': 'matched',
        'matchId': matchId,
        'opponentName': bestName,
      });

      await _onMatched(
        matchId: matchId,
        opponentName: bestName,
        onUpdate: onUpdate,
      );
    } catch (e) {
      onUpdate(FiveMmState(
        status: FiveMmStatus.error,
        message: 'Hata: $e',
      ));
    } finally {
      _claimInFlight = false;
    }
  }

  static Future<void> _onMatched({
    required String matchId,
    required void Function(FiveMmState) onUpdate,
    String? opponentName,
  }) async {
    if (_matchedHandled) return;
    _matchedHandled = true;
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();
    final uid = _activeUid;
    if (uid != null) {
      try {
        await _queueRef.child(uid).remove();
      } catch (_) {}
    }
    onUpdate(FiveMmState(
      status: FiveMmStatus.matched,
      matchId: matchId,
      opponentName: opponentName,
      message: 'Rakip bulundu!',
    ));
  }

  static Future<void> cancelSearch({bool silent = false}) async {
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();
    await _selfSub?.cancel();
    _selfSub = null;
    _claimInFlight = false;
    final uid = _activeUid;
    _activeUid = null;
    if (uid != null) {
      try {
        final snap = await _queueRef.child(uid).get();
        if (snap.exists) {
          final v = snap.value;
          if (v is Map && v['status'] != 'matched') {
            await _queueRef.child(uid).remove();
          }
        }
      } catch (_) {}
    }
  }
}
