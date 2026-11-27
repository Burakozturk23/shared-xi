import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/screens/mystery_chain_page.dart';
import 'package:shared_xi/online/career_transfer_online_page.dart';
import 'package:shared_xi/online/online_mode_catalog.dart';
import 'package:shared_xi/services/career_transfer_service.dart';
import 'package:shared_xi/theme/app_theme.dart';
import 'package:shared_xi/widgets/hub_ui.dart';

class FakeMysteryChain extends CareerTransferService {
  FakeMysteryChain(
    this.mode, {
    this.active = true,
    this.finished = false,
    this.extra = const {},
  });
  final String mode;
  final Map<String, dynamic> extra;
  bool active, finished;
  Map<String, dynamic>? mutation;
  static const a = {
    'id': 985,
    'name': 'Manchester United',
    'badgeKey': 'c_985',
  };
  static const b = {'id': 418, 'name': 'Real Madrid', 'badgeKey': 'c_418'};
  Map<String, dynamic> get session => {
    'id': 'run',
    'mode': mode,
    'revision': 0,
    'wrong': 0,
    'score': 0,
    'chains': 0,
    'streak': 0,
    'par': 2,
    'maxMoves': 5,
    'path': [],
    'skipped': 0,
    'start': a,
    'current': a,
    'target': b,
    'finished': finished,
    'optionalHints': 0,
    'hints': [],
    'initial': [
      {'id': 'country', 'text': 'Portekiz'},
      {'id': 'position', 'text': 'Forvet'},
    ],
    'freeHint': true,
    'adCredits': 0,
    'adRemaining': 2,
    'serverNow': DateTime.now().millisecondsSinceEpoch,
    'endAt': DateTime.now().millisecondsSinceEpoch + 60000,
    if (finished) 'result': {'medal': 4, 'coins': 6, 'xp': 12},
    if (finished && mode == 'mystery') 'player': {'name': 'Cristiano Ronaldo'},
    ...extra,
  };
  @override
  Future<Map<String, dynamic>> load(String mode) async => {
    'version': 'test',
    'coins': 120,
    'linked': true,
    'energy': {'available': 5, 'enabled': true},
    'pendingCoins': 0,
    'inventory': [],
    'collection': [],
    'streak': 3,
    'longestStreak': 6,
    'streakRewards': [
      {'id': 'streak_5', 'at': 5, 'coins': 10, 'earned': true},
      {'id': 'streak_10', 'at': 10, 'coins': 20, 'earned': false},
    ],
    'session': active ? session : null,
  };
  @override
  Future<Map<String, dynamic>> mutate(
    String call,
    Map<String, dynamic> input,
  ) async {
    mutation = input;
    if (input['action'] == 'guess') finished = true;
    return {'session': session};
  }

  @override
  Future<Map<String, dynamic>> search(Map<String, dynamic> input) async =>
      input['playerId'] != null
      ? {
          'clubs': [b],
        }
      : {
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
      'totalRounds': 5,
      'serverNow': 10000,
      'startsAt': 9000,
      'deadline': 39000,
      'mine': {'score': 0},
      'theirs': {'score': 0},
      'question': {
        'kind': 'mystery_duel',
        'country': 'Portekiz',
        'position': 'Forvet',
        'difficulty': 'easy',
        'hintAt': [8000, 16000, 24000],
        'hints': ['Oynadığı kulüp: Manchester United'],
        'options': [
          {'id': 1, 'name': 'Cristiano Ronaldo'},
          {'id': 2, 'name': 'Nani'},
          {'id': 3, 'name': 'Ricardo Quaresma'},
          {'id': 4, 'name': 'Diogo Jota'},
        ],
      },
    },
  };
  @override
  Future<Map<String, dynamic>> poll(Map<String, dynamic> input) =>
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
    final file = File('.dart_tool/mystery_chain_qa/$name.png');
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
  test(
    'C12: Chain has no online, friend invite or ranked mode; mystery duel is registered',
    () {
      final modes = OnlinePlayMode.values.map((m) => m.wireName);
      expect(modes, contains('mystery_duel'));
      expect(
        modes.where(
          (m) =>
              m.contains('chain') ||
              m.contains('mastermind') ||
              m.contains('blitz'),
        ),
        isEmpty,
      );
      expect(
        OnlinePlayModeX.fromWire('mystery_duel'),
        OnlinePlayMode.mysteryDuel,
      );
    },
  );
  for (final mode in ['mystery', 'mastermind', 'blitz']) {
    testWidgets(
      '$mode home, game, result fit both themes and 320px large text',
      (t) async {
        for (final light in [false, true]) {
          for (final stage in ['home', 'game', 'result']) {
            await mount(
              t,
              MysteryChainPage(
                mode: mode,
                service: FakeMysteryChain(
                  mode,
                  active: stage != 'home',
                  finished: stage == 'result',
                ),
              ),
              light: light,
            );
            await capture(t, '${mode}_${light ? 'light' : 'dark'}_$stage');
            expect(t.takeException(), isNull);
            await t.pumpWidget(const SizedBox());
          }
        }
        await mount(
          t,
          MysteryChainPage(mode: mode, service: FakeMysteryChain(mode)),
          width: 320,
          scale: 1.8,
        );
        await t.drag(find.byType(ListView).first, const Offset(0, -600));
        await t.pump();
        expect(t.takeException(), isNull);
        if (mode == 'blitz') {
          expect(find.textContaining('Reklam izle'), findsNothing);
          expect(find.textContaining('Yeni bilgi aç'), findsNothing);
          expect(find.textContaining('Pas geç'), findsOneWidget);
        }
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  for (final mode in ['mystery', 'mastermind', 'blitz']) {
    testWidgets('$mode home is a hero card with a rules list', (t) async {
      await mount(
        t,
        MysteryChainPage(
          mode: mode,
          service: FakeMysteryChain(mode, active: false),
        ),
      );
      expect(find.byType(HubHeroCard), findsOneWidget);
      expect(find.text('Kurallar ve kazanımlar'), findsOneWidget);
      // Shared budget, reward and energy lines are each their own note.
      expect(find.byType(HubSpecNote), findsAtLeastNWidgets(4));
      expect(
        find.widgetWithText(
          HubSpecNote,
          'Gizemli Futbolcu ve iki Zincir '
          'modu ortak günde 24 Coin / 48 XP bütçesini kullanır. Fazlası '
          'kaybolmaz; sırada bekler.',
        ),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'M04: selected player ID is submitted and result reveals the player',
    (t) async {
      final fake = FakeMysteryChain('mystery');
      await mount(t, MysteryChainPage(mode: 'mystery', service: fake));
      await t.ensureVisible(find.byType(TextField));
      await t.enterText(find.byType(TextField), 'Ronaldo');
      await t.pump(const Duration(milliseconds: 300));
      await t.pump();
      await t.ensureVisible(find.text('Cristiano Ronaldo'));
      await t.tap(find.text('Cristiano Ronaldo'));
      await t.pumpAndSettle();
      expect(fake.mutation!['playerId'], 8198);
      expect(fake.mutation!['action'], 'guess');
      t
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await t.pump();
      expect(find.text('Sonuç kaydedildi'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'chain sends player ID and chosen club ID as one server-validated move',
    (t) async {
      final fake = FakeMysteryChain('mastermind');
      await mount(t, MysteryChainPage(mode: 'mastermind', service: fake));
      await t.ensureVisible(find.byType(TextField));
      await t.enterText(find.byType(TextField), 'Ronaldo');
      await t.pump(const Duration(milliseconds: 300));
      await t.pump();
      await t.ensureVisible(find.text('Cristiano Ronaldo'));
      await t.tap(find.text('Cristiano Ronaldo'));
      await t.pump();
      final option = find.widgetWithText(ListTile, 'Real Madrid');
      await t.ensureVisible(option);
      await t.tap(option);
      await t.pump();
      expect(fake.mutation!['action'], 'move');
      expect(fake.mutation!['playerId'], 8198);
      expect(fake.mutation!['clubId'], 418);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Gizem Duellosu has synchronized clues, four choices and no ads at large text',
    (t) async {
      for (final light in [false, true]) {
        await mount(
          t,
          CareerTransferOnlinePage(
            mode: 'mystery_duel',
            service: FakeMysteryChain('mystery'),
          ),
          light: light,
        );
        await capture(t, 'mystery_duel_${light ? 'light' : 'dark'}');
        expect(find.text('Cristiano Ronaldo'), findsOneWidget);
        expect(find.textContaining('Reklam izle'), findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      }
      await mount(
        t,
        CareerTransferOnlinePage(
          mode: 'mystery_duel',
          service: FakeMysteryChain('mystery'),
        ),
        width: 320,
        scale: 1.8,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Gizem Duellosu shows the hint schedule, the next hint and the difficulty',
    (t) async {
      await mount(
        t,
        CareerTransferOnlinePage(
          mode: 'mystery_duel',
          service: FakeMysteryChain('mystery'),
        ),
      );
      expect(find.text('CANLI 1v1'), findsOneWidget);
      expect(find.text('TUR 1/5'), findsOneWidget);
      expect(find.text('Portekiz · Forvet'), findsOneWidget);
      expect(find.text('1. Oynadığı kulüp: Manchester United'), findsOneWidget);
      // The next clue says when it opens.
      expect(find.text('2. bilgi · 15 sn sonra açılır'), findsOneWidget);
      // Before the first clue a right answer earns the base only.
      expect(find.text('Şimdi doğru bilirsen +100 puan'), findsOneWidget);
      expect(find.text('Kolay'), findsOneWidget);
      final schedule = find.textContaining('8, 16, 24. saniyelerde');
      await t.scrollUntilVisible(
        schedule,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(schedule, findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Gizem Duellosu sends a choice with one tap', (t) async {
    final f = FakeMysteryChain('mystery');
    await mount(t, CareerTransferOnlinePage(mode: 'mystery_duel', service: f));
    await t.tap(find.text('Nani'));
    await t.pump();
    expect(f.mutation?['action'], 'answer');
    expect(f.mutation?['answer'], 2);
    expect(f.mutation?['round'], 0);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'mystery home sends level and daily, and shows the streak rewards',
    (t) async {
      final f = FakeMysteryChain('mystery', active: false);
      await mount(t, MysteryChainPage(mode: 'mystery', service: f));
      await t.scrollUntilVisible(
        find.text('Zor'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Seri 3 · En iyi 6'), findsOneWidget);
      expect(find.text('5 seri · +10 Coin'), findsOneWidget);
      await t.tap(find.text('Zor'));
      await t.pump();
      await t.ensureVisible(find.text('Yeni dosya aç'));
      await t.tap(find.text('Yeni dosya aç'));
      await t.pumpAndSettle();
      expect(f.mutation!['difficulty'], 'hard');
      await t.pumpWidget(const SizedBox());
      final d = FakeMysteryChain('mystery', active: false);
      await mount(t, MysteryChainPage(mode: 'mystery', service: d));
      await t.scrollUntilVisible(
        find.text('Günün gizemli futbolcusu'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(find.text('Günün gizemli futbolcusu'));
      await t.pumpAndSettle();
      expect(d.mutation!['daily'], true);
      expect(d.mutation!.containsKey('difficulty'), isFalse);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('a file close to its deadline warns before the reward is lost', (
    t,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final f = FakeMysteryChain(
      'mystery',
      extra: {
        'expiresAt': now + 2 * 3600000 + 60000,
        'daily': '2026-10-31',
        'initial': [
          {'id': 'country', 'text': 'Portekiz'},
          {'id': 'position', 'text': 'Forvet'},
          {'id': 'club_1', 'text': 'Oynadığı kulüp: Sporting CP'},
        ],
        'hints': [
          {
            'id': 'period',
            'text': 'Bir dönemi: Real Madrid, 2009 – 2018',
            'automatic': true,
          },
        ],
      },
    );
    await mount(t, MysteryChainPage(mode: 'mystery', service: f));
    expect(find.textContaining('2 saat içinde kapanır'), findsOneWidget);
    expect(find.text('Günün futbolcusu'), findsOneWidget);
    expect(find.text('Oynadığı kulüp: Sporting CP'), findsOneWidget);
    await capture(t, 'mystery_deadline');
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'finished mystery explains other answers, expiry and shares without the name',
    (t) async {
      final f = FakeMysteryChain(
        'mystery',
        finished: true,
        extra: {
          'found': true,
          'wrong': 1,
          'score': 70,
          'streak': 5,
          'optionalHints': 1,
          'daily': '2026-10-31',
          'answer': {'id': 2, 'name': 'Moussa Sissoko'},
          'alsoBy': ['Étienne Capoue'],
          'result': {'medal': 2, 'coins': 13, 'xp': 26, 'badge': 'streak_5'},
        },
      );
      await mount(t, MysteryChainPage(mode: 'mystery', service: f));
      await t.scrollUntilVisible(
        find.textContaining('uyan diğer futbolcular'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Senin cevabın da doğru'), findsOneWidget);
      expect(find.textContaining('Seri ödülü: 5 seri'), findsOneWidget);
      final text = mysteryShare(f.session);
      expect(text, contains('Günün futbolcusu · 31.10.2026'));
      expect(text, contains('🟥🟩⬜ Bulundu'));
      expect(text, contains('🔥 5 seri'));
      expect(text, isNot(contains('Ronaldo')));
      await t.pumpAndSettle();
      await capture(t, 'mystery_result');
      await t.pumpWidget(const SizedBox());
      final expired = FakeMysteryChain(
        'mystery',
        finished: true,
        extra: {
          'result': {'medal': 0, 'coins': 0, 'xp': 0, 'expired': true},
        },
      );
      await mount(t, MysteryChainPage(mode: 'mystery', service: expired));
      await t.scrollUntilVisible(
        find.textContaining('Serin bozulmadı'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'chain give-up asks first, then shows the shortest route and a share card',
    (t) async {
      final f = FakeMysteryChain('mastermind', extra: {'daily': '2026-10-31'});
      await mount(t, MysteryChainPage(mode: 'mastermind', service: f));
      expect(find.text('Günün zinciri'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('Teslim ol · çözümü gör'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(find.text('Teslim ol · çözümü gör'));
      await t.pumpAndSettle();
      expect(find.textContaining('ilk resmî ödül hakkı yanar'), findsOneWidget);
      await t.tap(find.text('Çözümü gör'));
      await t.pumpAndSettle();
      expect(f.mutation!['action'], 'skip');
      await t.pumpWidget(const SizedBox());
      final done = FakeMysteryChain(
        'mastermind',
        finished: true,
        extra: {
          'gaveUp': true,
          'found': false,
          'routeCount': 3,
          'daily': '2026-10-31',
          'result': {'medal': 0, 'coins': 0, 'xp': 0},
          'solution': [
            {
              'player': {'name': 'Xherdan Shaqiri'},
              'club': FakeMysteryChain.b,
            },
          ],
          'par': 1,
        },
      );
      await mount(t, MysteryChainPage(mode: 'mastermind', service: done));
      await t.scrollUntilVisible(
        find.text('Xherdan Shaqiri'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('EN KISA ROTA'), findsOneWidget);
      expect(find.text('Teslim oldun'), findsOneWidget);
      expect(find.textContaining('3 farklı en kısa rota'), findsOneWidget);
      final text = chainShare(done.session);
      expect(text, contains('Günün zinciri · 31.10.2026'));
      expect(text, contains('Manchester United → Real Madrid'));
      expect(text, contains('Bağlanamadı · PAR 1'));
      expect(text, isNot(contains('Shaqiri')));
      await t.pumpAndSettle();
      await capture(t, 'chain_solution');
      await t.pumpWidget(const SizedBox());
    },
  );
}
