enum LeaderboardScope { daily, weekly, global }

enum LeaderboardAvailability {
  available,
  pendingTrustedBackend,
}

class LeaderboardEntry {
  final int rank;
  final String uid;
  final String displayName;
  final String? normalizedName;
  final String? avatarId;

  /// Primary sortable value for the current board.
  ///
  /// Daily = server-validated score.
  /// Global = trusted Elo once Phase 16.3C is enabled.
  /// Weekly = trusted weekly points once Phase 16.3D is enabled.
  final int value;

  final double? successRate;
  final int? secondsLeft;
  final int? streak;
  final int? finishedAtMs;
  final int? daysPlayed;
  final int? bestDailyScore;

  const LeaderboardEntry({
    required this.rank,
    required this.uid,
    required this.displayName,
    required this.value,
    this.normalizedName,
    this.avatarId,
    this.successRate,
    this.secondsLeft,
    this.streak,
    this.finishedAtMs,
    this.daysPlayed,
    this.bestDailyScore,
  });
}

/// Canonical period keys shared by leaderboard reads and trusted aggregation.
abstract final class LeaderboardPeriodKeys {
  static String day(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String isoWeek(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    final thursday = day.add(Duration(days: 4 - day.weekday));
    final weekYear = thursday.year;

    final jan4 = DateTime.utc(weekYear, 1, 4);
    final week1Thursday = jan4.add(Duration(days: 4 - jan4.weekday));

    final week =
        1 + (thursday.difference(week1Thursday).inDays ~/ 7);
    return '$weekYear-W${week.toString().padLeft(2, '0')}';
  }

  static String normalizeWeekKey(String? value) {
    final trimmed = value?.trim() ?? '';
    if (RegExp(r'^\d{4}-W\d{2}$').hasMatch(trimmed)) {
      return trimmed;
    }
    return isoWeek(DateTime.now());
  }
}

class LeaderboardSnapshot {
  final LeaderboardScope scope;
  final String periodKey;
  final LeaderboardAvailability availability;
  final List<LeaderboardEntry> entries;

  /// True only when the ranking values are produced by a trusted backend.
  final bool serverValidated;

  /// Machine-readable reason when a board is intentionally unavailable.
  final String? unavailableReason;

  const LeaderboardSnapshot({
    required this.scope,
    required this.periodKey,
    required this.availability,
    required this.entries,
    required this.serverValidated,
    this.unavailableReason,
  });

  const LeaderboardSnapshot.pending({
    required this.scope,
    required this.periodKey,
    required this.unavailableReason,
  })  : availability = LeaderboardAvailability.pendingTrustedBackend,
        entries = const [],
        serverValidated = false;

  bool get isAvailable =>
      availability == LeaderboardAvailability.available;
}
