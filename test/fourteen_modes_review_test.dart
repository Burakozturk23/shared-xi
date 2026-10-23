import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/app/game_catalog.dart';
import 'package:shared_xi/app/route_appearance.dart';
import 'package:shared_xi/screens/career_transfer_page.dart';
import 'package:shared_xi/screens/mystery_chain_page.dart';
import 'package:shared_xi/screens/odd_club_page.dart';
import 'package:shared_xi/screens/daily_words_page.dart';
import 'package:shared_xi/screens/arcade_page.dart';
import 'package:shared_xi/screens/choice_page.dart';
import 'package:shared_xi/services/career_transfer_service.dart';
import 'package:shared_xi/services/game_error.dart';
import 'package:shared_xi/theme/app_theme.dart';
import 'package:shared_xi/widgets/game_ui.dart';
import 'career_transfer_page_test.dart' as career;
import 'mystery_chain_page_test.dart' as mystery;
import 'fake_club_page_test.dart' as fake;
import 'daily_words_page_test.dart' as words;
import 'arcade_page_test.dart' as arcade;
import 'choice_page_test.dart' as choice;
import 'game_design_standard_test.dart' as qa;

FirebaseFunctionsException missing() => FirebaseFunctionsException(code: 'not-found',
  message: 'NOT_FOUND\n#0 EnergyService.call (energy_service.dart:18)');
class Gate {
  bool failing = true;
  int reads = 0;
  void check() { reads++; if (failing) throw missing(); }
}
class RecoverCareer extends CareerTransferService {
  RecoverCareer(this.source, this.gate);
  final CareerTransferService source; final Gate gate;
  @override
  Future<Map<String,dynamic>> load(String mode) async { gate.check(); return source.load(mode); }
}
class RecoverWords extends words.WordFixture {
  RecoverWords(this.gate);
  final Gate gate;
  @override
  Future<Map<String,dynamic>> load(String mode) async { gate.check(); return super.load(mode); }
}
class RecoverArcade extends arcade.ArcadeFixture {
  RecoverArcade(this.gate);
  final Gate gate;
  @override
  Future<Map<String,dynamic>> load(String mode) async { gate.check(); return super.load(mode); }
}
class RecoverChoice extends choice.ChoiceFixture {
  RecoverChoice(this.gate);
  final Gate gate;
  @override
  Future<Map<String,dynamic>> load(String mode, {int offset = 0}) async { gate.check(); return super.load(mode, offset: offset); }
}
class UefaChoice extends choice.ChoiceFixture {
  UefaChoice({super.stage = 'intro'});
  final production = jsonDecode(File('functions/config/choice_catalog.json').readAsStringSync()) as Map;
  @override
  Future<Map<String,dynamic>> load(String mode, {int offset = 0}) async {
    final result = await super.load(mode, offset: offset);
    final metrics = (production['metrics'] as Map).values.map((m) => Map<String,dynamic>.from(m as Map)..remove('groups')).toList();
    result['catalog'] = {...Map<String,dynamic>.from(result['catalog'] as Map), 'metrics': metrics};
    if (result['session'] is Map) {
      final run = result['session'] as Map;
      run['metricId'] = 'uefa_ec_ucl_2023_appearances';
      run['metric'] = metrics.firstWhere((m) => m['id'] == run['metricId']);
      if (mode == 'higher_lower') (run['question'] as Map)['leftValue'] = 163;
    }
    return result;
  }
}
class ExpiredArcade extends arcade.ArcadeFixture {
  int writes = 0;
  @override
  Map<String,dynamic> session(String mode) => {...super.session(mode), 'totalRemainingMs': 1, 'roundRemainingMs': 1};
  @override
  Future<Map<String,dynamic>> mutate(Map<String,dynamic> input, {bool prepare = false}) async { writes++; throw missing(); }
}
Widget page(String mode, Gate gate) => switch (mode) {
  'career' || 'transfer' => CareerTransferPage(mode: mode, service: RecoverCareer(career.FakePuzzle(mode), gate)),
  'mystery' || 'mastermind' || 'blitz' => MysteryChainPage(mode: mode, service: RecoverCareer(mystery.FakeMysteryChain(mode), gate)),
  'fake_endless' || 'fake_speed' => OddClubPage(timed: mode == 'fake_speed',
    service: RecoverCareer(fake.FakeClubTransport(timed: mode == 'fake_speed', stage: 'game'), gate)),
  'daily_lingo' || 'passa_daily' || 'daily_anagram' || 'passa_weekly' => DailyWordsPage(mode: mode, service: RecoverWords(gate)),
  'burst' || 'pyramid' || 'matching' => ArcadePage(mode: mode, service: RecoverArcade(gate)),
  _ => ChoicePage(mode: mode, service: RecoverChoice(gate)),
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in [('Inter', 'assets/fonts/Inter-Body-Variable.ttf'), ('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf')]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
  });
  test('SDK details stay private; actionable business messages and uncertain replies remain accurate', () {
    for (final e in [missing(), FirebaseFunctionsException(code: 'internal', message: 'secret at backend.js:55'),
      StateError('secret https://backend.example/token')]) {
      expect(gameErrorMessage(e), isNot(contains('secret')));
      expect(gameErrorMessage(e), isNot(contains('NOT_FOUND')));
      expect(gameErrorMessage(e), isNot(contains('.dart:')));
    }
    expect(gameErrorMessage(TimeoutException('private')), contains('Gönderilmiş bir yanıt'));
    expect(gameErrorMessage(FirebaseFunctionsException(code: 'failed-precondition', message: 'Enerjin yetersiz.')), 'Enerjin yetersiz.');
  });
  // The 14 supplied screens plus shared-page variants (Sprint, timed fake club, weekly).
  for (final mode in ['career', 'transfer', 'mystery', 'mastermind', 'fake_endless',
    'daily_lingo', 'passa_daily', 'daily_anagram', 'burst', 'pyramid', 'matching',
    'this_or_that', 'higher_lower', 'blind_ranking', 'blitz', 'fake_speed', 'passa_weekly']) {
    for (final light in [false, true]) {
      testWidgets('$mode failure and real retry recovery ${light ? 'light large' : 'dark'}', (t) async {
        final gate = Gate();
        await qa.mount(t, page(mode, gate), light: light, large: light);
        expect(find.byType(GameErrorPanel), findsOneWidget);
        expect(find.textContaining('NOT_FOUND'), findsNothing);
        expect(find.textContaining('EnergyService.call'), findsNothing);
        expect(gate.reads, 1);
        expect(t.takeException(), isNull);
        await qa.capture(t, 'review_${mode}_error_$light');
        gate.failing = false;
        await t.ensureVisible(find.text('Tekrar dene')); await t.pump(); await t.tap(find.text('Tekrar dene'));
        await t.pump(); await t.pump(const Duration(milliseconds: 100));
        expect(gate.reads, 2);
        expect(find.byType(GameErrorPanel), findsNothing);
        expect(t.takeException(), isNull);
        // Return to the top after recovery, then check the lower controls too.
        final scroll = t.state<ScrollableState>(find.byType(Scrollable).first);
        scroll.position.jumpTo(0); await t.pump();
        await qa.capture(t, 'review_${mode}_game_$light');
        if (mode == 'pyramid') {
          final apex = t.getRect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Zlatan Ibrahimović').first);
          expect(apex.center.dx, closeTo(t.view.physicalSize.width / t.view.devicePixelRatio / 2, 2));
        }
        await t.drag(find.byType(Scrollable).first, const Offset(0, -600)); await t.pump();
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('failed Arcade timer write stops automatic retries and allows leaving the page', (t) async {
    final service = ExpiredArcade();
    await qa.mount(t, ArcadePage(mode: 'burst', service: service));
    await t.pump(const Duration(seconds: 3));
    expect(service.writes, 1);
    expect(find.byType(GameErrorPanel), findsOneWidget);
    await t.tap(find.byType(BackButton)); await t.pumpAndSettle();
    expect(find.byType(ArcadePage), findsNothing);
  });
  testWidgets('catalog entry routes preserve modern light and dark themes, including duplicate daily entries', (t) async {
    final titles = {'Career Puzzle','Transfer Detective','Gizemli Futbolcu','Kariyer Zinciri','Sahte Kulüp',
      'Futbol Lingo','Passaparola','Anagram','Burst','Pyramid','Matching','O mu Bu mu?','Higher or Lower','Blind Ranking'};
    final entries = [...GameCatalog.games.where((e) => titles.contains(e.title)), ...GameCatalog.dailyGames.skip(3)];
    expect(entries.length, 17);
    for (final light in [false, true]) {
      for (final entry in entries) {
        final observer = RouteAppearanceObserver();
        final nav = GlobalKey<NavigatorState>();
        await t.pumpWidget(MaterialApp(key: UniqueKey(), navigatorKey: nav,
          theme: light ? AppTheme.lightTheme : AppTheme.darkTheme, navigatorObservers: [observer],
          builder: (context, child) => ValueListenableBuilder<bool>(valueListenable: observer.legacy,
            builder: (context, legacy, _) => Theme(data: legacy ? AppTheme.legacyDarkTheme : Theme.of(context), child: child!)),
          home: const Scaffold()));
        nav.currentState!.push(LinkballRoute(modern: entry.modern, builder: (_) => const Scaffold(body: Text('route probe'))));
        await t.pumpAndSettle();
        final theme = Theme.of(t.element(find.text('route probe')));
        expect(observer.legacy.value, isFalse, reason: entry.title);
        expect(theme.colorScheme.primary, (light ? AppTheme.lightTheme : AppTheme.darkTheme).colorScheme.primary, reason: entry.title);
        expect(entry.requiresRepository, isFalse, reason: entry.title);
        await t.pumpWidget(const SizedBox()); observer.dispose();
      }
    }
  });
  for (final mode in ['higher_lower', 'blind_ranking']) {
    testWidgets('$mode production criteria select a verified metric and display historical scope', (t) async {
      final service = UefaChoice();
      await choice.mount(t, service, mode);
      expect(find.byType(GameErrorPanel), findsNothing);
      expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Oyunu hazırla')).onPressed, isNotNull);
      await t.ensureVisible(find.text('Oyunu hazırla')); await t.pump();
      await t.tap(find.text('Oyunu hazırla')); await t.pumpAndSettle();
      expect(service.sent?['metricId'], 'uefa_ec_ucl_2023_appearances');
      await choice.mount(t, UefaChoice(stage: 'game'), mode, light: true, large: true);
      expect(find.textContaining('1955–2023'), findsOneWidget);
      expect(find.textContaining('145 doğrulanmış futbolcu'), findsOneWidget);
      await choice.capture(t, '${mode}_verified_uefa_large');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
  testWidgets('unreviewed ranking defaults to playable personal lists while statistical gate stays closed', (t) async {
    await choice.mount(t, choice.ChoiceFixture(stage: 'intro', gated: true), 'blind_ranking');
    expect(find.text('Favorilerini sırala. Bu listede doğru sıra, puan veya rekor yok.'), findsOneWidget);
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Oyunu hazırla')).onPressed, isNotNull);
    await t.tap(find.text('İstatistik Sıralaması')); await t.pump();
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Oyunu hazırla')).onPressed, isNull);
  });
}
