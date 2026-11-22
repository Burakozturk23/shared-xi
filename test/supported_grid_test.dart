import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/screens/supported_grid_page.dart';
import 'package:shared_xi/services/energy_service.dart';
import 'package:shared_xi/services/story_support_service.dart';
import 'package:shared_xi/online/online_mode_catalog.dart';
import 'package:shared_xi/widgets/friend_room_section.dart';
import 'package:shared_xi/widgets/grid_friend_section.dart';
import 'package:shared_xi/widgets/paid_hint_button.dart';
import 'package:shared_xi/widgets/hint_panel.dart';

class GridWire extends EnergyService {
  final calls = <Map<String, dynamic>>[];
  bool hinted = false, legacy = false, finished = false, v2 = false, coach = false;
  bool botTurn = false, verified = false;
  Completer<Map<String, dynamic>>? pending;
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> input = const {},
  ]) async {
    calls.add({'callable': name, ...input});
    if (pending != null) return pending!.future;
    if (name == 'actGridSupport' && input['action'] == 'hint') hinted = true;
    if (name == 'searchGridSupport') {
      return {
        'players': <Map<String, dynamic>>[],
        'criteria': [
          {'id': 'club:7', 'label': 'Galatasaray', 'type': 'club'},
        ],
      };
    }
    final mode = input['mode'] as String;
    final reverse = mode.endsWith('reverse'), random = mode.endsWith('random');
    return {
      'legacy': legacy,
      'availability': true,
      'version': 'v',
      'serverNow': 0,
      'records': {
        '$mode:medium': {'best': 160, 'completed': 3, 'wins': 0},
      },
      'session': {
        'id': 'run',
        'version': 'v',
        'mode': mode,
        'revision': hinted ? 1 : 0,
        'finished': finished,
        'completed': finished,
        'turn': botTurn && !finished ? 'bot' : 'user',
        'botAt': botTurn ? 1000 : null,
        'difficulty': 'medium',
        'wrong': 2,
        'wrongCost': 5,
        'feedback': 'Oyuncu iki kritere uymuyor. −5 puan.',
        if (finished && !reverse)
          'solutions': {
            '4': {'id': '9', 'name': 'Hakan Şükür'},
          },
        if (finished && reverse)
          'accepted': [
            for (var i = 0; i < 6; i++) ['Galatasaray', 'Turkey'],
          ],
        'assisted': hinted,
        'cells': <String, dynamic>{},
        'axes': <String, dynamic>{},
        'userScore': 0,
        'botScore': 0,
        'roundsUsed': 0,
        'pairNumber': 1,
        'rows': [
          for (var i = 0; i < 3; i++)
            if (random) null else {'id': 'club:$i', 'label': 'Kulüp $i'},
        ],
        'cols': [
          for (var i = 0; i < 3; i++)
            if (random)
              null
            else if (coach && i == 0)
              {'id': 'coach:coach_171', 'type': 'coach', 'value': 'coach_171', 'label': 'Fatih Terim'}
            else
              {'id': 'country:$i', 'label': 'Milliyet $i'},
        ],
        'witnesses': [
          for (var i = 0; i < 9; i++) {'id': '$i', 'name': 'Futbolcu $i'},
        ],
        'hints': {
          if (hinted)
            (reverse
                    ? 'axis_0'
                    : random
                    ? 'pair_1'
                    : 'cell_0'):
                'Doğrulanmış bilgi',
        },
        'pending': random
            ? {
                'criteria': [
                  {'label': 'Birinci kulüp'},
                  {'label': 'İkinci kulüp'},
                ],
                'player': verified ? {'id': '9', 'name': 'Hakan Şükür'} : null,
              }
            : null,
        if (v2) 'hintMenu': {'version': 2, 'board': 'run', 'items': [{'id': 'milliyet', 'label': 'Milliyet', 'type': 'milliyet',
          'strong': false, 'price': 25, 'used': false}], 'suggested': ['milliyet', null],
          'ads': {'allowed': true, 'remaining': 2}, 'assisted': false},
        if (!v2) 'support': {
          'version': 1,
          'adRemaining': 2,
          'products': [
            {'id': 'boost_basic', 'priceCoins': 25, 'ads': true},
          ],
        },
      },
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final kind in ['classic', 'reverse', 'random']) {
    testWidgets(
      'Grid $kind keeps paid target, revision and assisted state at 320px/180%',
      (t) async {
        t.view.physicalSize = const Size(320, 1000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final wire = GridWire();
        final service = StorySupportService(
          transport: wire,
          currentUser: () => 'alice',
          useCallable: 'actGridSupport',
          loadCallable: 'getGridSupport',
          watchPlacement: 'grid_support_hint',
        );
        await t.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
              child: SupportedGridPage(
                mode: 'solo_grid_$kind',
                legacy: const Text('Eski oyun'),
                service: service,
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final select = kind == 'classic'
            ? find.byKey(const ValueKey('grid-cell-0'))
            : kind == 'reverse'
            ? find.byKey(const ValueKey('grid-axis-0'))
            : find.text('Ortak oyuncuyu bul');
        await t.scrollUntilVisible(
          select.hitTestable(),
          200,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 60,
        );
        await t.tap(select);
        await t.pumpAndSettle();
        final paid = find.byType(PaidHintButton).hitTestable();
        await t.scrollUntilVisible(
          paid,
          200,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 60,
        );
        await t.widget<PaidHintButton>(paid).onUse({
          'boostId': 'boost_basic',
          'paymentSource': 'coins',
          'expectedPriceCoins': 25,
        });
        await t.pumpAndSettle();
        final input = wire.calls.last;
        expect(input['action'], 'hint');
        expect(input['mode'], 'solo_grid_$kind');
        expect(input['target'], kind == 'random' ? 'pending' : 0);
        expect(input['revision'], 0);
        expect(input['sessionId'], 'run');
        expect(input['requestId'], matches(RegExp(r'^[a-f0-9]{32}$')));
        // The pinned input bar (180% type) leaves a short list; the card may sit below it.
        t
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await t.pump();
        await t.scrollUntilVisible(
          find.text('Doğrulanmış bilgi'),
          200,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 60,
        );
        expect(find.text('Doğrulanmış bilgi'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  Future<GridWire> open(
    WidgetTester t,
    String mode, {
    bool finished = false,
    bool coach = false,
  }) async {
    t.view.physicalSize = const Size(320, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final wire = GridWire()
      ..finished = finished
      ..coach = coach;
    await t.pumpWidget(
      MaterialApp(
        home: SupportedGridPage(
          key: UniqueKey(),
          mode: mode,
          legacy: const Text('Eski oyun'),
          service: StorySupportService(
            transport: wire,
            currentUser: () => 'alice',
            useCallable: 'actGridSupport',
            loadCallable: 'getGridSupport',
            watchPlacement: 'grid_support_hint',
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return wire;
  }

  testWidgets(
    'solo Grid shows score, wrong cost, record and the labelled board',
    (t) async {
      await open(t, 'solo_grid_classic');
      expect(find.text('her biri −5 puan'), findsOneWidget);
      expect(find.text('Rekor 160 · 3 tamamlanan'), findsOneWidget);
      expect(find.text('Oyuncu iki kritere uymuyor. −5 puan.'), findsOneWidget);
      expect(find.text('Kulüp 1'), findsOneWidget);
      expect(find.text('Milliyet 2'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final (mode, offered) in const [
    ('bot_grid_classic', true),
    ('bot_grid_reverse', true),
    ('bot_grid_random', true),
    ('solo_grid_classic', false),
  ]) {
    testWidgets('finished $mode coin bonus: $offered', (t) async {
      t.view.physicalSize = const Size(800, 3000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final seen = <String>[];
      await t.pumpWidget(
        MaterialApp(
          home: SupportedGridPage(
            mode: mode,
            legacy: const Text('Eski oyun'),
            service: StorySupportService(
              transport: GridWire()..finished = true,
              currentUser: () => 'alice',
              useCallable: 'actGridSupport',
              loadCallable: 'getGridSupport',
              watchPlacement: 'grid_support_hint',
            ),
            rewardCard: (p) {
              seen.add(p);
              return const Text('coin bonusu');
            },
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 50));
      await t.pump();
      expect(seen.toSet(), offered ? {'grid_result'} : <String>{});
      expect(
        find.textContaining('isteğe bağlı bonus', skipOffstage: false),
        offered ? findsOneWidget : findsNothing,
      );
      await t.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('coach criterion shows the coach name and TD tag', (t) async {
    await open(t, 'bot_grid_classic', coach: true);
    expect(find.text('Fatih Terim'), findsOneWidget);
    expect(find.text('TD'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('finished solo Grid lists an answer for each empty cell', (
    t,
  ) async {
    await open(t, 'solo_grid_classic', finished: true);
    final title = find.text('Boş kalan kutulara örnek cevaplar');
    await t.scrollUntilVisible(
      title,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Hakan Şükür'), findsOneWidget);
    await open(t, 'solo_grid_reverse', finished: true);
    final accepted = find.text('Kabul edilen kriterler');
    await t.scrollUntilVisible(
      accepted,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Satır 1: Galatasaray · Turkey'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('reverse Grid suggests criteria and sends the picked id', (
    t,
  ) async {
    final wire = await open(t, 'solo_grid_reverse');
    final chip = find.byKey(const ValueKey('grid-axis-0'));
    await t.scrollUntilVisible(
      chip.hitTestable(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(chip);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'galata');
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();
    final suggestion = find.text('Galatasaray');
    await t.scrollUntilVisible(
      suggestion.hitTestable(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(suggestion);
    await t.pumpAndSettle();
    final guess = wire.calls.lastWhere((c) => c['action'] == 'guess');
    expect(guess['answer'], 'club:7');
    expect(guess['target'], 0);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Grid menu links to a friend room for each variant', (t) async {
    await t.pumpWidget(
      const MaterialApp(home: Scaffold(body: GridFriendSection())),
    );
    expect(find.text('Arkadaşınla oyna'), findsOneWidget);
    for (final wire in ['grid_classic', 'grid_random', 'grid_reverse']) {
      expect(find.byKey(ValueKey('friend-room-$wire')), findsOneWidget);
    }
    expect(t.takeException(), isNull);
  });
  testWidgets('Club Manager friend room entry opens the online room', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FriendRoomSection(
            modes: [(OnlinePlayMode.clubManager, 'Kafa kafaya kadro', 'x')],
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('friend-room-club_manager')),
      findsOneWidget,
    );
    expect(find.text('Kafa kafaya kadro'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Grid rollout response opens existing legacy route', (t) async {
    final wire = GridWire()..legacy = true;
    final service = StorySupportService(
      transport: wire,
      currentUser: () => 'alice',
      loadCallable: 'getGridSupport',
    );
    await t.pumpWidget(
      MaterialApp(
        home: SupportedGridPage(
          mode: 'bot_grid_classic',
          service: service,
          legacy: const Text('Mevcut yerel oyun'),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Mevcut yerel oyun'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
  });
  test(
    'Grid rejects late account response and keeps request scoped to original owner',
    () async {
      final wire = GridWire()..pending = Completer<Map<String, dynamic>>();
      var uid = 'alice';
      final service = StorySupportService(
        transport: wire,
        currentUser: () => uid,
        useCallable: 'actGridSupport',
      );
      final future = service.use({
        'mode': 'solo_grid_classic',
        'targetId': 'solo_grid_classic',
        'action': 'hint',
        'sessionId': 'run',
        'target': 0,
      });
      final assertion = expectLater(future, throwsStateError);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      uid = 'bob';
      wire.pending!.complete({
        'session': {'assisted': true},
      });
      await assertion;
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey(
          'story.support.v1.alice.solo_grid_classic.solo_grid_classic',
        ),
        true,
      );
      expect(
        prefs.containsKey(
          'story.support.v1.bob.solo_grid_classic.solo_grid_classic',
        ),
        false,
      );
    },
  );
  for (final kind in ['classic', 'random']) {
    testWidgets('v2 Grid $kind opens HintPanel and sends {action: hint, itemId, paymentSource, target}', (t) async {
      t.view.physicalSize = const Size(400, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final wire = GridWire()..v2 = true;
      final service = StorySupportService(transport: wire, currentUser: () => 'alice',
          useCallable: 'actGridSupport', loadCallable: 'getGridSupport', watchPlacement: 'grid_support_hint');
      await t.pumpWidget(MaterialApp(home: SupportedGridPage(mode: 'solo_grid_$kind',
          legacy: const Text('Eski oyun'), service: service)));
      await t.pumpAndSettle();
      final select = kind == 'classic' ? find.byKey(const ValueKey('grid-cell-0')) : find.text('Ortak oyuncuyu bul');
      await t.scrollUntilVisible(select.hitTestable(), 200, scrollable: find.byType(Scrollable).first, maxScrolls: 60);
      await t.tap(select);
      await t.pumpAndSettle();
      expect(find.byType(PaidHintButton), findsNothing);
      final button = find.byType(HintButton);
      await t.scrollUntilVisible(button.hitTestable(), 200, scrollable: find.byType(Scrollable).first, maxScrolls: 60);
      await t.widget<HintButton>(button).onUse('milliyet', 'stock');
      await t.pumpAndSettle();
      final input = wire.calls.last;
      expect(input['action'], 'hint');
      expect(input['itemId'], 'milliyet');
      expect(input['paymentSource'], 'stock');
      expect(input['target'], kind == 'random' ? 'pending' : 0);
      expect(input.containsKey('boostId'), isFalse);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('a finished bot Grid starts the next board at the picked level', (t) async {
    t.view.physicalSize = const Size(320, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final wire = GridWire()..finished = true;
    await t.pumpWidget(
      MaterialApp(
        home: SupportedGridPage(
          mode: 'bot_grid_classic',
          legacy: const Text('Eski oyun'),
          poolInput: () async => {'clubIds': <String>[], 'minimumAnswers': 1},
          rewardCard: (_) => const SizedBox.shrink(),
          service: StorySupportService(
            transport: wire,
            currentUser: () => 'alice',
            useCallable: 'actGridSupport',
            loadCallable: 'getGridSupport',
            watchPlacement: 'grid_support_hint',
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final hard = find.byKey(const ValueKey('grid-level-hard'));
    await t.scrollUntilVisible(hard.hitTestable(), 200, scrollable: find.byType(Scrollable).first);
    expect(t.widget<ChoiceChip>(find.byKey(const ValueKey('grid-level-medium'))).selected, isTrue);
    await t.tap(hard);
    await t.pumpAndSettle();
    expect(find.textContaining('her zaman engeller'), findsOneWidget);
    wire.finished = false;
    final again = find.text('Yeni tahta');
    await t.scrollUntilVisible(again.hitTestable(), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(again);
    await t.pumpAndSettle();
    final start = wire.calls.lastWhere((c) => c['action'] == 'start');
    expect(start['difficulty'], 'hard');
    expect(find.byKey(const ValueKey('grid-level-hard')), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('solo Grid shows no bot level picker', (t) async {
    await open(t, 'solo_grid_classic', finished: true);
    expect(find.byKey(const ValueKey('grid-level-hard'), skipOffstage: false), findsNothing);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('bot turn loads once at the server deadline, not on a fixed poll', (t) async {
    final wire = GridWire()..botTurn = true;
    await t.pumpWidget(
      MaterialApp(
        home: SupportedGridPage(
          mode: 'bot_grid_classic',
          legacy: const Text('Eski oyun'),
          service: StorySupportService(
            transport: wire,
            currentUser: () => 'alice',
            useCallable: 'actGridSupport',
            loadCallable: 'getGridSupport',
            watchPlacement: 'grid_support_hint',
          ),
        ),
      ),
    );
    await t.pump();
    int loads() => wire.calls.where((c) => c['callable'] == 'getGridSupport').length;
    final first = loads();
    expect(first, 1);
    // botAt − serverNow = 1000 ms: nothing before it (the old poll fired at 750 ms).
    await t.pump(const Duration(milliseconds: 900));
    expect(loads(), first);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    wire.botTurn = false;
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    expect(loads(), first + 1);
    // The bot has moved: no further loads.
    await t.pump(const Duration(seconds: 6));
    expect(loads(), first + 1);
    await t.pumpWidget(const SizedBox.shrink());
  });
  Future<GridWire> openWith(WidgetTester t, String mode, GridWire wire) async {
    t.view.physicalSize = const Size(360, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        home: SupportedGridPage(
          mode: mode,
          legacy: const Text('Eski oyun'),
          service: StorySupportService(
            transport: wire,
            currentUser: () => 'alice',
            useCallable: 'actGridSupport',
            loadCallable: 'getGridSupport',
            watchPlacement: 'grid_support_hint',
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return wire;
  }
  testWidgets('bot Grid uses the online scoreboard and the pinned input bar', (t) async {
    await openWith(t, 'bot_grid_classic', GridWire());
    expect(find.byKey(const ValueKey('grid-score')), findsOneWidget);
    expect(find.text('VS'), findsOneWidget);
    expect(find.text('SIRA SENDE'), findsOneWidget);
    expect(find.text('BOT'), findsWidgets);
    expect(find.byKey(const ValueKey('grid-input')), findsNothing);
    await t.tap(find.byKey(const ValueKey('grid-cell-0')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('grid-input')), findsOneWidget);
    expect(find.text('Futbolcu ara'), findsOneWidget);
    await t.tap(find.byTooltip('Seçimi kaldır'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('grid-input')), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('a verified random pair is placed by tapping an anchor on the board', (t) async {
    final wire = await openWith(t, 'bot_grid_random', GridWire()..verified = true);
    expect(find.text('YERLEŞTİR'), findsNWidgets(3));
    expect(find.byKey(const ValueKey('grid-input')), findsNothing);
    final swap = find.byKey(const ValueKey('grid-swap'));
    await t.scrollUntilVisible(swap.hitTestable(), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(swap);
    await t.pumpAndSettle();
    final anchor = find.byKey(const ValueKey('grid-cell-4'));
    await t.scrollUntilVisible(anchor.hitTestable(), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(anchor);
    await t.pumpAndSettle();
    final place = wire.calls.lastWhere((c) => c['action'] == 'place');
    expect(place['target'], 4);
    expect(place['swap'], true);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });
}
