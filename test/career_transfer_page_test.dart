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

class FakePuzzle extends CareerTransferService {
  FakePuzzle(this.mode, {this.phase = 'guess', this.active = true});
  final String mode;
  String phase;
  bool active;
  Map<String, dynamic>? mutation;
  final stops = [
    {
      'id': 'period_a',
      'club': {'id': 985, 'name': 'Manchester United', 'badgeKey': 'c_985'},
      'visit': 1,
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
      'question': mode == 'career_race'
          ? {
              'kind': 'missing',
              'player': {'name': 'Cristiano Ronaldo'},
              'route': ['Sporting', '?', 'Real Madrid'],
              'options': [
                {'id': 1, 'name': 'Manchester United'},
                {'id': 2, 'name': 'Galatasaray'},
                {'id': 3, 'name': 'Barcelona'},
                {'id': 4, 'name': 'Milan'},
              ],
            }
          : {
              'kind': 'transfer',
              'from': {'name': 'Juventus'},
              'to': {'name': 'Manchester United'},
              'year': 2021,
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
