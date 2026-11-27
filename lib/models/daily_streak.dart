/// Shared play streak of the six daily games (server `getDailyStreak`).
/// A day counts once any one of them is completed, assisted runs included.
class DailyStreak {
  const DailyStreak({
    required this.streak,
    this.best = 0,
    this.playedToday = false,
    this.played = const [],
    this.total = 6,
    this.repairStreak = 0,
    this.nextMilestone = 7,
    this.rewardsEnabled = false,
  });

  factory DailyStreak.fromMap(Map<String, dynamic> map) {
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    final today = map['today'] is Map ? map['today'] as Map : const {};
    return DailyStreak(
      streak: n(map['streak']),
      best: n(map['best']),
      playedToday: map['playedToday'] == true,
      played: [
        for (final g in today['played'] as List? ?? const []) g.toString(),
      ],
      total: today['total'] == null ? 6 : n(today['total']),
      repairStreak: n(map['repairStreak']),
      nextMilestone: map['nextMilestone'] == null ? 7 : n(map['nextMilestone']),
      rewardsEnabled: map['rewardsEnabled'] == true,
    );
  }

  final int streak;
  final int best;
  final bool playedToday;

  /// Server game ids completed today, e.g. `daily_lingo`, `daily_question`.
  final List<String> played;
  final int total;

  /// Non-zero when one missed day can still be saved with a verified ad.
  final int repairStreak;
  final int nextMilestone;

  /// Milestone and six-of-six rewards are paid only while this is on.
  final bool rewardsEnabled;

  bool get full => played.length >= total;
}
