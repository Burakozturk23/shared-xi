import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/controllers/derby_day_controller.dart';
import 'package:shared_xi/models/derby_task.dart';
import 'package:shared_xi/services/derby_day_service.dart';

Map<String,dynamic> privatePack()=>derbyMap(jsonDecode(File('functions/config/derby_day_catalog.json').readAsStringSync()));
DerbyDayCatalog derbyPack()=>DerbyDayCatalog(derbyMap(jsonDecode(File('assets/data/derby_day_v2.json').readAsStringSync())));
Map<String,dynamic> derbyPrivate(String id)=>(privatePack()['tasks'] as List).map(derbyMap).firstWhere((t)=>t['id']==id);
class MemoryDerbyDayStore implements DerbyDayStore {
  Map<String,dynamic> data={};
  @override Future<Map<String,dynamic>> read() async=>derbyMap(jsonDecode(jsonEncode(data)));
  @override Future<void> write(Map<String,dynamic> value)async{data=derbyMap(jsonDecode(jsonEncode(value)));}
}
class FakeDerbyDayGateway implements DerbyDayGateway {
  bool offline=false;
  final List<Map<String,dynamic>> hintRequests=[];
  final Map<String,dynamic> results={},rewards={};
  @override Future<Map<String,dynamic>> call(String action,[Map<String,dynamic> input=const{}])async{
    if(offline)throw StateError('offline');
    if(action=='hint')hintRequests.add(Map<String,dynamic>.from(input));
    if(action=='submit'){
      final t=derbyPrivate(input['taskId'] as String);
      final a=derbyStrings(input['answers']),b=derbyStrings(t['answerKeys']);
      if(t['interaction']=='multi'){a.sort();b.sort();}
      if(jsonEncode(a)!=jsonEncode(b))return {'correct':false};
      results[t['id'] as String]=t['result'];rewards[t['id'] as String]={'coins':8,'xp':20,'settled':true};
    }
    final stamps=<String,dynamic>{for(final id in results.keys) id:{'period':derbyPrivate(id)['result']['period'],'earnedAt':1791676800000}};
    return {'version':2,'correct':true,'results':Map<String,dynamic>.from(results),'stamps':stamps,
      'rewards':Map<String,dynamic>.from(rewards),'rewardEligible':true};
  }
}
void solve(DerbyDayController c){
  final keys=derbyStrings(derbyPrivate(c.activeId!)['answerKeys']);
  switch(c.active!.interaction){
    case 'order':
      for(var i=0;i<keys.length;i++){
        while(c.answers.indexOf(keys[i])>i){c.move(c.answers.indexOf(keys[i]),-1);}
      }
    case 'match':for(var i=0;i<keys.length;i++){c.assign(i,keys[i]);}
    case 'multi':
      for(final a in List<String>.from(c.answers)){c.choose(a);}
      for(final a in keys){c.choose(a);}
    default:c.choose(keys.single);
  }
}
class FailingDerbyDayStore extends MemoryDerbyDayStore {
  bool fail=true;
  @override Future<void> write(Map<String,dynamic> value)async{if(fail)throw StateError('disk');await super.write(value);}
}
class DelayedDerbyDayGateway extends FakeDerbyDayGateway {
  final response=Completer<Map<String,dynamic>>();
  @override Future<Map<String,dynamic>> call(String action,[Map<String,dynamic> input=const{}])async=>response.future;
}
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  test('All 48 tasks complete and replay; 48 stamps require one task each',()async{
    final c=DerbyDayController(catalog:derbyPack(),store:MemoryDerbyDayStore(),gateway:FakeDerbyDayGateway());
    addTearDown(c.dispose);await c.load();
    for(final t in c.catalog.tasks){
      expect(t.data.containsKey('answerKeys'),false);expect(t.data.containsKey('result'),false);
      c.open(t.id);c.start();
      if(t.interaction=='single'){
        c.choose(t.optionIds.firstWhere((x)=>!derbyStrings(derbyPrivate(t.id)['answerKeys']).contains(x)));
        await c.submit();expect(c.phase,'task');
      }
      solve(c);await c.submit();expect(c.phase,'result');
      expect(c.stampCount,t.data['number']);
      c.open(t.id,replay:true);c.start();solve(c);await c.submit();
    }
    expect(c.count,48);expect(c.coins,384);expect(c.stampCount,48);
  });
  test('Offline ordering survives reopening; queued answer syncs once',()async{
    final store=MemoryDerbyDayStore(),gateway=FakeDerbyDayGateway()..offline=true;
    final c=DerbyDayController(catalog:derbyPack(),store:store,gateway:gateway);
    await c.load();c.open('DER-04');c.start();solve(c);await c.submit();
    expect(c.count,0);expect(c.pending,isNotEmpty);c.dispose();
    final restored=DerbyDayController(catalog:derbyPack(),store:store,gateway:gateway);addTearDown(restored.dispose);
    await restored.load();expect(restored.answers,derbyStrings(derbyPrivate('DER-04')['answerKeys']));
    gateway.offline=false;await restored.sync();expect(restored.count,1);expect(restored.pending,isEmpty);expect(restored.phase,'result');
  });
  test('UID stores and stable storage version retain drafts across content updates',()async{
    SharedPreferences.setMockInitialValues({});final a=LocalDerbyDayStore('alice'),b=LocalDerbyDayStore('bob');
    await a.write({'storageVersion':1,'drafts':{'DER-01':['fake']},'activeId':'DER-01','phase':'task'});
    expect(await b.read(),isEmpty);
    final data=derbyMap(jsonDecode(File('assets/data/derby_day_v2.json').readAsStringSync()))..['version']=3;
    final c=DerbyDayController(catalog:DerbyDayCatalog(data),store:a,gateway:FakeDerbyDayGateway()..offline=true);addTearDown(c.dispose);
    await c.load();expect(c.activeId,'DER-01');expect(c.answers,isEmpty);expect(c.count,0);
  });
  test('Completed stamps survive an offline restart',()async{
    final store=MemoryDerbyDayStore(),gateway=FakeDerbyDayGateway();
    final c=DerbyDayController(catalog:derbyPack(),store:store,gateway:gateway);
    await c.load();for(final id in ['DER-01','DER-02']){c.open(id);c.start();solve(c);await c.submit();}c.dispose();
    gateway.offline=true;final reopened=DerbyDayController(catalog:derbyPack(),store:store,gateway:gateway);addTearDown(reopened.dispose);
    await reopened.load();expect(reopened.stampCount,2);expect(reopened.count,2);
  });
  test('Failed disk write prevents sending; disposed controller ignores late replies',()async{
    final store=FailingDerbyDayStore(),gateway=FakeDerbyDayGateway();
    final c=DerbyDayController(catalog:derbyPack(),store:store,gateway:gateway);addTearDown(c.dispose);
    await c.load();c.open('DER-01');c.start();solve(c);await c.submit();expect(gateway.results,isEmpty);
    store.fail=false;await c.submit();expect(c.count,1);
    final late=DelayedDerbyDayGateway();final old=DerbyDayController(catalog:derbyPack(),store:MemoryDerbyDayStore(),gateway:late);
    final loading=old.load();await Future<void>.delayed(Duration.zero);old.dispose();
    late.response.complete({'version':2,'results':{'DER-01':{'answer':'late'}}});await loading;expect(old.count,0);
  });
  test('Corrupt persisted JSON is not discarded',()async{
    SharedPreferences.setMockInitialValues({'derby_day.v1.alice':'{broken'});
    await expectLater(LocalDerbyDayStore('alice').read(),throwsFormatException);
    expect((await SharedPreferences.getInstance()).getString('derby_day.v1.alice'),'{broken');
  });
}
