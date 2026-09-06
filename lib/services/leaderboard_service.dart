import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/leaderboard_models.dart';

import '../services/daily_challenge_service.dart';
import '../services/daily_leaderboard_service.dart';

/// One client-facing leaderboard gateway.
///
/// Important security boundary:
/// - Daily is already server-authoritative and can be exposed.
/// - Global Elo is NOT exposed yet because the current ranked Elo write path
///   still lives in the client profile transaction.
/// - Weekly is NOT exposed until a trusted server aggregate exists.
///
/// Later phases fill the pending boards behind this same API instead of
/// introducing mode-specific leaderboard services.
class LeaderboardService {
  LeaderboardService._();

  static final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://sharedix-default-rtdb.europe-west1.firebasedatabase.app',
  );

  static const int defaultLimit = 50;
  static const int maxLimit = 100;

  static int _safeLimit(int limit) => limit.clamp(1, maxLimit).toInt();

  static Future<LeaderboardSnapshot> fetchDaily({
    DateTime? date,
    int limit = defaultLimit,
  }) async {
    final day = date ?? DateTime.now();
    final rows = await DailyLeaderboardService.fetch(
      date: day,
      limit: _safeLimit(limit),
    );

    return LeaderboardSnapshot(
      scope: LeaderboardScope.daily,
      periodKey: DailyChallengeService.dateKeyFor(day),
      availability: LeaderboardAvailability.available,
      entries: _fromDaily(rows),
      serverValidated: true,
    );
  }

  static Stream<LeaderboardSnapshot> watchDaily({
    DateTime? date,
    int limit = defaultLimit,
  }) {
    final day = date ?? DateTime.now();

    return DailyLeaderboardService.watch(
      date: day,
      limit: _safeLimit(limit),
    ).map(
      (rows) => LeaderboardSnapshot(
        scope: LeaderboardScope.daily,
        periodKey: DailyChallengeService.dateKeyFor(day),
        availability: LeaderboardAvailability.available,
        entries: _fromDaily(rows),
        serverValidated: true,
      ),
    );
  }

  /// Trusted Global Elo projection.
  ///
  /// globalLeaderboard is server-write-only. Client-written users/{uid}/elo is
  /// never used as a ranking source.
  static Future<LeaderboardSnapshot> fetchGlobal({
    int limit = defaultLimit,
  }) async {
    final safeLimit = _safeLimit(limit);
    final query = _db
        .ref('globalLeaderboard')
        .orderByChild('elo')
        .limitToLast(safeLimit);
    final snap = await query.get();

    return LeaderboardSnapshot(
      scope: LeaderboardScope.global,
      periodKey: 'all-time',
      availability: LeaderboardAvailability.available,
      entries: _decodeGlobal(snap.value, limit: safeLimit),
      serverValidated: true,
    );
  }

  static Stream<LeaderboardSnapshot> watchGlobal({
    int limit = defaultLimit,
  }) {
    final safeLimit = _safeLimit(limit);
    final query = _db
        .ref('globalLeaderboard')
        .orderByChild('elo')
        .limitToLast(safeLimit);

    return query.onValue.map(
      (event) => LeaderboardSnapshot(
        scope: LeaderboardScope.global,
        periodKey: 'all-time',
        availability: LeaderboardAvailability.available,
        entries: _decodeGlobal(
          event.snapshot.value,
          limit: safeLimit,
        ),
        serverValidated: true,
      ),
    );
  }

  /// Trusted weekly aggregate of server-validated Daily scores.
  ///
  /// Each user's best accepted score for each day is counted once. The
  /// backend maintains weeklyLeaderboard; clients can only read it.
  static Future<LeaderboardSnapshot> fetchWeekly({
    String? weekKey,
    int limit = defaultLimit,
  }) async {
    final safeLimit = _safeLimit(limit);
    final periodKey = LeaderboardPeriodKeys.normalizeWeekKey(weekKey);
    final query = _db
        .ref('weeklyLeaderboard/$periodKey')
        .orderByChild('score')
        .limitToLast(safeLimit);
    final snap = await query.get();

    return LeaderboardSnapshot(
      scope: LeaderboardScope.weekly,
      periodKey: periodKey,
      availability: LeaderboardAvailability.available,
      entries: _decodeWeekly(snap.value, limit: safeLimit),
      serverValidated: true,
    );
  }

  static Stream<LeaderboardSnapshot> watchWeekly({
    String? weekKey,
    int limit = defaultLimit,
  }) {
    final safeLimit = _safeLimit(limit);
    final periodKey = LeaderboardPeriodKeys.normalizeWeekKey(weekKey);
    final query = _db
        .ref('weeklyLeaderboard/$periodKey')
        .orderByChild('score')
        .limitToLast(safeLimit);

    return query.onValue.map(
      (event) => LeaderboardSnapshot(
        scope: LeaderboardScope.weekly,
        periodKey: periodKey,
        availability: LeaderboardAvailability.available,
        entries: _decodeWeekly(
          event.snapshot.value,
          limit: safeLimit,
        ),
        serverValidated: true,
      ),
    );
  }

  static List<LeaderboardEntry> _decodeWeekly(
    Object? value, {
    required int limit,
  }) {
    if (value is! Map) return const [];

    final rows = <LeaderboardEntry>[];

    for (final rawEntry in value.entries) {
      if (rawEntry.value is! Map) continue;

      final data =
          Map<String, dynamic>.from(rawEntry.value as Map);

      if (data['serverValidated'] != true ||
          (int.tryParse('${data['validationVersion'] ?? 0}') ?? 0) < 1) {
        continue;
      }

      rows.add(
        LeaderboardEntry(
          rank: 0,
          uid: rawEntry.key.toString(),
          displayName: data['displayName']?.toString() ?? 'Oyuncu',
          normalizedName: data['normalizedName']?.toString(),
          avatarId: data['avatarId']?.toString(),
          value: int.tryParse('${data['score'] ?? 0}') ?? 0,
          daysPlayed:
              int.tryParse('${data['daysPlayed'] ?? 0}') ?? 0,
          bestDailyScore:
              int.tryParse('${data['bestDailyScore'] ?? 0}') ?? 0,
        ),
      );
    }

    rows.sort((a, b) {
      if (b.value != a.value) return b.value.compareTo(a.value);

      final aDays = a.daysPlayed ?? 0;
      final bDays = b.daysPlayed ?? 0;
      if (bDays != aDays) return bDays.compareTo(aDays);

      final aBest = a.bestDailyScore ?? 0;
      final bBest = b.bestDailyScore ?? 0;
      if (bBest != aBest) return bBest.compareTo(aBest);

      return a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
    });

    final ranked = <LeaderboardEntry>[];
    final take = rows.take(limit).toList(growable: false);

    for (var i = 0; i < take.length; i++) {
      final row = take[i];
      ranked.add(
        LeaderboardEntry(
          rank: i + 1,
          uid: row.uid,
          displayName: row.displayName,
          normalizedName: row.normalizedName,
          avatarId: row.avatarId,
          value: row.value,
          daysPlayed: row.daysPlayed,
          bestDailyScore: row.bestDailyScore,
        ),
      );
    }

    return List<LeaderboardEntry>.unmodifiable(ranked);
  }

  static List<LeaderboardEntry> _decodeGlobal(
    Object? value, {
    required int limit,
  }) {
    if (value is! Map) return const [];

    final rows = <LeaderboardEntry>[];

    for (final rawEntry in value.entries) {
      if (rawEntry.value is! Map) continue;

      final data =
          Map<String, dynamic>.from(rawEntry.value as Map);

      if (data['serverValidated'] != true ||
          (int.tryParse('${data['validationVersion'] ?? 0}') ?? 0) < 1) {
        continue;
      }

      rows.add(
        LeaderboardEntry(
          rank: 0,
          uid: rawEntry.key.toString(),
          displayName: data['displayName']?.toString() ?? 'Oyuncu',
          normalizedName: data['normalizedName']?.toString(),
          avatarId: data['avatarId']?.toString(),
          value: int.tryParse('${data['elo'] ?? 1000}') ?? 1000,
        ),
      );
    }

    rows.sort((a, b) {
      if (b.value != a.value) return b.value.compareTo(a.value);
      return a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
    });

    final ranked = <LeaderboardEntry>[];
    final take = rows.take(limit).toList(growable: false);

    for (var i = 0; i < take.length; i++) {
      final row = take[i];
      ranked.add(
        LeaderboardEntry(
          rank: i + 1,
          uid: row.uid,
          displayName: row.displayName,
          normalizedName: row.normalizedName,
          avatarId: row.avatarId,
          value: row.value,
        ),
      );
    }

    return List<LeaderboardEntry>.unmodifiable(ranked);
  }

  static List<LeaderboardEntry> _fromDaily(
    List<DailyLeaderboardEntry> rows,
  ) {
    return List<LeaderboardEntry>.unmodifiable(
      rows.indexed.map((indexed) {
        final rank = indexed.$1 + 1;
        final row = indexed.$2;

        return LeaderboardEntry(
          rank: rank,
          uid: row.uid,
          displayName: row.displayName,
          normalizedName: row.normalizedName,
          avatarId: row.avatarId,
          value: row.score,
          successRate: row.successRate,
          secondsLeft: row.secondsLeft,
          streak: row.streak,
          finishedAtMs: row.finishedAtMs,
        );
      }),
    );
  }
}
