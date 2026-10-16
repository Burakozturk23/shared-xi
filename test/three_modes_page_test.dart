import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/screens/three_modes_page.dart';
import 'package:shared_xi/services/three_modes_service.dart';
import 'package:shared_xi/theme/app_theme.dart';

class FakeModes extends ThreeModesService {
  FakeModes(this.mode, {this.active = false});
  final String mode;
  bool active;
  String? searched;
  Map<String, dynamic>? lastMutation;
  final List<String> positions = ['FWD', 'FWD', 'FWD', 'MID', 'MID', 'MID', 'DEF', 'DEF', 'DEF', 'DEF', 'GK'];
  Map<String, dynamic> get session => {
    'id': 'test-run', 'mode': mode, 'entry': 'random', 'targetId': 'A',
    'title': mode == 'squad_vault' ? 'Gizli kulüp' : mode == 'coach_xi' ? 'Pep Guardiola' : 'A harfi',
    'formation': '433', 'formations': ['433', '442', '352', '4231', '451'], 'revision': 0,
    'finished': false, 'score': 0, 'wrong': 0, 'hints': [], 'freeHint': true, 'adCredits': 0,
    'adRemaining': 2, 'remaining': 5, 'stars': 5,
    'coverage': 'Doğrulanamayan bağlar yanlış sayılmaz.',
    'historyNote': 'Farklı dönemlerin kadrosu; aynı sezon değildir.',
    'slots': List.generate(11, (i) => {'slot': i, 'position': positions[i], 'player': null,
      'country': mode == 'squad_vault' && i < 3 ? ['Brazil', 'England', 'France'][i] : null}),
  };
  @override
  Future<Map<String, dynamic>> load(String mode) async => {'version': 'test', 'mode': mode,
    'session': active ? session : null, 'linked': true, 'dailyUsed': false, 'leagueSnapshot': 'test',
    'entries': [{'id': 'A', 'name': mode == 'coach_xi' ? 'Pep Guardiola' : mode == 'squad_vault' ? 'Kilitli kasa' : 'A',
      'formations': ['433', '442'], 'count': 120, 'league': 'Premier League', 'record': null}]};
  @override
  Future<Map<String, dynamic>> mutate(String name, Map<String, dynamic> input) async {
    lastMutation = input; active = true; return {'session': session};
  }
  @override
  Future<Map<String, dynamic>> search(Map<String, dynamic> input) async {
    searched = '${input['query']}';
    return {'results': [{'id': 1, 'name': mode == 'squad_vault' ? 'Arsenal' : 'Lionel Messi',
      'country': 'Argentina', 'position': 'FWD', 'league': 'Premier League'}]};
  }
  @override
  Future<void> watchHint(String mode, String sessionId) async {}
}
final boundary = GlobalKey();
Future<void> open(WidgetTester t, FakeModes f, {double width = 390, double scale = 1, bool light = false}) async {
  t.view.physicalSize = Size(width, 900); t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
    home: RepaintBoundary(key: boundary, child: ThreeModesPage(mode: f.mode, service: f))));
  await t.pumpAndSettle();
}
Future<void> capture(WidgetTester t, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await t.runAsync(() async {
    final image = await (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final f = File('.dart_tool/three_modes_qa/$name.png'); await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List()); image.dispose();
  });
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry in [('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'), ('Inter', 'assets/fonts/Inter-Body-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf')]) {
      await (FontLoader(entry.$1)..addFont(rootBundle.load(entry.$2))).load();
    }
  });
  for (final mode in ['coach_xi', 'letter11', 'squad_vault']) {
    testWidgets('$mode landing and resumed pitch render in both themes and large type', (t) async {
      for (final light in [false, true]) {
        final fake = FakeModes(mode);
        await open(t, fake, light: light);
        await capture(t, '${mode}_${light ? 'light' : 'dark'}_home');
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await open(t, FakeModes(mode, active: true), light: light);
        await capture(t, '${mode}_${light ? 'light' : 'dark'}_pitch');
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      }
      await open(t, FakeModes(mode, active: true), width: 320, scale: 2);
      await t.drag(find.byType(ListView).first, const Offset(0, -700)); await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('search keeps unrelated known players visible and validates only selected identity', (t) async {
    final fake = FakeModes('letter11', active: true); await open(t, fake);
    await t.scrollUntilVisible(find.byType(TextField), 250, scrollable: find.byType(Scrollable).first);
    await t.enterText(find.byType(TextField), 'Messi'); await t.pump(const Duration(milliseconds: 400)); await t.pumpAndSettle();
    expect(fake.searched, 'Messi');
    await t.ensureVisible(find.text('Lionel Messi')); await t.tap(find.text('Lionel Messi')); await t.pumpAndSettle();
    expect(fake.lastMutation!['action'], 'place'); expect(fake.lastMutation!['playerId'], 1);
    expect(fake.lastMutation!['slot'], 0); expect(t.takeException(), isNull);
  });
  testWidgets('daily entry and vault guess use the same persisted server contract', (t) async {
    final fake = FakeModes('letter11'); await open(t, fake);
    final daily = find.text('Günün harfi · Ücretsiz');
    await t.scrollUntilVisible(daily, 250, scrollable: find.byType(Scrollable).first);
    await t.tap(daily); await t.pumpAndSettle(); expect(fake.lastMutation!['entry'], 'daily');
    await t.pumpWidget(const SizedBox());
    final vault = FakeModes('squad_vault', active: true); await open(t, vault);
    await t.scrollUntilVisible(find.byType(TextField), 250, scrollable: find.byType(Scrollable).first);
    await t.enterText(find.byType(TextField), 'Arsenal'); await t.pump(const Duration(milliseconds: 400)); await t.pumpAndSettle();
    await t.ensureVisible(find.text('Arsenal')); await t.tap(find.text('Arsenal')); await t.pumpAndSettle();
    expect(vault.lastMutation!['action'], 'guess'); expect(vault.lastMutation!['clubId'], 1);
  });
}
