import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/controllers/international_glory_controller.dart';
import 'package:shared_xi/models/international_match.dart';
import 'package:shared_xi/services/international_glory_service.dart';

InternationalCatalog igPack() => InternationalCatalog(igMap(jsonDecode(File('assets/data/international_glory_v2.json').readAsStringSync())));
Map<String, dynamic> igPrivate(String id) => (jsonDecode(File('functions/config/international_catalog.json').readAsStringSync())['matches'] as List)
    .map(igMap).firstWhere((m) => m['id'] == id);
class MemoryInternationalStore implements InternationalStore {
  Map<String, dynamic> data = {};
  @override Future<Map<String, dynamic>> read() async => igMap(jsonDecode(jsonEncode(data)));
  @override Future<void> write(Map<String, dynamic> value) async { data = igMap(jsonDecode(jsonEncode(value))); }
}
class FakeInternationalGateway implements InternationalGateway {
  bool offline = false;
  final List<Map<String, dynamic>> hintRequests = [];
  final Map<String, dynamic> results = {}, rewards = {};
  @override Future<Map<String, dynamic>> call(String action, [Map<String, dynamic> input = const {}]) async {
    if (offline) throw StateError('offline');
    if (action == 'hint') hintRequests.add(Map<String, dynamic>.from(input));
    if (action == 'submit') {
      final m = igPrivate(input['matchId'] as String);
      if (jsonEncode(input['answers']) != jsonEncode(m['answerKeys'])) return {'correct': false};
      results[m['id'] as String] = m['result'];
      rewards[m['id'] as String] = {'coins':8,'xp':20,'settled':true};
    }
    return {'version':2,'correct':true,'results':Map<String,dynamic>.from(results),
      'rewards':Map<String,dynamic>.from(rewards),'rewardEligible':true};
  }
}
void selectCorrect(InternationalGloryController c) {
  final keys = igStrings(igPrivate(c.activeId!)['answerKeys']);
  if (c.active!.type == 'timeline') {
    for (var i=0; i<keys.length; i++) {
      while(c.answers.indexOf(keys[i]) > i) { c.move(c.answers.indexOf(keys[i]), -1); }
    }
  } else if (c.active!.type == 'route') { for (var i=0; i<keys.length; i++) { c.assign(i, keys[i]); } } else { c.choose(keys.single); }
}
class FailingInternationalStore extends MemoryInternationalStore {
  bool fail = true;
  @override Future<void> write(Map<String,dynamic> value) async {
    if (fail) throw StateError('disk full');
    await super.write(value);
  }
}
class DelayedInternationalGateway extends FakeInternationalGateway {
  final response = Completer<Map<String,dynamic>>();
  @override Future<Map<String,dynamic>> call(String action,[Map<String,dynamic> input=const {}]) async => response.future;
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('All 40 tasks retry, complete and replay without client answer keys', () async {
    final c = InternationalGloryController(catalog:igPack(),store:MemoryInternationalStore(),gateway:FakeInternationalGateway());
    addTearDown(c.dispose); await c.load();
    for(final m in c.catalog.matches) {
      expect(m.data.containsKey('answerKeys'), false); expect(m.data.containsKey('result'), false);
      c.open(m.id); c.start();
      if(!m.ordered) {
        final correct=igStrings(igPrivate(m.id)['answerKeys']);
        c.choose(m.optionIds.firstWhere((id)=>!correct.contains(id)));
        await c.submit(); expect(c.phase,'task'); expect(c.results.containsKey(m.id),false);
      }
      selectCorrect(c); await c.submit(); expect(c.phase,'result');
      c.open(m.id,replay:true); c.start(); selectCorrect(c); await c.submit();
    }
    expect(c.count,40); expect(c.coins,320); // Milestones are separately covered by real server tests.
  });
  test('Offline ordered draft and pending answer survive reopen and synchronize', () async {
    final store=MemoryInternationalStore(), gateway=FakeInternationalGateway()..offline=true;
    final c=InternationalGloryController(catalog:igPack(),store:store,gateway:gateway);
    await c.load(); c.open('ig2_02'); c.start(); selectCorrect(c); await c.submit();
    expect(c.count,0); expect(c.pending.containsKey('ig2_02'),true); c.dispose();
    final restored=InternationalGloryController(catalog:igPack(),store:store,gateway:gateway);
    addTearDown(restored.dispose); await restored.load();
    expect(restored.phase,'task'); expect(restored.answers,igStrings(igPrivate('ig2_02')['answerKeys']));
    gateway.offline=false; await restored.sync();
    expect(restored.phase,'result'); expect(restored.count,1); expect(restored.pending,isEmpty);
  });
  test('Route slots restore empty and moving an opponent clears the previous slot', () async {
    final c = InternationalGloryController(catalog:igPack(),store:MemoryInternationalStore(),gateway:FakeInternationalGateway());
    addTearDown(c.dispose); await c.load(); c.open('ig2_36'); c.start(); expect(c.canSubmit,false);
    c.assign(0,c.active!.optionIds.first); c.assign(1,c.active!.optionIds.first);
    expect(c.answers[0],''); expect(c.canSubmit,false); selectCorrect(c); expect(c.canSubmit,true);
  });
  test('Local stores isolate users and malformed UI state cannot unlock a match', () async {
    SharedPreferences.setMockInitialValues({});
    final a=LocalInternationalStore('alice'), b=LocalInternationalStore('bob');
    await a.write({'version':2,'drafts':{'ig2_01':['forged']},'activeId':'ig2_01','phase':'result'});
    expect(await b.read(),isEmpty);
    final c=InternationalGloryController(catalog:igPack(),store:a,gateway:FakeInternationalGateway()..offline=true);
    addTearDown(c.dispose); await c.load(); expect(c.count,0); expect(c.phase,'task'); expect(c.answers,isEmpty);
  });
  test('Malformed route draft restores safe empty slots, not a broken task', () async {
    final store = MemoryInternationalStore()..data = {'version':2,'activeId':'ig2_36','phase':'task','drafts':{'ig2_36':['fake']}};
    final c=InternationalGloryController(catalog:igPack(),store:store,gateway:FakeInternationalGateway()..offline=true);
    addTearDown(c.dispose); await c.load(); expect(c.answers,['','']); expect(c.canSubmit,false);
    c.assign(1,c.active!.optionIds.first); expect(c.answers[1],c.active!.optionIds.first);
  });

  test('Disk failure prevents sending; retry persists then validates', () async {
    final store = FailingInternationalStore(), gateway = FakeInternationalGateway();
    final c = InternationalGloryController(catalog:igPack(),store:store,gateway:gateway);
    addTearDown(c.dispose); await c.load(); c.open('ig2_01'); c.start(); selectCorrect(c);
    await c.submit(); expect(gateway.results,isEmpty); expect(c.count,0);
    store.fail=false; await c.submit(); expect(c.count,1); expect(c.phase,'result');
  });
  test('Late replies after disposal cannot mutate progress or notify widgets', () async {
    final gateway = DelayedInternationalGateway();
    final c=InternationalGloryController(catalog:igPack(),store:MemoryInternationalStore(),gateway:gateway);
    final loading=c.load(); await Future<void>.delayed(Duration.zero); c.dispose();
    gateway.response.complete({'version':2,'results':{'ig2_01':{'answer':'late'}},'rewards':{}});
    await loading; expect(c.results,isEmpty);
  });
  test('Corrupt persisted JSON remains intact for recovery', () async {
    SharedPreferences.setMockInitialValues({'international_glory.v2.alice':'{broken'});
    await expectLater(LocalInternationalStore('alice').read(),throwsFormatException);
    expect((await SharedPreferences.getInstance()).getString('international_glory.v2.alice'),'{broken');
  });

}
