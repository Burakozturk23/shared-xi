class SeasonTier {
  const SeasonTier({
    required this.step,
    required this.requiredSp,
    required this.unlocked,
    required this.freeCoins,
    required this.proCoins,
    required this.freeClaimed,
    required this.proClaimed,
  });
  final int step, requiredSp, freeCoins, proCoins;
  final bool unlocked, freeClaimed, proClaimed;
  factory SeasonTier.fromMap(Map<String, dynamic> m) => SeasonTier(
    step: (m['step'] as num).toInt(),
    requiredSp: (m['requiredSp'] as num).toInt(),
    unlocked: m['unlocked'] == true,
    freeCoins: (m['freeCoins'] as num).toInt(),
    proCoins: (m['proCoins'] as num).toInt(),
    freeClaimed: m['freeClaimed'] == true,
    proClaimed: m['proClaimed'] == true,
  );
}

/// Last month's unlocked rewards that are still claimable (grace days).
class SeasonPrevious {
  const SeasonPrevious({
    required this.id,
    required this.level,
    required this.claimDaysLeft,
    required this.tiers,
  });
  final String id;
  final int level, claimDaysLeft;
  final List<SeasonTier> tiers;
  factory SeasonPrevious.fromMap(Map<String, dynamic> m) => SeasonPrevious(
    id: m['id'] as String,
    level: (m['level'] as num).toInt(),
    claimDaysLeft: (m['claimDaysLeft'] as num).toInt(),
    tiers: (m['tiers'] as List)
        .map((r) => SeasonTier.fromMap(Map<String, dynamic>.from(r)))
        .toList(),
  );
}

class SeasonPass {
  const SeasonPass({
    required this.id,
    required this.endsOn,
    required this.sp,
    required this.todaySp,
    required this.level,
    required this.daysLeft,
    required this.pro,
    required this.tiers,
    this.maxLevel = 20,
    this.stepSp = 100,
    this.dailyCap = 150,
    this.graceDays = 3,
    this.previous,
  });
  final String id, endsOn;
  final int sp, todaySp, level, daysLeft, maxLevel, stepSp, dailyCap, graceDays;
  final SeasonPrevious? previous;

  /// Days in this month, from the end date (YYYY-MM-DD).
  int get monthDays => int.tryParse(endsOn.split('-').last) ?? 30;

  /// Tier reached at month end if today's average pace holds.
  int get projectedLevel {
    final day = (monthDays - daysLeft + 1).clamp(1, monthDays);
    return (sp / day * monthDays / stepSp).floor().clamp(0, maxLevel);
  }

  /// SP a day still needed to finish the route by month end.
  int get neededPerDay => daysLeft <= 0
      ? 0
      : ((maxLevel * stepSp - sp).clamp(0, maxLevel * stepSp) / daysLeft)
            .ceil();
  final bool pro;
  final List<SeasonTier> tiers;
  int get ready => tiers.fold(
    0,
    (n, t) =>
        n +
        (t.unlocked && !t.freeClaimed ? 1 : 0) +
        (t.unlocked && pro && !t.proClaimed ? 1 : 0),
  );
  double get ratio => level >= maxLevel ? 1 : (sp % stepSp) / stepSp;
  factory SeasonPass.fromMap(Map<String, dynamic> m) => SeasonPass(
    id: m['id'] as String,
    endsOn: m['endsOn'] as String,
    sp: (m['sp'] as num).toInt(),
    todaySp: (m['todaySp'] as num).toInt(),
    level: (m['level'] as num).toInt(),
    daysLeft: (m['daysLeft'] as num).toInt(),
    maxLevel: (m['maxLevel'] as num).toInt(),
    stepSp: (m['stepSp'] as num).toInt(),
    dailyCap: (m['dailyCap'] as num).toInt(),
    graceDays: (m['graceDays'] as num?)?.toInt() ?? 3,
    previous: m['previous'] is Map
        ? SeasonPrevious.fromMap(Map<String, dynamic>.from(m['previous']))
        : null,
    pro: m['pro'] == true,
    tiers: (m['tiers'] as List)
        .map((r) => SeasonTier.fromMap(Map<String, dynamic>.from(r)))
        .toList(),
  );
}
