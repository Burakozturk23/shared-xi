import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/app/game_catalog.dart';
import 'package:shared_xi/controllers/home_resources_controller.dart';
import 'package:shared_xi/models/economy_models.dart';
import 'package:shared_xi/screens/app_home_page.dart';
import 'package:shared_xi/screens/player_profile_page.dart';
import 'package:shared_xi/screens/story_collections_page.dart';
import 'package:shared_xi/screens/progression_center_page.dart';
import 'package:shared_xi/screens/ucl_moments_page.dart';
import 'package:shared_xi/services/profile_service.dart';
import 'package:shared_xi/theme/app_theme.dart';

final boundary = GlobalKey();
HomeResourcesController resources() =>
    HomeResourcesController(
        prepare: () async {},
        accounts: () => const Stream.empty(),
        currentAccount: () => (uid: 'test', linked: true),
        readEnergy: () async => {},
        watchWallet: () => const Stream.empty(),
      )
      ..account = (uid: 'test', linked: true)
      ..wallet = const EconomyWallet(
        coins: 1250,
        lifetimeEarned: 1250,
        lifetimeSpent: 0,
      )
      ..energy = {
        'available': 4,
        'capacity': 6,
        'reserved': 0,
        'enabled': true,
      };

Future<void> open(
  WidgetTester t,
  Widget page, {
  bool light = false,
  double width = 390,
  double scale = 1,
}) async {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  await t.pumpWidget(
    MaterialApp(
      theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(key: boundary, child: page),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> capture(WidgetTester t, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await t.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final f = File('.dart_tool/experience_qa/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  for (final light in [false, true]) {
    testWidgets(
      'home groups daily games and opens every entry; theme light=$light',
      (t) async {
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final c = resources();
        addTearDown(c.dispose);
        GameEntry? selected;
        await open(
          t,
          Scaffold(
            appBar: AppBar(title: const Text('LINKBALL')),
            body: AppHomePage(
              resources: c,
              loadResources: false,
              onOpen: (g) => selected = g,
            ),
          ),
          light: light,
        );
        expect(find.text('1250'), findsOneWidget);
        expect(find.text('4 / 6'), findsOneWidget);
        expect(
          t.getTopLeft(find.text('Ortak Oyuncu Keşfi')).dy,
          lessThan(t.getTopLeft(find.text('Günlük Meydan Okumalar')).dy),
        );
        await t.tap(find.text('Bağlantıyı keşfet'));
        expect(selected, GameCatalog.discovery);
        await capture(t, 'home-hub-${light ? 'light' : 'dark'}');
        for (final game in GameCatalog.dailyGames) {
          await t.ensureVisible(find.text(game.title));
          await t.tap(find.text(game.title));
          expect(selected, game);
        }
        c.energyFailed = true;
        c.walletFailed = true;
        await open(
          t,
          Scaffold(body: AppHomePage(resources: c, loadResources: false)),
          light: light,
          width: 320,
          scale: 2,
        );
        expect(find.text('1250'), findsNothing);
        expect(find.text('4 / 6'), findsNothing);
        await t.scrollUntilVisible(find.text('Günlük ödül ve görevler'), 250);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      'profile prioritizes progression and keeps albums in one destination light=$light',
      (t) async {
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        Widget? selected;
        var edited = false;
        final page = Scaffold(
          appBar: AppBar(title: const Text('Profil')),
          body: PlayerProfileBody(
            profile: const UserProfile(
              uid: 'test',
              displayName: 'Kaptan Berat',
              normalizedName: 'kaptanberat',
              accountType: 'google',
              wins: 12,
              losses: 4,
              elo: 1240,
            ),
            onEditNickname: () => edited = true,
            onEditAvatar: () {},
            onLinkAccount: () {},
            onOpen: (p) => selected = p,
          ),
        );
        await open(t, page, light: light);
        await capture(t, 'profile-hub-${light ? 'light' : 'dark'}');
        await t.tap(find.text('İsmi düzenle'));
        expect(edited, true);
        await t.tap(find.text('İlerleme & Görevler'));
        expect(selected, isA<ProgressionCenterPage>());
        expect(find.text('Hanedanlıklar Atlası'), findsNothing);
        await t.ensureVisible(find.text('Hikâye koleksiyonlarım'));
        await t.tap(find.text('Hikâye koleksiyonlarım'));
        expect(selected, isA<StoryCollectionsPage>());
        await open(t, page, light: light, width: 320, scale: 2);
        await t.scrollUntilVisible(find.text('Uygulama ayarları'), 300);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'all eight collection links open the existing collection routes',
    (t) async {
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      Widget? selected;
      await open(t, StoryCollectionsPage(onOpen: (page) => selected = page));
      expect(StoryCollectionsPage.collections.length, 8);
      await capture(t, 'profile-story-collections');
      for (final entry in StoryCollectionsPage.collections) {
        await t.scrollUntilVisible(find.text(entry.title), 150);
        await t.tap(find.text(entry.title));
        expect(selected, same(entry.page));
      }
      expect(
        (StoryCollectionsPage.collections[2].page as UclMomentsPage)
            .openCollection,
        true,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
}
