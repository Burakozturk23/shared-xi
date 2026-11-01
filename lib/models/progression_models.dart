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
  final bool enabled;
  final List<int> scheduleCoins;
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

  /// Faz 2: the support each loop day adds (null for coin-only days).
  final List<String?> scheduleSupports;

  /// The support the next (or today's claimed) day adds, or ''.
  final String rewardSupport;

  /// Everyone may cover one missed day once in seven days.
  final bool freeProtectionEnabled;

  /// Day (yyyy-MM-dd) the free cover is ready again, or '' when it is ready.
  final String freeProtectionReadyOn;

  const DailyRewardStatus({
    this.enabled = true,
    this.scheduleCoins = const <int>[],
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
    this.scheduleSupports = const <String?>[],
    this.rewardSupport = '',
    this.freeProtectionEnabled = false,
    this.freeProtectionReadyOn = '',
  });

  /// Support of a loop day (1-based), or null.
  String? supportOn(int day) => day >= 1 && day <= scheduleSupports.length
      ? scheduleSupports[day - 1]
      : null;

  /// The free cover is waiting for a missed day (not used in the last week).
  bool get freeProtectionReady =>
      freeProtectionEnabled &&
      (freeProtectionReadyOn.isEmpty ||
          freeProtectionReadyOn.compareTo(dateKey) <= 0);

  /// The streak the next claim continues, or null when there is none.
  /// [currentStreak] keeps the last claimed run; after a missed day the
  /// server resets [nextStreak] to 1, which marks that count as stale.
  int? get activeStreak =>
      enabled && currentStreak > 0 && nextStreak > 1 ? currentStreak : null;

  factory DailyRewardStatus.fromMap(Map<String, dynamic> data) {
    return DailyRewardStatus(
      enabled: data['enabled'] != false,
      scheduleCoins: data['scheduleCoins'] is List
          ? List<int>.unmodifiable(
              (data['scheduleCoins'] as List).map(_progressionInt),
            )
          : const <int>[],
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
      scheduleSupports: data['scheduleSupports'] is List
          ? List<String?>.unmodifiable(
              (data['scheduleSupports'] as List).map(
                (v) => v is String && v.isNotEmpty ? v : null,
              ),
            )
          : const <String?>[],
      rewardSupport: data['rewardSupport']?.toString() ?? '',
      freeProtectionEnabled: data['freeProtectionEnabled'] == true,
      freeProtectionReadyOn: data['freeProtectionReadyOn']?.toString() ?? '',
    );
  }
}

/// A support a check-in day or the all-missions bonus left in the bag.
class SupportReward {
  final String itemId;
  final bool granted;

  /// The bag was full (99); the support could not be added.
  final bool full;

  /// The all-missions bonus was already given twice this week.
  final bool weeklyLimit;

  /// Coins paid instead when the bag was full (half the store price).
  final int coins;

  const SupportReward({
    required this.itemId,
    this.granted = false,
    this.full = false,
    this.weeklyLimit = false,
    this.coins = 0,
  });

  static SupportReward? from(Object? raw) {
    if (raw is! Map || (raw['itemId']?.toString() ?? '').isEmpty) return null;
    return SupportReward(
      itemId: raw['itemId'].toString(),
      granted: raw['granted'] == true,
      full: raw['full'] == true,
      weeklyLimit: raw['weeklyLimit'] == true,
      coins: _progressionInt(raw['coins']),
    );
  }
}

/// Player-facing support names (Turkish, English).
const supportNames = <String, (String, String)>{
  'boost_basic': ('Temel bilgi', 'Basic hint'),
  'boost_strong': ('Güçlü bilgi', 'Strong hint'),
  'boost_eliminate': ('Tek seçenek ele', 'Remove an option'),
  'boost_connection': ('Bağlantı yardımı', 'Connection help'),
};

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
              baseCoins: 0,
              multiplier: 1,
              rewardCoins: 0,
              xpReward: 0,
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
  final SupportReward? support;

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
    this.support,
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
