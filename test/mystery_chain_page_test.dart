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

class FakeMysteryChain extends CareerTransferService {
  FakeMysteryChain(this.mode, {this.active = true, this.finished = false});
  final String mode;
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
}
