enum AchievementCategory {
  ranked,
  mastery,
  daily,
  social,
}

enum AchievementTier {
  bronze,
  silver,
  gold,
  platinum,
}

class AchievementDefinition {
  final String id;
  final String title;
  final String description;
  final AchievementCategory category;
  final AchievementTier tier;
  final String signal;
  final int target;
  final int coinReward;
  final String iconKey;
  final bool hidden;

  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.tier,
    required this.signal,
    required this.target,
    required this.coinReward,
    required this.iconKey,
    this.hidden = false,
  });
}

class AchievementProgress {
  final String id;
  final int value;
  final int rawValue;
  final int target;
  final bool unlocked;
  final int? unlockedAtMs;
  final int? updatedAtMs;
  final int catalogVersion;

  const AchievementProgress({
    required this.id,
    required this.value,
    required this.rawValue,
    required this.target,
    required this.unlocked,
    this.unlockedAtMs,
    this.updatedAtMs,
    this.catalogVersion = 1,
  });

  double get ratio {
    if (target <= 0) return unlocked ? 1 : 0;
    return (value / target).clamp(0, 1).toDouble();
  }

  factory AchievementProgress.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return AchievementProgress(
      id: id,
      value: _achievementInt(data['value']),
      rawValue: _achievementInt(data['rawValue']),
      target: _achievementInt(data['target']),
      unlocked: data['unlocked'] == true,
      unlockedAtMs: _achievementNullableInt(data['unlockedAt']),
      updatedAtMs: _achievementNullableInt(data['updatedAt']),
      catalogVersion: _achievementInt(data['catalogVersion'], fallback: 1),
    );
  }
}

class UserAchievement {
  final String id;
  final int unlockedAtMs;
  final String source;
  final int catalogVersion;

  const UserAchievement({
    required this.id,
    required this.unlockedAtMs,
    required this.source,
    this.catalogVersion = 1,
  });

  factory UserAchievement.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return UserAchievement(
      id: id,
      unlockedAtMs: _achievementInt(data['unlockedAt']),
      source: data['source']?.toString() ?? 'server',
      catalogVersion: _achievementInt(data['catalogVersion'], fallback: 1),
    );
  }
}

int _achievementInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _achievementNullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
