import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../online/room_service.dart';
import 'auth_service.dart';

enum LotoMmStatus { idle, searching, matched, cancelled, timeout, error }

class LotoMmState {
  final LotoMmStatus status;
  final String? matchId; // room code
  final String? message;
  final String? opponentName;
  final bool isHost;

  const LotoMmState({
    this.status = LotoMmStatus.idle,
    this.matchId,
    this.message,
    this.opponentName,
    this.isHost = false,
  });
}

/// Rastgele Football Loto eşleşmesi.
/// Kuyruk: matchmaking/lotoQueue — oda: RoomService (matchType: loto)
class LotoMatchmakingService {
  LotoMatchmakingService._();

  static final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static DatabaseReference get _queueRef => _db.ref('matchmaking/lotoQueue');
  static const int queueTimeoutSeconds = 60;

  static StreamSubscription<DatabaseEvent>? _selfSub;
  static Timer? _pollTimer;
  static Timer? _timeoutTimer;
  static bool _claimInFlight = false;
  static bool _matchedHandled = false;
  static String? _activeUid;

  static Future<void> startSearch({
    required void Function(LotoMmState) onUpdate,
    String? displayName,
  }) async {
    await cancelSearch(silent: true);
    _matchedHandled = false;

    final user = await AuthService.ensureSignedIn(displayName: displayName);
    final uid = user.uid;
    _activeUid = uid;
    final name = user.displayName ?? displayName ?? 'Oyuncu';

    onUpdate(const LotoMmState(
      status: LotoMmStatus.searching,
      message: 'Loto rakibi aranıyor…',
    ));

    await _queueRef.child(uid).set({
      'uid': uid,
      'displayName': name,
      'status': 'waiting',
      'joinedAt': ServerValue.timestamp,
      'matchId': null,
      'mode': 'loto',
    });

    _selfSub = _queueRef.child(uid).onValue.listen((event) async {
      if (_matchedHandled) return;
      final v = event.snapshot.value;
      if (v is! Map) return;
      final data = Map<String, dynamic>.from(
        v.map((k, val) => MapEntry('$k', val)),
      );
      if (data['status'] == 'matched' && data['matchId'] != null) {
        await _onMatched(
          matchId: data['matchId'].toString(),
          opponentName: data['opponentName']?.toString(),
          isHost: data['isHost'] == true,
          onUpdate: onUpdate,
        );
      }
    });

    _pollTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      _tryClaim(uid, name, onUpdate);
    });

    _timeoutTimer = Timer(const Duration(seconds: queueTimeoutSeconds), () {
      if (_matchedHandled) return;
      cancelSearch(silent: true);
      onUpdate(const LotoMmState(
        status: LotoMmStatus.timeout,
        message: 'Rakip bulunamadı. Tekrar dene.',
      ));
    });
  }

  static Future<void> _tryClaim(
    String uid,
    String myName,
    void Function(LotoMmState) onUpdate,
  ) async {
    if (_claimInFlight || _matchedHandled) return;
    _claimInFlight = true;
    try {
      final snap = await _queueRef.get();
      if (!snap.exists || snap.value is! Map) return;
      final all = Map<String, dynamic>.from(
        (snap.value as Map).map((k, v) => MapEntry('$k', v)),
      );

      String? bestUid;
      String? bestName;
      int? bestJoined;

      for (final e in all.entries) {
        if (e.key == uid) continue;
        if (e.value is! Map) continue;
        final o = Map<String, dynamic>.from(
          (e.value as Map).map((k, v) => MapEntry('$k', v)),
        );
        if (o['status']?.toString() != 'waiting') continue;
        final joined = (o['joinedAt'] as num?)?.toInt() ?? 0;
        if (bestJoined == null || joined < bestJoined) {
          bestJoined = joined;
          bestUid = e.key;
          bestName = o['displayName']?.toString() ?? 'Rakip';
        }
      }
      if (bestUid == null) return;

      final claim = await _queueRef.child(bestUid).runTransaction((current) {
        if (current is! Map) return Transaction.abort();
        final data = Map<String, dynamic>.from(
          current.map((k, v) => MapEntry('$k', v)),
        );
        if (data['status']?.toString() != 'waiting') {
          return Transaction.abort();
        }
        data['status'] = 'matched';
        data['claimedBy'] = uid;
        return Transaction.success(data);
      });
      if (!claim.committed) return;

      // Host oda kurar, rakip join eder
      final roomCode = await RoomService.createRoom(
        playerName: myName,
        matchType: 'loto',
      );
      // Rakip kendi tarafında joinRoom yapar (RandomLotoMatchPage).

      await _queueRef.child(bestUid).update({
        'status': 'matched',
        'matchId': roomCode,
        'opponentName': myName,
        'isHost': false,
      });
      await _queueRef.child(uid).update({
        'status': 'matched',
        'matchId': roomCode,
        'opponentName': bestName,
        'isHost': true,
      });

      await _onMatched(
        matchId: roomCode,
        opponentName: bestName,
        isHost: true,
        onUpdate: onUpdate,
      );
    } catch (e) {
      onUpdate(LotoMmState(
        status: LotoMmStatus.error,
        message: 'Hata: $e',
      ));
    } finally {
      _claimInFlight = false;
    }
  }

  static Future<void> _onMatched({
    required String matchId,
    required void Function(LotoMmState) onUpdate,
    String? opponentName,
    bool isHost = false,
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
    onUpdate(LotoMmState(
      status: LotoMmStatus.matched,
      matchId: matchId,
      opponentName: opponentName,
      isHost: isHost,
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
