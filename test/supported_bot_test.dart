import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/screens/supported_bot_page.dart';
import 'package:shared_xi/widgets/hint_panel.dart';
import 'package:shared_xi/services/energy_service.dart';
import 'package:shared_xi/services/story_support_service.dart';
import 'package:shared_xi/widgets/hub_ui.dart';
import 'package:shared_xi/widgets/paid_hint_button.dart';

class BotWire extends EnergyService {
  final calls = <Map<String, dynamic>>[];
  bool hinted = false, legacy = false, paused = false, finished = false, v2 = false;
  bool staleNext = false, rejectNext = false, botTurn = false, fiveClosed = false;

  /// A Random Five match started before rules 2 (alternating turns, old screen).
  bool fiveLegacy = false;

  /// A Team Race match started before rules 2 (the bot plays out an ended round).
  bool raceLegacy = false;
  int pausesLeft = 2, deadlineIn = 12000;
  Completer<Map<String, dynamic>>? pending;
  static const keys = {
    'loto': 'player_0',
    'team_race': 'round_0',
    'cinko': 'cell_2',
    'random_five': 'round_0',
  };
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> input = const {},
  ]) async {
    calls.add({'callable': name, ...input});
    if (pending != null) return pending!.future;
    if (name == 'searchBotSupport')
      return {
        'players': [
          {'id': '9', 'name': 'Arda Turan'},
        ],
      };
    if (name == 'actBotSupport' && input['action'] == 'hint') hinted = true;
    if (name == 'actBotSupport' && staleNext && input['action'] == 'place') {
      staleNext = false;
      throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'Sıradaki oyuncu değişti.',
      );
    }
    if (name == 'actBotSupport' && rejectNext && input['action'] == 'confirm') {
      rejectNext = false;
      throw FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'Kutular yan yana veya üst üste bağlı kalmalı. Çapraz bağlantı sayılmaz.',
      );
    }
    if (name == 'actBotSupport' && input['action'] == 'pause') paused = true;
    final mode = input['mode'] as String;
    final kind = mode.substring(4);
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'legacy': legacy,
      'availability': true,
      'version': 'v',
      'session': {
        'id': 'run',
        'version': 'v',
        'mode': mode,
        'revision': hinted ? 1 : 0,
        'finished': finished,
        'completed': finished,
        if (finished) 'winner': 1,
        'turn': botTurn ? 'bot' : 'user',
        'botAt': botTurn ? now + 5000 : null,
        'assisted': hinted,
        'paused': paused,
        'userScore': finished ? 7 : 0,
        'botScore': finished ? 4 : 0,
        'serverNow': now,
        'hints': {if (hinted) keys[kind]!: 'Doğrulanmış bilgi'},
        if (v2) 'hintMenu': {'version': 2, 'board': 'run', 'items': [{'id': 'milliyet', 'label': 'Milliyet',
          'type': 'milliyet', 'strong': false, 'price': 25, 'used': false}], 'suggested': ['milliyet', null],
          'ads': {'allowed': kind != 'loto', 'remaining': 2}, 'assisted': false},
        if (!v2) 'support': {
          'version': 1,
          'adRemaining': 2,
          'products': [
            {
              'id': 'boost_basic',
              'priceCoins': 25,
              'ads': kind != 'loto',
              'category': 'Temel',
            },
          ],
        },
        if (kind == 'loto') ...{
          'index': 0,
          'botIndex': 3,
          'deadline': now + deadlineIn,
          'pausesLeft': pausesLeft,
          'pauses': 2,
          'seconds': 12,
          'current': paused ? null : {'id': '7', 'name': 'Hakan Şükür'},
          'placements': <String, dynamic>{},
          'criteria': [
            for (var i = 0; i < 16; i++)
              {'id': 'club:$i', 'label': 'Kriter $i'},
          ],
        },
        if (kind == 'team_race') ...{
          'round': 0,
          'club': {'label': 'Galatasaray'},
          'opponent': {'label': 'Fenerbahçe'},
          'startsAt': now - 1000,
          'endsAt': now + 50000,
          'over': false,
          'total': 8,
          'remaining': 8,
          'userFound': 0,
          'botFound': 0,
          'found': [
            {'id': '4', 'name': 'Hagi', 'owner': 2},
            {'id': '5', 'name': 'Arda Turan', 'owner': 1},
          ],
          'rules': raceLegacy ? 1 : 2,
          'botAt': now + 5000,
          'finds': {'user': 0, 'bot': 0},
          if (!raceLegacy) ...{'maxRounds': 5, 'pausesLeft': 2, 'pauses': 2},
        },
        if (kind == 'cinko') ...{
          'cells': [
            for (var i = 0; i < 25; i++)
              {
                'id': 'club:$i',
                'label': 'Kutu $i',
                'owner': 0,
                'playable': true,
              },
          ],
          'current': null,
          'last': null,
          'rules': 2,
          'botFirst': true,
          'secondBonus': 1,
          'passes': 1,
          'maxPasses': 4,
          'difficulty': 'hard',
          'moves': [
            {'owner': 2, 'pass': false, 'points': 2, 'correct': [7, 8], 'wrong': [],
              'player': {'id': '4', 'name': 'Alex de Souza'}},
          ],
        },
        if (kind == 'random_five' && fiveLegacy) ...{
          'round': 0,
          'totalRounds': 5,
          'wrongLeft': 2,
          'botFirst': false,
          'history': [
            {
              'round': 0,
              'user': {
                'player': {'name': 'Arda Turan'},
                'clubs': [1, 2],
              },
              'bot': {
                'player': {'name': 'Hakan Şükür'},
                'clubs': [1],
              },
              'best': [
                {'name': 'Emre Belözoğlu', 'clubs': 4},
              ],
            },
          ],
          'clubs': [
            for (var i = 0; i < 5; i++) {'id': 'club:$i', 'label': 'Kulüp $i'},
          ],
        },
        if (kind == 'random_five' && !fiveLegacy) ...{
          'round': 0,
          'totalRounds': 5,
          'wrongLeft': 2,
          'botFirst': false,
          'rules': 2,
          'simultaneous': true,
          'botReady': !fiveClosed,
          'fivePoints': [0, 1, 2, 4, 6, 8],
          if (fiveClosed) 'turn': 'result',
          if (!fiveClosed) 'feedback': 'Pelé bu beş kulübe uymuyor. 2 deneme hakkın kaldı.',
          'history': [
            {
              'round': 0,
              'clubs': [
                for (var i = 0; i < 5; i++) {'id': 'club:$i', 'label': 'Kulüp $i'},
              ],
              if (fiveClosed) ...{
                'user': {
                  'player': {'id': '1', 'name': 'Emre Belözoğlu'},
                  'clubs': [
                    {'id': 'club:0', 'label': 'Kulüp 0'},
                    {'id': 'club:1', 'label': 'Kulüp 1'},
                    {'id': 'club:2', 'label': 'Kulüp 2'},
                  ],
                  'points': 4,
                },
                'bot': {
                  'player': {'id': '2', 'name': 'Hakan Şükür'},
                  'clubs': [
                    {'id': 'club:0', 'label': 'Kulüp 0'},
                  ],
                  'points': 1,
                },
                'best': [
                  {'name': 'Ümit Davala', 'clubs': 4, 'points': 6},
                ],
              },
            },
          ],
          'clubs': [
            for (var i = 0; i < 5; i++) {'id': 'club:$i', 'label': 'Kulüp $i'},
          ],
        },
      },
    };
  }
}

StorySupportService _service(BotWire wire) => StorySupportService(
  transport: wire,
  currentUser: () => 'alice',
  useCallable: 'actBotSupport',
  loadCallable: 'getBotSupport',
  watchPlacement: 'bot_support_hint',
);
Future<void> _scrollTo(WidgetTester t, Finder f) => t.scrollUntilVisible(
  f.hitTestable(),
  200,
  scrollable: find.byType(Scrollable).first,
  maxScrolls: 80,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final kind in ['loto', 'team_race', 'cinko', 'random_five']) {
    testWidgets(
      'Bot $kind sends typed paid target and shows assisted state at 320px/180%',
      (t) async {
        t.view.physicalSize = const Size(320, 1000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final wire = BotWire();
        await t.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
              child: SupportedBotPage(
                mode: 'bot_$kind',
                legacy: const Text('Eski oyun'),
                service: _service(wire),
              ),
            ),
          ),
        );
        await t.pump(const Duration(milliseconds: 50));
        await t.pump();
        if (kind == 'cinko') {
          // At 320px/180% the 5×5 board scrolls sideways too, as online.
          await t.ensureVisible(find.byKey(const ValueKey('cinko-cell-2'), skipOffstage: false));
          await t.pump();
          await t.tap(find.byKey(const ValueKey('cinko-cell-2')));
          await t.pump();
        }
        final paid = find.byType(PaidHintButton);
        await _scrollTo(t, paid);
        await t.widget<PaidHintButton>(paid).onUse({
          'boostId': 'boost_basic',
          'paymentSource': 'coins',
          'expectedPriceCoins': 25,
        });
        await t.pump();
        await t.pump();
        final input = wire.calls.last;
        expect(input['callable'], 'actBotSupport');
        expect(input['action'], 'hint');
        expect(input['mode'], 'bot_$kind');
        expect(input['target'], kind == 'cinko' ? 2 : 0);
        expect(input['sessionId'], 'run');
        expect(input['requestId'], matches(RegExp(r'^[a-f0-9]{32}$')));
        // Loto pins a bar under the list (180% type): the card may sit below the fold.
        t.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
        await t.pump();
        await _scrollTo(t, find.text('Doğrulanmış bilgi'));
        expect(
          find.text('Doğrulanmış bilgi', skipOffstage: false),
          findsOneWidget,
        );
        await t.drag(find.byType(Scrollable).first, const Offset(0, 6000));
        await t.pump();
        expect(
          // Every bot mode now shows it on the online scoreboard.
          find.text('Yardımlı'),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final (kind, placement) in const [
    ('loto', 'loto_result'),
    ('team_race', 'team_race_result'),
    ('cinko', 'cinko_result'),
    ('random_five', 'random_five_result'),
  ]) {
    testWidgets('finished bot $kind offers the coin bonus', (t) async {
      t.view.physicalSize = const Size(800, 3000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final seen = <String>[];
      await t.pumpWidget(
        MaterialApp(
          home: SupportedBotPage(
            mode: 'bot_$kind',
            legacy: const Text('Eski'),
            service: _service(BotWire()..finished = true),
            rewardCard: (p) {
              seen.add(p);
              return const Text('coin bonusu');
            },
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 50));
      await t.pump();
      expect(seen.toSet(), {placement});
      expect(
        find.textContaining('isteğe bağlı bonus', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('coin bonusu', skipOffstage: false), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('an active bot match shows no coin bonus', (t) async {
    final seen = <String>[];
    await t.pumpWidget(
      MaterialApp(
        home: SupportedBotPage(
          mode: 'bot_loto',
          legacy: const Text('Eski'),
          service: _service(BotWire()),
          rewardCard: (p) {
            seen.add(p);
            return const Text('coin bonusu');
          },
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 50));
    await t.pump();
    expect(seen, isEmpty);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('a won bot match ends on a winning result card', (t) async {
    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final wire = BotWire()..finished = true;
    await t.pumpWidget(
      MaterialApp(
        home: SupportedBotPage(
          mode: 'bot_loto',
          legacy: const Text('Eski oyun'),
          service: _service(wire),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 50));
    await t.pump();
    final card = find.byType(HubResultCard);
    expect(t.widget<HubResultCard>(card).tone, HubResultTone.win);
    for (final text in ['MAÇ BİTTİ', 'Kazandın', 'Sen 7 · Bot 4']) {
      expect(
        find.descendant(of: card, matching: find.text(text)),
        findsOneWidget,
        reason: text,
      );
    }
    expect(find.text('Yeni maç'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'Loto places the shown player index and pauses without exposing the next player',
    (t) async {
      final wire = BotWire();
      await t.pumpWidget(
        MaterialApp(
          home: SupportedBotPage(
            mode: 'bot_loto',
            legacy: const Text('Eski'),
            service: _service(wire),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 50));
      await t.pump();
      expect(find.byKey(const ValueKey('loto-current')), findsOneWidget);
      expect(find.byKey(const ValueKey('loto-score')), findsOneWidget);
      await _scrollTo(t, find.byKey(const ValueKey('loto-cell-5')));
      await t.tap(find.byKey(const ValueKey('loto-cell-5')));
      await t.pump();
      await t.pump();
      expect(wire.calls.last['action'], 'place');
      expect(wire.calls.last['index'], 0);
      expect(wire.calls.last['target'], 5);
      await t.tap(find.byTooltip('Duraklat · 2 hak'));
      await t.pump();
      await t.pump();
      expect(wire.calls.last['action'], 'pause');
      expect(find.textContaining('Hakan Şükür'), findsNothing);
      expect(find.byTooltip('Devam et'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Random Five and Team Race answer through server search only', (
    t,
  ) async {
    for (final kind in ['random_five', 'team_race']) {
      final wire = BotWire();
      await t.pumpWidget(
        MaterialApp(
          key: ValueKey(kind),
          home: SupportedBotPage(
            mode: 'bot_$kind',
            legacy: const Text('Eski'),
            service: _service(wire),
            clubId: 'club:141',
            clubName: 'Galatasaray',
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 50));
      await t.pump();
      await t.enterText(find.byType(TextField), 'arda');
      await t.pump(const Duration(milliseconds: 300));
      await t.pump();
      expect(
        wire.calls.any(
          (c) => c['callable'] == 'searchBotSupport' && c['query'] == 'arda',
        ),
        true,
      );
      await t.ensureVisible(find.text('Arda Turan'));
      await t.pump();
      await t.tap(find.text('Arda Turan'));
      await t.pump();
      await t.pump();
      expect(wire.calls.last['action'], 'guess');
      expect(wire.calls.last['playerId'], '9');
      if (kind == 'team_race') expect(wire.calls.last['round'], 0);
      await t.pumpWidget(const SizedBox.shrink());
    }
  });
  testWidgets(
    'Team Race sessions from before rules 2 show the clock ring and say the bot plays out an ended round',
    (t) async {
      t.view.physicalSize = const Size(420, 2000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final wire = BotWire()..raceLegacy = true;
      await t.pumpWidget(
        MaterialApp(
          home: SupportedBotPage(
            mode: 'bot_team_race',
            legacy: const Text('Eski'),
            service: _service(wire),
            clubId: 'club:141',
            clubName: 'Galatasaray',
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 50));
      await t.pump();
      expect(find.text('SN'), findsOneWidget);
      expect(find.byTooltip('Duraklat'), findsOneWidget);
      final end = find.text('Turu bitir · bot kalan sürede oynar');
      await t.ensureVisible(end);
      await t.tap(end);
      await t.pump();
      await t.pump();
      expect(wire.calls.last['action'], 'end_round');
      expect(wire.calls.last['round'], 0);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Random Five sessions from before rules 2 keep their screen: who starts, attempts left, best answers',
    (t) async {
      t.view.physicalSize = const Size(420, 2000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final wire = BotWire()..fiveLegacy = true;
      await t.pumpWidget(
        MaterialApp(
          home: SupportedBotPage(
            mode: 'bot_random_five',
            legacy: const Text('Eski'),
            service: _service(wire),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 50));
      await t.pump();
      expect(find.textContaining('bu turda sen önce oynarsın'), findsOneWidget);
      expect(find.text('En iyi cevaplar: Emre Belözoğlu (4)'), findsOneWidget);
      expect(find.textContaining('2 deneme hakkın var'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Bot rollout response opens the existing legacy route', (
    t,
  ) async {
    final wire = BotWire()..legacy = true;
    await t.pumpWidget(
      MaterialApp(
        home: SupportedBotPage(
          mode: 'bot_cinko',
          service: _service(wire),
          legacy: const Text('Mevcut yerel oyun'),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 50));
    await t.pump();
    expect(find.text('Mevcut yerel oyun'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
  });
  for (final kind in ['loto', 'team_race', 'random_five']) {
    testWidgets('v2 bot $kind shows the hint panel and sends the item with its target', (t) async {
      t.view.physicalSize = const Size(400, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final wire = BotWire()..v2 = true;
      await t.pumpWidget(MaterialApp(home: SupportedBotPage(mode: 'bot_$kind', legacy: const Text('Eski oyun'),
          service: _service(wire))));
      await t.pump(const Duration(milliseconds: 50));
      await t.pump();
      expect(find.byType(PaidHintButton), findsNothing);
      final button = find.byType(HintButton);
      await _scrollTo(t, button);
      await t.widget<HintButton>(button).onUse('milliyet', 'stock');
      await t.pump();
      await t.pump();
      final input = wire.calls.last;
      expect(input['action'], 'hint');
      expect(input['itemId'], 'milliyet');
      expect(input['target'], 0);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final kind in ['loto', 'team_race']) {
    testWidgets('$kind: the background refresh never locks the screen or shows a loading bar', (t) async {
      t.view.physicalSize = const Size(400, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final wire = BotWire();
      await t.pumpWidget(MaterialApp(home: SupportedBotPage(mode: 'bot_$kind', legacy: const Text('Eski oyun'),
          service: _service(wire))));
      await t.pump(const Duration(milliseconds: 50));
      await t.pump();
      // A slow network: the next poll hangs.
      wire.pending = Completer<Map<String, dynamic>>();
      await t.pump(const Duration(milliseconds: 1100));
      await t.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      if (kind == 'team_race') {
        expect(t.widget<TextField>(find.byType(TextField).first).enabled, isNot(false));
      }
      wire.pending!.complete(await (BotWire().call('getBotSupport', {'mode': 'bot_$kind'})));
      await t.pump();
      await t.pumpWidget(const SizedBox.shrink());
    });
  }
  Future<BotWire> openLoto(WidgetTester t, BotWire wire) async {
    t.view.physicalSize = const Size(400, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(home: SupportedBotPage(mode: 'bot_loto', legacy: const Text('Eski'),
        service: _service(wire))));
    await t.pump(const Duration(milliseconds: 50));
    await t.pump();
    return wire;
  }
  int loads(BotWire w) => w.calls.where((c) => c['callable'] == 'getBotSupport').length;
  testWidgets('Loto: a move the clock overtook catches up instead of locking the board', (t) async {
    final wire = await openLoto(t, BotWire()..staleNext = true);
    final before = loads(wire);
    await _scrollTo(t, find.byKey(const ValueKey('loto-cell-5')));
    await t.tap(find.byKey(const ValueKey('loto-cell-5')));
    await t.pump();
    await t.pump();
    await t.pump();
    expect(find.byKey(const ValueKey('bot-notice')), findsOneWidget);
    expect(find.textContaining('Sıradaki oyuncu değişti.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    expect(loads(wire), before + 1, reason: 'catches up at once');
    // Shown for a few seconds, then gone; the board stays playable meanwhile.
    await t.pump(const Duration(seconds: 7));
    expect(find.byKey(const ValueKey('bot-notice')), findsNothing);
    await t.tap(find.byKey(const ValueKey('loto-cell-6')));
    await t.pump();
    await t.pump();
    expect(wire.calls.last['action'], 'place');
    expect(wire.calls.last['target'], 6);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Loto: no request while nothing is due; one as soon as the time is up', (t) async {
    final far = await openLoto(t, BotWire()..deadlineIn = 60000);
    final before = loads(far);
    await t.pump(const Duration(seconds: 3));
    expect(loads(far), before, reason: 'the old poll asked every second');
    await t.pumpWidget(const SizedBox.shrink());
    final due = await openLoto(t, BotWire()..deadlineIn = -500);
    final start = loads(due);
    await t.pump(const Duration(milliseconds: 1100));
    await t.pump();
    expect(loads(due), greaterThan(start));
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Loto: with no pause left the button is off and leaving the app does not pause', (t) async {
    final wire = await openLoto(t, BotWire()..pausesLeft = 0);
    expect(find.text('Duraklatma 0/2'), findsOneWidget);
    final button = find.byTooltip('Duraklat · 0 hak');
    expect(button, findsOneWidget);
    await t.tap(button);
    await t.pump();
    expect(wire.calls.where((c) => c['action'] == 'pause'), isEmpty);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump();
    expect(wire.calls.where((c) => c['action'] == 'pause'), isEmpty);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpWidget(const SizedBox.shrink());
  });
  Future<BotWire> openCinko(WidgetTester t, BotWire wire) async {
    t.view.physicalSize = const Size(420, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(home: SupportedBotPage(mode: 'bot_cinko', legacy: const Text('Eski'),
        service: _service(wire))));
    await t.pump(const Duration(milliseconds: 50));
    await t.pump();
    return wire;
  }
  Future<void> tapCell(WidgetTester t, int i) async {
    await _scrollTo(t, find.byKey(ValueKey('cinko-cell-$i')));
    await t.tap(find.byKey(ValueKey('cinko-cell-$i')));
    await t.pump();
  }
  testWidgets('Çinko as online: cells first, then the player in the bar, sent together', (t) async {
    final wire = await openCinko(t, BotWire());
    expect(find.byKey(const ValueKey('cinko-score')), findsOneWidget);
    expect(find.textContaining('+1 ikinci başlama'), findsOneWidget);
    expect(find.textContaining('bot önce başladı'), findsOneWidget);
    expect(find.textContaining('Alex de Souza'), findsOneWidget);
    expect(find.byKey(const ValueKey('cinko-input')), findsNothing);
    await tapCell(t, 0);
    await tapCell(t, 1);
    expect(find.text('2 kutu seçili · doğrular +1, yanlışlar −1'), findsOneWidget);
    expect(find.byKey(const ValueKey('cinko-input')), findsOneWidget);
    await t.enterText(find.descendant(of: find.byKey(const ValueKey('cinko-input')), matching: find.byType(TextField)), 'arda');
    await t.pump(const Duration(milliseconds: 300));
    await t.pump();
    await t.tap(find.text('Arda Turan'));
    await t.pump();
    await t.pump();
    final sent = wire.calls.last;
    expect(sent['action'], 'confirm');
    expect(sent['cells'], [0, 1]);
    expect(sent['playerId'], '9');
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Çinko: a diagonal selection is flagged and cannot be sent', (t) async {
    await openCinko(t, BotWire());
    await tapCell(t, 0);
    await tapCell(t, 6);
    expect(find.textContaining('bağlı olmalı; çapraz sayılmaz'), findsOneWidget);
    expect(find.byKey(const ValueKey('cinko-input')), findsNothing);
    await tapCell(t, 1);
    expect(find.text('3 kutu seçili · doğrular +1, yanlışlar −1'), findsOneWidget);
    expect(find.byKey(const ValueKey('cinko-input')), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Çinko: a refused move shows a notice and never locks the board', (t) async {
    final wire = await openCinko(t, BotWire()..rejectNext = true);
    await tapCell(t, 3);
    await t.enterText(find.descendant(of: find.byKey(const ValueKey('cinko-input')), matching: find.byType(TextField)), 'arda');
    await t.pump(const Duration(milliseconds: 300));
    await t.pump();
    await t.tap(find.text('Arda Turan'));
    await t.pump();
    await t.pump();
    expect(find.byKey(const ValueKey('bot-notice')), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    // Still playable: the pass goes through.
    await _scrollTo(t, find.byKey(const ValueKey('cinko-pass')));
    await t.tap(find.byKey(const ValueKey('cinko-pass')));
    await t.pump();
    await t.pump();
    expect(wire.calls.last['action'], 'pass');
    await t.pump(const Duration(seconds: 7));
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Çinko: the bot turn asks the server when the bot is due, not every 750 ms', (t) async {
    final wire = await openCinko(t, BotWire()..botTurn = true);
    final before = loads(wire);
    expect(find.text('BOT OYNUYOR'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    expect(loads(wire), before, reason: 'botAt is 5 s away');
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Çinko setup explains what each bot level does', (t) async {
    final wire = BotWire();
    await t.pumpWidget(MaterialApp(home: SupportedBotPage(mode: 'bot_cinko', legacy: const Text('Eski'),
        service: StorySupportService(transport: _NoSession(wire), currentUser: () => 'alice',
          useCallable: 'actBotSupport', loadCallable: 'getBotSupport', watchPlacement: 'bot_support_hint'))));
    await t.pump(const Duration(milliseconds: 50));
    await t.pump();
    expect(find.textContaining('en fazla 3 bağlı kutu'), findsOneWidget);
    await t.tap(find.widgetWithText(ChoiceChip, 'Kolay'));
    await t.pump();
    expect(find.textContaining('en fazla 2 bağlı kutu'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
  });
  Future<BotWire> openFive(WidgetTester t, BotWire wire) async {
    t.view.physicalSize = const Size(420, 2000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(home: SupportedBotPage(mode: 'bot_random_five', legacy: const Text('Eski'),
        service: _service(wire))));
    await t.pump(const Duration(milliseconds: 50));
    await t.pump();
    await t.pump(const Duration(seconds: 3));
    return wire;
  }
  testWidgets('Random Five as online: the bot locks its guess, the bar answers, the table pays', (t) async {
    final wire = await openFive(t, BotWire());
    expect(find.byKey(const ValueKey('five-score')), findsOneWidget);
    expect(find.text('BEŞLİ 1/5'), findsOneWidget);
    expect(find.byKey(const ValueKey('five-bot-locked')), findsOneWidget);
    expect(find.textContaining('3 kulüp +4 · 4 kulüp +6 · 5 kulüp +8'), findsOneWidget);
    // A refused name shows in the pinned bar, not at the top of the list.
    expect(find.byKey(const ValueKey('five-feedback')), findsOneWidget);
    expect(find.byKey(const ValueKey('five-input')), findsOneWidget);
    await t.enterText(find.descendant(of: find.byKey(const ValueKey('five-input')), matching: find.byType(TextField)), 'arda');
    await t.pump(const Duration(milliseconds: 300));
    await t.pump();
    await t.tap(find.text('Arda Turan'));
    await t.pump();
    await t.pump();
    expect(wire.calls.last['action'], 'guess');
    expect(wire.calls.last['playerId'], '9');
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Random Five: a closed five shows both answers, their points and the next button', (t) async {
    final wire = await openFive(t, BotWire()..fiveClosed = true);
    expect(find.text('BEŞLİ AÇILDI'), findsOneWidget);
    expect(find.byKey(const ValueKey('five-input')), findsNothing);
    expect(find.text('Emre Belözoğlu'), findsOneWidget);
    expect(find.text('Hakan Şükür'), findsOneWidget);
    expect(find.textContaining('Ümit Davala (4 kulüp · +6)'), findsOneWidget);
    expect(find.text('+4 · +1'), findsOneWidget);
    await _scrollTo(t, find.byKey(const ValueKey('five-next')));
    await t.tap(find.byKey(const ValueKey('five-next')));
    await t.pump();
    await t.pump();
    expect(wire.calls.last['action'], 'next');
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Team Race as online: clock scoreboard, the two clubs, found players, pinned bar', (t) async {
    t.view.physicalSize = const Size(420, 2000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final wire = BotWire();
    await t.pumpWidget(MaterialApp(home: SupportedBotPage(mode: 'bot_team_race', legacy: const Text('Eski'),
        service: _service(wire), clubId: 'club:141', clubName: 'Galatasaray')));
    await t.pump(const Duration(milliseconds: 50));
    await t.pump();
    expect(find.byKey(const ValueKey('race-score')), findsOneWidget);
    expect(find.byKey(const ValueKey('race-versus')), findsOneWidget);
    expect(find.text('Tur galibiyeti 0/3'), findsNWidgets(2));
    expect(find.text('BULUNAN 2 / 8'), findsOneWidget);
    expect(find.text('Hagi'), findsOneWidget);
    expect(find.text('Bot +1'), findsOneWidget);
    expect(find.byKey(const ValueKey('race-input')), findsOneWidget);
    expect(find.text('Turu şimdi bitir · o anki skorla'), findsOneWidget);
    expect(find.byTooltip('Duraklat · 2 hak'), findsOneWidget);
    // The bot is due in 5 s: no request before that.
    final before = loads(wire);
    await t.pump(const Duration(seconds: 3));
    expect(loads(wire), before);
    await _scrollTo(t, find.byKey(const ValueKey('race-end')));
    await t.tap(find.byKey(const ValueKey('race-end')));
    await t.pump();
    await t.pump();
    expect(wire.calls.last['action'], 'end_round');
    await t.pumpWidget(const SizedBox.shrink());
  });
}

class _NoSession extends EnergyService {
  _NoSession(this.inner);
  final BotWire inner;
  @override
  Future<Map<String, dynamic>> call(String name, [Map<String, dynamic> input = const {}]) async =>
      {...await inner.call(name, input), 'session': null};
}
