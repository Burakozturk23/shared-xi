import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'package:shared_xi/widgets/letter_slot_reveal.dart';

Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: OrtakSahaTheme.dark,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion, size: const Size(400, 800)),
    child: RepaintBoundary(key: boundary, child: Scaffold(backgroundColor: Colors.black87, body: child)),
  ),
);

final boundary = GlobalKey();

Future<void> capture(WidgetTester t, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await t.runAsync(() async {
    final img = await (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio: 1);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final file = File('.dart_tool/letter_qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    img.dispose();
  });
}

void main() {
  setUpAll(() async {
    for (final e in [
      ('Inter', 'assets/fonts/Inter-Body-Variable.ttf'),
      ('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(e.$1)..addFont(rootBundle.load(e.$2))).load();
    }
  });
  testWidgets('the reel spins, lands on the server letter and only then offers to start', (t) async {
    var done = 0;
    await t.pumpWidget(host(LetterSlotReveal(letter: 'K', difficulty: 'easy', onDone: () => done++)));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Dokun: hemen göster'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 900));
    await capture(t, 'spinning');
    await t.tap(find.text('Kadroyu kur'), warnIfMissed: false);
    expect(done, 0, reason: 'no start before the letter lands');
    await t.pump(LetterSlotReveal.spin);
    await t.pumpAndSettle();
    expect(find.text('K harfi'), findsOneWidget);
    expect(find.text('Kolay harf'), findsOneWidget);
    await capture(t, 'landed');
    expect(find.textContaining('K ile başlayan 11 oyuncu'), findsOneWidget);
    await t.tap(find.text('Kadroyu kur'));
    expect(done, 1);
  });

  testWidgets('a tap skips the spin; reduced motion shows the letter at once', (t) async {
    await t.pumpWidget(host(const LetterSlotReveal(letter: 'Ş')));
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(find.byType(LetterSlotReveal));
    await t.pumpAndSettle();
    expect(find.text('Ş harfi'), findsOneWidget);
    expect(find.text('Dokun: hemen göster'), findsNothing);

    await t.pumpWidget(host(const LetterSlotReveal(letter: 'A', daily: true), reduceMotion: true));
    await t.pump();
    await t.pumpAndSettle();
    expect(find.text('A harfi'), findsOneWidget);
    expect(find.text('GÜNÜN HARFİ'), findsOneWidget);
  });
}
