import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/controllers/daily_footballer_controller.dart';
import 'package:shared_xi/models/daily_words.dart';
import 'package:shared_xi/screens/daily_footballer_page.dart';
import 'package:shared_xi/screens/daily_question_page.dart';
import 'package:shared_xi/screens/daily_words_page.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'package:shared_xi/widgets/hub_ui.dart';

import 'daily_footballer_test.dart' show MemoryFootballerStore, sampleCatalog;
import 'daily_question_page_test.dart' show sample;
import 'daily_words_page_test.dart' show WordFixture;

Future<void> _show(WidgetTester t, Widget page, {double height = 2600}) async {
  t.view.physicalSize = Size(390, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(theme: OrtakSahaTheme.dark, home: page));
  await t.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a fresh Lingo opens with its intro and focuses the guess', (
    t,
  ) async {
    await _show(
      t,
      DailyWordsPage(mode: 'daily_lingo', service: WordFixture()),
      height: 844,
    );
    for (final label in ['TARİH', 'MALİYET', 'HAK']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('0 enerji'), findsOneWidget);
    expect(find.text('GÜNLÜK MOD'), findsOneWidget);
    for (final legend in ['Doğru yer', 'Yanlış yer', 'Yok']) {
      expect(find.text(legend), findsOneWidget, reason: legend);
    }
    await t.tap(find.text('Kelimeyi bulmaya başla'));
    await t.pumpAndSettle();
    expect(
      t.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
  });

  testWidgets('the daily trio counts finished games', (t) async {
    await _show(
      t,
      DailyWordsPage(
        mode: 'passa_daily',
        service: WordFixture(stage: 'result'),
      ),
    );
    // The fixture marks Lingo complete for a finished day.
    expect(find.text('1 / 3 TAMAM'), findsOneWidget);
    // Results skip the intro.
    expect(find.text('GÜNLÜK MOD'), findsNothing);
  });

  testWidgets('Passaparola and Anagram intros show their real rules', (
    t,
  ) async {
    await _show(t, DailyWordsPage(mode: 'passa_daily', service: WordFixture()));
    expect(find.text('Süre serbest'), findsOneWidget);
    expect(find.text('Çemberi başlat'), findsOneWidget);
    expect(find.text('Haftalık Klasik'), findsOneWidget);

    await _show(
      t,
      DailyWordsPage(
        key: UniqueKey(),
        mode: 'daily_anagram',
        service: WordFixture(),
      ),
    );
    expect(find.text('KARIŞIK HARFLER'), findsOneWidget);
    expect(find.text('1 / 3 futbolcu'), findsOneWidget);
    expect(find.text('Harfleri çözmeye başla'), findsOneWidget);
    expect(find.text('Sekizli Pratik'), findsOneWidget);
  });

  testWidgets('Günün Futbolcusu previews the six compared traits', (t) async {
    final game = DailyFootballerController(
      catalog: sampleCatalog,
      store: MemoryFootballerStore(),
      clock: () => DateTime.utc(2026, 10, 29),
      watchAd: () async => false,
    );
    addTearDown(game.dispose);
    await _show(t, DailyFootballerPage(controller: game));
    expect(find.text('6 hak kaldı'), findsOneWidget);
    expect(find.text('6 KRİTER'), findsOneWidget);
    for (final trait in ['ÜLKE', 'KULÜP', 'LİG', 'MEVKİ', 'YAŞ', 'FORMA']) {
      expect(find.text(trait), findsOneWidget, reason: trait);
    }
  });

  testWidgets('Günün Sorusu marks the chosen option and its reset', (t) async {
    await _show(
      t,
      DailyQuestionPage(initialData: sample(), request: (_, _) async => {}),
    );
    expect(find.byType(DailyResetCountdown), findsOneWidget);
    expect(find.text('Seçildi'), findsNothing);
    await t.tap(find.text('1968–69'));
    await t.pumpAndSettle();
    expect(find.text('Seçildi'), findsOneWidget);
    unawaited(Future<void>.value());
  });

  test('shared results mark assisted runs with a puzzle piece', () {
    final session = {
      'mode': 'passa_daily',
      'period': '2026-10-29',
      'rounds': [
        {'status': 'correct'},
      ],
      'result': {'medal': 'Gümüş', 'solved': 1, 'assisted': true},
    };
    expect(dailyWordsShare(session), endsWith('Gümüş · 1 doğru · 🧩 Yardımlı'));
    session['result'] = {'medal': 'Altın', 'solved': 1};
    expect(dailyWordsShare(session), isNot(contains('🧩')));
  });
}
