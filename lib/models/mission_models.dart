enum MissionKind { daily, weekly, general }

class MissionItem {
  final String id;
  final String routeKey;
  final String periodKey;
  final String modeId;
  final int rewardSp;
  final bool unavailable;
  final MissionKind kind;
  final String title;
  final String description;
  final int progress;
  final int rawProgress;
  final int target;
  final int rewardCoins;
  final bool enabled;
  final bool limitReached;
  final bool claimable;
  final bool claimed;
  final int? claimedAtMs;
  final String chainId;
  final int stage;
  final int stageCount;

  const MissionItem({
    this.routeKey = '',
    this.periodKey = '',
    this.modeId = '',
    this.rewardSp = 0,
    this.unavailable = false,
    this.enabled = true,
    this.limitReached = false,
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.progress,
    required this.rawProgress,
    required this.target,
    required this.rewardCoins,
    required this.claimable,
    required this.claimed,
    this.claimedAtMs,
    required this.chainId,
    required this.stage,
    required this.stageCount,
  });

  double get ratio {
    if (target <= 0) return 1;
    return (progress / target).clamp(0, 1).toDouble();
  }

  factory MissionItem.fromMap(Map<String, dynamic> data) {
    return MissionItem(
      routeKey: data['routeKey']?.toString() ?? '',
      periodKey: data['periodKey']?.toString() ?? '',
      modeId: data['modeId']?.toString() ?? '',
      rewardSp: _missionInt(data['rewardSp']),
      unavailable: data['unavailable'] == true,
      enabled: data['enabled'] != false,
      limitReached: data['limitReached'] == true,
      id: data['id']?.toString() ?? '',
      kind: data['kind']?.toString() == 'daily'
          ? MissionKind.daily
          : data['kind']?.toString() == 'weekly' ? MissionKind.weekly : MissionKind.general,
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      progress: _missionInt(data['progress']),
      rawProgress: _missionInt(data['rawProgress']),
      target: _missionInt(data['target']),
      rewardCoins: _missionInt(data['rewardCoins']),
      claimable: data['claimable'] == true,
      claimed: data['claimed'] == true,
      claimedAtMs: _missionNullableInt(data['claimedAt']),
      chainId: data['chainId']?.toString() ?? '',
      stage: _missionInt(data['stage']),
      stageCount: _missionInt(data['stageCount']),
    );
  }
}

class MissionProfile {
  final String dateKey;
  final String weekKey, availabilityNotice;
  final List<MissionItem> weekly;
  final int weeklyClaimLimit, weeklyCompletedCount;
  final bool weeklyEnabled;
  final List<MissionItem> daily;
  final List<MissionItem> general;
  final int dailyClaimLimit;
  final int dailyCompletedCount;
  final int generalCompletedCount;
  final int? updatedAtMs;
  final int version;

  const MissionProfile({
    this.weekKey = '', this.availabilityNotice = '',
    this.weekly = const [], this.weeklyClaimLimit = 2,
    this.weeklyCompletedCount = 0, this.weeklyEnabled = false,
    this.dailyClaimLimit = 3,
    required this.dateKey,
    required this.daily,
    required this.general,
    required this.dailyCompletedCount,
    required this.generalCompletedCount,
    this.updatedAtMs,
    this.version = 1,
  });

  factory MissionProfile.fromMap(Map<String, dynamic> data) {
    return MissionProfile(
      weekKey: data['weekKey']?.toString() ?? '',
      availabilityNotice: data['availabilityNotice']?.toString() ?? '',
      weekly: _missionList(data['weekly']),
      weeklyClaimLimit: _missionInt(data['weeklyClaimLimit'], fallback: 2),
      weeklyCompletedCount: _missionInt(data['weeklyCompletedCount']),
      weeklyEnabled: data['weeklyEnabled'] == true,
      dailyClaimLimit: _missionInt(data['dailyClaimLimit'], fallback: 3),
      dateKey: data['dateKey']?.toString() ?? '',
      daily: _missionList(data['daily']),
      general: _missionList(data['general']),
      dailyCompletedCount: _missionInt(data['dailyCompletedCount']),
      generalCompletedCount: _missionInt(data['generalCompletedCount']),
      updatedAtMs: _missionNullableInt(data['updatedAt']),
      version: _missionInt(data['version'], fallback: 1),
    );
  }
}

class MissionClaimResult {
  final bool granted;
  final bool alreadyClaimed;
  final int amount;
  final int walletCoins;
  final String missionId;
  final String periodKey;
  final MissionProfile profile;

  const MissionClaimResult({
    required this.granted,
    required this.alreadyClaimed,
    required this.amount,
    required this.walletCoins,
    required this.missionId,
    required this.periodKey,
    required this.profile,
  });
}

List<MissionItem> _missionList(Object? raw) {
  if (raw is! List) return const <MissionItem>[];

  return raw
      .whereType<Map>()
      .map((item) => MissionItem.fromMap(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

int _missionInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _missionNullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
