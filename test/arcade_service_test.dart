import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/models/burst_offline.dart';
import 'package:shared_xi/models/rewarded_ad_models.dart';
import 'package:shared_xi/services/arcade_service.dart';
import 'package:shared_xi/services/energy_service.dart';

final catalog = rewardMap(jsonDecode(File('functions/config/arcade_catalog.json').readAsStringSync()));
final vectors = rewardMap(jsonDecode(File('test/fixtures/burst_offline_vectors.json').readAsStringSync()));
class ArcadeWire extends EnergyService {
  final kit = {'version': catalog['version'], 'questions': catalog['burst'], 'players': catalog['players']};
  Map<String,dynamic> run = rewardMap((vectors['scenarios'] as List).first['initial']);
  final seen = <String>{};
  final calls = <Map<String,dynamic>>[];
  bool fail = false, acceptedButLost = false;
  void Function()? beforeReturn;
  @override
  Future<Map<String,dynamic>> call(String name, [Map<String,dynamic> input = const {}]) async {
    calls.add({'name': name, ...input});
    void apply(Map<String,dynamic> event) {
      if (seen.add('${event['requestId']}')) {
        if (event['revision'] != run['revision']) throw FirebaseFunctionsException(code: 'aborted');
        run = BurstOffline(kit).apply(run,event)..remove('pendingValidation');
      }
    }
    if (name == 'actArcade' && acceptedButLost) {apply(input); acceptedButLost = false; throw FirebaseFunctionsException(code: 'unavailable');}
    if (fail) throw FirebaseFunctionsException(code: 'unavailable');
    if (name == 'actArcade') apply(input);
    if (name == 'replayArcade') for (final e in input['events'] as List) {apply(rewardMap(e));}
    beforeReturn?.call();
    return {'version': catalog['version'], 'session': run, 'burstKit': kit, 'linked': true,
      'availability': {'enabled': true, 'rewardsEnabled': true}, 'records': {}, 'medals': {}, 'pendingCoins': 0};
  }
}
Map<String,dynamic> event(Map<String,dynamic> data, String action, {int elapsed = 1000, String? id}) {
  final r = rewardMap(data['session']);
  return {'mode': 'burst', 'sessionId': r['id'], 'revision': r['revision'], 'action': action,
    'questionId': rewardMap(r['question'])['id'], 'elapsedMs': elapsed, if (id != null) 'entityId': id};
}
String nextPlayer(Map<String,dynamic> data) {
  final r = rewardMap(data['session']); final q = (catalog['burst'] as List).map(rewardMap)
    .firstWhere((q) => q['id'] == rewardMap(r['question'])['id']);
  final used = (r['found'] as List).map((p) => rewardMap(p)['id']);
  return '${(q['answers'] as List).firstWhere((id) => !used.contains(id))}';
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('lost reply, offline continuation and restart replay the original request IDs once', () async {
    final wire = ArcadeWire(); ArcadeService service() => ArcadeService(transport: wire, currentUser: () => 'alice');
    final s = service(); var data = await s.load('burst'); wire.acceptedButLost = true;
    data = await s.mutate(event(data, 'answer', id: nextPlayer(data)));
    expect(data['offlinePlayable'], isTrue); final original = wire.calls.last['requestId'];
    data = await s.mutate(event(data, 'answer', id: nextPlayer(data))); expect(rewardMap(data['session'])['correct'], 2);
    wire.fail = true; final restarted = service(); data = await restarted.load('burst');
    expect(data['offlinePlayable'], isTrue); expect(rewardMap(data['session'])['correct'], 2);
    wire.fail = false; data = await restarted.load('burst');
    expect(data['offline'], isFalse); expect(rewardMap(data['session'])['correct'], 2);
    expect(wire.seen.contains(original), isTrue);
    final prefs = await SharedPreferences.getInstance(); expect(prefs.containsKey('arcade.v1.alice.burst.queue'), isFalse);
    expect(prefs.getString('arcade.v1.alice.burst')!.contains('players'), isFalse); // kit is stored once, separately
  });
  test('unsent clock checkpoints coalesce without crossing round boundaries', () async {
    final wire = ArcadeWire(); final service = ArcadeService(transport: wire, currentUser: () => 'alice');
    var data = await service.load('burst');
    for (var i = 0; i < 35; i++) {data = await service.checkpoint(event(data,'tick'));}
    final prefs = await SharedPreferences.getInstance(); final queue = jsonDecode(prefs.getString('arcade.v1.alice.burst.queue')!) as List;
    expect(queue.length, 2); expect(queue.first['elapsedMs'], 30000); expect(queue.last['elapsedMs'], 5000);
    expect(wire.calls.length, 1); expect(rewardMap(data['session'])['activeMs'], 35000);
    data = await service.mutate(event(data,'answer', elapsed: 0, id: nextPlayer(data)));
    expect(wire.calls.last['name'], 'replayArcade'); expect(wire.run['activeMs'], 35000);
    expect(wire.run['roundAt'], 30000); expect(wire.run['score'], 100);
  });
  test('account changes cannot cache or display another UID response', () async {
    String? uid = 'alice'; final wire = ArcadeWire(); final service = ArcadeService(transport: wire, currentUser: () => uid);
    wire.beforeReturn = () => uid = 'bob'; await expectLater(service.load('burst'), throwsStateError);
    final prefs = await SharedPreferences.getInstance(); expect(prefs.getString('arcade.v1.alice.burst'), isNull);
    expect(prefs.getString('arcade.v1.bob.burst'), isNull);
  });
  test('offline snapshots and frozen answer kits cannot cross account boundaries', () async {
    final wire = ArcadeWire(); await ArcadeService(transport: wire, currentUser: () => 'alice').load('burst'); wire.fail = true;
    await expectLater(ArcadeService(transport: wire, currentUser: () => 'bob').load('burst'), throwsA(isA<FirebaseFunctionsException>()));
  });
}
