import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/app/game_catalog.dart';
import 'package:shared_xi/models/mission_models.dart';
import 'package:shared_xi/models/progression_models.dart';
import 'package:shared_xi/services/experience/progress_gateway.dart';
import 'package:shared_xi/widgets/daily_rewards_sheet.dart';

ProgressionProfile progressionWith({required bool canClaim}) =>
    ProgressionProfile.fromMap({
      'dailyReward': {
        'dateKey': '2026-11-01',
        'canClaim': canClaim,
        'currentStreak': 4,
        'nextStreak': 5,
        'nextDayIndex': 5,
        'rewardCoins': 20,
        'xpReward': 25,
        'scheduleCoins': [10, 12, 15, 18, 20, 25, 30],
      },
    });

Map<String, dynamic> mission(
  String id,
  String slot, {
  int progress = 0,
  bool claimed = false,
  bool bonus = false,
  String routeKey = 'matching',
}) => {
  'id': id,
  'kind': 'daily',
  'slot': slot,
  'bonus': bonus,
  'title': bonus ? 'Tüm Görevler Bonusu' : 'Görev $id',
  'progress': progress,
  'target': bonus ? 3 : 1,
  'rewardCoins': bonus ? 40 : 15,
  'rewardXp': bonus ? 40 : 15,
  'rewardSp': bonus ? 0 : 30,
  'enabled': true,
  'claimable': bonus ? progress >= 3 : progress >= 1,
  'claimed': claimed,
  'routeKey': routeKey,
  'periodKey': '2026-11-01',
};

class SheetGateway extends ProgressGateway {
  SheetGateway({this.canClaim = true, this.ready = true});
  bool canClaim, ready;
  int dailyClaims = 0, loads = 0;
  final claimed = <String>{};
  @override
  bool get connected => true;
  MissionProfile _missions() => MissionProfile.fromMap({
    'dateKey': '2026-11-01',
    'daily': [
      mission(
        'daily_v3_slot_1',
        'knowledge',
        progress: ready ? 1 : 0,
        claimed: claimed.contains('daily_v3_slot_1'),
      ),
      mission('daily_v3_slot_2', 'rivalry', routeKey: 'online_mode'),
      mission('daily_v3_slot_3', 'discovery', routeKey: 'solo_catalog'),
      mission(
        'daily_bonus',
        '',
        bonus: true,
        progress: claimed.length,
        routeKey: '',
      ),
    ],
  });
  @override
  Future<ProgressionProfile> progression() async {
    loads++;
    return progression2();
  }

  ProgressionProfile progression2() => progressionWith(canClaim: canClaim);
  @override
  Future<MissionProfile> missions() async => _missions();
  @override
  Future<DailyRewardClaimResult> claimDaily() async {
    dailyClaims++;
    canClaim = false;
    return DailyRewardClaimResult(
      granted: true,
      alreadyClaimed: false,
      amount: 20,
      xp: 25,
      dayIndex: 5,
      multiplier: 1,
      streakProtected: false,
      walletCoins: 120,
      profile: progression2(),
    );
  }

  @override
  Future<MissionClaimResult> claimMission(
    String id, {
    String periodKey = '',
  }) async {
    claimed.add(id);
    return MissionClaimResult(
      granted: true,
      alreadyClaimed: false,
      amount: 15,
      walletCoins: 135,
      missionId: id,
      periodKey: periodKey,
      profile: _missions(),
    );
  }
}

class Host extends StatelessWidget {
  const Host({super.key, required this.gateway});
  final ProgressGateway gateway;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: FilledButton(
          onPressed: () =>
              DailyRewardsSheet.maybeShow(context, gateway: gateway, uid: 'u1'),
          child: const Text('aç'),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'sheet claims the check-in and a mission, and shows slots and bonus',
    (t) async {
      final g = SheetGateway();
      await t.pumpWidget(MaterialApp(home: Host(gateway: g)));
      await t.tap(find.text('aç'));
      await t.pumpAndSettle();
      expect(find.text('Günlük Ödüller'), findsOneWidget);
      expect(find.text('4 günlük seri · 5. günü kaçırma'), findsOneWidget);
      await t.tap(find.text('Bugünkü Ödülü Al · +20 Link Coin'));
      await t.pumpAndSettle();
      expect(g.dailyClaims, 1);
      expect(find.text('Bugünün ödülü alındı'), findsOneWidget);
      await t.tap(find.text('Görevler'));
      await t.pumpAndSettle();
      expect(find.text('BİLGİ'), findsOneWidget);
      expect(find.text('REKABET'), findsOneWidget);
      await t.tap(find.text('Al'));
      await t.pumpAndSettle();
      expect(g.claimed, {'daily_v3_slot_1'});
      expect(find.text('Alındı'), findsOneWidget);
      expect(find.text('Git'), findsWidgets);
      final bonus = find.text('Tüm Görevler Bonusu');
      await t.scrollUntilVisible(
        bonus,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(bonus, findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('sheet shows once a day and stays away when nothing is ready', (
    t,
  ) async {
    final g = SheetGateway();
    await t.pumpWidget(MaterialApp(home: Host(gateway: g)));
    await t.tap(find.text('aç'));
    await t.pumpAndSettle();
    expect(find.text('Günlük Ödüller'), findsOneWidget);
    Navigator.of(t.element(find.text('Günlük Ödüller'))).pop();
    await t.pumpAndSettle();
    await t.tap(find.text('aç'));
    await t.pumpAndSettle();
    expect(find.text('Günlük Ödüller'), findsNothing);

    SharedPreferences.setMockInitialValues({});
    final idle = SheetGateway(canClaim: false, ready: false);
    await t.pumpWidget(MaterialApp(home: Host(gateway: idle)));
    await t.tap(find.text('aç'));
    await t.pumpAndSettle();
    expect(find.text('Günlük Ödüller'), findsNothing);
    expect(idle.loads, 1);
  });

  testWidgets('Faz 2: loop supports, cover note, tomorrow line and full bag', (
    t,
  ) async {
    ProgressionProfile day({required bool canClaim}) =>
        ProgressionProfile.fromMap({
          'dailyReward': {
            'dateKey': '2026-11-03',
            'canClaim': canClaim,
            'currentStreak': 2,
            'nextStreak': 3,
            'nextDayIndex': 3,
            'rewardCoins': 15,
            'xpReward': 25,
            'scheduleCoins': [10, 12, 15, 18, 20, 25, 30],
            'scheduleSupports': [
              null,
              null,
              'boost_basic',
              null,
              null,
              null,
              'boost_strong',
            ],
            'rewardSupport': canClaim ? 'boost_basic' : 'boost_basic',
            'wouldUseStreakProtection': canClaim,
            'freeProtectionEnabled': true,
            'freeProtectionReadyOn': canClaim ? '' : '2026-11-10',
          },
        });
    final g = _SupportGateway(day);
    await t.pumpWidget(MaterialApp(home: Host(gateway: g)));
    await t.tap(find.text('aç'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('sheet-support-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('sheet-support-7')), findsOneWidget);
    expect(find.byKey(const ValueKey('sheet-support-4')), findsNothing);
    expect(
      find.text('Bugün ayrıca: 1 Temel bilgi destek çantana.'),
      findsOneWidget,
    );
    expect(
      find.text('Dün girmedin ama serin korunuyor (7 günde bir).'),
      findsOneWidget,
    );
    await t.tap(find.text('Bugünkü Ödülü Al · +15 Link Coin'));
    await t.pump();
    expect(
      find.text(
        '+15 Link Coin · +25 XP · Temel bilgi eklenemedi: destek çantan dolu (99).',
      ),
      findsOneWidget,
    );
    await t.pumpAndSettle();
    expect(find.text('Yarın: +18 Link Coin'), findsOneWidget);
    expect(
      find.text('Seri koruması 2026-11-10 tarihinde yenilenir.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('sheet-today-support')), findsNothing);
    expect(t.takeException(), isNull);
  });

  test('support reward parsing ignores rows without an item', () {
    expect(SupportReward.from(null), isNull);
    expect(SupportReward.from({'granted': true}), isNull);
    final r = SupportReward.from({'itemId': 'boost_strong', 'granted': true})!;
    expect(r.granted, isTrue);
    expect(r.full, isFalse);
  });

  test('online mode missions route to the online hub', () {
    expect(GameCatalog.missionRoute('online_mode'), GameCatalog.onlineRanked);
  });
}

class _SupportGateway extends SheetGateway {
  _SupportGateway(this.day);
  final ProgressionProfile Function({required bool canClaim}) day;
  @override
  ProgressionProfile progression2() => day(canClaim: canClaim);
  @override
  Future<DailyRewardClaimResult> claimDaily() async {
    dailyClaims++;
    canClaim = false;
    return DailyRewardClaimResult(
      granted: true,
      alreadyClaimed: false,
      amount: 15,
      xp: 25,
      dayIndex: 3,
      multiplier: 1,
      streakProtected: true,
      walletCoins: 120,
      profile: progression2(),
      support: const SupportReward(itemId: 'boost_basic', full: true),
    );
  }
}
