import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/app/game_catalog.dart';
import 'package:shared_xi/controllers/daily_footballer_controller.dart';
import 'package:shared_xi/models/daily_footballer.dart';
import 'package:shared_xi/screens/app_home_page.dart';
import 'package:shared_xi/screens/daily_footballer_page.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'daily_footballer_test.dart' show MemoryFootballerStore, sampleCatalog;

final boundaryKey = GlobalKey();
Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await tester.runAsync(() async {
    final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('.dart_tool/daily_qa');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> open(WidgetTester tester, Widget child,
    {bool light = false, double width = 390, double scale = 1}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme: light ? OrtakSahaTheme.light : OrtakSahaTheme.dark,
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale)), child: child!),
    home: RepaintBoundary(key: boundaryKey, child: child)));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (family, path) in [
      ('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'),
      ('Inter', 'assets/fonts/Inter-Body-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) { await (FontLoader(family)..addFont(rootBundle.load(path))).load(); }
  });

  testWidgets('search selection consumes one guess and exposes all six clues', (tester) async {
    final game = DailyFootballerController(catalog: sampleCatalog, store: MemoryFootballerStore(),
      clock: () => DateTime.utc(2026, 10, 6), watchAd: () async => false);
    addTearDown(game.dispose);
    await open(tester, DailyFootballerPage(controller: game));
    expect(tester.widget<OutlinedButton>(find.byKey(const ValueKey('daily-hint'))).onPressed, isNull);
    final wrong = sampleCatalog.players.firstWhere((p) => p.id != game.round!.target.id);
    await tester.enterText(find.byKey(const ValueKey('daily-footballer-search')), wrong.name.substring(0, 1));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('daily-footballer-search')), wrong.name);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('guess-${wrong.id}')));
    await tester.pumpAndSettle();
    expect(game.round!.guesses.length, 1);
    expect(find.byKey(const ValueKey('daily-answer')), findsNothing);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('guess-card-0')), 200);
    await tester.pumpAndSettle();
    for (final label in ['Ülke', 'Kulüp', 'Lig', 'Mevki', 'Yaş', 'Forma']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final light in [false, true]) {
    testWidgets('home and clue cards fit ${light ? 'light' : 'dark'} at normal and large text', (tester) async {
      GameEntry? selected;
      await open(tester, Scaffold(body: SafeArea(child: AppHomePage(onOpen: (entry) => selected = entry))), light: light);
      expect(find.text('Tüm oyunları keşfet'), findsNothing);
      await tester.tap(find.text('Futbolcuyu bul'));
      expect(selected, same(GameCatalog.dailyFootballer));
      expect(selected!.requiresRepository, isFalse);
      expect(selected!.requiresAuth, isFalse);
      await capture(tester, 'home-footballer-${light ? 'light' : 'dark'}');
      await tester.scrollUntilVisible(find.text('Ortak Oyuncu Keşfi'), 150);
      await tester.tap(find.text('Ortak Oyuncu Keşfi'));
      expect(selected, same(GameCatalog.discovery));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());

      final catalog = DailyFootballerCatalog.fromJson(jsonDecode(
        File('assets/data/daily_footballer_catalog.json').readAsStringSync()) as Map<String, dynamic>);
      final target = catalog.players.firstWhere((p) => p.name == 'Erling Haaland');
      final guess = catalog.players.firstWhere((p) => p.name == 'Kylian Mbappé');
      final saved = MemoryFootballerStore()..value = jsonEncode(DailyFootballerRound(
        dayKey: '2026-10-06', catalogVersion: catalog.version, asOf: catalog.asOf,
        target: target, guesses: [guess]).toJson());
      final game = DailyFootballerController(catalog: catalog, store: saved,
        clock: () => DateTime.utc(2026, 10, 6), watchAd: () async => false);
      addTearDown(game.dispose);
      await open(tester, DailyFootballerPage(controller: game), light: light);
      await capture(tester, 'footballer-start-${light ? 'light' : 'dark'}');
      await tester.scrollUntilVisible(find.byKey(const ValueKey('guess-card-0')), 200);
      await tester.pumpAndSettle();
      await capture(tester, 'footballer-clues-${light ? 'light' : 'dark'}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await open(tester, DailyFootballerPage(controller: game), light: light, width: 320, scale: 1.8);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('guess-card-0')), 200);
      await tester.pumpAndSettle();
      await capture(tester, 'footballer-large-${light ? 'light' : 'dark'}');
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Nasıl oynanır?'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Anladım'), 300, scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('Anladım'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await open(tester, Scaffold(body: SafeArea(child: AppHomePage(onOpen: (_) {}))),
        light: light, width: 320, scale: 1.8);
      await tester.scrollUntilVisible(find.text('Günlük ödül ve görevler'), 250);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
