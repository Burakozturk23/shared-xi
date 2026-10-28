import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/screens/choice_page.dart';
import 'package:shared_xi/services/choice_service.dart';
import 'package:shared_xi/widgets/paid_hint_button.dart';

class ChoiceFixture extends ChoiceService {
  ChoiceFixture({
    this.stage = 'game',
    this.type = 'objective',
    this.size = 5,
    this.offline = false,
    this.gated = false,
    this.training = false,
  });
  String stage, type;
  int size;
  bool offline, gated, training;
  Map<String, dynamic>? sent;
  Map<String, dynamic> player(int i) => {
    'id': 'p$i',
    'name': [
      'Lionel Messi',
      'Cristiano Ronaldo',
      'Zlatan Ibrahimović',
      'Kevin De Bruyne',
      'Kylian Mbappé',
    ][i % 5],
    'country': 'Argentina',
    'position': 'Attack',
  };
  Map<String, dynamic> session(String mode) {
    final result = stage == 'result';
    return {
      'id': 'session1',
      'mode': mode,
      'phase': stage == 'prepared' ? 'prepared' : 'active',
      'revision': 1,
      'finished': result,
      'completed': result,
      'createdAt': 1000,
      'completedAt': result ? 100000 : null,
      if (training) ...{
        'training': true,
        'practice': true,
        'support': {
          'version': 1,
          'products': [
            {'id': 'boost_basic', 'priceCoins': 25, 'ads': true},
          ],
        },
      },
      'dataVersion': 'test-v1',
      'earnedCoins': result ? 2 : 0,
      'rewardKeys': [],
      if (mode == 'this_or_that') ...{
        'bracketId': 'prime_battles_32',
        'size': 16,
        'type': 'player',
        'roundSize': 16,
        'leftId': 'p0',
        'rightId': 'p1',
        'matchNumber': 1,
        'orderedCandidateIds': List.generate(16, (i) => 'p$i'),
        'candidates': {for (var i = 0; i < 16; i++) 'p$i': player(i)},
        'championId': result ? 'p0' : null,
        'history': result
            ? [
                {
                  'matchNumber': 15,
                  'leftId': 'p0',
                  'rightId': 'p1',
                  'winnerId': 'p0',
                },
              ]
            : [],
      },
      if (mode == 'higher_lower') ...{
        'metricId': 'peak_market_value',
        'streak': 10,
        'answered': result || stage == 'reveal',
        'correct': !result,
        'question': {
          'id': 'q1',
          'left': player(0),
          'right': player(1),
          'leftValue': 180000000,
          if (result || stage == 'reveal') 'rightValue': 120000000,
          'knownSide': 0,
          'difficulty': 'hard',
        },
      },
      if (mode == 'blind_ranking') ...{
        'type': type,
        'size': size,
        'metricId': 'peak_market_value',
        'themeId': 'favorites',
        if (!result) 'current': player(0),
        'placements': result
            ? List.generate(
                size,
                (i) => {'slot': i, 'candidateId': 'p$i', 'player': player(i)},
              )
            : [],
        if (result && type == 'objective') ...{
          'score': 80,
          'exactMatches': 3,
          'comparable': 10,
          'values': {
            for (var i = 0; i < size; i++) 'p$i': (size - i) * 10000000,
          },
        },
      },
    };
  }

  @override
  Future<Map<String, dynamic>> load(String mode, {int offset = 0}) async => {
    'version': 'test-v1',
    'availability': {'enabled': true, 'rewardsEnabled': true},
    'linked': true,
    'energyCost': 1,
    'offline': offline,
    'notice': offline ? 'Çevrimdışı kayıt korunuyor.' : null,
    'session': stage == 'intro' ? null : session(mode),
    'records': {},
    'archive': [],
    'daily': {},
    'catalog': {
      'themes': [
        {
          'id': 'prime_battles_32',
          'title': 'Zirve Sezonlar',
          'type': 'player',
          'candidateCount': 128,
          'formats': [
            16,
            32,
            64,
            128,
          ].map((n) => {'size': n, 'approved': !gated}).toList(),
        },
      ],
      'metrics': [
        {
          'id': 'peak_market_value',
          'label': 'Zirve Piyasa Değeri',
          'unit': 'EUR',
          'gatePassed': !gated,
          'reason': 'Kaynak incelemesi bekleniyor.',
        },
      ],
      'personal': [
        {'id': 'favorites', 'label': 'Genel Favoriler'},
      ],
    },
  };
  @override
  Future<Map<String, dynamic>> mutate(
    Map<String, dynamic> input, {
    bool prepare = false,
  }) async {
    sent = input;
    if (prepare) stage = 'prepared';
    if (input['action'] == 'confirm') stage = 'game';
    if (input['action'] == 'guess') stage = 'reveal';
    if (input['action'] == 'finish') stage = 'result';
    return load('${input['mode']}');
  }
}

final boundary = GlobalKey();
Future<void> mount(
  WidgetTester t,
  ChoiceFixture service,
  String mode, {
  bool light = false,
  bool large = false,
  bool records = false,
}) async {
  t.view.physicalSize = Size(large ? 320 : 390, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      theme: light ? OrtakSahaTheme.light : OrtakSahaTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(large ? 1.8 : 1)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: boundary,
        child: ChoicePage(
          key: UniqueKey(),
          mode: mode,
          service: service,
          recordsInitially: records,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> capture(WidgetTester t, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await t.runAsync(() async {
    final image =
        await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('.dart_tool/choice_qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final e in [
      ('Inter', 'assets/fonts/Inter-Body-Variable.ttf'),
      ('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(e.$1)..addFont(rootBundle.load(e.$2))).load();
    }
  });
  for (final mode in ['higher_lower', 'blind_ranking']) {
    testWidgets(
      '$mode training support binds current question and refuses offline spending',
      (t) async {
        final fixture = ChoiceFixture(training: true);
        await mount(t, fixture, mode, large: true);
        await t.scrollUntilVisible(
          find.byType(PaidHintButton).hitTestable(),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        final button = t.widget<PaidHintButton>(find.byType(PaidHintButton));
        expect(button.disabled, isFalse);
        await button.onUse({
          'boostId': 'boost_basic',
          'paymentSource': 'coins',
          'expectedPriceCoins': 25,
        });
        await t.pumpAndSettle();
        expect(fixture.sent?['action'], 'hint');
        expect(
          fixture.sent?['questionId'],
          mode == 'higher_lower' ? 'q1' : 'p0',
        );
        expect(fixture.sent?['expectedPriceCoins'], 25);
        expect(t.takeException(), isNull);
        await mount(t, ChoiceFixture(training: true, offline: true), mode);
        expect(
          t.widget<PaidHintButton>(find.byType(PaidHintButton)).disabled,
          isTrue,
        );
      },
    );
  }
  for (final mode in ['this_or_that', 'higher_lower', 'blind_ranking']) {
    for (final stage in ['intro', 'prepared', 'game', 'result']) {
      testWidgets('$mode $stage reachable without overflow', (t) async {
        final fixture = ChoiceFixture(stage: stage);
        await mount(t, fixture, mode);
        expect(t.takeException(), isNull);
        await capture(t, '${mode}_$stage');
        if (stage == 'prepared') {
          await t.tap(find.text('Başlat'));
          await t.pumpAndSettle();
          expect(fixture.sent?['action'], 'confirm');
        }
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
      });
    }
    testWidgets('$mode 320px large text setup and gameplay', (t) async {
      for (final stage in ['intro', 'game']) {
        await mount(t, ChoiceFixture(stage: stage), mode, large: true);
        expect(t.takeException(), isNull);
        await capture(t, '${mode}_${stage}_large');
        if (mode == 'blind_ranking' && stage == 'intro') {
          await t.ensureVisible(find.text('Benim Sıralamam'));
          await t.tap(find.text('Benim Sıralamam'));
          await t.pumpAndSettle();
          expect(find.text('Genel Favoriler'), findsOneWidget);
          expect(t.takeException(), isNull);
          await t.ensureVisible(find.text('İstatistik Sıralaması'));
          await t.tap(find.text('İstatistik Sıralaması'));
          await t.pumpAndSettle();
          expect(find.text('Genel Favoriler'), findsNothing);
          expect(t.takeException(), isNull);
        }
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
      }
    });
    testWidgets('$mode collection is reachable', (t) async {
      await mount(t, ChoiceFixture(), mode, records: true);
      expect(find.text('Koleksiyon ve rekorlar'), findsOneWidget);
      expect(t.takeException(), isNull);
      await capture(t, '${mode}_records');
    });
  }
  testWidgets('ranking slot selection previews before explicit confirmation', (
    t,
  ) async {
    final fixture = ChoiceFixture();
    await mount(t, fixture, 'blind_ranking');
    await t.tap(find.text('2. Boş sıra'));
    await t.pumpAndSettle();
    expect(fixture.sent, isNull);
    await t.ensureVisible(find.text('2. sıraya yerleştir'));
    await capture(t, 'ranking_preview');
    await t.tap(find.text('2. sıraya yerleştir'));
    await t.pumpAndSettle();
    expect(fixture.sent?['action'], 'place');
    expect(fixture.sent?['slot'], 1);
    expect(fixture.sent?['candidateId'], 'p0');
  });
  testWidgets('personal ten-player result has no objective score', (t) async {
    await mount(
      t,
      ChoiceFixture(stage: 'result', type: 'personal', size: 10),
      'blind_ranking',
    );
    expect(find.text('Benim Sıralamam'), findsOneWidget);
    expect(find.textContaining('/ 100'), findsNothing);
    expect(find.textContaining('tam sıra'), findsNothing);
    await capture(t, 'personal_result');
  });
  testWidgets('higher/lower hides value until guess and then requires next', (
    t,
  ) async {
    final fixture = ChoiceFixture();
    await mount(t, fixture, 'higher_lower');
    expect(find.text('€120.000.000'), findsNothing);
    await t.ensureVisible(find.text('Daha düşük'));
    await t.tap(find.text('Daha düşük'));
    await t.pumpAndSettle();
    expect(find.text('€120.000.000'), findsOneWidget);
    expect(find.text('Sonraki çift'), findsOneWidget);
    expect(find.text('Daha düşük'), findsNothing);
    await capture(t, 'higher_reveal');
  });
  testWidgets('unreviewed metric cannot start', (t) async {
    await mount(t, ChoiceFixture(stage: 'intro', gated: true), 'higher_lower');
    final b = t.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Oyunu hazırla'),
    );
    expect(b.onPressed, isNull);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    await capture(t, 'metric_locked');
  });
  testWidgets('offline tournament choices remain actionable', (t) async {
    final fixture = ChoiceFixture(offline: true);
    await mount(t, fixture, 'this_or_that');
    await t.tap(find.text('Seç: Lionel Messi'));
    await t.pumpAndSettle();
    expect(fixture.sent?['action'], 'choose');
  });
  testWidgets(
    'objective result exposes reference order only after completion',
    (t) async {
      await mount(t, ChoiceFixture(stage: 'result'), 'blind_ranking');
      await t.ensureVisible(find.text('Doğru sıralama'));
      await t.tap(find.text('Doğru sıralama'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('Eşit değerler aynı sırayı paylaşır'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
      await capture(t, 'objective_reference');
    },
  );
  testWidgets('PNG card includes valid bytes', (t) async {
    final r = ChoiceFixture(
      stage: 'result',
      type: 'personal',
      size: 10,
    ).session('blind_ranking');
    await t.runAsync(() async {
      final bytes = await choiceSharePng(r);
      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(bytes.length, greaterThan(1000));
    });
  });
}
