import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/app/game_catalog.dart';
import 'package:shared_xi/online/career_transfer_online_page.dart';
import 'package:shared_xi/online/online_mode_catalog.dart';
import 'package:shared_xi/online/online_mode_selection_page.dart';
import 'package:shared_xi/screens/games_catalog_page.dart';
import 'package:shared_xi/screens/odd_club_mode_selection_page.dart';
import 'package:shared_xi/screens/odd_club_page.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'package:shared_xi/widgets/online_ui.dart';
import 'arcade_page_test.dart' as arcade;
import 'choice_page_test.dart' as choice;
import 'pvp_page_test.dart' as pvp;
import 'career_transfer_page_test.dart' as career;
import 'fake_club_page_test.dart' as fake;

class DuelFixture extends career.FakePuzzle {
  DuelFixture(super.mode, this.stage);
  final String stage;
  @override
  Future<Map<String, dynamic>> onlineLoad(String mode) async {
    final result = Map<String, dynamic>.from(await super.onlineLoad(mode));
    result['availability'] = {'friends': true, 'ranked': true};
    if (stage == 'setup') { result['room'] = {}; return result; }
    final room = Map<String, dynamic>.from(result['room'] as Map);
    result['room'] = room;
    room.addAll({'status': stage, 'ranked': false, 'host': true, 'code': 'ABCD1234', 'result': 'win'});
    if (mode == 'fake_club_duel') {
      room['question'] = {'kind': mode, 'player': {'name': 'David Beckham'}, 'options': fake.FakeClubTransport.clubs};
    } else if (mode == 'mystery_duel') {
      room['question'] = {'kind': mode, 'country': 'Argentina', 'position': 'Forvet',
        'hints': ['Barcelona ve Paris Saint-Germain formaları giydi.'],
        'options': [{'id': 1, 'name': 'Lionel Messi'}, {'id': 2, 'name': 'Paulo Dybala'}]};
    }
    return result;
  }
}

final boundary = GlobalKey();
Future<void> mount(WidgetTester t, Widget page, {bool light = false, bool large = false}) async {
  t.view.physicalSize = Size(large ? 320 : 390, 1100); t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(key: UniqueKey(), theme: light ? OrtakSahaTheme.light : OrtakSahaTheme.dark,
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(large ? 1.8 : 1)), child: child!),
    initialRoute: '/game', routes: {
      '/': (_) => const Scaffold(),
      '/game': (_) => RepaintBoundary(key: boundary, child: page),
    }));
  await t.pump(); await t.pump(const Duration(milliseconds: 200));
}
Future<void> capture(WidgetTester t, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await t.runAsync(() async {
    final image = await (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('.dart_tool/game_design_qa/$name.png'); await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List()); image.dispose();
  });
}
void expectTheme(WidgetTester t, bool light) {
  final theme = Theme.of(t.element(find.byType(Scaffold).first));
  expect(theme.brightness, light ? Brightness.light : Brightness.dark);
  expect(theme.scaffoldBackgroundColor, light ? PitchColors.light.background : PitchColors.dark.background);
  expect(t.takeException(), isNull);
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in [('Inter', 'assets/fonts/Inter-Body-Variable.ttf'), ('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf')]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
  });
  for (final ranked in [false, true]) {
    testWidgets('online menu $ranked finds all 13 modes and clears search', (t) async {
      await mount(t, OnlineModeSelectionPage(ranked: ranked));
      expectTheme(t, false); await capture(t, 'menu_${ranked}_dark');
      await mount(t, OnlineModeSelectionPage(ranked: ranked), light: true, large: true);
      expectTheme(t, true);
      await capture(t, 'menu_${ranked}_light_large');
      for (final mode in OnlinePlayMode.values) {
        await t.enterText(find.byType(TextField), mode.title); await t.pumpAndSettle();
        expect(find.descendant(of: find.byType(OnlineModeTile), matching: find.text(mode.title)), findsOneWidget);
        expect(t.takeException(), isNull);
      }
      await t.tap(find.byTooltip('Aramayı temizle')); await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('13 mod'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('13 mod'), findsOneWidget);
    });
  }
  for (final light in [false, true]) {
    testWidgets('catalog groups and fake club selector theme $light', (t) async {
      for (final group in GameCatalog.groups.where((g) => ['Hız & Eşleştirme', 'Seçim & Sıralama'].contains(g.title))) {
        await mount(t, GamesCatalogPage(key: UniqueKey(), group: group), light: light, large: light);
        expectTheme(t, light); await capture(t, '${group.icon.codePoint}_$light');
      }
      await mount(t, const OddClubModeSelectionPage(), light: light, large: light);
      expectTheme(t, light); await capture(t, 'fake_selector_$light');
      expect(GameCatalog.games.firstWhere((g) => g.page is OddClubModeSelectionPage).modern, isTrue);
    });
    for (final timed in [false, true]) {
      testWidgets('fake club solo $timed theme $light', (t) async {
        for (final stage in ['home', 'game', 'result']) {
          await mount(t, OddClubPage(key: UniqueKey(), timed: timed, service: fake.FakeClubTransport(timed: timed, stage: stage)), light: light, large: light);
          expectTheme(t, light); await capture(t, 'fake_${timed}_${stage}_$light');
          await t.pumpWidget(const SizedBox());
        }
      });
    }
    for (final mode in ['career_race', 'transfer_duel', 'mystery_duel', 'fake_club_duel']) {
      testWidgets('$mode setup lobby play result theme $light', (t) async {
        for (final stage in ['setup', 'waiting', 'playing', 'finished']) {
          await mount(t, CareerTransferOnlinePage(key: UniqueKey(), mode: mode, service: DuelFixture(mode, stage)), light: light, large: light);
          expectTheme(t, light);
          if (stage == 'waiting') expect(find.text('ABCD1234'), findsOneWidget);
          if (stage == 'playing') expect(find.textContaining('Tur 1 /'), findsOneWidget);
          if (stage == 'finished') expect(find.text('Kazandın'), findsOneWidget);
          if (stage == 'setup') expect(find.text('Arkadaş odası oluştur'), findsOneWidget);
          await capture(t, '${mode}_${stage}_$light');
          final scrollable = find.byType(Scrollable).first;
          await t.drag(scrollable, const Offset(0, -650)); await t.pump();
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        }
      });
    }
  }
  testWidgets('matching visible cards remain readable with large text', (t) async {
    await arcade.mount(t, arcade.ArcadeFixture(stage: 'locked'), 'matching', large: true, light: true);
    expectTheme(t, true);
    expect(find.text('Zlatan Ibrahimović'), findsOneWidget);
    await arcade.capture(t, 'matching_visible_light_large');
    await t.pumpWidget(const SizedBox());
  });
  for (final mode in ['burst', 'pyramid', 'matching']) {
    testWidgets('$mode inherits light theme across stages', (t) async {
      for (final stage in ['intro', 'prepared', 'game', 'paused', 'result']) {
        await arcade.mount(t, arcade.ArcadeFixture(stage: stage), mode, light: true);
        expectTheme(t, true); await arcade.capture(t, '${mode}_${stage}_light');
        await t.pumpWidget(const SizedBox());
      }
    });
  }
  for (final mode in ['this_or_that', 'higher_lower', 'blind_ranking']) {
    testWidgets('$mode inherits light theme across stages', (t) async {
      for (final stage in ['intro', 'prepared', 'game', 'result']) {
        await choice.mount(t, choice.ChoiceFixture(stage: stage), mode, light: true);
        expectTheme(t, true); await choice.capture(t, '${mode}_${stage}_light');
        await t.pumpWidget(const SizedBox());
      }
    });
  }
  for (final mode in OnlinePlayMode.values.take(9)) {
    testWidgets('${mode.name} pvp inherits light theme', (t) async {
      await pvp.mount(t, mode, pvp.PvpFixture(), light: true);
      expectTheme(t, true); await pvp.capture(t, '${mode.name}_light');
      await t.pumpWidget(const SizedBox());
    });
  }
}
