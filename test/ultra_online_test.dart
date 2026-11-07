import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/models/friend_models.dart';
import 'package:shared_xi/online/online_mode_catalog.dart';
import 'package:shared_xi/online/online_mode_selection_page.dart';
import 'package:shared_xi/screens/friends_page.dart';
import 'package:shared_xi/screens/leaderboard_page.dart';
import 'package:shared_xi/screens/online_hub_page.dart';
import 'package:shared_xi/services/profile_service.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';

import 'social_center_test.dart' show BoardFake, FriendsFake;

Future<void> _show(WidgetTester t, Widget page, {double height = 2400}) async {
  t.view.physicalSize = Size(390, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(theme: OrtakSahaTheme.dark, home: page));
  await t.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('ranked mode menu leads with the player and a quick match', (
    t,
  ) async {
    await _show(
      t,
      OnlineModeSelectionPage(
        ranked: true,
        me: Stream.value(
          const UserProfile(uid: 'u', displayName: 'Kaptan', elo: 1240),
        ),
      ),
      height: 3400,
    );
    expect(find.text('DERECELİ 1V1 ARENA'), findsOneWidget);
    expect(find.text('1.240 ELO'), findsOneWidget);
    expect(find.text('Kulüp × Kulüp ile hızlı eşleş'), findsOneWidget);
    // Chips and section headers count their modes.
    expect(find.text('(5)'), findsOneWidget);
    expect(find.text('5 MOD'), findsOneWidget);
    expect(find.text('Eşleş'), findsNWidgets(OnlinePlayMode.values.length));
  });

  // Live profile and friend feeds are single-subscription streams.
  testWidgets('switching Online and friends keeps the live ELO feed', (
    t,
  ) async {
    final me = StreamController<UserProfile?>();
    addTearDown(me.close);
    await _show(t, OnlineModeSelectionPage(ranked: true, me: me.stream));
    me.add(const UserProfile(uid: 'u', displayName: 'Kaptan', elo: 1240));
    await t.pumpAndSettle();
    expect(find.text('1.240 ELO'), findsOneWidget);
    for (final tab in ['Arkadaşlarla', 'Online', 'Arkadaşlarla', 'Online']) {
      await t.tap(find.text(tab));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: tab);
    }
    expect(find.text('1.240 ELO'), findsOneWidget);
  });

  testWidgets('online hub survives its hero scrolling out and back', (t) async {
    final me = StreamController<UserProfile?>();
    final friends = StreamController<List<FriendshipEdge>>();
    final incoming = StreamController<List<FriendRequestEdge>>();
    addTearDown(me.close);
    addTearDown(friends.close);
    addTearDown(incoming.close);
    await _show(
      t,
      Scaffold(
        body: OnlineHubPage(
          persistentAccount: true,
          invites: Stream.value(const []),
          me: me.stream,
          friends: friends.stream,
          incoming: incoming.stream,
        ),
      ),
      height: 500,
    );
    me.add(const UserProfile(uid: 'u', displayName: 'Kaptan', elo: 1240));
    friends.add(const [FriendshipEdge(uid: 'a')]);
    incoming.add(const []);
    await t.pumpAndSettle();
    final list = find.byType(Scrollable).first;
    for (var i = 0; i < 2; i++) {
      await t.drag(list, const Offset(0, -3000));
      await t.pumpAndSettle();
      await t.drag(list, const Offset(0, 3000));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    }
    expect(find.text('1.240 ELO'), findsOneWidget);
  });

  testWidgets('friend mode menu offers rooms instead of matchmaking', (
    t,
  ) async {
    await _show(t, const OnlineModeSelectionPage(ranked: false), height: 3400);
    expect(find.text('ÖZEL ODA · DOSTLUK MAÇI'), findsOneWidget);
    expect(find.text('Kulüp × Kulüp ile oda kur'), findsOneWidget);
    expect(find.text('Oda kur'), findsNWidgets(OnlinePlayMode.values.length));
    expect(find.text('Eşleş'), findsNothing);
  });

  testWidgets('leaderboard podium puts the champion in the middle', (t) async {
    await _show(t, LeaderboardPage(gateway: BoardFake()));
    expect(find.text('Genel · Elo'), findsOneWidget);
    final first = t.getCenter(find.text('#1')).dx;
    expect(first, greaterThan(t.getCenter(find.text('#2')).dx));
    expect(first, lessThan(t.getCenter(find.text('#3')).dx));
    expect(find.text('ŞAMPİYON'), findsOneWidget);
    // Ranked rows keep the score on the same line as the name.
    expect(
      (t.getCenter(find.text('Golcü')).dy - t.getCenter(find.text('1.270')).dy)
          .abs(),
      lessThan(16),
    );
  });

  testWidgets('friend cards keep their menu on the name row', (t) async {
    final fake = FriendsFake()
      ..rows = const [FriendshipEdge(uid: 'a'), FriendshipEdge(uid: 'b')];
    await _show(t, FriendsPage(gateway: fake));
    expect(find.text('Aktif liste'), findsOneWidget);
    expect(find.text('2 OYUNCU'), findsOneWidget);
    final name = t.getCenter(find.text('Saha Kaptanı').first).dy;
    final menu = t.getCenter(find.byTooltip('Arkadaş seçenekleri').first).dy;
    expect((name - menu).abs(), lessThan(24));
  });
}
