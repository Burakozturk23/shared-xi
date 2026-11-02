/// Which avatar pool a Pro step draws from and how many of it are still to get.
class SeasonAvatarPool {
  const SeasonAvatarPool({
    required this.step,
    required this.tier,
    required this.count,
  });
  final int step, tier, count;
}

/// Support names on the season lane (Turkish).
const seasonSupportNames = <String, String>{
  'boost_basic': 'Temel bilgi',
  'boost_strong': 'Güçlü bilgi',
  'boost_connection': 'Bağlantı',
  'boost_eliminate': 'Tek seçenek ele',
};

/// "2 Güçlü bilgi" / "1 Bağlantı + 1 Tek seçenek ele + 1 Temel bilgi".
String seasonSupportLine(Map<String, int> items) => [
  for (final e in items.entries)
    '${e.value} ${seasonSupportNames[e.key] ?? e.key}',
].join(' + ');

class SeasonTier {
  const SeasonTier({
    required this.step,
    required this.requiredSp,
    required this.unlocked,
    required this.freeCoins,
    required this.proCoins,
    required this.freeClaimed,
    required this.proClaimed,
    this.proAvatar = false,
    this.proRewardTitle = '',
    this.proAvatarTier = 0,
    this.proSupports = const {},
    this.proRewardSupports = const {},
  });

  /// Avatar steps: the price pool the avatar comes from (300 or 450).
  final int proAvatarTier;

  /// Support steps: items and counts this step gives instead of coins.
  final Map<String, int> proSupports;
  final int step, requiredSp, freeCoins, proCoins;
  final bool unlocked, freeClaimed, proClaimed;

  /// Faz 4: the Pro reward of this step is a random avatar, not coins.
  final bool proAvatar;

  /// What the avatar step gave, once claimed.
  final String proRewardTitle;
  factory SeasonTier.fromMap(Map<String, dynamic> m) => SeasonTier(
    step: (m['step'] as num).toInt(),
    requiredSp: (m['requiredSp'] as num).toInt(),
    unlocked: m['unlocked'] == true,
    freeCoins: (m['freeCoins'] as num).toInt(),
    proCoins: (m['proCoins'] as num).toInt(),
    freeClaimed: m['freeClaimed'] == true,
    proClaimed: m['proClaimed'] == true,
    proAvatar: m['proAvatar'] == true,
    proAvatarTier: (m['proAvatarTier'] as num?)?.toInt() ?? 0,
    proSupports: m['proSupports'] is Map
        ? {
            for (final e in (m['proSupports'] as Map).entries)
              e.key.toString(): (e.value as num).toInt(),
          }
        : const {},
    proRewardTitle: m['proReward'] is Map
        ? ((m['proReward'] as Map)['title']?.toString() ?? '')
        : '',
    proRewardSupports:
        m['proReward'] is Map && (m['proReward'] as Map)['supports'] is Map
        ? {
            for (final e
                in ((m['proReward'] as Map)['supports'] as Map).entries)
              e.key.toString(): (e.value as num).toInt(),
          }
        : const {},
  );

  /// What a support step gave, once claimed.
  final Map<String, int> proRewardSupports;

  bool get supportStep =>
      proSupports.isNotEmpty || proRewardSupports.isNotEmpty;

  bool get avatarStep => proAvatar || proRewardTitle.isNotEmpty;
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
    this.avatarSteps = const [],
    this.avatarPools = const [],
    this.supportSteps = const [],
    this.proTotal = 1040,
  });

  /// Pro steps that give a random avatar (empty while the switch is off).
  final List<int> avatarSteps;

  /// The pool each avatar step draws from (step 10: 300, step 20: 450).
  final List<SeasonAvatarPool> avatarPools;

  /// Pro steps that give supports instead of coins (5 and 15).
  final List<int> supportSteps;

  /// Coins on the Pro lane (640 with the final lane, 1040 before).
  final int proTotal;

  /// "640 Link Coin + 5 destek + 2 avatar" for the final lane, else coins only.
  String get proLaneSummary {
    final supports = tiers
        .where(
          (t) => t.proSupports.isNotEmpty || t.proRewardSupports.isNotEmpty,
        )
        .fold<int>(
          0,
          (n, t) =>
              n +
              (t.proSupports.isNotEmpty ? t.proSupports : t.proRewardSupports)
                  .values
                  .fold<int>(0, (a, b) => a + b),
        );
    return avatarSteps.isEmpty
        ? '$proTotal Link Coin'
        : '$proTotal Link Coin + $supports destek + ${avatarSteps.length} avatar';
  }

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
    avatarSteps: m['avatarSteps'] is List
        ? [for (final v in m['avatarSteps'] as List) (v as num).toInt()]
        : const [],
    avatarPools: m['avatarPools'] is List
        ? [
            for (final p in (m['avatarPools'] as List).whereType<Map>())
              SeasonAvatarPool(
                step: (p['step'] as num).toInt(),
                tier: (p['tier'] as num).toInt(),
                count: (p['count'] as num).toInt(),
              ),
          ]
        : const [],
    supportSteps: m['supportSteps'] is List
        ? [for (final v in m['supportSteps'] as List) (v as num).toInt()]
        : const [],
    proTotal: (m['proTotal'] as num?)?.toInt() ?? 1040,
    tiers: (m['tiers'] as List)
        .map((r) => SeasonTier.fromMap(Map<String, dynamic>.from(r)))
        .toList(),
  );
}
