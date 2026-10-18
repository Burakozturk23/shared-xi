import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/models/daily_words.dart';
import 'package:shared_xi/models/passaparola_question.dart';
import 'package:shared_xi/screens/daily_words_page.dart';
import 'package:shared_xi/screens/anagram_page.dart';
import 'package:shared_xi/services/daily_words_service.dart';
import 'package:shared_xi/theme/app_theme.dart';

class WordFixture extends DailyWordsService {
  WordFixture({this.stage = 'game', this.offline = false, this.longWord = false});
  String stage;
  bool offline, longWord;
  Map<String, dynamic>? sent;
  bool hint = false;
  String mixed = 'REGUL';
  final now = DateTime.now().millisecondsSinceEpoch;
  Map<String, dynamic> session(String mode) {
    final result = stage == 'result'; final lingo = mode == 'daily_lingo'; final anagram = mode == 'daily_anagram';
    final weekly = mode == 'passa_weekly';
    return {'mode': mode, 'period': '2026-10-19', 'packId': 'pack-test', 'contentVersion': 'dw-test',
      'revision': 3, 'serverNow': now, 'closesAt': now + 86400000, 'deadline': weekly ? now + 240000 : null,
      'finished': result, 'index': result && anagram ? 2 : 0, 'score': anagram && result ? 270 : 0,
      'attempts': result ? (lingo ? 2 : anagram ? 5 : weekly ? 29 : 7) : 0,
      'questionId': 'q-one', 'hintUsed': hint || stage == 'hint', 'hintAvailable': stage == 'hint',
      if (lingo) ...{'category': 'player', 'length': longWord ? 9 : 5,
        'guesses': stage == 'hint' ? [
          {'word': 'DZEKO', 'marks': ['absent', 'absent', 'absent', 'present', 'absent']},
          {'word': 'NEUER', 'marks': ['absent', 'present', 'exact', 'present', 'exact']},
          {'word': 'PIRLO', 'marks': ['absent', 'absent', 'present', 'present', 'absent']},
        ] : result ? [
          {'word': 'DZEKO', 'marks': ['absent', 'absent', 'absent', 'present', 'absent']},
          {'word': 'GULER', 'marks': ['exact', 'exact', 'exact', 'exact', 'exact']},
        ] : [], 'hint': 'Ülke: Türkiye', if (result) ...{'answer': 'GULER', 'display': 'Arda Güler'}},
      if (anagram) 'rounds': List.generate(3, (i) => {
        'status': result ? 'correct' : 'pending', 'guesses': result ? ['GULER'] : [],
        'bio': stage == 'hint', 'first': stage == 'hint', 'score': result ? 90 : 0,
        if (i == 0 || result) ...{'questionId': 'q-$i', 'scrambledLetters': mixed},
        if (stage == 'hint' && i == 0) ...{'hint': 'Türkiye · Orta saha', 'firstLetter': 'G'},
        if (result) ...{'answer': ['GULER', 'DEBRUYNE', 'GRIEZMANN'][i], 'name': ['Arda Güler', 'Kevin De Bruyne', 'Antoine Griezmann'][i]},
      }),
      if (!lingo && !anagram) ...{
        'question': {'id': 'q-one', 'letter': 'Ğ', 'rule': 'contains',
          'prompt': 'Ülke: Almanya. “İlkay …” adlı futbolcunun eksik isim parçası?', 'category': 'player',
          'difficulty': 2, 'passAvailable': stage != 'hint'},
        'rounds': (weekly ? PassaparolaAlphabet.letters : ['Ğ', 'H', 'L', 'A', 'B', 'Ç', 'Ü']).map((letter) => {
          'letter': letter, 'status': result ? 'correct' : 'pending', 'passed': stage == 'hint' && letter == 'Ğ',
          if (result) ...{'answer': 'Gündoğan', 'prompt': 'İlkay …?', 'explanation': 'İlkay Gündoğan · Almanya.'},
        }).toList(),
      },
      if (result) 'result': {'solved': lingo ? 1 : anagram ? 3 : weekly ? 29 : 7,
        'coins': weekly ? 2 : 3, 'xp': 6, 'score': anagram ? 270 : 0, 'medal': 'Ustalık',
        'reason': 'completed', 'eligibleForDailyBonus': !weekly, 'rewardEnabled': true},
    };
  }
  @override
  Future<Map<String, dynamic>> load(String mode) async => {
    'mode': mode, 'period': '2026-10-19', 'packId': 'pack-test', 'contentVersion': 'dw-test',
    'serverNow': now, 'availability': true, 'rewardsEnabled': true, 'linked': true, 'offline': offline,
    if (offline) 'notice': 'Çevrimdışısın. Son kayıt gösteriliyor.',
    'session': stage == 'intro' ? null : session(mode),
    'dailyCompletion': {'daily_lingo': stage == 'result', 'passa_daily': false, 'daily_anagram': false},
    'archive': {'streak': 4, 'days': List.generate(30, (i) => {'day': '2026-10-${(19 - i).abs().toString().padLeft(2, '0')}',
      'status': i < 4 ? 'completed' : 'missed', 'results': i < 4 ? {mode: {'medal': 'Altın', 'solved': 3}} : {}}),
      'weeks': [{'period': '2026-10-12', 'result': {'medal': 'Gümüş'}}]},
  };
  @override
  Future<Map<String, dynamic>> mutate(Map<String, dynamic> input) async {
    sent = input; if (input['action'] == 'hint') hint = true;
    if (input['action'] == 'shuffle') mixed = 'LERUG';
    return {'session': session('${input['mode']}')};
  }
  @override
  Future<Map<String, dynamic>> history(String mode, String period) async {
    stage = 'result'; return {'session': {...session(mode), 'period': period}, 'readOnly': true};
  }
}
final boundary = GlobalKey();
Future<void> mount(WidgetTester t, Widget child, {bool light = false, bool large = false}) async {
  t.view.physicalSize = Size(large ? 320 : 390, 1100); t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(large ? 1.8 : 1)), child: child!),
    home: RepaintBoundary(key: boundary, child: child)));
  await t.pumpAndSettle();
}
Future<void> capture(WidgetTester t, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await t.runAsync(() async {
    final picture = await (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio: 1);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    final f = File('.dart_tool/daily_words_qa/$name.png'); await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List()); picture.dispose();
  });
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final e in [('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'), ('Inter', 'assets/fonts/Inter-Body-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf')]) {
      await (FontLoader(e.$1)..addFont(rootBundle.load(e.$2))).load();
    }
  });
  test('29 letters, explicit aliases, Ğ contains and shared normalization', () {
    expect(PassaparolaAlphabet.letters.length, 29);
    const h = PassaparolaQuestion(id: 'h', letter: 'H', category: PassaparolaCategory.player,
      question: 'Tam adı?', answers: ['Harry Kane']);
    expect(h.matchesAnswer('Kane'), isFalse); expect(h.matchesAnswer('Harry Kane'), isTrue);
    const g = PassaparolaQuestion(id: 'g', letter: 'Ğ', category: PassaparolaCategory.player,
      question: 'İlkay …?', answers: ['Gündoğan']);
    expect(g.matchesAnswer('GUNDOGAN'), isTrue);
    expect(dailyWordKey('ı İ ğ Ç ö ü é ø ł'), 'IIGCOUEOL');
  });
  test('all share cards contain outcomes only; no solution or hidden letters', () {
    for (final mode in ['daily_lingo', 'passa_daily', 'passa_weekly', 'daily_anagram']) {
      final share = dailyWordsShare(WordFixture(stage: 'result').session(mode));
      expect(share, contains('2026-10-19'));
      for (final name in ['GULER', 'Güler', 'Gündoğan', 'DEBRUYNE', 'GRIEZMANN', 'DZEKO']) {
        expect(share, isNot(contains(name)));
      }
    }
  });
  for (final mode in ['daily_lingo', 'passa_daily', 'passa_weekly', 'daily_anagram']) {
    for (final light in [false, true]) {
      testWidgets('$mode ${light ? 'light' : 'dark'} game/hint/result/archives', (t) async {
        for (final stage in ['game', 'hint', 'result']) {
          await mount(t, DailyWordsPage(key: ValueKey('$mode-$stage'), mode: mode,
            service: WordFixture(stage: stage)), light: light);
          expect(t.takeException(), isNull);
          expect(find.text('0 enerji'), findsOneWidget);
          await capture(t, '${mode}_${light ? 'light' : 'dark'}_$stage');
          if (stage == 'result') {
            expect(find.text('Ustalık'), findsOneWidget);
            expect(find.text('Yanıtla'), findsNothing);
          }
        }
        await t.tap(find.byTooltip('30 günlük arşiv')); await t.pumpAndSettle();
        expect(find.text('Günlük seri · 4 gün'), findsOneWidget); expect(t.takeException(), isNull);
        await capture(t, '${mode}_${light ? 'light' : 'dark'}_archive');
        await t.pumpWidget(const SizedBox.shrink()); await t.pump();
      });
    }
    testWidgets('$mode fits 320px / 1.8 text without overflow', (t) async {
      await mount(t, DailyWordsPage(mode: mode, service: WordFixture(longWord: mode == 'daily_lingo')), large: true);
      expect(t.takeException(), isNull); await capture(t, '${mode}_large');
      await t.drag(find.byType(ListView).first, const Offset(0, -800)); await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink()); await t.pump();
    });
  }
  testWidgets('Lingo submits pinned identity and preserves typed text on offline read-only page', (t) async {
    final service = WordFixture();
    await mount(t, DailyWordsPage(mode: 'daily_lingo', service: service));
    await t.enterText(find.byType(TextField), 'DZEKO');
    await t.ensureVisible(find.text('Yanıtla')); await t.tap(find.text('Yanıtla')); await t.pumpAndSettle();
    expect(service.sent?['answer'], 'DZEKO'); expect(service.sent?['revision'], 3);
    expect(service.sent?['packId'], 'pack-test'); expect(service.sent?['questionId'], 'q-one');
    await mount(t, DailyWordsPage(key: const ValueKey('offline'), mode: 'daily_lingo', service: WordFixture(offline: true)));
    expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(t.takeException(), isNull);
  });
  testWidgets('Anagram tile input and safe shuffle use the same official session', (t) async {
    final service = WordFixture(); await mount(t, DailyWordsPage(mode: 'daily_anagram', service: service));
    await t.tap(find.widgetWithText(OutlinedButton, 'R').first); await t.pump();
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, 'R');
    await t.tap(find.text('Yeniden karıştır')); await t.pumpAndSettle();
    expect(service.sent?['action'], 'shuffle'); expect(service.sent?['packId'], 'pack-test');
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, '');
  });
  testWidgets('Passaparola cannot pass twice; weekly has explicit start and practice has separate entry', (t) async {
    await mount(t, DailyWordsPage(mode: 'passa_daily', service: WordFixture(stage: 'hint')));
    expect(t.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Pas')).onPressed, isNull);
    await mount(t, DailyWordsPage(key: const ValueKey('weekly'), mode: 'passa_weekly', service: WordFixture(stage: 'intro')));
    expect(find.text('240 saniyeyi başlat'), findsOneWidget); await capture(t, 'weekly_intro');
    await mount(t, const AnagramPage());
    expect(find.text('Sekizli Pratik'), findsOneWidget); expect(find.text('Günün Anagramı'), findsOneWidget);
    await capture(t, 'anagram_modes');
  });
}
