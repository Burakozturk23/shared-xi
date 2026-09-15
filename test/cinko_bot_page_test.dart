import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/controllers/vs_bot_cinko_controller.dart';
import 'package:shared_xi/screens/vs_bot_cinko_page.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'package:shared_xi/widgets/pitch_ui.dart';

import 'support/cinko_fixture.dart';

const _captureKey = Key('cinko-capture');
Finder get _verticalScroll => find
    .byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    )
    .first;

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('UPDATE_CINKO_SCREENSHOTS')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await Directory('.dart_tool/cinko_qa').create(recursive: true);
  await File('.dart_tool/cinko_qa/$name.png')
      .writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
}

Future<VsBotCinkoController> open(
  WidgetTester tester, {
  Size size = const Size(416, 1000),
  double scale = 1,
  bool dark = true,
  bool navigator = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final session = cinkoFixture(
    answers: {
      for (var i = 0; i < 25; i++)
        i: {
          i + 1,
          if ([1, 5].contains(i)) 1,
        },
    },
  );
  final c = VsBotCinkoController(loadSession: (_) async => session);
  final page = VsBotCinkoPage(controllerFactory: () => c);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: MaterialApp(
        theme: dark ? OrtakSahaTheme.dark : OrtakSahaTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: navigator
            ? Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => page)),
                    child: const Text('Open Çinko'),
                  ),
                ),
              )
            : page,
      ),
    ),
  );
  if (navigator) {
    await tester.tap(find.text('Open Çinko'));
  }
  await tester.pumpAndSettle();
  return c;
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

  testWidgets(
    'Invalid input stays editable; choosing an identity opens the board',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = await open(tester);
      await capture(tester, 'ready-dark');
      await tester.tap(find.text('Maça başla'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('cinko-answer')),
        'Unknown footballer',
      );
      await tester.tap(find.widgetWithText(PitchAction, 'Kutuları seç'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('cinko-answer')))
            .controller!
            .text,
        'Unknown footballer',
      );
      expect(c.canChoosePlayer, isTrue);
      await tester.enterText(
        find.byKey(const Key('cinko-answer')),
        'Thierry Henry',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Thierry Henry'));
      await tester.pumpAndSettle();
      expect(c.canSelect, isTrue);
      expect(find.text('Tahtadan kutu seç'), findsOneWidget);
      c.toggleCell(0);
      c.toggleCell(1);
      c.toggleCell(5);
      await tester.pumpAndSettle();
      expect(find.text('3 kutuyu onayla'), findsOneWidget);
      await capture(tester, 'selection-dark');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Board and actions remain usable in light/dark and large text', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final (size, scale, dark) in [
      (const Size(390, 844), 1.0, false),
      (const Size(320, 568), 2.0, true),
      (const Size(700, 400), 2.0, false),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      final c = await open(tester, size: size, scale: scale, dark: dark);
      c.begin();
      c.submitPlayerName('Thierry Henry');
      c.toggleCell(0);
      await tester.pumpAndSettle();
      expect(find.text('1 kutuyu onayla').hitTestable(), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('ORTAK TAHTA'),
        100,
        scrollable: _verticalScroll,
      );
      await tester.pumpAndSettle();
      if (!dark && scale == 1) await capture(tester, 'selection-light');
      await tester.scrollUntilVisible(
        find.text(
          'Doğru +1 · Yanlış −1 · Pas 0\nYatay ve dikey bağlantı geçerli. L olur, çapraz olmaz.',
        ),
        150,
        scrollable: _verticalScroll,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size @ $scale');
    }
  });

  testWidgets(
    'Back pauses play, cancel restores it and exit returns one route',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = await open(tester, navigator: true);
      c.begin();
      c.pass();
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Maçtan çıkılsın mı?'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(c.moves.length, 1);
      await tester.tap(find.text('Oyuna dön'));
      await tester.pumpAndSettle();
      expect(c.phase, CinkoMatchPhase.playing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Çık'));
      await tester.pumpAndSettle();
      expect(find.text('Open Çinko'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Background freezes bot; manual pause is preserved on return', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = await open(tester);
    c.begin();
    c.pass();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    expect(c.moves.length, 1);
    expect(c.phase, CinkoMatchPhase.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(c.phase, CinkoMatchPhase.playing);
    c.pause();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(c.phase, CinkoMatchPhase.paused);
    expect(tester.takeException(), isNull);
  });
}
