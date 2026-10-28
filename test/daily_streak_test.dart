import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/controllers/home_resources_controller.dart';
import 'package:shared_xi/models/progression_models.dart';

DailyRewardStatus _status({
  required int current,
  required int next,
  bool enabled = true,
}) => DailyRewardStatus(
  enabled: enabled,
  dateKey: '2026-10-28',
  canClaim: true,
  currentStreak: current,
  bestStreak: current,
  nextStreak: next,
  nextDayIndex: 1,
  baseCoins: 0,
  multiplier: 1,
  rewardCoins: 0,
  xpReward: 0,
  streakProtectionAvailable: false,
  wouldUseStreakProtection: false,
);

void main() {
  test('activeStreak reports only a streak the next claim continues', () {
    expect(_status(current: 7, next: 8).activeStreak, 7);
    // A missed day resets the next claim to 1: the old count is stale.
    expect(_status(current: 7, next: 1).activeStreak, isNull);
    expect(_status(current: 0, next: 1).activeStreak, isNull);
    expect(_status(current: 7, next: 8, enabled: false).activeStreak, isNull);
  });

  test('controller loads the streak for linked accounts only', () async {
    var calls = 0;
    HomeResourcesController make(bool linked, Future<int?> Function() read) =>
        HomeResourcesController(
          prepare: () async {},
          accounts: () => const Stream.empty(),
          currentAccount: () => (uid: 'u', linked: linked),
          readEnergy: () async => {},
          watchWallet: () => const Stream.empty(),
          readStreak: () {
            calls++;
            return read();
          },
        );

    final linked = make(true, () async => 7);
    addTearDown(linked.dispose);
    await linked.start();
    await pumpEventQueue();
    expect(linked.streak, 7);

    final guest = make(false, () async => 7);
    addTearDown(guest.dispose);
    calls = 0;
    await guest.start();
    await pumpEventQueue();
    expect(guest.streak, isNull);
    expect(calls, 0);

    // A failed read hides the badge instead of showing a zero.
    final failing = make(true, () async => throw StateError('offline'));
    addTearDown(failing.dispose);
    await failing.start();
    await pumpEventQueue();
    expect(failing.streak, isNull);
  });
}
