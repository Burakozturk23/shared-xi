import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'auth_service.dart';
import 'daily_challenge_service.dart';

class DailyLeaderboardEntry {
  final String uid;
  final String displayName;
  final int score;
  final double successRate;
  final int? secondsLeft;
  final int? finishedAtMs;
  final int? streak;

  const DailyLeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.score,
    this.successRate = 0,
    this.secondsLeft,
    this.finishedAtMs,
    this.streak,
  });

  factory DailyLeaderboardEntry.fromMap(String uid, Map data) {
    return DailyLeaderboardEntry(
      uid: uid,
      displayName: data['displayName']?.toString() ?? 'Oyuncu',
      score: int.tryParse('${data['score'] ?? 0}') ?? 0,
      successRate:
          double.tryParse('${data['successRate'] ?? 0}') ?? 0,
      secondsLeft: int.tryParse('${data['secondsLeft'] ?? ''}'),
      finishedAtMs: int.tryParse('${data['finishedAt'] ?? ''}'),
      streak: int.tryParse('${data['streak'] ?? ''}'),
    );
  }
}

/// RTDB: dailyLeaderboard/{yyyy-MM-dd}/{uid}
class DailyLeaderboardService {
  DailyLeaderboardService._();

  static final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static DatabaseReference _dayRef(String dateKey) =>
      _db.ref('dailyLeaderboard/$dateKey');

  /// Skoru yazar. Aynı gün daha yüksek skor gelirse günceller.
  static Future<void> submitScore({
    required DateTime date,
    required int score,
    required double successRate,
    int? secondsLeft,
    int? streak,
    String? displayName,
  }) async {
    final user = await AuthService.ensureSignedIn(displayName: displayName);
    final dateKey = DailyChallengeService.dateKeyFor(date);
    final ref = _dayRef(dateKey).child(user.uid);

    final existing = await ref.get();
    if (existing.exists && existing.value is Map) {
      final old = Map<String, dynamic>.from(existing.value as Map);
      final oldScore = int.tryParse('${old['score'] ?? 0}') ?? 0;
      // Daha düşük skoru üzerine yazma
      if (score < oldScore) return;
      if (score == oldScore) {
        final oldLeft = int.tryParse('${old['secondsLeft'] ?? -1}') ?? -1;
        if (secondsLeft != null && oldLeft >= 0 && secondsLeft <= oldLeft) {
          return; // aynı skor, daha yavaş / eşit süre
        }
      }
    }

    await ref.set({
      'displayName': user.displayName ?? displayName ?? 'Oyuncu',
      'score': score,
      'successRate': successRate,
      'secondsLeft': secondsLeft,
      'streak': streak,
      'finishedAt': ServerValue.timestamp,
    });
  }

  /// Bugün / verilen gün sıralaması (skor ↓, kalan süre ↑).
  static Future<List<DailyLeaderboardEntry>> fetch({
    DateTime? date,
    int limit = 50,
  }) async {
    final dateKey =
        DailyChallengeService.dateKeyFor(date ?? DateTime.now());
    final snap = await _dayRef(dateKey).get();
    if (!snap.exists || snap.value is! Map) return const [];

    final map = Map<String, dynamic>.from(snap.value as Map);
    final list = <DailyLeaderboardEntry>[];
    for (final e in map.entries) {
      if (e.value is! Map) continue;
      list.add(
        DailyLeaderboardEntry.fromMap(
          e.key,
          Map<String, dynamic>.from(e.value as Map),
        ),
      );
    }

    list.sort((a, b) {
      if (b.score != a.score) return b.score.compareTo(a.score);
      final sa = a.secondsLeft ?? -1;
      final sb = b.secondsLeft ?? -1;
      if (sb != sa) return sb.compareTo(sa); // daha çok kalan süre = daha hızlı
      final fa = a.finishedAtMs ?? 1 << 62;
      final fb = b.finishedAtMs ?? 1 << 62;
      return fa.compareTo(fb);
    });

    if (list.length > limit) return list.sublist(0, limit);
    return list;
  }

  static Stream<List<DailyLeaderboardEntry>> watch({
    DateTime? date,
    int limit = 50,
  }) {
    final dateKey =
        DailyChallengeService.dateKeyFor(date ?? DateTime.now());
    return _dayRef(dateKey).onValue.map((event) {
      final v = event.snapshot.value;
      if (v is! Map) return <DailyLeaderboardEntry>[];
      final map = Map<String, dynamic>.from(v);
      final list = <DailyLeaderboardEntry>[];
      for (final e in map.entries) {
        if (e.value is! Map) continue;
        list.add(
          DailyLeaderboardEntry.fromMap(
            e.key,
            Map<String, dynamic>.from(e.value as Map),
          ),
        );
      }
      list.sort((a, b) {
        if (b.score != a.score) return b.score.compareTo(a.score);
        final sa = a.secondsLeft ?? -1;
        final sb = b.secondsLeft ?? -1;
        if (sb != sa) return sb.compareTo(sa);
        final fa = a.finishedAtMs ?? 1 << 62;
        final fb = b.finishedAtMs ?? 1 << 62;
        return fa.compareTo(fb);
      });
      if (list.length > limit) return list.sublist(0, limit);
      return list;
    });
  }
}
