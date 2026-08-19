import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'auth_service.dart';

enum RankedResult { win, loss, draw }

class MatchHistoryEntry {
  final String matchId;
  final RankedResult result;
  final String? opponentName;
  final int? myScore;
  final int? opponentScore;
  final int? playedAtMs;
  final int? eloBefore;
  final int? eloAfter;
  final int? eloDelta;

  const MatchHistoryEntry({
    required this.matchId,
    required this.result,
    this.opponentName,
    this.myScore,
    this.opponentScore,
    this.playedAtMs,
    this.eloBefore,
    this.eloAfter,
    this.eloDelta,
  });

  String get resultLabel {
    switch (result) {
      case RankedResult.win:
        return 'G';
      case RankedResult.loss:
        return 'M';
      case RankedResult.draw:
        return 'B';
    }
  }
}

class UserProfile {
  final String uid;
  final String displayName;
  final int wins;
  final int losses;
  final int draws;
  final int elo;
  final List<MatchHistoryEntry> recentMatches;

  const UserProfile({
    required this.uid,
    required this.displayName,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.elo = ProfileService.defaultElo,
    this.recentMatches = const [],
  });

  int get played => wins + losses + draws;

  double get winRate {
    if (played == 0) return 0;
    return wins / played;
  }

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    final history = <MatchHistoryEntry>[];
    final raw = data['matchHistory'];
    if (raw is Map) {
      for (final e in raw.entries) {
        if (e.value is! Map) continue;
        final m = Map<String, dynamic>.from(e.value as Map);
        final r = m['result']?.toString() ?? 'loss';
        final result = RankedResult.values.firstWhere(
          (x) => x.name == r,
          orElse: () => RankedResult.loss,
        );
        history.add(
          MatchHistoryEntry(
            matchId: e.key.toString(),
            result: result,
            opponentName: m['opponentName']?.toString(),
            myScore: UserProfile._toInt(m['myScore']),
            opponentScore: UserProfile._toInt(m['opponentScore']),
            playedAtMs: UserProfile._toInt(m['playedAt']),
            eloBefore: UserProfile._toInt(m['eloBefore']),
            eloAfter: UserProfile._toInt(m['eloAfter']),
            eloDelta: UserProfile._toInt(m['eloDelta']),
          ),
        );
      }
      history.sort((a, b) => (b.playedAtMs ?? 0).compareTo(a.playedAtMs ?? 0));
    }

    return UserProfile(
      uid: uid,
      displayName: data['displayName']?.toString() ?? 'Oyuncu',
      wins: _toInt(data['wins']) ?? 0,
      losses: _toInt(data['losses']) ?? 0,
      draws: _toInt(data['draws']) ?? 0,
      elo: _toInt(data['elo']) ?? ProfileService.defaultElo,
      recentMatches: history.take(15).toList(),
    );
  }

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }
}

/// Klasik Elo (K=32, başlangıç 1000).
class ProfileService {
  ProfileService._();

  static const int defaultElo = 1000;
  static const int kFactor = 32;

  static final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static DatabaseReference _userRef(String uid) => _db.ref('users/$uid');

  /// Beklenen skor (0–1).
  static double expectedScore(int myElo, int opponentElo) {
    return 1.0 / (1.0 + math.pow(10, (opponentElo - myElo) / 400.0));
  }

  /// Yeni Elo (yuvarlanmış int).
  static int nextElo({
    required int myElo,
    required int opponentElo,
    required RankedResult result,
  }) {
    final score = switch (result) {
      RankedResult.win => 1.0,
      RankedResult.draw => 0.5,
      RankedResult.loss => 0.0,
    };
    final exp = expectedScore(myElo, opponentElo);
    return (myElo + kFactor * (score - exp)).round();
  }

  static Future<int> _readElo(String uid) async {
    final snap = await _userRef(uid).child('elo').get();
    return UserProfile._toInt(snap.value) ?? defaultElo;
  }

  static Future<UserProfile?> fetchMyProfile() async {
    final uid = AuthService.uid;
    if (uid == null) return null;
    final snap = await _userRef(uid).get();
    if (!snap.exists || snap.value is! Map) {
      return UserProfile(
        uid: uid,
        displayName: AuthService.currentUser?.displayName ?? 'Oyuncu',
      );
    }
    return UserProfile.fromMap(
      uid,
      Map<String, dynamic>.from(snap.value as Map),
    );
  }

  static Stream<UserProfile?> watchMyProfile() {
    final uid = AuthService.uid;
    if (uid == null) return Stream.value(null);
    return _userRef(uid).onValue.map((event) {
      final v = event.snapshot.value;
      if (v is! Map) {
        return UserProfile(
          uid: uid,
          displayName: AuthService.currentUser?.displayName ?? 'Oyuncu',
        );
      }
      return UserProfile.fromMap(uid, Map<String, dynamic>.from(v));
    });
  }

  /// Ranked sonuç + Elo. opponentUid verilirse gerçek rakip Elo’su kullanılır.
  static Future<void> recordMatchResult({
    required String matchId,
    required RankedResult result,
    String? opponentName,
    String? opponentUid,
    int? myScore,
    int? opponentScore,
  }) async {
    final uid = AuthService.uid;
    if (uid == null || matchId.isEmpty) return;

    final myEloBefore = await _readElo(uid);
    final oppElo = (opponentUid != null && opponentUid.isNotEmpty)
        ? await _readElo(opponentUid)
        : defaultElo;

    final myEloAfter = nextElo(
      myElo: myEloBefore,
      opponentElo: oppElo,
      result: result,
    );
    final delta = myEloAfter - myEloBefore;

    await _userRef(uid).runTransaction((current) {
      final data = current is Map
          ? Map<String, dynamic>.from(current)
          : <String, dynamic>{};

      final recorded = data['recordedMatches'] is Map
          ? Map<String, dynamic>.from(data['recordedMatches'] as Map)
          : <String, dynamic>{};

      if (recorded.containsKey(matchId)) {
        return Transaction.abort();
      }

      recorded[matchId] = result.name;
      if (recorded.length > 50) {
        final keys = recorded.keys.toList()..sort();
        for (var i = 0; i < recorded.length - 50; i++) {
          recorded.remove(keys[i]);
        }
      }
      data['recordedMatches'] = recorded;

      final history = data['matchHistory'] is Map
          ? Map<String, dynamic>.from(data['matchHistory'] as Map)
          : <String, dynamic>{};

      history[matchId] = {
        'result': result.name,
        'opponentName': opponentName,
        'myScore': myScore,
        'opponentScore': opponentScore,
        'playedAt': ServerValue.timestamp,
        'eloBefore': myEloBefore,
        'eloAfter': myEloAfter,
        'eloDelta': delta,
      };

      if (history.length > 15) {
        final keys = history.keys.toList();
        while (keys.length > 15) {
          history.remove(keys.removeAt(0));
        }
      }
      data['matchHistory'] = history;

      data['wins'] = (int.tryParse(data['wins']?.toString() ?? '') ?? 0) +
          (result == RankedResult.win ? 1 : 0);
      data['losses'] = (int.tryParse(data['losses']?.toString() ?? '') ?? 0) +
          (result == RankedResult.loss ? 1 : 0);
      data['draws'] = (int.tryParse(data['draws']?.toString() ?? '') ?? 0) +
          (result == RankedResult.draw ? 1 : 0);
      data['elo'] = myEloAfter;
      data['updatedAt'] = ServerValue.timestamp;

      return Transaction.success(data);
    });

  }
}