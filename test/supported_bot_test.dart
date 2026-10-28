import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/screens/supported_bot_page.dart';
import 'package:shared_xi/services/energy_service.dart';
import 'package:shared_xi/services/story_support_service.dart';
import 'package:shared_xi/widgets/hub_ui.dart';
import 'package:shared_xi/widgets/paid_hint_button.dart';

class BotWire extends EnergyService {
  final calls = <Map<String, dynamic>>[];
  bool hinted = false, legacy = false, paused = false, finished = false;
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
        'turn': 'user',
        'assisted': hinted,
        'paused': paused,
        'userScore': finished ? 7 : 0,
        'botScore': finished ? 4 : 0,
        'serverNow': now,
        'hints': {if (hinted) keys[kind]!: 'Doğrulanmış bilgi'},
        'support': {
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
          'deadline': now + 12000,
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
          'over': false,
          'total': 8,
          'remaining': 8,
          'userFound': 0,
          'botFound': 0,
          'found': [],
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
        },
        if (kind == 'random_five') ...{
          'round': 0,
          'totalRounds': 5,
          'history': [
            {'round': 0},
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
          await _scrollTo(t, find.byKey(const ValueKey('cinko-cell-2')));
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
        expect(
          find.text('Doğrulanmış bilgi', skipOffstage: false),
          findsOneWidget,
        );
        await t.drag(find.byType(Scrollable).first, const Offset(0, 6000));
        await t.pump();
        expect(find.text('Yardımlı · Ayrı sonuç kaydı'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }
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
      expect(find.textContaining('Hakan Şükür'), findsOneWidget);
      await _scrollTo(t, find.byKey(const ValueKey('loto-cell-5')));
      await t.tap(find.byKey(const ValueKey('loto-cell-5')));
      await t.pump();
      await t.pump();
      expect(wire.calls.last['action'], 'place');
      expect(wire.calls.last['index'], 0);
      expect(wire.calls.last['target'], 5);
      await t.tap(find.byTooltip('Duraklat'));
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
      await t.tap(find.text('Arda Turan'));
      await t.pump();
      await t.pump();
      expect(wire.calls.last['action'], 'guess');
      expect(wire.calls.last['playerId'], '9');
      if (kind == 'team_race') expect(wire.calls.last['round'], 0);
      await t.pumpWidget(const SizedBox.shrink());
    }
  });
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
}
