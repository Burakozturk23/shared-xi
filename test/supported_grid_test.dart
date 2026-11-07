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

class GridWire extends EnergyService {
  final calls = <Map<String, dynamic>>[];
  bool hinted = false, legacy = false, finished = false;
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
        'turn': 'user',
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
            if (random) null else {'id': 'country:$i', 'label': 'Milliyet $i'},
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
                'player': null,
              }
            : null,
        'support': {
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
            ? find.widgetWithText(ChoiceChip, 'Satır 1')
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
  }) async {
    t.view.physicalSize = const Size(320, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final wire = GridWire()..finished = finished;
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
    final chip = find.widgetWithText(ChoiceChip, 'Satır 1');
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
}
