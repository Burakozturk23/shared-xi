import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/controllers/what_if_controller.dart';
import 'package:shared_xi/models/what_if.dart';
import 'package:shared_xi/services/journey_gateway.dart';
import 'package:shared_xi/services/what_if_store.dart';

WhatIfCatalog whatIfPack()=>WhatIfCatalog(jsonDecode(File('assets/data/what_if_v2.json').readAsStringSync()) as Map<String,dynamic>);
class MemoryWhatIfStore implements WhatIfStore {
  Map<String,dynamic> value={};bool fail=false;
  @override
  Future<Map<String,dynamic>> read() async=>jsonDecode(jsonEncode(value)) as Map<String,dynamic>;
  @override
  Future<void> write(Map<String,dynamic> next) async {
    if(fail)throw StateError('disk failure');value=jsonDecode(jsonEncode(next)) as Map<String,dynamic>;
  }
}
class FakeWhatIfGateway implements JourneyGateway {
  bool offline=false;final submissions=<Map<String,dynamic>>[];
  Map<String,dynamic> data={};
  @override
  Future<Map<String,dynamic>> call(String action,[Map<String,dynamic> input=const {}]) async {
    if(offline)throw StateError('offline');
    if(action=='submit')submissions.add(input);
    return data;
  }
  @override
  Future<void> watch(String placement,{Map<String,dynamic> context=const {}}) async {}
}
Future<void> solveWhatIf(WhatIfController c,WhatIfScenario s,String route) async {
  await c.selectRoute(s,route);
  for(final key in s.route(route).task.answers){await c.choose(s,key);}
  await c.submit(s);
}
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  test('24 scenarios, 48 solvable tasks; shuffle, wrong choice and wrong timeline fail',(){
    final pack=whatIfPack();expect(pack.scenarios.length,24);
    for(final s in pack.scenarios){
      expect(s.routes.length,2);
      for(final r in s.routes){
        expect(r.task.accepts(r.task.answers),isTrue);
        expect(r.task.accepts(['bad']),isFalse);
        expect(r.task.accepts([...r.task.answers,r.task.answers.first]),isFalse);
        if(r.task.timeline)expect(r.task.accepts(r.task.shuffled(Random(4))),isFalse);
      }
    }
  });
  test('resume route, picks and hint; replay retains both endings and favorites',() async {
    final pack=whatIfPack(),store=MemoryWhatIfStore(),s=whatIfPack().scenarios.first;
    final c=WhatIfController(catalog:pack,store:store);addTearDown(c.dispose);await c.initialize();
    await c.selectRoute(s,'alternate');await c.choose(s,'o0');await c.freeHint(s);await c.favorite(s);
    final restored=WhatIfController(catalog:pack,store:store);addTearDown(restored.dispose);await restored.initialize();
    expect(restored.route(s)!.id,'alternate');expect(restored.picked(s),['o0']);expect(restored.freeHintShown(s),isTrue);
    await restored.submit(s);expect(restored.ends(s),{'alternate'});
    await solveWhatIf(restored,s,'real');expect(restored.ends(s),{'real','alternate'});
    await restored.selectRoute(s,'alternate');expect(restored.ends(s).length,2);expect(restored.favorites,{s.id});
    expect(restored.cloud,isEmpty);expect(store.value['proofs'],isEmpty);
  });
  test('disk failure cannot advance or lose existing saves',() async {
    final pack=whatIfPack(),store=MemoryWhatIfStore();final c=WhatIfController(catalog:pack,store:store);addTearDown(c.dispose);
    await c.initialize();final s=pack.scenarios.first;
    await c.selectRoute(s,'real');await c.choose(s,'o0');store.fail=true;
    await c.submit(s);expect(c.phase(s),'task');expect(c.ends(s),isEmpty);expect(c.message,isNotNull);
    store.fail=false;await c.submit(s);expect(c.phase(s),'result');
  });
  test('offline proofs survive restart; only server response establishes reward',() async {
    final pack=whatIfPack(),store=MemoryWhatIfStore(),gateway=FakeWhatIfGateway()..offline=true;
    final c=WhatIfController(catalog:pack,store:store,gateway:gateway,userId:'alice');addTearDown(c.dispose);
    await c.initialize();await solveWhatIf(c,pack.scenarios.first,'real');await c.sync();
    expect((store.value['proofs'] as Map).length,1);expect(c.rewards,isEmpty);
    final next=WhatIfController(catalog:pack,store:store,gateway:gateway,userId:'alice');addTearDown(next.dispose);
    await next.initialize();gateway.offline=false;gateway.data={'rewards':{'scenario__messi':{'settled':true}}};
    await next.sync();expect((store.value['proofs'] as Map),isEmpty);expect(gateway.submissions.length,1);
    expect(next.rewards['scenario__messi']['settled'],isTrue);
  });
  test('cloud endings survive offline reopening, malformed save is not overwritten',() async {
    final pack=whatIfPack(),store=MemoryWhatIfStore(),gateway=FakeWhatIfGateway();
    gateway.data={'progress':{'messi':{'ends':{'alternate':123}}}};
    final c=WhatIfController(catalog:pack,store:store,gateway:gateway,userId:'alice');addTearDown(c.dispose);
    await c.initialize();await c.sync();expect(c.ends(pack.scenarios.first),{'alternate'});
    final next=WhatIfController(catalog:pack,store:store);addTearDown(next.dispose);await next.initialize();
    expect(next.ends(pack.scenarios.first),{'alternate'});
    store.value={'version':7};await next.initialize();expect(next.error,isNotNull);
    await next.selectRoute(pack.scenarios.first,'real');expect(store.value,{'version':7});
  });
  test('two open controllers merge disk writes without losing favorites or endings',() async {
    final pack=whatIfPack(),store=MemoryWhatIfStore();
    final a=WhatIfController(catalog:pack,store:store),b=WhatIfController(catalog:pack,store:store);
    addTearDown(a.dispose);addTearDown(b.dispose);await a.initialize();await b.initialize();
    await solveWhatIf(a,pack.scenarios.first,'real');
    await b.favorite(pack.scenarios[1]);
    final result=WhatIfController(catalog:pack,store:store);addTearDown(result.dispose);await result.initialize();
    expect(result.ends(pack.scenarios.first),{'real'});expect(result.favorites,{pack.scenarios[1].id});
  });
  test('all 48 route completions persist and timeline order survives restoration',() async {
    final pack=whatIfPack(),store=MemoryWhatIfStore();
    final c=WhatIfController(catalog:pack,store:store);addTearDown(c.dispose);await c.initialize();
    for(final s in pack.scenarios){for(final r in s.routes){await solveWhatIf(c,s,r.id);}}
    expect(c.complete,24);expect(c.dual,24);
    final next=WhatIfController(catalog:pack,store:store);addTearDown(next.dispose);await next.initialize();
    expect(next.complete,24);expect(next.dual,24);
    final s=pack.scenarios.firstWhere((s)=>s.routes.first.task.timeline);
    await next.selectRoute(s,'real');await next.choose(s,'o1');await next.choose(s,'o2');
    final again=WhatIfController(catalog:pack,store:store);addTearDown(again.dispose);await again.initialize();
    expect(again.picked(s),['o1','o2']);expect(again.ends(s).length,2);
  });

}
