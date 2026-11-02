import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/models/pro_crate.dart';
import 'package:shared_xi/models/season_pass.dart';
import 'package:shared_xi/screens/season_pass_page.dart';
import 'package:shared_xi/services/experience/pro_gateway.dart';
import 'package:shared_xi/services/experience/season_gateway.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'package:shared_xi/widgets/pro_crate_card.dart';

Map<String, dynamic> crateMap({
  bool enabled = true,
  bool pro = true,
  bool canOpen = true,
  bool opened = false,
  bool remind = false,
}) => {
  'enabled': enabled,
  'pro': pro,
  'month': '2026-11',
  'endsOn': '2026-11-30',
  'daysLeft': remind ? 2 : 20,
  'remind': remind,
  'opened': opened,
  'canOpen': canOpen,
  'openableAt': DateTime(2026, 11, 12, 9, 30).millisecondsSinceEpoch,
  'contents': {
    'boost_basic': 12,
    'boost_strong': 4,
    'boost_connection': 2,
    'boost_eliminate': 2,
    'avatarTier': 450,
  },
  'odds': {
    'count': 48,
    'tiers': [
      {'price': 450, 'count': 48, 'chance': 1, 'each': 0.020833},
    ],
  },
  if (opened)
    'receipt': {
      'supports': {
        'boost_basic': 12,
        'boost_strong': 4,
        'boost_connection': 2,
        'boost_eliminate': 2,
      },
      'overflowCoins': 0,
      'avatar': {
        'kind': 'avatar',
        'itemId': 'night_owl',
        'title': 'Gece Kuşu',
        'coins': 0,
      },
    },
};

class CrateFake extends ProGateway {
  CrateFake(this.state);
  Map<String, dynamic> state;
  int opens = 0;
  final equipped = <String>[];
  @override
  bool get connected => true;
  @override
  Future<ProCrateStatus> crate() async => ProCrateStatus.fromMap(state);
  @override
  Future<ProCrateStatus> openCrate() async {
    opens++;
    state = crateMap(opened: true, canOpen: false);
    return ProCrateStatus.fromMap(state);
  }

  @override
  Future<void> equip(String itemId) async => equipped.add(itemId);
}

Future<void> host(WidgetTester t, Widget child) async {
  t.view.physicalSize = const Size(390, 1000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      theme: OrtakSahaTheme.dark,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'Pro Kasası shows contents and odds, opens once and offers to use the avatar',
    (t) async {
      final g = CrateFake(crateMap());
      await host(t, ProCrateCard(gateway: g));
      expect(find.text('Kasım Kasası'), findsOneWidget);
      expect(find.text('12 Temel bilgi'), findsOneWidget);
      expect(find.text('4 Güçlü bilgi'), findsOneWidget);
      expect(
        find.textContaining('48 özel (450 coin) avatar arasından eşit şansla'),
        findsOneWidget,
      );
      expect(find.textContaining('%2,08'), findsOneWidget);
      await t.tap(find.text('Kasayı aç'));
      await t.pumpAndSettle();
      expect(g.opens, 1);
      expect(find.byKey(const ValueKey('pro-crate-result')), findsOneWidget);
      expect(find.text('Yeni avatarın'), findsOneWidget);
      await t.tap(find.text('Tamam'));
      await t.pumpAndSettle();
      expect(find.text('Bu ayın Kasası açıldı'), findsOneWidget);
      await t.tap(find.text('Kullan'));
      await t.pumpAndSettle();
      expect(g.equipped, ['night_owl']);
      expect(find.text('Kullanılıyor'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Kasa: hidden while off, Pro-only label, 48-hour wait and last-days reminder',
    (t) async {
      await host(t, ProCrateCard(gateway: CrateFake(crateMap(enabled: false))));
      expect(find.byKey(const ValueKey('pro-crate-card')), findsNothing);
      await host(
        t,
        ProCrateCard(gateway: CrateFake(crateMap(pro: false, canOpen: false))),
      );
      expect(find.text('Pro üyelerine özel'), findsOneWidget);
      await host(t, ProCrateCard(gateway: CrateFake(crateMap(canOpen: false))));
      expect(find.text('12.11 09:30 itibarıyla açılır'), findsOneWidget);
      await host(t, ProCrateCard(gateway: CrateFake(crateMap(remind: true))));
      expect(find.byKey(const ValueKey('pro-crate-remind')), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('Sezon: avatar steps show the random avatar and the odds', (
    t,
  ) async {
    await host(
      t,
      SizedBox(height: 900, child: SeasonPassPage(gateway: _AvatarSeason())),
    );
    expect(find.byKey(const ValueKey('season-avatar-odds')), findsOneWidget);
    expect(find.textContaining('%21,6'), findsOneWidget);
    await t.scrollUntilVisible(
      find.byKey(const ValueKey('season-avatar-10')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Rastgele avatar'), findsWidgets);
    expect(t.takeException(), isNull);
  });
}

class _AvatarSeason extends SeasonGateway {
  @override
  bool get connected => true;
  @override
  Future<SeasonPass> load() async => SeasonPass.fromMap({
    'id': '2026-11',
    'endsOn': '2026-11-30',
    'sp': 1050,
    'todaySp': 40,
    'level': 10,
    'daysLeft': 20,
    'maxLevel': 20,
    'stepSp': 100,
    'dailyCap': 150,
    'pro': true,
    'avatarSteps': [10, 20],
    'avatarOdds': {
      'count': 164,
      'tiers': [
        {'price': 300, 'count': 116, 'chance': 0.7838, 'each': 0.0068},
        {'price': 450, 'count': 48, 'chance': 0.2162, 'each': 0.0045},
      ],
    },
    'tiers': [
      for (var step = 1; step <= 20; step++)
        {
          'step': step,
          'requiredSp': step * 100,
          'unlocked': step <= 10,
          'freeCoins': step % 5 == 0 ? 60 : 20,
          'proCoins': step == 10 || step == 20
              ? 0
              : step % 5 == 0
              ? 100
              : 40,
          'proAvatar': step == 10 || step == 20,
          'freeClaimed': step < 10,
          'proClaimed': step < 10,
        },
    ],
  });
}
