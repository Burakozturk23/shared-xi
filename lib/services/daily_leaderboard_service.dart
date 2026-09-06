import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';

import 'auth_service.dart';
import 'daily_challenge_service.dart';

class DailyLeaderboardEntry {
  final String uid;
  final String displayName;
  final String? normalizedName;
  final String? avatarId;
  final int score;
  final double successRate;
  final int? secondsLeft;
  final int? finishedAtMs;
  final int? streak;
  final bool serverValidated;
  final int validationVersion;

  const DailyLeaderboardEntry({
    required this.uid,
    required this.displayName,
    this.normalizedName,
    this.avatarId,
    required this.score,
    this.successRate = 0,
    this.secondsLeft,
    this.finishedAtMs,
    this.streak,
    required this.serverValidated,
    required this.validationVersion,
  });

  factory DailyLeaderboardEntry.fromMap(String uid, Map data) {
    return DailyLeaderboardEntry(
      uid: uid,
      displayName: data['displayName']?.toString() ?? 'Oyuncu',
      normalizedName: data['normalizedName']?.toString(),
      avatarId: data['avatarId']?.toString(),
      score: int.tryParse('${data['score'] ?? 0}') ?? 0,
      successRate:
          double.tryParse('${data['successRate'] ?? 0}') ?? 0,
      secondsLeft: int.tryParse('${data['secondsLeft'] ?? ''}'),
      finishedAtMs: int.tryParse('${data['finishedAt'] ?? ''}'),
      streak: int.tryParse('${data['streak'] ?? ''}'),
      serverValidated: data['serverValidated'] == true,
      validationVersion:
          int.tryParse('${data['validationVersion'] ?? 0}') ?? 0,
    );
  }
}

/// RTDB: dailyLeaderboard/{yyyy-MM-dd}/{uid}
class DailyLeaderboardService {
  DailyLeaderboardService._();

  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'europe-west1',
  );

  static final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static DatabaseReference _dayRef(String dateKey) =>
      _db.ref('dailyLeaderboard/$dateKey');

  /// Skoru yazar. Aynı gün daha yüksek skor gelirse günceller.
  static Future<bool> startSession({
    required DateTime date,
    String? displayName,
  }) async {
    await AuthService.ensureSignedIn(displayName: displayName);
    final dateKey = DailyChallengeService.dateKeyFor(date);
    try {
      final callable = _functions.httpsCallable('startDailyScoreSession');
      final response = await callable.call(<String, dynamic>{
        'dateKey': dateKey,
      });
      final data = response.data;
      return data is Map && data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> submitScore({
    required DateTime date,
    required int score,
    required double successRate,
    int? secondsLeft,
    int? streak,
    String? displayName,
    int? foundCount,
    int? targetCount,
    int? wrongCount,
  }) async {
    await AuthService.ensureSignedIn(displayName: displayName);
    final dateKey = DailyChallengeService.dateKeyFor(date);
    final safeFound = foundCount ?? (score ~/ 10).clamp(0, 80);
    var safeTarget = targetCount;
    if (safeTarget == null || safeTarget <= 0) {
      if (successRate > 0 && safeFound > 0) {
        safeTarget = (safeFound / successRate).round();
      } else {
        safeTarget = safeFound > 0 ? safeFound : 1;
      }
    }
    safeTarget = safeTarget.clamp(safeFound, 80);
    final safeWrong = (wrongCount ?? 0).clamp(0, 10);
    final callable = _functions.httpsCallable('submitDailyScore');
    await callable.call(<String, dynamic>{
      'dateKey': dateKey,
      'foundCount': safeFound,
      'targetCount': safeTarget,
      'wrongCount': safeWrong,
    });
  }

  static int _compareEntries(
    DailyLeaderboardEntry a,
    DailyLeaderboardEntry b,
  ) {
    if (b.score != a.score) return b.score.compareTo(a.score);

    final sa = a.secondsLeft ?? -1;
    final sb = b.secondsLeft ?? -1;
    if (sb != sa) return sb.compareTo(sa);

    final fa = a.finishedAtMs ?? 1 << 62;
    final fb = b.finishedAtMs ?? 1 << 62;
    return fa.compareTo(fb);
  }

  static List<DailyLeaderboardEntry> _decodeBoard(
    Object? value, {
    required int limit,
  }) {
    if (value is! Map) return const [];

    final map = Map<String, dynamic>.from(value);
    final list = <DailyLeaderboardEntry>[];

    for (final entry in map.entries) {
      if (entry.value is! Map) continue;

      final decoded = DailyLeaderboardEntry.fromMap(
        entry.key,
        Map<String, dynamic>.from(entry.value as Map),
      );

      // Only rows created by the trusted submitDailyScore callable are
      // eligible for the canonical leaderboard. Historical/untrusted rows are
      // intentionally excluded instead of being silently mixed in.
      if (!decoded.serverValidated || decoded.validationVersion < 1) {
        continue;
      }

      list.add(decoded);
    }

    list.sort(_compareEntries);

    final safeLimit = limit.clamp(1, 100).toInt();
    if (list.length > safeLimit) {
      return List<DailyLeaderboardEntry>.unmodifiable(
        list.take(safeLimit),
      );
    }

    return List<DailyLeaderboardEntry>.unmodifiable(list);
  }

  /// Bugün / verilen gün sıralaması (skor ↓, kalan süre ↑).
  static Future<List<DailyLeaderboardEntry>> fetch({
    DateTime? date,
    int limit = 50,
  }) async {
    final dateKey =
        DailyChallengeService.dateKeyFor(date ?? DateTime.now());
    final snap = await _dayRef(dateKey).get();
    if (!snap.exists) return const [];

    return _decodeBoard(
      snap.value,
      limit: limit,
    );
  }

  static Stream<List<DailyLeaderboardEntry>> watch({
    DateTime? date,
    int limit = 50,
  }) {
    final dateKey =
        DailyChallengeService.dateKeyFor(date ?? DateTime.now());
    return _dayRef(dateKey).onValue.map(
      (event) => _decodeBoard(
        event.snapshot.value,
        limit: limit,
      ),
    );
  }
}
