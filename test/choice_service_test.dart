import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/services/choice_service.dart';
import 'package:shared_xi/services/energy_service.dart';
import 'package:shared_xi/models/rewarded_ad_models.dart';

Map<String,dynamic> initial() => {'version': 'test','session': {'id': 'session1','mode': 'this_or_that',
  'phase': 'active','revision': 1,'finished': false,'completed': false,'size': 16,
  'orderedCandidateIds': List.generate(16,(i) => 'p$i'),'history': [],'leftId': 'p0','rightId': 'p1',
  'roundSize': 16,'roundNumber': 1,'matchNumber': 1}};
class Wire extends EnergyService {
  Map<String,dynamic> snapshot = initial(); bool offline = false, loseReply = false;
  void Function()? duringCall;
  final seen = <String>{}; final attempts = <List<String>>[];
  @override
  Future<Map<String,dynamic>> call(String name, [Map<String,dynamic> input = const {}]) async {
    duringCall?.call();
    if (offline) throw FirebaseFunctionsException(code: 'unavailable',message: 'offline');
    if (name == 'replayChoice') {
      final events = (input['events'] as List).map(rewardMap).toList();
      attempts.add(events.map((e) => '${e['requestId']}').toList());
      for (final e in events) {
        if (seen.add('${e['requestId']}')) snapshot['session'] = ChoiceService.tournamentStep(rewardMap(snapshot['session']),e);
      }
      if (loseReply) {loseReply = false; throw FirebaseFunctionsException(code: 'deadline-exceeded',message: 'lost reply');}
    }
    return rewardMap(jsonDecode(jsonEncode(snapshot)));
  }
}
Map<String,dynamic> choose(Map<String,dynamic> snapshot) {
  final r = rewardMap(snapshot['session']); return {'mode': 'this_or_that','sessionId': r['id'],
    'revision': r['revision'],'action': 'choose','candidateId': r['leftId']};
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('lost reply, fifteen offline decisions and restart reuse exact request identities', () async {
    final wire = Wire(); final service = ChoiceService(transport: wire,currentUser: () => 'alice');
    var snapshot = await service.load('this_or_that'); wire.loseReply = true;
    snapshot = await service.mutate(choose(snapshot)); expect(snapshot['offline'],true);
    final firstId = wire.attempts.single.single; wire.offline = true;
    for (var i=1;i<15;i++) snapshot = await service.mutate(choose(snapshot));
    expect(rewardMap(snapshot['session'])['completed'],true); expect(rewardMap(snapshot['session'])['earnedCoins'],0);
    final restarted = ChoiceService(transport: wire,currentUser: () => 'alice');
    expect(rewardMap((await restarted.load('this_or_that'))['session'])['history'],hasLength(15));
    wire.offline = false; snapshot = await restarted.load('this_or_that');
    expect(snapshot['offline'],false); expect(wire.seen,hasLength(15)); expect(wire.attempts.last.first,firstId);
    expect((await SharedPreferences.getInstance()).containsKey('choice.v1.alice.this_or_that.journal'),false);
  });
  test('crash after journal before snapshot reconstructs missing choice only once', () async {
    final snapshot = initial(); final event = {...choose(snapshot),'requestId': 'event1'};
    SharedPreferences.setMockInitialValues({'choice.v1.alice.this_or_that': jsonEncode(snapshot),
      'choice.v1.alice.this_or_that.journal': jsonEncode({'call': 'replayChoice','input': {'mode': 'this_or_that','events': [event]}})});
    final wire = Wire()..offline = true;
    final service = ChoiceService(transport: wire,currentUser: () => 'alice');
    for (var i=0;i<2;i++) {
      final result = await service.load('this_or_that'); expect(rewardMap(result['session'])['revision'],2);
      expect(rewardMap(result['session'])['history'],hasLength(1));
    }
  });
  test('account change during transport cannot write snapshot under previous account', () async {
    String uid = 'alice'; final wire = Wire()..duringCall = () => uid = 'bob';
    final service = ChoiceService(transport: wire,currentUser: () => uid);
    await expectLater(service.load('this_or_that'),throwsStateError);
    expect((await SharedPreferences.getInstance()).getString('choice.v1.alice.this_or_that'),isNull);
  });
  test('offline account B cannot read account A cache', () async {
    final wire = Wire(); await ChoiceService(transport: wire,currentUser: () => 'alice').load('this_or_that');
    wire.offline = true;
    await expectLater(ChoiceService(transport: wire,currentUser: () => 'bob').load('this_or_that'),throwsA(isA<FirebaseFunctionsException>()));
  });
  test('offline undo crosses round boundary but final cannot be undone', () {
    var snapshot = initial();
    for (var i=0;i<8;i++) snapshot['session'] = ChoiceService.tournamentStep(rewardMap(snapshot['session']),choose(snapshot));
    var run = rewardMap(snapshot['session']); expect(run['roundSize'],8);
    run = ChoiceService.tournamentStep(run,{'mode': 'this_or_that','sessionId': run['id'],'revision': run['revision'],'action': 'undo'});
    expect(run['roundSize'],16); snapshot['session'] = run;
    while (rewardMap(snapshot['session'])['finished'] != true) {
      snapshot['session'] = ChoiceService.tournamentStep(rewardMap(snapshot['session']),choose(snapshot));
    }
    run = rewardMap(snapshot['session']);
    expect(() => ChoiceService.tournamentStep(run,{'mode': 'this_or_that','sessionId': run['id'],
      'revision': run['revision'],'action': 'undo'}),throwsStateError);
  });
}
