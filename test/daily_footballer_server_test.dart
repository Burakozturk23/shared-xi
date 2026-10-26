import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/controllers/daily_footballer_controller.dart';
import 'package:shared_xi/models/daily_footballer.dart';
import 'package:shared_xi/screens/daily_footballer_page.dart';
import 'package:shared_xi/services/energy_service.dart';
import 'package:shared_xi/services/story_support_service.dart';
import 'package:shared_xi/services/daily_footballer_store.dart';
import 'package:shared_xi/widgets/paid_hint_button.dart';
import 'daily_footballer_test.dart' show MemoryFootballerStore, sampleCatalog;

class FootballerWire extends EnergyService {
  final calls = <Map<String, dynamic>>[];
  bool hint = false;
  @override
  Future<Map<String, dynamic>> call(String name, [Map<String, dynamic> input = const {}]) async {
    calls.add({'name': name, ...input});
    if (name == 'actDailyFootballer' && input['action'] == 'hint') hint = true;
    return {'legacy': false, 'catalog': {'version': sampleCatalog.version, 'asOf': sampleCatalog.asOf,
      'players': sampleCatalog.players.map((p) => p.toJson()).toList()},
      'serverNow': DateTime.utc(2026, 10, 6).millisecondsSinceEpoch,
      'session': {'id': 'df', 'dayKey': '2026-10-06', 'catalogVersion': sampleCatalog.version,
        'asOf': sampleCatalog.asOf, 'revision': hint ? 2 : 1, 'finished': false, 'won': false,
        'target': null, 'guesses': [sampleCatalog.players[1].toJson()], 'hintUsed': hint,
        'hint': hint ? 'Adı A harfiyle başlıyor.' : null, 'assisted': hint,
        'clues': {'1': [for (final label in ['Ülke', 'Kulüp', 'Lig', 'Mevki', 'Yaş', 'Forma'])
          {'label': label, 'value': 'Kayıtlı değer', 'match': 'different'}]},
        'support': {'version': 1, 'adRemaining': 1, 'products': [{'id': 'boost_basic', 'priceCoins': 25, 'ads': true}]}}};
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('server target permutation agrees with existing Dart catalog across dates', () {
    final c = DailyFootballerCatalog.fromJson(jsonDecode(File('assets/data/daily_footballer_catalog.json').readAsStringSync()));
    final vectors = jsonDecode(File('test/support/daily_footballer_targets.json').readAsStringSync()) as List;
    for (final v in vectors) {
      expect(c.targetFor(DateTime.parse('${v['day']}T12:00:00Z')).id, v['id']);
    }
  });
  test('legacy local save migrates to only one account and is guarded on account switch', () async {
    SharedPreferences.setMockInitialValues({LocalDailyFootballerStore.key: 'legacy'});
    var uid = 'alice'; final alice = LocalDailyFootballerStore(userId: 'alice', currentUser: () => uid);
    expect(await alice.read(), 'legacy');
    final bob = LocalDailyFootballerStore(userId: 'bob', currentUser: () => 'bob');
    expect(await bob.read(), isNull);
    await bob.write('bob progress'); expect(await alice.read(), 'legacy');
    uid = 'bob'; await expectLater(alice.read(), throwsStateError);
    await expectLater(alice.write('bad'), throwsStateError); expect(await bob.read(), 'bob progress');
  });
  testWidgets('server footballer hides target and sends paid hint with authoritative revision', (t) async {
    t.view.physicalSize = const Size(320, 1100); t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
    final wire = FootballerWire();
    final support = StorySupportService(transport: wire, currentUser: () => 'alice',
      useCallable: 'actDailyFootballer', loadCallable: 'getDailyFootballer', watchPlacement: 'daily_footballer_hint');
    final game = DailyFootballerController(catalog: sampleCatalog, store: MemoryFootballerStore(),
      watchAd: () async => throw StateError('legacy ad must not run'), server: support,
      clock: () => DateTime.utc(2026, 10, 6));
    addTearDown(game.dispose);
    await t.pumpWidget(MaterialApp(home: MediaQuery(data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
      child: DailyFootballerPage(controller: game)))); await t.pumpAndSettle();
    expect(game.round!.knownTarget, isNull); expect(game.round!.compare(game.round!.guesses.first).length, 6);
    expect(find.byKey(const ValueKey('daily-answer')), findsNothing);
    final target = find.byType(PaidHintButton).hitTestable();
    await t.scrollUntilVisible(target, 200, scrollable: find.byType(Scrollable).first, maxScrolls: 40);
    await t.pumpAndSettle();
    await t.widget<PaidHintButton>(target).onUse({'boostId': 'boost_basic', 'paymentSource': 'coins', 'expectedPriceCoins': 25});
    await t.pumpAndSettle();
    expect(wire.calls.last['action'], 'hint'); expect(wire.calls.last['revision'], 1);
    expect(wire.calls.last['sessionId'], 'df'); expect(wire.calls.last['requestId'], matches(RegExp(r'^[a-f0-9]{32}$')));
    expect(game.round!.assisted, true); expect(game.round!.hint, 'Adı A harfiyle başlıyor.');
    expect(t.takeException(), isNull); await t.pumpWidget(const SizedBox.shrink());
  });
}
