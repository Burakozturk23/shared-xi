import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/screens/odd_club_page.dart';
import 'package:shared_xi/online/career_transfer_online_page.dart';
import 'package:shared_xi/online/online_mode_catalog.dart';
import 'package:shared_xi/services/career_transfer_service.dart';
import 'package:shared_xi/theme/app_theme.dart';

class FakeClubTransport extends CareerTransferService {
  FakeClubTransport({this.timed = false, this.stage = 'game', this.enabled = true});
  final bool timed, enabled;
  String stage;
  int? selected;
  List<int> eliminated = [];
  Map<String, dynamic>? mutation;
  static const clubs = [
    {'id': 985, 'name': 'Manchester United', 'badgeKey': 'c_985'},
    {'id': 418, 'name': 'Real Madrid', 'badgeKey': 'c_418'},
    {'id': 583, 'name': 'Paris Saint-Germain', 'badgeKey': 'c_583'},
    {'id': 131, 'name': 'FC Barcelona', 'badgeKey': 'c_131'},
  ];
  bool get finished => stage == 'result';
  bool get answered => stage == 'answer' || finished;
  Map<String, dynamic> get session => {'id': 'run', 'mode': timed ? 'fake_speed' : 'fake_endless',
    'revision': 1, 'dataVersion': 'fc-test', 'serverNow': DateTime.now().millisecondsSinceEpoch,
    'deadline': timed ? DateTime.now().millisecondsSinceEpoch + 10000 : null,
    'lives': 3, 'streak': answered ? 1 : 0, 'bestStreak': answered ? 1 : 0, 'score': answered ? 50 : 0,
    'correct': answered ? 1 : 0, 'answers': answered ? 1 : 0, 'questionNumber': 1,
    'free5050': eliminated.isEmpty, 'traceRemaining': 2, 'adCredits': 0, 'traceAvailable': true,
    'eliminated': eliminated, 'confirmed': [], 'finished': finished, 'answered': answered,
    'hintsUsed': eliminated.isEmpty ? 0 : 1, 'earnedCoins': 0, 'earnedXp': 0,
    'reason': finished ? 'Oturum kapatıldı; rekorların korundu.' : '',
    'question': {'questionId': 'q1', 'difficulty': 'easy', 'options': clubs,
      'player': {'id': 4000000023, 'name': 'David Beckham'}},
    if (answered) ...{'selectedId': selected ?? 131, 'wasCorrect': true, 'quick': false, 'points': 50,
      'fakeClubId': 131, 'explanation': 'David Beckham; Manchester United, Real Madrid, Paris Saint-Germain kulüplerinde oynadı. FC Barcelona için doğrulanmış A takım kaydı yok.',
      'evidence': {'sources': ['https://en.wikipedia.org/wiki/David_Beckham']}},
    'history': finished ? [{'player': {'name': 'David Beckham'}, 'correct': true, 'points': 50,
      'explanation': 'Üç doğrulanmış kulüp ve bir sahte kulüp.'}] : [],
  };
  @override
  Future<Map<String, dynamic>> load(String mode) async => {'version': 'fc-test', 'coins': 120, 'linked': true,
    'energy': {'available': 5, 'enabled': true}, 'energyCost': 1, 'pendingCoins': 0, 'inventory': [], 'records': {},
    'medals': {}, 'daily': null, 'availability': {'solo': enabled, 'rewards': enabled, 'friends': enabled, 'ranked': enabled},
    'session': stage == 'home' ? null : session};
  @override
  Future<Map<String, dynamic>> mutate(String call, Map<String, dynamic> input) async {
    mutation = input;
    if (input['action'] == 'answer') { selected = input['clubId'] as int; stage = 'answer'; }
    if (input['action'] == 'fifty') eliminated = [985, 418];
    if (input['action'] == 'next') { stage = 'game'; eliminated = []; }
    if (call == 'startFakeClub') stage = 'game';
    return {'session': session};
  }
  @override
  Future<Map<String, dynamic>> onlineLoad(String mode) async => {'version': 'fc-test',
    'availability': {'friends': enabled, 'ranked': enabled},
    if (stage != 'home') 'room': {'id': 'ABC12345', 'mode': mode, 'ranked': false, 'status': 'playing',
      'round': 0, 'totalRounds': 10, 'serverNow': 10000, 'startsAt': 9000, 'deadline': 19000,
      'roundToken': 'token', 'mine': {'score': 0}, 'theirs': {'score': 0},
      'question': {'kind': 'fake_club_duel', 'player': {'name': 'David Beckham'}, 'options': clubs}},
  };
  @override
  Future<Map<String, dynamic>> poll(Map<String, dynamic> input) => onlineLoad('${input['mode']}');
}
final boundary = GlobalKey();
Future<void> mount(WidgetTester t, Widget page, {bool light = false, double width = 390, double scale = 1}) async {
  t.view.physicalSize = Size(width, 1000); t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
    home: RepaintBoundary(key: boundary, child: page)));
  await t.pump(); await t.pump(const Duration(milliseconds: 100));
}
Future<void> capture(WidgetTester t, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await t.runAsync(() async {
    final image = await (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('.dart_tool/fake_club_qa/$name.png'); await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List()); image.dispose();
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
  test('fake club duel has a canonical online identity', () {
    expect(OnlinePlayModeX.fromWire('fake_club_duel'), OnlinePlayMode.fakeClubDuel);
    expect(OnlinePlayMode.fakeClubDuel.title, 'Sahte Kulüp Düellosu');
  });
  for (final timed in [false, true]) {
    testWidgets('SC15: ${timed ? 'speed' : 'endless'} home, question, reveal, result and records fit both themes', (t) async {
      for (final light in [false, true]) {
        for (final stage in ['home', 'game', 'answer', 'result', 'records']) {
          await mount(t, OddClubPage(timed: timed, service: FakeClubTransport(timed: timed, stage: stage)), light: light);
          if (stage == 'records') { await t.tap(find.byTooltip('Kulüp Dedektifi')); await t.pump(); }
          await capture(t, '${timed ? 'speed' : 'endless'}_${light ? 'light' : 'dark'}_$stage');
          expect(t.takeException(), isNull); await t.pumpWidget(const SizedBox());
        }
      }
      await mount(t, OddClubPage(timed: timed, service: FakeClubTransport(timed: timed)), width: 320, scale: 1.8);
      await t.drag(find.byType(ListView).first, const Offset(0, -700)); await t.pump();
      expect(t.takeException(), isNull);
      if (timed) {
        expect(find.textContaining('Reklam izle'), findsNothing); expect(find.textContaining('50/50'), findsNothing);
      }
      await t.pumpWidget(const SizedBox());
    });
  }
  testWidgets('SC08: 50/50 is server action; club answer contains ID, question and revision', (t) async {
    final fake = FakeClubTransport(); await mount(t, OddClubPage(timed: false, service: fake));
    final help = find.text('50/50 · oturumda 1 ücretsiz'); await t.ensureVisible(help); await t.tap(help); await t.pump();
    expect(fake.mutation!['action'], 'fifty'); expect(find.text('Elendi · oynadı'), findsNWidgets(2));
    final club = find.text('FC Barcelona'); await t.ensureVisible(club); await t.tap(club); await t.pumpAndSettle();
    expect(fake.mutation!['action'], 'answer'); expect(fake.mutation!['clubId'], 131);
    expect(fake.mutation!['questionId'], 'q1'); expect(fake.mutation!['revision'], 1);
    expect(find.textContaining('için doğrulanmış A takım kaydı yok.'), findsOneWidget);
    expect(t.takeException(), isNull); await t.pumpWidget(const SizedBox());
  });
  testWidgets('ON: four club cards, ten-second question, no help and stage gate in lobby', (t) async {
    for (final light in [false, true]) {
      await mount(t, CareerTransferOnlinePage(mode: 'fake_club_duel', service: FakeClubTransport()), light: light);
      expect(find.text('David Beckham'), findsOneWidget); expect(find.textContaining('Reklam izle'), findsNothing);
      expect(find.textContaining('Tur 1 / 10'), findsOneWidget);
      await capture(t, 'duel_${light ? 'light' : 'dark'}');
      expect(t.takeException(), isNull); await t.pumpWidget(const SizedBox());
    }
    await mount(t, CareerTransferOnlinePage(mode: 'fake_club_duel', service: FakeClubTransport()), width: 320, scale: 1.8);
    expect(t.takeException(), isNull); await t.pumpWidget(const SizedBox());
    await mount(t, CareerTransferOnlinePage(mode: 'fake_club_duel', service: FakeClubTransport(stage: 'home', enabled: false)));
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Arkadaş odası oluştur')).onPressed, isNull);
    expect(t.takeException(), isNull); await t.pumpWidget(const SizedBox());
  });
}
