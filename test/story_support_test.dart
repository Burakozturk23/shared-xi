import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/services/energy_service.dart';
import 'package:shared_xi/services/story_support_service.dart';
import 'package:shared_xi/widgets/paid_hint_button.dart';
import 'package:shared_xi/widgets/story_support_panel.dart';

Map<String, dynamic> publicSupport({bool used = false}) => {
  'legacy': false, 'contentVersion': 'v1', 'completed': false,
  'session': {'id': 'section', 'revision': used ? 1 : 0, 'finished': false,
    'support': {'version': 1, 'assisted': used, 'products': [
      {'id': 'boost_basic', 'priceCoins': 25, 'ads': true},
      {'id': 'boost_strong', 'priceCoins': 60, 'ads': false},
    ]}}, 'hints': {if (used) 'boost_basic': 'Doğrulanmış tarihsel bilgi'},
};
class Transport extends EnergyService {
  final calls = <Map<String, dynamic>>[];
  bool loseResponse = false, used = false, legacy = false;
  Completer<Map<String, dynamic>>? waitForLoad;
  @override
  Future<Map<String, dynamic>> call(String name, [Map<String, dynamic> input = const {}]) async {
    calls.add({'name': name, ...input});
    if (name == 'useStorySupport' || name == 'useDailyQuestionHint') {
      used = true;
      if (loseResponse) { loseResponse = false; throw FirebaseFunctionsException(code: 'unavailable', message: 'Lost response'); }
    } else if (waitForLoad != null) { return waitForLoad!.future; }
    return legacy ? {'legacy': true} : publicSupport(used: used);
  }
  @override
  Future<void> watch(String placement, {required bool pro, Map<String, dynamic>? context}) async {
    calls.add({'placement': placement, 'pro': pro, ...?context});
  }
}
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('lost story purchase replays same request after restart and keeps payment/content scope', () async {
    final transport = Transport()..loseResponse = true;
    var service = StorySupportService(transport: transport, currentUser: () => 'alice');
    final input = {'mode': 'nostalgia', 'targetId': 'task', 'contentVersion': 'v1', 'revision': 0,
      'sessionId': 'section', 'boostId': 'boost_basic', 'paymentSource': 'coins', 'expectedPriceCoins': 25};
    await expectLater(service.use(input), throwsA(isA<FirebaseFunctionsException>()));
    service = StorySupportService(transport: transport, currentUser: () => 'alice');
    await service.load('nostalgia', 'task');
    expect(transport.calls[0], transport.calls[1]);
    expect(transport.calls[0]['requestId'], matches(RegExp(r'^[a-f0-9]{32}$')));
    expect(transport.calls[0]['energyClientVersion'], 1);
    await service.watch({...input, 'boostId': 'boost_basic'});
    expect(transport.calls.last['pro'], false);
    expect(transport.calls.last['placement'], 'story_support_hint');
  });
  test('daily quiz retries its own callable and verified placement with the same stored request', () async {
    final transport = Transport()..loseResponse = true;
    StorySupportService service() => StorySupportService(transport: transport, currentUser: () => 'alice',
      useCallable: 'useDailyQuestionHint', loadCallable: 'getDailyQuestion', watchPlacement: 'daily_question_hint');
    final input = {'mode': 'daily_question', 'targetId': 'daily_question', 'day': '2026-10-25',
      'sessionId': 'quiz', 'revision': 0, 'boostId': 'boost_eliminate', 'paymentSource': 'coins',
      'expectedPriceCoins': 35};
    await expectLater(service().use(input), throwsA(isA<FirebaseFunctionsException>()));
    await service().load('daily_question', 'daily_question');
    expect(transport.calls[0], transport.calls[1]);
    expect(transport.calls[1]['name'], 'useDailyQuestionHint');
    expect(transport.calls[2]['name'], 'getDailyQuestion');
    await service().watch({'sessionId': 'quiz', 'boostId': 'boost_eliminate'});
    expect(transport.calls.last['placement'], 'daily_question_hint');
    expect(transport.calls.last['pro'], false);
  });
  test('late result cannot move a paid request to another account', () async {
    var uid = 'alice'; final transport = Transport()..waitForLoad = Completer<Map<String, dynamic>>();
    final service = StorySupportService(transport: transport, currentUser: () => uid);
    final loading = service.load('what_if', 'task');
    final check = expectLater(loading, throwsStateError);
    await Future<void>.delayed(Duration.zero); uid = 'bob';
    transport.waitForLoad!.complete(publicSupport()); await check;
  });
  testWidgets('paid story panel hides free controls, separates strong ads and shows verified hint at large text', (t) async {
    t.view.physicalSize = const Size(320, 1100); t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
    final transport = Transport();
    final service = StorySupportService(transport: transport, currentUser: () => 'alice');
    await t.pumpWidget(MaterialApp(home: MediaQuery(data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
      child: Scaffold(body: ListView(children: [StorySupportPanel(mode: 'nostalgia', targetId: 'task', service: service,
        legacy: const Text('Eski ücretsiz yardım'))])))));
    await t.pumpAndSettle();
    expect(find.text('Eski ücretsiz yardım'), findsNothing);
    final buttons = t.widgetList<PaidHintButton>(find.byType(PaidHintButton)).toList();
    expect(buttons.length, 2); expect(buttons.last.onWatch, isNull);
    await buttons.first.onUse({'boostId': 'boost_basic', 'paymentSource': 'coins', 'expectedPriceCoins': 25});
    await t.pumpAndSettle();
    expect(find.text('Bu bölüm: Yardımlı'), findsOneWidget);
    expect(find.text('Doğrulanmış tarihsel bilgi'), findsOneWidget); expect(t.takeException(), isNull);
    expect(transport.calls.last['contentVersion'], 'v1'); expect(transport.calls.last['targetId'], 'task');
  });
  testWidgets('server-preserved legacy rights retain original controls', (t) async {
    final service = StorySupportService(transport: Transport()..legacy = true, currentUser: () => 'alice');
    await t.pumpWidget(MaterialApp(home: StorySupportPanel(mode: 'what_if', targetId: 'task', service: service,
      legacy: const Text('Önceden kazanılmış Pro desteği'))));
    await t.pumpAndSettle();
    expect(find.text('Önceden kazanılmış Pro desteği'), findsOneWidget);
    expect(find.byType(PaidHintButton), findsNothing);
  });
}
