int _number(dynamic value) => value is num ? value.toInt() : 0;
Map<String, dynamic> rewardMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

class RewardedAdTicket {
  const RewardedAdTicket({
    required this.id,
    required this.amount,
    required this.status,
    required this.unitId,
    required this.userId,
  });
  final String id, status, unitId, userId;
  final int amount;
  bool get credited => status == 'credited';
  bool get verified => status == 'verified';
  factory RewardedAdTicket.fromMap(
    Map<String, dynamic> value, {
    String userId = '',
  }) => RewardedAdTicket(
    id: value['id']?.toString() ?? '',
    amount: _number(value['amount']),
    status: value['status']?.toString() ?? '',
    unitId: value['unitId']?.toString() ?? '',
    userId: userId,
  );
}

class RewardedAdStatus {
  const RewardedAdStatus({
    required this.enabled,
    required this.pro,
    required this.testingOnly,
    required this.amount,
    required this.remaining,
    required this.dailyLimit,
    this.pendingCoins = 0,
    this.ticket,
  });
  final bool enabled, pro, testingOnly;
  final int amount, remaining, dailyLimit, pendingCoins;
  final RewardedAdTicket? ticket;
  factory RewardedAdStatus.fromMap(Map<String, dynamic> value) =>
      RewardedAdStatus(
        enabled: value['enabled'] == true,
        pro: value['pro'] == true,
        testingOnly: value['testingOnly'] == true,
        amount: _number(value['amount']),
        remaining: _number(value['remaining']),
        dailyLimit: _number(value['dailyLimit']),
        pendingCoins: _number(value['pendingCoins']),
        ticket: value['ticket'] is Map
            ? RewardedAdTicket.fromMap(rewardMap(value['ticket']))
            : null,
      );
}
