import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/controllers/turkish_nostalgia_controller.dart';
import 'package:shared_xi/screens/turkish_nostalgia_page.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';

import 'nostalgia_test.dart';

Future<void> go(WidgetTester t, Key key) async {
  await t.drag(find.byType(ListView), const Offset(0, 5000));
  await t.pumpAndSettle();
  await t.scrollUntilVisible(
    find.byKey(key),
    200,
    scrollable: find.byType(Scrollable).last,
    maxScrolls: 80,
  );
  await t.pumpAndSettle();
}

Future<void> shot(WidgetTester t, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await t.pumpAndSettle();
  await t.runAsync(() async {
    final im =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 1);
    final data = await im.toByteData(format: ui.ImageByteFormat.png);
    final file = File('.dart_tool/nostalgia_qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    im.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (name, path) in [
      ('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'),
      ('Inter', 'assets/fonts/Inter-Body-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(name)..addFont(rootBundle.load(path))).load();
    }
  });
  for (final light in [false, true]) {
    testWidgets(
      'Nostalji: all mechanics, sources, hint confirmation and album at 320px/180% light=$light',
      (t) async {
        t.view.physicalSize = const Size(320, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final c = NostalgiaController(
          catalog: nostalgiaPack(),
          store: MemoryNostalgiaStore(),
          gateway: FakeNostalgiaGateway(),
        );
        addTearDown(c.dispose);
        await c.load();
        final key = GlobalKey();
        await t.pumpWidget(
          MaterialApp(
            theme: light ? OrtakSahaTheme.light : OrtakSahaTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.8)),
              child: RepaintBoundary(key: key, child: child!),
            ),
            home: TurkishNostalgiaPage(controller: c),
          ),
        );
        await t.pumpAndSettle();
        await shot(t, key, 'archive-$light');
        for (final id in ['nostalgia_01', 'nostalgia_04', 'nostalgia_07']) {
          c.openChapter(id);
          await t.pumpAndSettle();
          await go(t, const ValueKey('nostalgia-start'));
          await t.tap(find.byKey(const ValueKey('nostalgia-start')));
          await t.pumpAndSettle();
          for (var i = 0; i < 2; i++) {
            await shot(t, key, '${c.active!.type}-$light');
            c.hint();
            await t.pumpAndSettle();
            expect(c.hintOpen, true);
            selectNostalgia(c);
            await t.pumpAndSettle();
            await go(t, const ValueKey('nostalgia-submit'));
            await t.tap(find.byKey(const ValueKey('nostalgia-submit')));
            await t.pumpAndSettle();
            expect(c.phase, 'result');
            final source = PageStorageKey('nostalgia-sources-${c.activeId}');
            await go(t, source);
            await t.tap(find.text('Tarihsel kaynaklar'));
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            c.next();
            await t.pumpAndSettle();
          }
          expect(c.phase, 'album');
          await shot(t, key, 'album-$id-$light');
          expect(t.takeException(), isNull);
        }
        c.openChapter('nostalgia_02');
        c.start();
        await t.pumpAndSettle();
        await t.scrollUntilVisible(
          find.text('Güçlü yardım · 6 coin'),
          200,
          scrollable: find.byType(Scrollable).last,
          maxScrolls: 60,
        );
        await t.tap(find.text('Güçlü yardım · 6 coin'));
        await t.pumpAndSettle();
        expect(find.text('Yardımı aç'), findsOneWidget);
        await t.tap(find.text('Vazgeç'));
        await t.pumpAndSettle();
        expect(c.hints, isEmpty);
        expect(t.takeException(), isNull);
      },
    );
  }
}
