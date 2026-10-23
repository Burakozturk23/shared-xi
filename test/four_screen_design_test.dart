import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/online/online_mode_catalog.dart';
import 'package:shared_xi/online/online_mode_selection_page.dart';
import 'package:shared_xi/screens/daily_words_page.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'daily_words_page_test.dart' show WordFixture;

class DelayedWords extends WordFixture {
  final first = Completer<Map<String, dynamic>>();
  int loads = 0;
  @override
  Future<Map<String, dynamic>> load(String mode) {
    loads++;
    return loads == 1 ? first.future : super.load(mode);
  }
}
final boundary = GlobalKey();
Future<void> mount(WidgetTester t, Widget page, {bool light = false, bool large = false}) async {
  t.view.physicalSize = Size(large ? 320 : 390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(key: UniqueKey(), theme: light ? OrtakSahaTheme.light : OrtakSahaTheme.dark,
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(large ? 1.8 : 1)), child: child!),
    initialRoute: '/game', routes: {
      '/': (_) => const Scaffold(),
      '/game': (_) => RepaintBoundary(key: boundary, child: page),
    }));
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}
Future<void> capture(WidgetTester t, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await t.runAsync(() async {
    final picture = await (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio: 1);
    final data = await picture.toByteData(format: ui.ImageByteFormat.png);
    final file = File('.dart_tool/four_screen_qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    picture.dispose();
  });
}
void main() {
  setUpAll(() async {
    for (final font in [('Inter', 'assets/fonts/Inter-Body-Variable.ttf'), ('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf')]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
  });
  for (final ranked in [false, true]) {
    testWidgets('online $ranked category and search filters compose and reset', (t) async {
      await mount(t, OnlineModeSelectionPage(ranked: ranked));
      await capture(t, 'menu_${ranked}_dark');
      for (var i = 0; i < onlineModeGroups.length; i++) {
        final chip = find.widgetWithText(ChoiceChip, onlineModeGroups[i]);
        await t.ensureVisible(chip); await t.tap(chip); await t.pumpAndSettle();
        expect(find.text('${i == 0 ? 5 : 4} mod'), findsOneWidget);
      }
      await t.enterText(find.byType(TextField), 'bulunamayan oyun');
      await t.pumpAndSettle();
      expect(find.text('0 mod'), findsOneWidget);
      await t.ensureVisible(find.text('Filtreleri temizle'));
      await t.tap(find.text('Filtreleri temizle')); await t.pumpAndSettle();
      expect(find.text('13 mod'), findsOneWidget);
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
      expect(t.takeException(), isNull);
      await mount(t, OnlineModeSelectionPage(ranked: ranked), light: true);
      await capture(t, 'menu_${ranked}_light');
      await t.pumpWidget(const SizedBox());
    });
  }
  for (final mode in ['daily_lingo', 'passa_daily']) {
    for (final large in [false, true]) {
      testWidgets('$mode loading timeout retry and stale response ${large ? 'large light' : 'dark'}', (t) async {
        final service = DelayedWords();
        await mount(t, DailyWordsPage(mode: mode, service: service), light: large, large: large);
        expect(find.text('Günlük içerik yükleniyor'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(t.takeException(), isNull);
        await capture(t, '${mode}_loading_$large');
        await t.pump(const Duration(seconds: 31)); await t.pumpAndSettle();
        expect(find.text('Oyunla bağlantı kurulamadı'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        await t.ensureVisible(find.text('Tekrar dene')); await t.pumpAndSettle();
        await capture(t, '${mode}_error_$large');
        await t.tap(find.text('Tekrar dene')); await t.pumpAndSettle();
        expect(service.loads, 2);
        expect(find.text('0 enerji'), findsOneWidget);
        expect(find.text('Tekrar dene'), findsNothing);
        // A timed-out request must never replace the successfully retried game.
        service.first.complete({'availability': false, 'reason': 'STALE RESPONSE'});
        await t.pumpAndSettle();
        expect(find.text('STALE RESPONSE'), findsNothing);
        final scroll = t.state<ScrollableState>(find.byType(Scrollable).first);
        scroll.position.jumpTo(0); await t.pumpAndSettle();
        await capture(t, '${mode}_game_$large');
        await t.drag(find.byType(ListView).first, const Offset(0, -600)); await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox()); await t.pump();
      });
    }
  }
  testWidgets('invalid daily response offers recovery without enabling answers', (t) async {
    final service = DelayedWords();
    await mount(t, DailyWordsPage(mode: 'daily_lingo', service: service));
    service.first.complete({}); await t.pumpAndSettle();
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
}
