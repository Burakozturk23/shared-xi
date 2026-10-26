import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/screens/supported_grid_page.dart';
import 'package:shared_xi/services/energy_service.dart';
import 'package:shared_xi/services/story_support_service.dart';
import 'package:shared_xi/widgets/paid_hint_button.dart';

class GridWire extends EnergyService {
  final calls = <Map<String, dynamic>>[];
  bool hinted = false, legacy = false;
  Completer<Map<String, dynamic>>? pending;
  @override
  Future<Map<String, dynamic>> call(String name, [Map<String, dynamic> input = const {}]) async {
    calls.add({'callable': name, ...input});
    if (pending != null) return pending!.future;
    if (name == 'actGridSupport' && input['action'] == 'hint') hinted = true;
    final mode = input['mode'] as String;
    final reverse = mode.endsWith('reverse'), random = mode.endsWith('random');
    return {'legacy': legacy, 'availability': true, 'version': 'v', 'session': {
      'id': 'run', 'version': 'v', 'mode': mode, 'revision': hinted ? 1 : 0,
      'finished': false, 'turn': 'user', 'assisted': hinted, 'cells': <String, dynamic>{}, 'axes': <String, dynamic>{},
      'userScore': 0, 'botScore': 0, 'roundsUsed': 0, 'pairNumber': 1,
      'rows': [for (var i = 0; i < 3; i++) if (random) null else {'id': 'club:$i', 'label': 'Kulüp $i'}],
      'cols': [for (var i = 0; i < 3; i++) if (random) null else {'id': 'country:$i', 'label': 'Milliyet $i'}],
      'witnesses': [for (var i = 0; i < 9; i++) {'id': '$i', 'name': 'Futbolcu $i'}],
      'hints': {if (hinted) (reverse ? 'axis_0' : random ? 'pair_1' : 'cell_0'): 'Doğrulanmış bilgi'},
      'pending': random ? {'criteria': [{'label': 'Birinci kulüp'}, {'label': 'İkinci kulüp'}], 'player': null} : null,
      'support': {'version': 1, 'adRemaining': 2, 'products': [{'id': 'boost_basic', 'priceCoins': 25, 'ads': true}]},
    }};
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final kind in ['classic', 'reverse', 'random']) {
    testWidgets('Grid $kind keeps paid target, revision and assisted state at 320px/180%', (t) async {
      t.view.physicalSize = const Size(320, 1000); t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
      final wire = GridWire();
      final service = StorySupportService(transport: wire, currentUser: () => 'alice', useCallable: 'actGridSupport',
        loadCallable: 'getGridSupport', watchPlacement: 'grid_support_hint');
      await t.pumpWidget(MaterialApp(home: MediaQuery(data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
        child: SupportedGridPage(mode: 'solo_grid_$kind', legacy: const Text('Eski oyun'), service: service))));
      await t.pumpAndSettle();
      final select = kind == 'classic' ? find.byKey(const ValueKey('grid-cell-0')) :
        kind == 'reverse' ? find.widgetWithText(ChoiceChip, 'Satır 1') : find.text('Ortak oyuncuyu bul');
      await t.scrollUntilVisible(select.hitTestable(), 200, scrollable: find.byType(Scrollable).first, maxScrolls: 60);
      await t.tap(select); await t.pumpAndSettle();
      final paid = find.byType(PaidHintButton).hitTestable();
      await t.scrollUntilVisible(paid, 200, scrollable: find.byType(Scrollable).first, maxScrolls: 60);
      await t.widget<PaidHintButton>(paid).onUse({'boostId': 'boost_basic', 'paymentSource': 'coins', 'expectedPriceCoins': 25});
      await t.pumpAndSettle();
      final input = wire.calls.last;
      expect(input['action'], 'hint'); expect(input['mode'], 'solo_grid_$kind');
      expect(input['target'], kind == 'random' ? 'pending' : 0); expect(input['revision'], 0);
      expect(input['sessionId'], 'run'); expect(input['requestId'], matches(RegExp(r'^[a-f0-9]{32}$')));
      expect(find.text('Doğrulanmış bilgi'), findsOneWidget); expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('Grid rollout response opens existing legacy route', (t) async {
    final wire = GridWire()..legacy = true;
    final service = StorySupportService(transport: wire, currentUser: () => 'alice', loadCallable: 'getGridSupport');
    await t.pumpWidget(MaterialApp(home: SupportedGridPage(mode: 'bot_grid_classic', service: service,
      legacy: const Text('Mevcut yerel oyun')))); await t.pumpAndSettle();
    expect(find.text('Mevcut yerel oyun'), findsOneWidget); await t.pumpWidget(const SizedBox.shrink());
  });
  test('Grid rejects late account response and keeps request scoped to original owner', () async {
    final wire = GridWire()..pending = Completer<Map<String, dynamic>>(); var uid = 'alice';
    final service = StorySupportService(transport: wire, currentUser: () => uid, useCallable: 'actGridSupport');
    final future = service.use({'mode': 'solo_grid_classic', 'targetId': 'solo_grid_classic',
      'action': 'hint', 'sessionId': 'run', 'target': 0});
    final assertion = expectLater(future, throwsStateError);
    await Future<void>.delayed(const Duration(milliseconds: 20)); uid = 'bob';
    wire.pending!.complete({'session': {'assisted': true}}); await assertion;
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('story.support.v1.alice.solo_grid_classic.solo_grid_classic'), true);
    expect(prefs.containsKey('story.support.v1.bob.solo_grid_classic.solo_grid_classic'), false);
  });
}
