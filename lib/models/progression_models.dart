class ProgressionLevel {
  final int level;
  final int currentXp;
  final int nextLevelXp;
  final int cap;

  const ProgressionLevel({
    required this.level,
    required this.currentXp,
    required this.nextLevelXp,
    required this.cap,
  });

  double get ratio {
    if (nextLevelXp <= 0) return 1;
    return (currentXp / nextLevelXp).clamp(0, 1).toDouble();
  }

  factory ProgressionLevel.fromMap(Map<String, dynamic> data) {
    return ProgressionLevel(
      level: _progressionInt(data['level'], fallback: 1),
      currentXp: _progressionInt(data['currentXp']),
      nextLevelXp: _progressionInt(data['nextLevelXp']),
      cap: _progressionInt(data['cap'], fallback: 100),
    );
  }
}

class ProgressionSeason {
  final String id;
  final String title;
  final String startsOn;
  final String endsOn;
  final int xp;
  final int level;
  final int currentXp;
  final int nextLevelXp;
  final int levelCap;

  const ProgressionSeason({
    required this.id,
    required this.title,
    required this.startsOn,
    required this.endsOn,
    required this.xp,
    required this.level,
    required this.currentXp,
    required this.nextLevelXp,
    required this.levelCap,
  });

  double get ratio {
    if (nextLevelXp <= 0) return 1;
    return (currentXp / nextLevelXp).clamp(0, 1).toDouble();
  }

  factory ProgressionSeason.fromMap(Map<String, dynamic> data) {
    return ProgressionSeason(
      id: data['id']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      startsOn: data['startsOn']?.toString() ?? '',
      endsOn: data['endsOn']?.toString() ?? '',
      xp: _progressionInt(data['xp']),
      level: _progressionInt(data['level'], fallback: 1),
      currentXp: _progressionInt(data['currentXp']),
      nextLevelXp: _progressionInt(data['nextLevelXp']),
      levelCap: _progressionInt(data['levelCap'], fallback: 50),
    );
  }
}

class DailyRewardStatus {
  final String dateKey;
  final bool canClaim;
  final int currentStreak;
  final int bestStreak;
  final int nextStreak;
  final int nextDayIndex;
  final int baseCoins;
  final int multiplier;
  final int rewardCoins;
  final int xpReward;
  final bool streakProtectionAvailable;
  final bool wouldUseStreakProtection;
  final int? lastClaimedAtMs;

  const DailyRewardStatus({
    required this.dateKey,
    required this.canClaim,
    required this.currentStreak,
    required this.bestStreak,
    required this.nextStreak,
    required this.nextDayIndex,
    required this.baseCoins,
    required this.multiplier,
    required this.rewardCoins,
    required this.xpReward,
    required this.streakProtectionAvailable,
    required this.wouldUseStreakProtection,
    this.lastClaimedAtMs,
  });

  factory DailyRewardStatus.fromMap(Map<String, dynamic> data) {
    return DailyRewardStatus(
      dateKey: data['dateKey']?.toString() ?? '',
      canClaim: data['canClaim'] == true,
      currentStreak: _progressionInt(data['currentStreak']),
      bestStreak: _progressionInt(data['bestStreak']),
      nextStreak: _progressionInt(data['nextStreak'], fallback: 1),
      nextDayIndex: _progressionInt(data['nextDayIndex'], fallback: 1),
      baseCoins: _progressionInt(data['baseCoins']),
      multiplier: _progressionInt(data['multiplier'], fallback: 1),
      rewardCoins: _progressionInt(data['rewardCoins']),
      xpReward: _progressionInt(data['xpReward']),
      streakProtectionAvailable: data['streakProtectionAvailable'] == true,
      wouldUseStreakProtection: data['wouldUseStreakProtection'] == true,
      lastClaimedAtMs: _progressionNullableInt(data['lastClaimedAt']),
    );
  }
}

class ProgressionProfile {
  final int lifetimeXp;
  final ProgressionLevel level;
  final ProgressionSeason season;
  final DailyRewardStatus dailyReward;
  final int? updatedAtMs;
  final int version;

  const ProgressionProfile({
    required this.lifetimeXp,
    required this.level,
    required this.season,
    required this.dailyReward,
    this.updatedAtMs,
    this.version = 1,
  });

  factory ProgressionProfile.fromMap(Map<String, dynamic> data) {
    final rawLevel = data['level'];
    final rawSeason = data['season'];
    final rawDaily = data['dailyReward'];

    return ProgressionProfile(
      lifetimeXp: _progressionInt(data['lifetimeXp']),
      level: rawLevel is Map
          ? ProgressionLevel.fromMap(Map<String, dynamic>.from(rawLevel))
          : const ProgressionLevel(
              level: 1,
              currentXp: 0,
              nextLevelXp: 100,
              cap: 100,
            ),
      season: rawSeason is Map
          ? ProgressionSeason.fromMap(Map<String, dynamic>.from(rawSeason))
          : const ProgressionSeason(
              id: '',
              title: '',
              startsOn: '',
              endsOn: '',
              xp: 0,
              level: 1,
              currentXp: 0,
              nextLevelXp: 100,
              levelCap: 50,
            ),
      dailyReward: rawDaily is Map
          ? DailyRewardStatus.fromMap(Map<String, dynamic>.from(rawDaily))
          : const DailyRewardStatus(
              dateKey: '',
              canClaim: false,
              currentStreak: 0,
              bestStreak: 0,
              nextStreak: 1,
              nextDayIndex: 1,
              baseCoins: 20,
              multiplier: 1,
              rewardCoins: 20,
              xpReward: 25,
              streakProtectionAvailable: false,
              wouldUseStreakProtection: false,
            ),
      updatedAtMs: _progressionNullableInt(data['updatedAt']),
      version: _progressionInt(data['version'], fallback: 1),
    );
  }
}

class DailyRewardClaimResult {
  final bool granted;
  final bool alreadyClaimed;
  final int amount;
  final int xp;
  final int dayIndex;
  final int multiplier;
  final bool streakProtected;
  final int walletCoins;
  final ProgressionProfile profile;

  const DailyRewardClaimResult({
    required this.granted,
    required this.alreadyClaimed,
    required this.amount,
    required this.xp,
    required this.dayIndex,
    required this.multiplier,
    required this.streakProtected,
    required this.walletCoins,
    required this.profile,
  });
}

int _progressionInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _progressionNullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
