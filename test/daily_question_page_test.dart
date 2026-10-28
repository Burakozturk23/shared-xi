import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/screens/daily_question_page.dart';
import 'package:shared_xi/widgets/energy_sheet.dart';
import 'package:shared_xi/widgets/paid_hint_button.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';

Map<String, dynamic> sample() => {
  'question': {
    'id': 'q_test',
    'day': '2026-10-14',
    'category': 'turkey',
    'prompt':
        'Göztepe, Fuar Şehirleri Kupası’nda hangi sezonda yarı finale yükseldi?',
    'options': ['1966–67', '1968–69', '1969–70'],
  },
  'streak': 6,
  'total': 29,
  'pro': false,
  'eliminated': null,
  'result': null,
};
Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await t.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final f = File('.dart_tool/energy_qa/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
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
  testWidgets(
    'paid quiz binds displayed day and price and removes legacy Pro ad button',
    (t) async {
      final value = {
        ...sample(),
        'pro': true,
        'session': {
          'id': 'quiz-run',
          'revision': 0,
          'support': {
            'version': 1,
            'products': [
              {'id': 'boost_eliminate', 'priceCoins': 35, 'ads': true},
            ],
          },
        },
      };
      Map<String, dynamic>? sent;
      await t.pumpWidget(
        MaterialApp(
          home: DailyQuestionPage(
            initialData: value,
            request: (name, input) async {
              expect(name, 'useDailyQuestionHint');
              sent = input;
              return {...value, 'eliminated': 0};
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.byType(PaidHintButton).hitTestable(),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Pro ipucu · bir yanlışı ele'), findsNothing);
      await t.widget<PaidHintButton>(find.byType(PaidHintButton)).onUse({
        'boostId': 'boost_eliminate',
        'paymentSource': 'coins',
        'expectedPriceCoins': 35,
      });
      await t.pumpAndSettle();
      expect(sent?['day'], '2026-10-14');
      expect(sent?['questionId'], 'q_test');
      expect(sent?['sessionId'], 'quiz-run');
      expect(sent?['expectedPriceCoins'], 35);
      expect(
        t.widget<PaidHintButton>(find.byType(PaidHintButton)).disabled,
        isTrue,
      );
      expect(t.takeException(), isNull);
    },
  );
  for (final light in [false, true]) {
    testWidgets(
      'daily quiz selects once, shows receipt, fits narrow screen light=$light',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final key = GlobalKey();
        var submits = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: light ? OrtakSahaTheme.light : OrtakSahaTheme.dark,
            home: RepaintBoundary(
              key: key,
              child: DailyQuestionPage(
                initialData: sample(),
                request: (name, input) async {
                  expect(name, 'submitDailyQuestion');
                  expect(input['option'], 1);
                  submits++;
                  return {
                    ...sample(),
                    'streak': 7,
                    'total': 30,
                    'result': {
                      'correct': true,
                      'option': 1,
                      'answer': 1,
                      'coins': 28,
                      'xp': 40,
                      'bonus': true,
                      'explanation':
                          'Göztepe 1968–69 sezonunda yarı finale ulaştı.',
                      'sources': [
                        {'url': 'https://goztepe.org.tr/Kulup/Tarihce'},
                      ],
                    },
                  };
                },
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Cevabımı gönder'), findsOneWidget);
        expect(
          t
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Cevabımı gönder'),
              )
              .onPressed,
          isNull,
        );
        await capture(t, key, 'question-${light ? "light" : "dark"}');
        await t.tap(find.byKey(const ValueKey('quiz-option-1')));
        await t.pump();
        await t.ensureVisible(find.text('Cevabımı gönder'));
        await t.tap(find.text('Cevabımı gönder'));
        await t.pumpAndSettle();
        expect(submits, 1);
        expect(find.text('Cevabımı gönder'), findsNothing);
        expect(find.text('+28 Link Coin · +40 XP'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.ensureVisible(find.text('Futbol bilgine sağlık!'));
        await t.pumpAndSettle();
        await capture(t, key, 'result-${light ? "light" : "dark"}');
      },
    );
    testWidgets('energy panel has capacity-aware offers light=$light', (
      t,
    ) async {
      t.view.physicalSize = const Size(320, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await t.pumpWidget(
        MaterialApp(
          theme: light ? OrtakSahaTheme.light : OrtakSahaTheme.dark,
          home: RepaintBoundary(
            key: key,
            child: const Scaffold(
              body: EnergySheet(
                initialData: {
                  'enabled': true,
                  'balance': 4,
                  'reserved': 0,
                  'serverNow': 100000,
                  'nextRefillAt': 1300000,
                  'pro': true,
                  'daily': {'ads': 0, 'purchases': 0, 'pro': false},
                },
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('4 / 6'), findsOneWidget);
      expect(
        t
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '+5 enerji · 60 Link Coin'),
            )
            .onPressed,
        isNull,
      );
      expect(
        t
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '+2 enerji · 25 Link Coin'),
            )
            .onPressed,
        isNotNull,
      );
      expect(t.takeException(), isNull);
      await capture(t, key, 'energy-${light ? "light" : "dark"}');
    });
  }
}
