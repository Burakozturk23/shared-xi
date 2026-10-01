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
  });
  final String id, endsOn;
  final int sp, todaySp, level, daysLeft, maxLevel, stepSp, dailyCap;
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
    pro: m['pro'] == true,
    tiers: (m['tiers'] as List)
        .map((r) => SeasonTier.fromMap(Map<String, dynamic>.from(r)))
        .toList(),
  );
}
