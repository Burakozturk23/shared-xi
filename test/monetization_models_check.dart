// Dependency-free contract check: dart --enable-asserts test/monetization_models_check.dart
import '../lib/models/progression_models.dart';
import '../lib/models/mission_models.dart';
import '../lib/models/economy_models.dart';
import '../lib/models/achievement_catalog.dart';
import '../lib/models/squad_challenge.dart';

void main() {
  final daily = DailyRewardStatus.fromMap({
    'enabled': true,
    'canClaim': true,
    'rewardCoins': 40,
    'xpReward': 25,
    'scheduleCoins': [20, 24, 30, 36, 40, 50, 60],
  });
  assert(daily.rewardCoins == 40 && daily.xpReward == 25);
  assert(daily.scheduleCoins[4] == 40); // Already multiplied by the server.
  assert(DailyRewardStatus.fromMap({}).scheduleCoins.isEmpty);
  assert(!DailyRewardStatus.fromMap({'enabled': false}).enabled);
  assert(ProgressionProfile.fromMap({}).dailyReward.rewardCoins == 0);
  assert(!ProgressionProfile.fromMap({}).dailyReward.canClaim);
  final receipt = EconomyLedgerEntry.fromMap('purchase__avatar', {
    'amount': -180,
    'balanceBefore': 500,
    'balanceAfter': 320,
    'idempotencyKey': 'purchase__avatar',
    'economyConfigId': 'economy-test',
  });
  assert(receipt.balanceBefore == 500 && receipt.balanceAfter == 320);
  assert(receipt.idempotencyKey == 'purchase__avatar');
  final legacy = EconomyLedgerEntry.fromMap('old', {
    'amount': 20,
    'balanceAfter': 50,
  });
  assert(legacy.balanceBefore == 30 && legacy.economyConfigId == 'legacy');
  final legacySpend = EconomyLedgerEntry.fromMap('old-spend', {
    'amount': -20,
    'balanceAfter': 50,
  });
  assert(legacySpend.balanceBefore == 70);
  final original = AchievementCatalog.all.first;
  final priced = original.withCoinReward(35);
  assert(
    original.coinReward == 0 &&
        priced.coinReward == 35 &&
        priced.id == original.id,
  );
  final hub = SquadHub.fromJson({
    'catalogVersion': 'test',
    'day': '2026-09-20',
    'enabled': false,
    'extraPrice': 15,
    'freeRemaining': 0,
    'missions': [],
  });
  assert(!hub.enabled && hub.extraPrice == 15);
  assert(MissionProfile.fromMap({'dailyClaimLimit': 2}).dailyClaimLimit == 2);
  assert(MissionItem.fromMap({'enabled': false}).enabled == false);
  assert(MissionItem.fromMap({'limitReached': true}).limitReached);
  print('Economy model checks passed.');
}
