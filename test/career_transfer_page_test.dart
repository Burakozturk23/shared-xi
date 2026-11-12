import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/screens/career_transfer_page.dart';
import 'package:shared_xi/online/career_transfer_online_page.dart';
import 'package:shared_xi/services/career_transfer_service.dart';
import 'package:shared_xi/theme/app_theme.dart';
import 'package:shared_xi/widgets/hub_ui.dart';

class FakePuzzle extends CareerTransferService {
  FakePuzzle(
    this.mode, {
    this.phase = 'guess',
    this.active = true,
    this.extra = const {},
    this.question,
    this.revealAnswer,
    this.rivalAnswer,
  });

  /// The revealed answer and the rival's (an order round reveals a list).
  final Object? revealAnswer, rivalAnswer;
  final String mode;
  final Map<String, dynamic> extra;

  /// Overrides the online round's question (Career Race order / mystery).
  final Map<String, dynamic>? question;
  String phase;
  bool active;
  Map<String, dynamic>? mutation;
  final stops = [
    {
      'id': 'period_a',
      'club': {'id': 985, 'name': 'Manchester United', 'badgeKey': 'c_985'},
      'visit': 2,
    },
    {
      'id': 'period_b',
      'club': {'id': 418, 'name': 'Real Madrid', 'badgeKey': 'c_418'},
    },
    {
      'id': 'period_c',
      'club': {'id': 985, 'name': 'Manchester United', 'badgeKey': 'c_985'},
      'visit': 2,
    },
  ];
  Map<String, dynamic> get session => {
    'id': 'run',
    'mode': mode,
    'phase': phase,
    'wrong': 0,
    'checks': 0,
    'revision': 0,
    'score': phase == 'order' ? 25 : 0,
    'streak': 2,
    'finished': false,
    'found': phase == 'order',
    'hints': [],
    'freeHint': true,
    'adCredits': 0,
    'adRemaining': 2,
    'stops': stops,
    'correctness': [],
    'transfer': {
      'from': {'id': 506, 'name': 'Juventus', 'badgeKey': 'c_506'},
      'to': {'id': 985, 'name': 'Manchester United', 'badgeKey': 'c_985'},
      'year': 2021,
    },
    if (phase == 'order') 'player': {'name': 'Cristiano Ronaldo'},
    'maxChecks': 2,
    ...extra,
  };
  @override
  Future<Map<String, dynamic>> load(String mode) async => {
    'version': 'test',
    'coins': 120,
    'linked': true,
    'energy': {'available': 5, 'enabled': true},
    'inventory': [],
    'collection': [],
    'pendingCoins': 0,
    'session': active ? session : null,
  };
  @override
  Future<Map<String, dynamic>> mutate(
    String call,
    Map<String, dynamic> input,
  ) async {
    mutation = input;
    active = true;
    if (input['action'] == 'guess') phase = 'order';
    return {'session': session};
  }

  @override
  Future<Map<String, dynamic>> search(Map<String, dynamic> input) async => {
    'results': [
      {
        'id': 8198,
        'name': 'Cristiano Ronaldo',
        'country': 'Portugal',
        'position': 'FWD',
      },
    ],
  };
  @override
  Future<Map<String, dynamic>> onlineLoad(String mode) async => {
    'version': 'test',
    'room': {
      'id': 'ABC12345',
      'mode': mode,
      'ranked': true,
      'status': 'playing',
      'round': 0,
      'totalRounds': mode == 'career_race' ? 6 : 5,
      'serverNow': 10000,
      'startsAt': 9000,
      'deadline': 30000,
      'mine': {'score': 0},
      'theirs': {'score': 0},
      'submitted': false,
      if (phase == 'reveal') ...{
        'reveal': revealAnswer ?? 1,
        'opponentAnswer': rivalAnswer ?? 2,
        'correct': false,
        if (revealAnswer == null)
          'explanation': 'Cristiano Ronaldo · 2021-08-31 · 36 yaşında',
      },
      'question': question != null
          ? question!
          : mode == 'career_race'
          ? {
              'kind': 'missing',
              'difficulty': 'normal',
              'player': {'name': 'Cristiano Ronaldo'},
              'route': ['Sporting', '?', 'Real Madrid'],
              'years': ['2002', '2003', '2009'],
              'options': [
                {'id': 1, 'name': 'Manchester United'},
                {'id': 2, 'name': 'Galatasaray'},
                {'id': 3, 'name': 'Barcelona'},
                {'id': 4, 'name': 'Milan'},
              ],
            }
          : {
              'kind': 'transfer',
              'difficulty': 'hard',
              'from': {'name': 'Juventus'},
              'to': {'name': 'Manchester United'},
              'year': 2021,
              'month': '08',
              'hints': ['Milliyet: Portugal'],
            },
    },
  };
  @override
  Future<Map<String, dynamic>> poll(Map<String, dynamic> input) async =>
      onlineLoad('${input['mode']}');
}

final boundary = GlobalKey();
Future<void> mount(
  WidgetTester t,
  Widget page, {
  bool light = false,
  double width = 390,
  double scale = 1,
}) async {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(key: boundary, child: page),
    ),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
}

Future<void> capture(WidgetTester t, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await t.runAsync(() async {
    final image =
        await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('.dart_tool/career_transfer_qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final e in [
      ('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'),
      ('Inter', 'assets/fonts/Inter-Body-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(e.$1)..addFont(rootBundle.load(e.$2))).load();
    }
  });
  testWidgets('career difficulty is a segmented choice sent on start', (
    t,
  ) async {
    final f = FakePuzzle('career', active: false);
    await mount(t, CareerTransferPage(mode: 'career', service: f));
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.byWidgetPredicate((w) => w is HubSegmented), findsOneWidget);
    expect(find.text('ZORLUK'), findsOneWidget);
    // Rules are visible notes, not hidden in a collapsed tile.
    expect(
      find.textContaining('1 ücretsiz + 2 reklamlı ipucu'),
      findsOneWidget,
    );
    await t.ensureVisible(find.text('Efsane\n8–12 dönem'));
    await t.tap(find.text('Efsane\n8–12 dönem'));
    await t.pump();
    await t.ensureVisible(find.text('Yeni bulmaca'));
    await t.tap(find.text('Yeni bulmaca'));
    await t.pump();
    expect(f.mutation!['difficulty'], 'legend');
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('transfer level and today\'s file are sent on start', (t) async {
    final f = FakePuzzle('transfer', active: false);
    await mount(t, CareerTransferPage(mode: 'transfer', service: f));
    expect(find.byWidgetPredicate((w) => w is HubSegmented), findsOneWidget);
    expect(find.text('Karışık'), findsOneWidget);
    expect(
      find.textContaining('1 ücretsiz + 2 reklamlı ipucu'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Seri yalnızca ilk denemelerde'),
      findsOneWidget,
    );
    await t.ensureVisible(find.text('Zor'));
    await t.tap(find.text('Zor'));
    await t.pump();
    await t.ensureVisible(find.text('Yeni transfer dosyası'));
    await t.tap(find.text('Yeni transfer dosyası'));
    await t.pump();
    expect(f.mutation!['difficulty'], 'hard');
    await t.pumpWidget(const SizedBox());
    final daily = FakePuzzle('transfer', active: false);
    await mount(t, CareerTransferPage(mode: 'transfer', service: daily));
    await t.scrollUntilVisible(
      find.text('Günün transferi'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.text('Günün transferi'));
    await t.pump();
    expect(daily.mutation!['daily'], true);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'finished transfer explains shared moves, badge reward and shares without the name',
    (t) async {
      final f = FakePuzzle(
        'transfer',
        phase: 'result',
        extra: {
          'finished': true,
          'found': true,
          'wrong': 1,
          'score': 120,
          'streak': 5,
          'hints': [
            {'kind': 'country', 'text': 'Italy'},
          ],
          'answer': {'id': 7, 'name': 'Andrea Belotti'},
          'transfer': {
            'from': {'id': 416, 'name': 'Torino', 'badgeKey': 'c_416'},
            'to': {'id': 800, 'name': 'Atalanta', 'badgeKey': 'c_800'},
            'year': 2024,
            'date': '2024-07-01',
            'source': 'V4 transfers / HIGH',
            'alsoBy': ['Ola Aina'],
          },
          'result': {'coins': 16, 'xp': 32, 'medal': 2, 'badge': 'streak_5'},
        },
      );
      await mount(t, CareerTransferPage(mode: 'transfer', service: f));
      await t.scrollUntilVisible(
        find.textContaining('aynı yıl yapan diğer futbolcular'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Senin cevabın da doğru'), findsOneWidget);
      expect(find.textContaining('Keskin Dedektif açıldı'), findsOneWidget);
      final text = transferShare(f.session);
      expect(text, contains('Torino → Atalanta · 2024'));
      expect(text, contains('🟥🟩⬜ Çözüldü'));
      expect(text, contains('🔥 5 seri'));
      expect(text, isNot(contains('Belotti')));
      await t.pumpAndSettle();
      await capture(t, 'transfer_result');
      await t.pumpWidget(const SizedBox());
    },
  );
  for (final mode in ['career', 'transfer']) {
    testWidgets(
      '$mode home/game use both themes, 320px large text and no local coin controls',
      (t) async {
        for (final light in [false, true]) {
          for (final active in [false, true]) {
            final fake = FakePuzzle(mode, active: active);
            await mount(
              t,
              CareerTransferPage(mode: mode, service: fake),
              light: light,
            );
            await capture(
              t,
              '${mode}_${light ? 'light' : 'dark'}_${active ? 'game' : 'home'}',
            );
            expect(t.takeException(), isNull);
            await t.pumpWidget(const SizedBox());
          }
        }
        await mount(
          t,
          CareerTransferPage(
            mode: mode,
            service: FakePuzzle(mode, phase: 'order'),
          ),
          width: 320,
          scale: 1.8,
        );
        await t.drag(find.byType(ListView).first, const Offset(0, -450));
        await t.pump();
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'selected identity is submitted; returned club visits keep unique reorder IDs',
    (t) async {
      final f = FakePuzzle('career');
      await mount(t, CareerTransferPage(mode: 'career', service: f));
      await t.scrollUntilVisible(
        find.byType(TextField),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.enterText(find.byType(TextField), 'Ronaldo');
      await t.pump(const Duration(milliseconds: 400));
      await t.pump();
      await t.ensureVisible(find.text('Cristiano Ronaldo'));
      await t.tap(find.text('Cristiano Ronaldo'));
      await t.pump();
      expect(f.mutation!['playerId'], 8198);
      await t.pumpAndSettle();
      final outerScroll = t.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      outerScroll.position.jumpTo(0);
      await t.pumpAndSettle();
      expect(find.text('2 / 2 · Kariyeri sırala'), findsOneWidget);
      expect(find.byKey(const ValueKey('period_a')), findsOneWidget);
      expect(find.byKey(const ValueKey('period_c')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('today\'s career is started from home with the daily flag', (
    t,
  ) async {
    final f = FakePuzzle('career', active: false);
    await mount(t, CareerTransferPage(mode: 'career', service: f));
    await t.ensureVisible(find.text('Günün kariyeri'));
    await t.tap(find.text('Günün kariyeri'));
    await t.pump();
    expect(f.mutation!['daily'], true);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'ordering shows checks by career length, return count and the gaps note',
    (t) async {
      final f = FakePuzzle(
        'career',
        phase: 'order',
        extra: {
          'maxChecks': 3,
          'checks': 1,
          'gaps': true,
          'daily': '2026-10-31',
        },
      );
      await mount(t, CareerTransferPage(mode: 'career', service: f));
      expect(find.text('Kontrol: 1 / 3'), findsOneWidget);
      expect(find.text('Günün kariyeri'), findsOneWidget);
      expect(find.text('2 ayrı dönem · dönüş var'), findsNWidgets(2));
      expect(find.textContaining('1. dönem'), findsNothing);
      expect(find.textContaining('Doğrulanmamış dönemler'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('Kontrol et · 2. hak'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Kontrol et · 2. hak'), findsOneWidget);
      await capture(t, 'career_order_checks');
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'finished career lists the right order and a spoiler-free share',
    (t) async {
      final solution = [
        {
          'id': 'period_a',
          'start': '2003-08-12',
          'end': '2009-07-01',
          'club': {'id': 985, 'name': 'Manchester United', 'badgeKey': 'c_985'},
        },
        {
          'id': 'period_b',
          'start': '2009-07-01',
          'end': '2018-07-10',
          'club': {'id': 418, 'name': 'Real Madrid', 'badgeKey': 'c_418'},
        },
      ];
      final f = FakePuzzle(
        'career',
        phase: 'result',
        extra: {
          'finished': true,
          'found': true,
          'checks': 2,
          'score': 100,
          'correctness': [true, false, true],
          'solution': solution,
          'daily': '2026-10-31',
          'result': {'coins': 8, 'xp': 16, 'medal': 3},
        },
      );
      await mount(t, CareerTransferPage(mode: 'career', service: f));
      await t.scrollUntilVisible(
        find.text('Real Madrid · 2009 – 2018'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('DOĞRU SIRA'), findsOneWidget);
      final text = careerShare(f.session);
      expect(text, contains('Günün kariyeri · 31.10.2026'));
      expect(text, contains('🟩🟥🟩 · 2/2 kontrol'));
      expect(text, isNot(contains('Ronaldo')));
      await capture(t, 'career_result');
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Career Race shows the route as a timeline, the round type and the revealed answer',
    (t) async {
      await mount(
        t,
        CareerTransferOnlinePage(
          mode: 'career_race',
          ranked: true,
          service: FakePuzzle('career_race'),
        ),
      );
      expect(find.text('Eksik kulüp'), findsOneWidget);
      expect(find.text('Orta'), findsOneWidget);
      expect(find.text('Sporting'), findsOneWidget);
      expect(find.text('2002'), findsOneWidget);
      expect(find.text('Eksik durak'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await mount(
        t,
        CareerTransferOnlinePage(
          mode: 'career_race',
          ranked: true,
          service: FakePuzzle('career_race', phase: 'reveal'),
        ),
      );
      await t.ensureVisible(find.text('Doğru cevap'));
      expect(find.text('Doğru cevap'), findsOneWidget);
      expect(find.text('Rakibin seçimi'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Transfer Duel shows the move, the timed hints and the transfer details after the round',
    (t) async {
      await mount(
        t,
        CareerTransferOnlinePage(
          mode: 'transfer_duel',
          ranked: true,
          service: FakePuzzle('transfer_duel'),
        ),
      );
      expect(find.text('CANLI 1v1'), findsOneWidget);
      expect(find.text('TUR 1/5'), findsOneWidget);
      expect(find.text('Zor'), findsOneWidget);
      expect(find.text('Ağustos 2021 · Yaz transferi'), findsOneWidget);
      expect(find.text('Juventus'), findsOneWidget);
      expect(find.text('Manchester United'), findsOneWidget);
      expect(find.text('Milliyet: Portugal'), findsOneWidget);
      // The second hint is still closed: when it opens and what it costs.
      expect(find.text('Mevki · 19 sn sonra açılır · −15'), findsOneWidget);
      // Answer now: 100 − 15 (one hint open) + speed bonus (20 s of 30 left).
      expect(find.text('Şimdi doğru bilirsen +118 puan'), findsOneWidget);
      expect(find.textContaining('taban puanını 15 düşürür'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await mount(
        t,
        CareerTransferOnlinePage(
          mode: 'transfer_duel',
          ranked: true,
          service: FakePuzzle('transfer_duel', phase: 'reveal'),
        ),
      );
      final details = find.text(
        'Doğru cevap: Cristiano Ronaldo · 2021-08-31 · 36 yaşında',
      );
      await t.ensureVisible(details);
      expect(details, findsOneWidget);
      expect(find.text('Rakip yanlış cevap verdi'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Transfer Duel sends a suggestion with one tap', (t) async {
    final f = FakePuzzle('transfer_duel');
    await mount(
      t,
      CareerTransferOnlinePage(mode: 'transfer_duel', ranked: true, service: f),
    );
    await t.enterText(find.widgetWithText(TextField, 'Futbolcu ara'), 'Cris');
    await t.pump(const Duration(milliseconds: 300));
    await t.pump();
    await t.tap(find.text('Cristiano Ronaldo'));
    await t.pump();
    expect(f.mutation?['action'], 'answer');
    expect(f.mutation?['answer'], 8198);
    expect(f.mutation?['round'], 0);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('Career Race: the route with its missing stop and club cards', (
    t,
  ) async {
    final f = FakePuzzle('career_race');
    await mount(
      t,
      CareerTransferOnlinePage(mode: 'career_race', ranked: true, service: f),
    );
    expect(find.text('Kariyer Yarışı'), findsOneWidget);
    expect(find.text('CANLI 1v1'), findsOneWidget);
    expect(find.text('TUR 1/6'), findsOneWidget);
    expect(find.text('Eksik kulüp'), findsOneWidget);
    expect(find.text('Cristiano Ronaldo'), findsOneWidget);
    expect(find.text('Sporting'), findsOneWidget);
    expect(find.text('Eksik durak'), findsOneWidget);
    // 20 s round, 20 s left: 100 + 50 (a few ms pass while the screen builds).
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            RegExp(
              r'^Şimdi doğru bilirsen \+(149|150) puan$',
            ).hasMatch(w.data ?? ''),
      ),
      findsOneWidget,
    );
    await t.tap(find.text('Galatasaray'));
    await t.pump();
    expect(f.mutation?['action'], 'answer');
    expect(f.mutation?['answer'], 2);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('Career Race: order rounds move stops and send the order', (
    t,
  ) async {
    final f = FakePuzzle(
      'career_race',
      question: {
        'kind': 'order',
        'difficulty': 'normal',
        'player': {'name': 'Cristiano Ronaldo'},
        'options': [
          {'id': 'b', 'name': 'Real Madrid'},
          {'id': 'a', 'name': 'Manchester United'},
          {'id': 'c', 'name': 'Juventus'},
        ],
      },
    );
    await mount(
      t,
      CareerTransferOnlinePage(mode: 'career_race', ranked: true, service: f),
    );
    expect(find.text('Kronoloji'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('order-down-b')));
    await t.pump();
    await t.tap(find.text('Sıralamayı gönder'));
    await t.pump();
    expect(f.mutation?['answer'], ['a', 'b', 'c']);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Career Race: a closed order round shows the right order (no white screen)',
    (t) async {
      final f = FakePuzzle(
        'career_race',
        phase: 'reveal',
        revealAnswer: ['a', 'b', 'c'],
        rivalAnswer: ['a', 'b', 'c'],
        question: {
          'kind': 'order',
          'difficulty': 'normal',
          'player': {'name': 'Cristiano Ronaldo'},
          'options': [
            {'id': 'b', 'name': 'Real Madrid'},
            {'id': 'a', 'name': 'Manchester United'},
            {'id': 'c', 'name': 'Juventus'},
          ],
        },
      );
      await mount(
        t,
        CareerTransferOnlinePage(mode: 'career_race', ranked: true, service: f),
      );
      expect(t.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      final rival = find.text('Rakip de bildi');
      await t.scrollUntilVisible(
        rival,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(rival, findsOneWidget);
      expect(
        find.textContaining('Manchester United → Real Madrid → Juventus'),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Career Race: the mystery career shows the route and four players',
    (t) async {
      final f = FakePuzzle(
        'career_race',
        question: {
          'kind': 'mystery',
          'difficulty': 'hard',
          'route': ['Sporting', 'Manchester United', 'Real Madrid'],
          'options': [
            {'id': 8198, 'name': 'Cristiano Ronaldo'},
            {'id': 2, 'name': 'Nani'},
            {'id': 3, 'name': 'Quaresma'},
            {'id': 4, 'name': 'Pepe'},
          ],
        },
      );
      await mount(
        t,
        CareerTransferOnlinePage(mode: 'career_race', ranked: true, service: f),
      );
      expect(find.text('Gizemli kariyer'), findsOneWidget);
      expect(find.text('Bu kariyer kimin?'), findsOneWidget);
      await t.tap(find.text('Nani'));
      await t.pump();
      expect(f.mutation?['answer'], 2);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  for (final mode in ['career_race', 'transfer_duel']) {
    testWidgets(
      '$mode online screen has timer and no hints, 320px and large type',
      (t) async {
        for (final light in [false, true]) {
          await mount(
            t,
            CareerTransferOnlinePage(
              mode: mode,
              ranked: true,
              service: FakePuzzle(mode),
            ),
            light: light,
          );
          await capture(t, '${mode}_${light ? 'light' : 'dark'}');
          expect(find.textContaining('İpucu'), findsNothing);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        }
        await mount(
          t,
          CareerTransferOnlinePage(mode: mode, service: FakePuzzle(mode)),
          width: 320,
          scale: 1.8,
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
