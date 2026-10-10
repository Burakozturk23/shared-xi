import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/controllers/ucl_moments_controller.dart';
import 'package:shared_xi/models/ucl_moment.dart';
import 'package:shared_xi/services/ucl_moments_service.dart';

UclCatalog uclPack() => UclCatalog(uclMap(jsonDecode(File('assets/data/ucl_moments_v2.json').readAsStringSync())));
Map<String, dynamic> uclPrivate(String id) => (jsonDecode(File('functions/config/ucl_catalog.json').readAsStringSync())['matches'] as List)
    .map(uclMap).firstWhere((m) => m['id'] == id);
class MemoryUclStore implements UclStore {
  Map<String, dynamic> data = {};
  @override Future<Map<String, dynamic>> read() async => uclMap(jsonDecode(jsonEncode(data)));
  @override Future<void> write(Map<String, dynamic> value) async { data = uclMap(jsonDecode(jsonEncode(value))); }
}
class FakeUclGateway implements UclGateway {
  bool offline = false;
  final Map<String, dynamic> results = {}, rewards = {};
  @override Future<Map<String, dynamic>> call(String action, [Map<String, dynamic> input = const {}]) async {
    if (offline) throw StateError('offline');
    if (action == 'submit') {
      final m = uclPrivate(input['matchId'] as String);
      if (jsonEncode(input['answers']) != jsonEncode(m['answerKeys'])) return {'correct': false};
      results[m['id'] as String] = m['result'];
      rewards[m['id'] as String] = {'coins':8,'xp':20,'settled':true};
    }
    return {'version':1,'correct':true,'results':Map<String,dynamic>.from(results),
      'rewards':Map<String,dynamic>.from(rewards),'rewardEligible':true};
  }
}
void selectCorrect(UclMomentsController c) {
  final keys = uclStrings(uclPrivate(c.activeId!)['answerKeys']);
  if (c.active!.type == 'timeline') {
    for (var i=0; i<keys.length; i++) {
      while(c.answers.indexOf(keys[i]) > i) { c.move(c.answers.indexOf(keys[i]), -1); }
    }
  } else { c.choose(keys.single); }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('All 34 tasks retry, complete and replay without client answer keys', () async {
    final c = UclMomentsController(catalog:uclPack(),store:MemoryUclStore(),gateway:FakeUclGateway());
    addTearDown(c.dispose); await c.load();
    for(final m in c.catalog.matches) {
      expect(m.data.containsKey('answerKeys'), false); expect(m.data.containsKey('result'), false);
      c.open(m.id); c.start();
      if(m.type!='timeline') {
        final correct=uclStrings(uclPrivate(m.id)['answerKeys']);
        c.choose(m.optionIds.firstWhere((id)=>!correct.contains(id)));
        await c.submit(); expect(c.phase,'task'); expect(c.results.containsKey(m.id),false);
      }
      selectCorrect(c); await c.submit(); expect(c.phase,'result');
      c.open(m.id,replay:true); c.start(); selectCorrect(c); await c.submit();
    }
    expect(c.count,34); expect(c.coins,272); // Milestones are separately covered by real server tests.
  });
  test('Offline ordered draft and pending answer survive reopen and synchronize', () async {
    final store=MemoryUclStore(), gateway=FakeUclGateway()..offline=true;
    final c=UclMomentsController(catalog:uclPack(),store:store,gateway:gateway);
    await c.load(); c.open('ucl_07'); c.start(); selectCorrect(c); await c.submit();
    expect(c.count,0); expect(c.pending.containsKey('ucl_07'),true); c.dispose();
    final restored=UclMomentsController(catalog:uclPack(),store:store,gateway:gateway);
    addTearDown(restored.dispose); await restored.load();
    expect(restored.phase,'task'); expect(restored.answers,uclStrings(uclPrivate('ucl_07')['answerKeys']));
    gateway.offline=false; await restored.sync();
    expect(restored.phase,'result'); expect(restored.count,1); expect(restored.pending,isEmpty);
  });
  test('Local stores isolate users and malformed UI state cannot unlock a match', () async {
    SharedPreferences.setMockInitialValues({});
    final a=LocalUclStore('alice'), b=LocalUclStore('bob');
    await a.write({'version':1,'drafts':{'ucl_01':['forged']},'activeId':'ucl_01','phase':'result'});
    expect(await b.read(),isEmpty);
    final c=UclMomentsController(catalog:uclPack(),store:a,gateway:FakeUclGateway()..offline=true);
    addTearDown(c.dispose); await c.load(); expect(c.count,0); expect(c.phase,'task'); expect(c.answers,isEmpty);
  });
}
