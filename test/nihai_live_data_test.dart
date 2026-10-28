import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/controllers/home_resources_controller.dart';
import 'package:shared_xi/models/friend_models.dart';
import 'package:shared_xi/models/mission_models.dart';
import 'package:shared_xi/screens/app_home_page.dart';
import 'package:shared_xi/screens/games_catalog_page.dart';
import 'package:shared_xi/screens/online_hub_page.dart';
import 'package:shared_xi/screens/player_profile_page.dart';
import 'package:shared_xi/screens/progression_center_page.dart';
import 'package:shared_xi/services/profile_service.dart';
import 'package:shared_xi/theme/app_theme.dart';
import 'package:shared_xi/widgets/hub_ui.dart';

MissionItem _mission(String id, {int coins = 50, bool ready = false}) =>
    MissionItem(
      id: id,
      kind: MissionKind.daily,
      title: id,
      description: '',
      progress: ready ? 1 : 0,
      rawProgress: ready ? 1 : 0,
      target: 1,
      rewardCoins: coins,
      claimable: ready,
      claimed: false,
      chainId: '',
      stage: 1,
      stageCount: 1,
    );

final _missions = MissionProfile(
  dateKey: '2026-10-29',
  daily: [_mission('a', coins: 150, ready: true), _mission('b'), _mission('c')],
  general: const [],
  dailyCompletedCount: 1,
  generalCompletedCount: 0,
  dailyClaimLimit: 3,
);

HomeResourcesController _resources({MissionProfile? missions}) =>
    HomeResourcesController(
        prepare: () async {},
        accounts: () => const Stream.empty(),
        currentAccount: () => (uid: 'u', linked: true),
        readEnergy: () async => {},
        watchWallet: () => const Stream.empty(),
      )
      ..account = (uid: 'u', linked: true)
      ..missions = missions;

Future<void> _show(WidgetTester t, Widget body, {double height = 2400}) async {
  t.view.physicalSize = Size(390, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: body),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  test('daily content resets at midnight Türkiye time', () {
    // 21:00 UTC is 00:00 in Istanbul: a whole day remains.
    expect(
      dailyResetRemaining(DateTime.utc(2026, 10, 28, 21)),
      const Duration(hours: 24),
    );
    expect(
      dailyResetRemaining(DateTime.utc(2026, 10, 28, 20, 59, 59)),
      const Duration(seconds: 1),
    );
    expect(
      dailyResetRemaining(DateTime.utc(2026, 10, 28, 15, 42, 6)),
      const Duration(hours: 5, minutes: 17, seconds: 54),
    );
  });

  testWidgets('home counts down to the reset and summarises missions', (
    t,
  ) async {
    final c = _resources(missions: _missions);
    addTearDown(c.dispose);
    Widget? opened;
    await _show(
      t,
      AppHomePage(
        resources: c,
        loadResources: false,
        onOpenPage: (page) => opened = page,
        now: () => DateTime.utc(2026, 10, 28, 15, 42, 6),
      ),
    );
    expect(find.text('05:17:54'), findsOneWidget);
    expect(find.text('1/3 ödül alındı · 150 coin hazır'), findsOneWidget);
    await t.tap(find.text('1/3 ödül alındı · 150 coin hazır'));
    expect(opened, isA<ProgressionCenterPage>());

    // Without a server read the row keeps its generic copy.
    c.missions = null;
    await _show(
      t,
      AppHomePage(resources: c, loadResources: false, onOpenPage: (_) {}),
    );
    expect(find.textContaining('ödül alındı'), findsNothing);
    expect(find.text('Görevlerini tamamla, ödüllerini topla.'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('controller reads missions for linked accounts only', (t) async {
    var reads = 0;
    final auth = StreamController<ResourceAccount>();
    addTearDown(auth.close);
    final c = HomeResourcesController(
      prepare: () async {},
      accounts: () => auth.stream,
      currentAccount: () => (uid: 'u', linked: true),
      readEnergy: () async => {},
      watchWallet: () => const Stream.empty(),
      readMissions: () async {
        reads++;
        return _missions;
      },
    );
    addTearDown(c.dispose);
    await c.start();
    await t.pump();
    expect(reads, 1);
    expect(c.missions?.dailyCompletedCount, 1);
    // Switching to a guest drops the linked account's missions.
    auth.add((uid: 'g', linked: false));
    await t.pump();
    expect(reads, 1);
    expect(c.missions, isNull);
  });

  testWidgets('games offer category chips and the daily mission card', (
    t,
  ) async {
    final c = _resources(missions: _missions);
    addTearDown(c.dispose);
    await _show(t, GamesCatalogPage(resources: c));
    final all = find.byKey(const ValueKey('games-chip-all'));
    expect(all, findsOneWidget);
    expect(
      find.descendant(of: all, matching: find.textContaining('Tümü (')),
      findsOneWidget,
    );
    expect(find.text('Günlük görevler'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    final chip = find.byKey(const ValueKey('games-chip-Harf & Kelime'));
    await t.ensureVisible(chip);
    await t.pumpAndSettle();
    await t.tap(chip);
    await t.pumpAndSettle();
    expect(find.text('Harf & Kelime modlarında ara'), findsOneWidget);
  });

  testWidgets('online hero shows the player and friend counts', (t) async {
    await _show(
      t,
      OnlineHubPage(
        persistentAccount: true,
        invites: Stream.value(const []),
        me: Stream.value(
          const UserProfile(uid: 'u', displayName: 'Kaptan', elo: 1240),
        ),
        friends: Stream.value(const [
          FriendshipEdge(uid: 'a'),
          FriendshipEdge(uid: 'b'),
          FriendshipEdge(uid: 'c'),
        ]),
        incoming: Stream.value(const [
          FriendRequestEdge(uid: 'x'),
          FriendRequestEdge(uid: 'y'),
        ]),
      ),
    );
    expect(find.text('Kaptan'), findsOneWidget);
    expect(find.text('1.240 ELO'), findsOneWidget);
    expect(find.text('3 arkadaşın var. İsteklerini yönet.'), findsOneWidget);
    expect(find.text('2 yeni istek'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('profile shows the form streak and confirms sign-out', (t) async {
    var signedOut = 0;
    MatchHistoryEntry m(String id, RankedResult r) =>
        MatchHistoryEntry(matchId: id, result: r);
    Widget body({VoidCallback? onSignOut, String type = 'google'}) =>
        PlayerProfileBody(
          profile: UserProfile(
            uid: 'u',
            displayName: 'Kaptan',
            accountType: type,
            wins: 12,
            losses: 4,
            draws: 1,
            elo: 1240,
            recentMatches: [
              m('1', RankedResult.win),
              m('2', RankedResult.win),
              m('3', RankedResult.loss),
              m('4', RankedResult.win),
            ],
          ),
          onEditNickname: () {},
          onEditAvatar: () {},
          onLinkAccount: () {},
          onOpen: (_) {},
          onSignOut: onSignOut,
        );
    await _show(t, body(onSignOut: () => signedOut++), height: 3200);
    expect(find.text('FORM SERİSİ'), findsOneWidget);
    expect(find.text('Üst üste galibiyet'), findsOneWidget);
    expect(find.text('12G - 1B - 4M'), findsOneWidget);
    await t.tap(find.text('Oturumu kapat'));
    await t.pumpAndSettle();
    await t.tap(find.text('Vazgeç'));
    await t.pumpAndSettle();
    expect(signedOut, 0);
    await t.tap(find.text('Oturumu kapat'));
    await t.pumpAndSettle();
    await t.tap(find.text('Çıkış yap'));
    await t.pumpAndSettle();
    expect(signedOut, 1);

    // Guests have nothing to sign out of.
    await _show(t, body(onSignOut: () {}, type: 'guest'), height: 3200);
    expect(find.text('Oturumu kapat'), findsNothing);
  });
}
