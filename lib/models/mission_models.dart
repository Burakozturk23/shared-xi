enum MissionKind { daily, general }

class MissionItem {
  final String id;
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
      enabled: data['enabled'] != false,
      limitReached: data['limitReached'] == true,
      id: data['id']?.toString() ?? '',
      kind: data['kind']?.toString() == 'daily'
          ? MissionKind.daily
          : MissionKind.general,
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
  final List<MissionItem> daily;
  final List<MissionItem> general;
  final int dailyClaimLimit;
  final int dailyCompletedCount;
  final int generalCompletedCount;
  final int? updatedAtMs;
  final int version;

  const MissionProfile({
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
