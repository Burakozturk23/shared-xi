import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/controllers/journey_rewards_controller.dart';
import 'package:shared_xi/services/journey_gateway.dart';
import 'package:shared_xi/screens/journey_passport_page.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'journey_v2_test.dart' show journeyTestPack;
import 'journey_v2_page_test.dart' show snapshot;

class FakeJourneyGateway implements JourneyGateway {
  final calls=<Map<String,dynamic>>[];
  Map<String,dynamic> state={'completed':<String>[],'favorites':<String>[]};
  String? failingJourney;
  Completer<void>? adWait;
  @override
  Future<Map<String,dynamic>> call(String action,[Map<String,dynamic> input=const{}]) async {
    calls.add({'action':action,...input});
    if(action=='submit' && input['journeyId']==failingJourney) throw StateError('offline');
    if(action=='favorites') state['favorites']=input['ids'];
    return state;
  }
  @override
  Future<void> watch(String placement,{Map<String,dynamic> context=const{}}) async { await adWait?.future; }
}
Future<void> idle(JourneyRewardsController c) async {
  for(var i=0;i<100 && c.busy;i++) { await Future<void>.delayed(const Duration(milliseconds:1)); }
  expect(c.busy,isFalse);
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  test('offline proof survives controller recreation and only acknowledgement removes it',() async {
    final j=journeyTestPack().first, api=FakeJourneyGateway()..failingJourney='messi';
    final c=JourneyRewardsController(gateway:api,userId:'alice');
    await c.enqueue(j.id,j.tasks.first,j.tasks.first.answerKeys); await idle(c); c.dispose();
    final prefs=await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString('journey.proofs.v1.alice')!) as Map,isNotEmpty);
    api.failingJourney=null;
    final restored=JourneyRewardsController(gateway:api,userId:'alice');addTearDown(restored.dispose);
    await restored.refresh();
    expect(jsonDecode(prefs.getString('journey.proofs.v1.alice')!),isEmpty);
  });
  test('one legacy skipped stage does not block other journeys or leak across accounts',() async {
    final prefs=await SharedPreferences.getInstance();
    await prefs.setString('journey.proofs.v1.alice',jsonEncode({
      'messi_v2_4':{'journeyId':'messi','taskId':'messi_v2_4'},
      'ronaldo_v2_1':{'journeyId':'ronaldo','taskId':'ronaldo_v2_1'},
    }));
    final api=FakeJourneyGateway()..failingJourney='messi';
    final bob=JourneyRewardsController(gateway:api,userId:'bob');addTearDown(bob.dispose);
    await bob.refresh();expect(api.calls.where((c)=>c['action']=='submit'),isEmpty);
    final alice=JourneyRewardsController(gateway:api,userId:'alice');addTearDown(alice.dispose);
    await alice.refresh();
    expect((jsonDecode(prefs.getString('journey.proofs.v1.alice')!) as Map).keys,['messi_v2_4']);
    expect(alice.message,contains('Diğer kariyerlerin etkilenmez'));
  });
  test('proof enqueued during ad completion is flushed afterwards',() async {
    final api=FakeJourneyGateway()..adWait=Completer<void>();
    final c=JourneyRewardsController(gateway:api,userId:'alice');addTearDown(c.dispose);
    final ad=c.action('story_hint',{},ad:true);
    final j=journeyTestPack().first;
    await c.enqueue(j.id,j.tasks.first,j.tasks.first.answerKeys);
    api.adWait!.complete();await ad;await idle(c);
    expect(api.calls.where((c)=>c['action']=='submit').length,1);
  });
  for(final large in [false,true]) {
    testWidgets('passport has chapter rewards, favorite actions and readable narrow layout $large',(tester) async {
      tester.view.physicalSize=Size(large?320:390,844);tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      final api=FakeJourneyGateway()..state={
        'completed':['messi','ronaldo','ronaldinho','modric','zidane','kaka','benzema','maldini'],
        'favorites':['messi'], 'rewards':{'chapter__1':{'settled':true}},
      };
      final c=JourneyRewardsController(gateway:api,userId:'alice');addTearDown(c.dispose);
      final key=GlobalKey();
      await tester.pumpWidget(MaterialApp(theme:large?OrtakSahaTheme.light:OrtakSahaTheme.dark,
        builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(large?1.8:1)),
          child:RepaintBoundary(key:key,child:child!)),home:JourneyPassportPage(controller:c)));
      await tester.runAsync(() async {
        for(var i=0;i<100;i++) {
          await tester.pump();
          if(find.text('8 / 32 kariyer damgası').evaluate().isNotEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds:20));
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('8 / 32 kariyer damgası'),findsOneWidget);
      expect(tester.takeException(),isNull);
      await snapshot(tester,key,'passport-${large?"large-light":"dark"}');
      await tester.scrollUntilVisible(find.text('Reklamla 2× bölüm coini'),250,maxScrolls:30);
      expect(tester.takeException(),isNull);
      await snapshot(tester,key,'passport-rewards-${large?"large-light":"dark"}');
      await tester.scrollUntilVisible(find.byTooltip('Vitrinden kaldır').first,180,maxScrolls:30);
      await tester.tap(find.byTooltip('Vitrinden kaldır').first);await tester.pumpAndSettle();
      expect(api.state['favorites'],isEmpty);
      expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
