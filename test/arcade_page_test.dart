import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/screens/arcade_page.dart';
import 'package:shared_xi/services/arcade_service.dart';

class ArcadeFixture extends ArcadeService {
  ArcadeFixture({this.stage = 'game', this.difficulty = 'normal', this.style = 'speed', this.offline = false, this.offlinePlayable = false});
  String stage, difficulty, style;
  bool offline, offlinePlayable;
  Map<String, dynamic>? sent;
  Map<String, dynamic> session(String mode) {
    final finished = stage == 'result'; final easy = difficulty == 'easy';
    final n = easy ? 4 : 5; final count = easy ? 6 : difficulty == 'hard' ? 12 : 8;
    final slots = <Map<String, dynamic>>[]; final filled = <String, dynamic>{};
    for (var row = 0, id = 0; row < n; row++) {
      for (var column = 0; column <= row; column++, id++) {
        slots.add({'id': '$id', 'row': row, 'column': column, 'supports': row < n - 1 ? ['${(row+1)*(row+2)~/2+column}', '${(row+1)*(row+2)~/2+column+1}'] : <String>[]});
        if (row == 0 || row == n-1) filled['$id'] = {'id': 'p$id', 'type': 'player', 'name': ['Zlatan Ibrahimović', 'Real Madrid', 'Clarence Seedorf', 'Arjen Robben', 'Hernán Crespo', 'Portekiz'][column]};
      }
    }
    return {'id': 'session-one', 'mode': mode, 'phase': stage == 'prepared' ? 'prepared' : 'active', 'revision': 3,
      'style': style, 'pairType': 'clubClub', 'difficulty': difficulty, 'paused': stage == 'paused', 'finished': finished,
      'won': finished, 'score': 1350, 'correct': mode == 'matching' ? 2 : 6, 'rounds': 2, 'streak': 6, 'bestStreak': 6,
      'lives': 5, 'hints': stage == 'hint' ? 1 : 0, 'freeUsed': stage == 'hint', 'adCredits': 0, 'adGranted': 0,
      'passes': 0, 'activeMs': 20000, 'totalRemainingMs': 100000, 'roundRemainingMs': 20000, 'serverNow': 100000,
      'moves': 4, 'lockUntil': stage == 'locked' ? 101000 : 0, 'stars': finished ? 3 : 0, 'earnedCoins': finished ? 2 : 0,
      'reason': finished ? 'Tüm bağları tamamladın!' : '', 'hint': stage == 'hint' ? 'Z. I. · Sweden' : '', 'message': '',
      if (mode == 'burst') ...{'question': {'id': 'q1', 'left': 'Real Madrid', 'right': 'Chelsea', 'difficulty': 'easy'},
        'found': [{'id': 'p1', 'name': 'Eden Hazard'}],
        if (finished) 'history': [{'title': 'Real Madrid × Chelsea', 'missed': ['Arjen Robben', 'Claude Makélélé']}]},
      if (mode == 'pyramid') ...{'board': {'id': 'p1', 'levels': n, 'slots': slots, 'initial': filled.keys.toList()}, 'filled': filled,
        'canUndo': false, if (finished) 'solution': filled},
      if (mode == 'matching') ...{'board': {'id': 'm1', 'count': count, 'cards': List.generate(count * 2, (i) =>
        {'id': 'card$i', 'visible': stage == 'locked' && i < 2 || finished,
          if (stage == 'locked' && i < 2 || finished) ...{'name': i.isEven ? 'Zlatan Ibrahimović' : 'Paris Saint-Germain', 'type': i.isEven ? 'player' : 'club', 'matched': finished}})},
        if (finished) 'proof': [{'player': 'Zlatan Ibrahimović', 'club': 'Paris Saint-Germain', 'sources': ['Reviewed senior career']}]},
    };
  }
  @override
  Future<Map<String, dynamic>> load(String mode) async => {'version': 'test-v1', 'availability': {'enabled': true, 'rewardsEnabled': true},
    'linked': true, 'energyCost': 1, 'offline': offline, 'offlinePlayable': offlinePlayable, if (offline) 'notice': 'Bağlantı yok. Kayıt korunuyor.',
    'session': stage == 'intro' ? null : session(mode), 'records': {'one': {'mode': mode, 'difficulty': difficulty, 'style': style,
      'pairType': 'clubClub', 'bestScore': 1350, 'bestRounds': 2, 'bestStreak': 6, 'bestCorrect': 6, 'sessions': 3, 'bestMoves': 12, 'bestTimeMs': 34000}},
    'medals': {}, 'paid': {}, 'pendingCoins': 0, 'recent': [], 'legacy': mode == 'burst' ? {'blitz': 45} : {}};
  @override
  Future<Map<String, dynamic>> mutate(Map<String, dynamic> input, {bool prepare = false}) async {
    sent = input; if (input['action'] == 'pause') stage = 'paused';
    if (input['action'] == 'resume' || input['action'] == 'confirm') stage = 'game';
    if (input['action'] == 'finish') stage = 'result';
    if (prepare) stage = 'prepared';
    return load('${input['mode']}');
  }
  @override
  Future<List<Map<String, dynamic>>> search(String mode, String sessionId, String query) async => [{'id': 'ronaldo', 'name': 'Ronaldo', 'type': 'player', 'country': 'Brazil'}];
}
final boundary = GlobalKey();
Future<void> mount(WidgetTester t, ArcadeFixture service, String mode, {bool light = false, bool large = false}) async {
  t.view.physicalSize = Size(large ? 320 : 390, 1100); t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(theme: light ? OrtakSahaTheme.light : OrtakSahaTheme.dark, builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
    textScaler: TextScaler.linear(large ? 1.8 : 1)), child: child!),
    home: RepaintBoundary(key: boundary, child: ArcadePage(key: UniqueKey(), mode: mode, service: service))));
  await t.pumpAndSettle();
}
Future<void> capture(WidgetTester t, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await t.runAsync(() async {
    final img = await (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio: 1);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final file = File('.dart_tool/arcade_qa/$name.png'); await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List()); img.dispose();
  });
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final e in [('Inter', 'assets/fonts/Inter-Body-Variable.ttf'), ('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf')]) {
      await (FontLoader(e.$1)..addFont(rootBundle.load(e.$2))).load();
    }
  });
  for (final mode in ['burst', 'pyramid', 'matching']) {
    for (final stage in ['intro', 'prepared', 'game', 'paused', 'result']) {
      testWidgets('$mode $stage is reachable and renders without overflow', (t) async {
        final fixture = ArcadeFixture(stage: stage); await mount(t, fixture, mode);
        expect(t.takeException(), isNull); await capture(t, '${mode}_$stage');
        if (stage == 'prepared') {
          await t.tap(find.text('Başlat')); await t.pumpAndSettle(); expect(fixture.sent?['action'], 'confirm');
          expect(fixture.sent?['revision'], 3);
        }
        await t.pumpWidget(const SizedBox.shrink()); await t.pump();
      });
    }
    for (final diff in ['easy', 'normal', 'hard']) {
      testWidgets('$mode $diff 320px large text layout', (t) async {
        await mount(t, ArcadeFixture(difficulty: diff), mode, large: true);
        expect(t.takeException(), isNull); await capture(t, '${mode}_${diff}_large');
        await t.drag(find.byType(ListView).first, const Offset(0, -450)); await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink()); await t.pump();
      });
    }
    testWidgets('$mode records are reachable and offline cannot spend', (t) async {
      await mount(t, ArcadeFixture(offline: true), mode);
      await t.tap(find.byTooltip('Rekor Merkezi')); await t.pumpAndSettle();
      expect(find.text('Kişisel rekorların'), findsOneWidget); await capture(t, '${mode}_records');
      await t.pumpWidget(const SizedBox.shrink()); await t.pump();
    });
  }
  testWidgets('closed matching cards reveal no names and 12/16/24 geometry', (t) async {
    for (final entry in {'easy': 12, 'normal': 16, 'hard': 24}.entries) {
      final fixture = ArcadeFixture(difficulty: entry.key); await mount(t, fixture, 'matching');
      expect(find.text('Zlatan Ibrahimović'), findsNothing); expect(find.text('Paris Saint-Germain'), findsNothing);
      final grid = t.widget<GridView>(find.byType(GridView));
      expect((grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount).crossAxisCount, entry.key == 'easy' ? 3 : 4);
      expect(grid.semanticChildCount, entry.value);
    }
    await t.pumpWidget(const SizedBox.shrink()); await t.pump();
  });
  testWidgets('Burst query selects global identity; survival hints do not cost life', (t) async {
    final fixture = ArcadeFixture(style: 'survival', stage: 'hint'); await mount(t, fixture, 'burst');
    await capture(t, 'burst_survival_hint');
    await t.enterText(find.byType(TextField), 'ron'); await t.pump(const Duration(milliseconds: 300)); await t.pumpAndSettle();
    await t.ensureVisible(find.text('Ronaldo')); await t.tap(find.text('Ronaldo')); await t.pumpAndSettle();
    expect(fixture.sent?['entityId'], 'ronaldo'); expect(fixture.sent?['questionId'], 'q1');
    await t.pumpWidget(const SizedBox.shrink()); await t.pump();
  });
  testWidgets('Matching mismatch disables all third taps', (t) async {
    final fixture = ArcadeFixture(stage: 'locked'); await mount(t, fixture, 'matching');
    expect(find.text('Kartları hatırla…'), findsOneWidget); await capture(t, 'matching_locked');
    final cardButtons = t.widgetList<OutlinedButton>(find.descendant(of: find.byType(GridView), matching: find.byType(OutlinedButton)));
    expect(cardButtons.every((b) => b.onPressed == null), isTrue);
    await t.pumpWidget(const SizedBox.shrink()); await t.pump();
  });
  testWidgets('offline Burst remains playable while canonical rewards wait for verification', (t) async {
    final fixture = ArcadeFixture(offline: true, offlinePlayable: true);
    await mount(t, fixture, 'burst');
    expect(t.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    await capture(t, 'burst_offline');
    await t.enterText(find.byType(TextField), 'Ronaldo');
    await t.ensureVisible(find.text('Cevabı kontrol et')); await t.tap(find.text('Cevabı kontrol et')); await t.pumpAndSettle();
    expect(fixture.sent?['query'], 'Ronaldo'); expect(fixture.sent?['elapsedMs'], isA<int>());
    await t.pumpWidget(const SizedBox.shrink()); await t.pump();
  });

}
