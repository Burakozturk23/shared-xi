import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/app/game_catalog.dart';
import 'package:shared_xi/controllers/home_resources_controller.dart';
import 'package:shared_xi/models/daily_streak.dart';
import 'package:shared_xi/models/economy_models.dart';
import 'package:shared_xi/screens/app_home_page.dart';
import 'package:shared_xi/screens/player_profile_page.dart';
import 'package:shared_xi/screens/story_collections_page.dart';
import 'package:shared_xi/screens/progression_center_page.dart';
import 'package:shared_xi/screens/ucl_moments_page.dart';
import 'package:shared_xi/services/profile_service.dart';
import 'package:shared_xi/theme/app_theme.dart';
import 'package:shared_xi/widgets/hub_ui.dart';

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
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
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
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (family, path) in [
      ('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'),
      ('Inter', 'assets/fonts/Inter-Body-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(path))).load();
    }
  });
  for (final light in [false, true]) {
    testWidgets(
      'home groups daily games and opens every entry; theme light=$light',
      (t) async {
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final c = resources()
          ..streak = const DailyStreak(
            streak: 7,
            played: ['daily_lingo', 'daily_question', 'daily_match'],
          );
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
        // Quick modes say which play alone and which are live.
        expect(find.text('SOLO'), findsOneWidget);
        expect(find.text('CANLI'), findsOneWidget);
        // Coins and energy live in the shell app bar, not the home body.
        expect(find.text('1.250'), findsNothing);
        expect(find.byType(HubEconomyPills), findsNothing);
        expect(
          t.getTopLeft(find.text('Ortak Oyuncu Keşfi')).dy,
          lessThan(t.getTopLeft(find.text('Günlük Meydan Okumalar')).dy),
        );
        await t.tap(find.text('Bağlantıyı keşfet'));
        expect(selected, GameCatalog.discovery);
        await capture(t, 'home-hub-${light ? 'light' : 'dark'}');
        // Günün Futbolcusu leads the daily section as the featured puzzle.
        await t.scrollUntilVisible(find.text('GÜNÜN BULMACASI'), 150);
        await t.pumpAndSettle();
        expect(
          find.ancestor(
            of: find.text(GameCatalog.dailyFootballer.title),
            matching: find.byKey(const ValueKey('home-featured-daily')),
          ),
          findsOneWidget,
        );
        for (final game in GameCatalog.dailyGames) {
          await t.scrollUntilVisible(find.text(game.title), 150);
          await t.pumpAndSettle();
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
        expect(find.text('1.250'), findsNothing);
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
        await t.scrollUntilVisible(find.text('İlerleme & Görevler'), 150);
        await t.pumpAndSettle();
        await t.tap(find.text('İlerleme & Görevler'));
        expect(selected, isA<ProgressionCenterPage>());
        expect(find.text('Hanedanlıklar Atlası'), findsNothing);
        await t.scrollUntilVisible(find.text('Hikâye koleksiyonlarım'), 150);
        await t.pumpAndSettle();
        await t.tap(find.text('Hikâye koleksiyonlarım'));
        expect(selected, isA<StoryCollectionsPage>());
        await open(t, page, light: light, width: 320, scale: 2);
        await t.scrollUntilVisible(find.text('Uygulama ayarları'), 300);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('home shows the shared play streak and hides it otherwise', (
    t,
  ) async {
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final c = resources()
      ..streak = const DailyStreak(
        streak: 7,
        best: 9,
        played: ['daily_lingo', 'daily_question', 'daily_match'],
      );
    addTearDown(c.dispose);
    GameEntry? opened;
    await open(
      t,
      Scaffold(
        body: AppHomePage(
          resources: c,
          loadResources: false,
          onOpen: (game) => opened = game,
        ),
      ),
    );
    expect(find.text('7 günlük seri · 3/6'), findsOneWidget);
    await t.tap(find.text('7 günlük seri · 3/6'));
    await t.pumpAndSettle();
    expect(find.text('Bugün 3/6'), findsOneWidget);
    expect(find.text('En uzun serin: 9 gün'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(3));
    // Rewards stay unmentioned until the server flag opens them.
    expect(find.textContaining('+20 coin'), findsNothing);
    await t.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(GameCatalog.dailyAnagram.title),
      ),
    );
    await t.pumpAndSettle();
    expect(opened, GameCatalog.dailyAnagram);

    c.streak = const DailyStreak(streak: 0, repairStreak: 4);
    await open(
      t,
      Scaffold(
        body: AppHomePage(
          resources: c,
          loadResources: false,
          onOpen: (game) => opened = game,
        ),
      ),
    );
    await t.tap(find.text('Seriyi kurtar · 4 gün'));
    await t.pumpAndSettle();
    await t.tap(find.text('Serimi koru'));
    await t.pumpAndSettle();
    expect(opened, GameCatalog.daily);
    c.streak = null;
    await open(
      t,
      Scaffold(body: AppHomePage(resources: c, loadResources: false)),
    );
    expect(find.textContaining('günlük seri'), findsNothing);
    await t.pumpWidget(const SizedBox.shrink());
  });
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
        await t.pumpAndSettle();
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
