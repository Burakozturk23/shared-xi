import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'package:shared_xi/widgets/vault_open_reveal.dart';

final boundary = GlobalKey();

Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: OrtakSahaTheme.dark,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion, size: const Size(400, 860)),
    child: RepaintBoundary(key: boundary, child: Scaffold(backgroundColor: Colors.black87, body: child)),
  ),
);

Future<void> capture(WidgetTester t, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await t.runAsync(() async {
    final img = await (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio: 1);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final file = File('.dart_tool/vault_qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    img.dispose();
  });
}

const flags = <VaultFlag>[
  (country: 'Brazil', position: 'Forvet'),
  (country: 'Spain', position: 'Orta saha'),
  (country: 'France', position: 'Defans'),
];

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

  testWidgets('the door opens, the three flags drop and only then the vault can be solved', (t) async {
    var done = 0;
    await t.pumpWidget(host(VaultOpenReveal(flags: flags, difficulty: 'medium', onDone: () => done++)));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Dokun: hemen aç'), findsOneWidget);
    await capture(t, 'dial');
    await t.pump(const Duration(milliseconds: 1100));
    await capture(t, 'door');
    await t.pump(VaultOpenReveal.duration);
    await t.pumpAndSettle();
    expect(find.text('Brazil'), findsOneWidget);
    expect(find.text('Orta saha'), findsOneWidget);
    expect(find.text('Orta kasa'), findsOneWidget);
    expect(find.byKey(const Key('vault-open-rule')), findsOneWidget);
    await capture(t, 'open');
    await t.tap(find.text('Kasayı çöz'));
    expect(done, 1);
  });

  testWidgets('a tap skips to the open vault; reduced motion opens at once', (t) async {
    var done = 0;
    await t.pumpWidget(host(VaultOpenReveal(flags: flags, onDone: () => done++)));
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(find.byType(VaultOpenReveal));
    await t.pumpAndSettle();
    expect(find.text('Dokun: hemen aç'), findsNothing);
    await t.tap(find.text('Kasayı çöz'));
    expect(done, 1);

    await t.pumpWidget(host(const VaultOpenReveal(flags: flags, daily: true), reduceMotion: true));
    await t.pump();
    await t.pumpAndSettle();
    expect(find.text('GÜNÜN KASASI'), findsOneWidget);
    expect(find.text('France'), findsOneWidget);
  });
}
