import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/controllers/vs_bot_random_five_controller.dart';
import 'package:shared_xi/screens/vs_bot_random_five_page.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'package:shared_xi/widgets/pitch_ui.dart';

import 'support/random_five_fixture.dart';

Finder get vertical => find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;
const captureKey = Key('five-capture');

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(captureKey),
  );
  final image = await boundary.toImage(pixelRatio: 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await Directory('.dart_tool/five_qa').create(recursive: true);
  await File('.dart_tool/five_qa/$name.png')
      .writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
}

Future<VsBotRandomFiveController> open(
  WidgetTester tester, {
  Size size = const Size(416, 1000),
  double scale = 1,
  bool dark = true,
  bool navigator = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final c = VsBotRandomFiveController(
    loadSession: () async => fiveFixture(),
    random: Random(4),
  );
  final page = VsBotRandomFivePage(controllerFactory: () => c);
  await tester.pumpWidget(
    RepaintBoundary(
      key: captureKey,
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
                    child: const Text('Open Five'),
                  ),
                ),
              )
            : page,
      ),
    ),
  );
  if (navigator) await tester.tap(find.text('Open Five'));
  await tester.pumpAndSettle();
  expect(c.phase, FiveMatchPhase.ready);
  return c;
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 160, scrollable: vertical);
  await tester.pumpAndSettle();
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
  setUp(() {});

  testWidgets(
    'Explicit start; rejected text stays editable and ambiguity is selectable',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = await open(tester);
      await capture(tester, 'ready-dark');
      await tester.pump(const Duration(seconds: 10));
      expect(c.history, isEmpty);
      await reveal(tester, find.text('Maça başla'));
      await tester.tap(find.text('Maça başla'));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('five-answer')));
      await tester.enterText(
        find.byKey(const Key('five-answer')),
        'Unknown player',
      );
      await reveal(tester, find.widgetWithText(PitchAction, 'Cevabı gönder'));
      await tester.tap(find.widgetWithText(PitchAction, 'Cevabı gönder'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('five-answer')))
            .controller!
            .text,
        'Unknown player',
      );
      expect(c.canAnswer, isTrue);
      await tester.enterText(find.byKey(const Key('five-answer')), 'Ronaldo');
      await tester.pumpAndSettle();
      await reveal(tester, find.widgetWithText(ListTile, 'Cristiano Ronaldo'));
      await tester.tap(find.widgetWithText(ListTile, 'Cristiano Ronaldo'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(c.phase, FiveMatchPhase.roundResult);
      expect(c.userMove!.player!.name, 'Cristiano Ronaldo');
      expect(find.text('Sonraki tur').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Scrolled history expansion never reads a double as bool', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = await open(tester, size: const Size(390, 844), dark: false);
    c.begin();
    await tester.pumpAndSettle();
    await capture(tester, 'playing-light');
    // Store a scroll offset before the first history tile is inserted.
    await tester.drag(vertical, const Offset(0, -450));
    await tester.pumpAndSettle();
    c.submitGuess('Thierry Henry');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Tur geçmişi'));
    await tester.tap(find.text('Tur geçmişi'));
    await tester.pumpAndSettle();
    await tester.drag(vertical, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Sonraki tur'));
    await tester.pumpAndSettle();
    expect(c.roundNumber, 2);
    expect(c.canAnswer, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Large text, narrow and landscape layouts support review and replay',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final (size, scale, dark) in [
        (const Size(390, 844), 1.0, true),
        (const Size(320, 568), 2.0, false),
        (const Size(700, 400), 2.0, true),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        final c = await open(tester, size: size, scale: scale, dark: dark);
        await reveal(tester, find.text('Maça başla'));
        expect(find.text('Maça başla').hitTestable(), findsOneWidget);
        c.begin();
        await tester.pumpAndSettle();
        await reveal(tester, find.byKey(const Key('five-answer')));
        for (var round = 0; round < 5; round++) {
          c.pass();
          await tester.pump(const Duration(seconds: 2));
          await tester.pumpAndSettle();
          expect(
            find
                .text(round == 4 ? 'Maç sonucunu gör' : 'Sonraki tur')
                .hitTestable(),
            findsOneWidget,
          );
          c.nextRound();
          await tester.pumpAndSettle();
        }
        expect(c.phase, FiveMatchPhase.finished);
        await reveal(tester, find.text('Yeniden oyna'));
        if (scale == 1) await capture(tester, 'result-dark');
        await tester.tap(find.text('Yeniden oyna'));
        await tester.pumpAndSettle();
        expect(c.phase, FiveMatchPhase.ready);
        expect(tester.takeException(), isNull, reason: '$size at $scale');
      }
    },
  );

  testWidgets(
    'Background and exit dialog freeze bot; cancel resumes and exit pops',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = await open(tester, navigator: true);
      c.begin();
      c.pass();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 10));
      expect(c.history, isEmpty);
      expect(c.phase, FiveMatchPhase.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(c.phase, FiveMatchPhase.playing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      expect(c.history, isEmpty);
      await tester.tap(find.text('Oyuna dön'));
      await tester.pumpAndSettle();
      expect(c.phase, FiveMatchPhase.playing);
      c.pause();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(c.phase, FiveMatchPhase.paused);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Çık'));
      await tester.pumpAndSettle();
      expect(find.text('Open Five'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
