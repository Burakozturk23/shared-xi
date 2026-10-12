import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/controllers/journey_v2_controller.dart';
import 'package:shared_xi/controllers/turkish_nostalgia_controller.dart';
import 'package:shared_xi/controllers/ucl_moments_controller.dart';
import 'package:shared_xi/controllers/international_glory_controller.dart';
import 'package:shared_xi/controllers/dynasties_controller.dart';
import 'package:shared_xi/models/journey_task.dart';
import 'package:shared_xi/models/turkish_nostalgia_state.dart';
import 'package:shared_xi/models/ucl_moment.dart';
import 'package:shared_xi/models/international_match.dart';
import 'package:shared_xi/models/dynasty_task.dart';
import 'package:shared_xi/services/journey_v2_store.dart';
import 'package:shared_xi/services/ucl_moments_service.dart';
import 'package:shared_xi/services/international_glory_service.dart';
import 'package:shared_xi/services/dynasties_service.dart';
import 'package:shared_xi/services/nostalgia_service.dart';
import 'package:shared_xi/screens/journey_v2_page.dart';
import 'package:shared_xi/screens/ucl_moments_page.dart';
import 'package:shared_xi/screens/international_glory_page.dart';
import 'package:shared_xi/screens/dynasties_page.dart';
import 'package:shared_xi/screens/turkish_nostalgia_page.dart';
import 'journey_v2_test.dart' show MemoryJourneyStore;
import 'ucl_moments_test.dart' show MemoryUclStore;
import 'international_glory_test.dart' show MemoryInternationalStore;
import 'dynasties_test.dart' show MemoryDynastiesStore;
import 'turkish_nostalgia_test.dart' show MemoryStore;

Map<String,dynamic> privatePack() => jsonDecode(File('functions/config/five_mode_expansion.json').readAsStringSync()) as Map<String,dynamic>;
List<Map<String,dynamic>> privateTasks(String mode) {
  final pack=privatePack();
  final List raw = mode=='nostalgia' ? (pack[mode] as List).expand((c)=>c['tasks'] as List).toList()
    : mode=='journey' ? (pack[mode]['journeys'] as List).expand((j)=>j['tasks'] as List).toList() : pack[mode] as List;
  return raw.map((t)=>Map<String,dynamic>.from(t as Map)).toList();
}
class ExpansionGateway implements UclGateway, InternationalGateway, DynastiesGateway, NostalgiaGateway {
  ExpansionGateway(this.mode, this.version);
  final String mode;
  final int version;
  bool offline=false;
  final Map<String,dynamic> results={}, completed={};
  @override Future<Map<String,dynamic>> call(String action,[Map<String,dynamic> input=const{}]) async {
    if(offline) throw StateError('offline');
    if(action=='submit') {
      final t=privateTasks(mode).firstWhere((t)=>t['id']==(input['taskId']??input['matchId']));
      final a=List<String>.from(input['answers'] as List), b=List<String>.from(t['answerKeys'] as List);
      if(t['interaction']=='multi'){a.sort();b.sort();}
      if(jsonEncode(a)!=jsonEncode(b))return {'correct':false};
      results[t['id'] as String]=t['result'];completed[t['id'] as String]=1;
    }
    return {'version':version,'correct':true,'results':Map<String,dynamic>.from(results),
      'completed':Map<String,dynamic>.from(completed),'seals':<String,dynamic>{},
      'rewards':<String,dynamic>{},'rewardEligible':true};
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (name,path) in [('Satoshi','assets/fonts/Satoshi-Variable.ttf'),('Inter','assets/fonts/Inter-Body-Variable.ttf'),('MaterialIcons','fonts/MaterialIcons-Regular.otf')]) {
      await (FontLoader(name)..addFont(rootBundle.load(path))).load();
    }
  });
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  test('runtime loaders append all 51 tasks with empty private answers',() async {
    final pj=await loadJourneyChapter('chapter_5_expansion');
    expect(pj.length,8);expect(pj.expand((j)=>j.tasks).length,32);
    for(final t in pj.expand((j)=>j.tasks)){expect(t.serverValidated,true);expect(t.answerKeys,isEmpty);expect(t.explanation,isEmpty);}
    expect((await UclCatalog.load()).matches.length,37);
    expect((await InternationalCatalog.load()).matches.length,44);
    expect((await NostalgiaCatalog.load()).tasks.length,30);
    expect((await DynastiesCatalog.load()).tasks.length,38);
  });
  test('new careers save offline selection and cannot advance without server; concurrent submit is single',() async {
    final journey=(await loadJourneyChapter('chapter_5_expansion')).first;
    final store=MemoryJourneyStore();var calls=0;
    final c=JourneyV2Controller(journey:journey,store:store,verify:(_,__)async{throw StateError('offline');});
    await c.initialize();final key=List<String>.from(privateTasks('journey').first['answerKeys'] as List).single;
    c.choose(key);await c.submit();expect(c.checkpoint!.solved,0);c.dispose();
    final gate=Completer<Map<String,dynamic>>();
    final restored=JourneyV2Controller(journey:journey,store:store,verify:(_,__)async{calls++;return gate.future;});
    addTearDown(restored.dispose);await restored.initialize();expect(restored.selected,[key]);
    final first=restored.submit();await Future<void>.delayed(Duration.zero);await restored.submit();
    expect(calls,1);gate.complete({'story':'Santos FC'});await first;
    expect(restored.checkpoint!.solved,1);expect(restored.explanation,'Santos FC');
    final a=LocalJourneyV2Store(scope:'expansion.alice'),b=LocalJourneyV2Store(scope:'expansion.bob');
    await a.write(journey.id,restored.checkpoint!.toJson(journey));expect(await b.read(journey.id),isNull);
    expect((await LocalJourneyV2Store.summaries(scope:'expansion.alice'))[journey.id]?.$1,1);
    expect(await LocalJourneyV2Store.summaries(scope:'expansion.bob'),isEmpty);
  });
  test('all 32 career tasks can finish through the server-only callback',() async {
    for(final j in await loadJourneyChapter('chapter_5_expansion')) {
      final c=JourneyV2Controller(journey:j,store:MemoryJourneyStore(),verify:(t,answers)async{
        final expected=privateTasks('journey').firstWhere((p)=>p['id']==t.id);
        expect(answers,expected['answerKeys']);return Map<String,dynamic>.from(expected['result'] as Map);
      });
      await c.initialize();
      for(final t in j.tasks) {
        final p=privateTasks('journey').firstWhere((p)=>p['id']==t.id);
        for(final k in List<String>.from(p['answerKeys'] as List)){c.choose(k);}
        await c.submit();expect(c.checkpoint!.reviewing,true);await c.next();
      }
      expect(c.checkpoint!.complete,true);c.dispose();
    }
  });
  test('nostalgia offline pending answer restores; wrong response never unlocks second task',() async {
    final catalog=await NostalgiaCatalog.load(), store=MemoryStore(), gateway=ExpansionGateway('nostalgia',2)..offline=true;
    final c=TurkishNostalgiaController(catalog:catalog,store:store,gateway:gateway);
    await c.load();await Future<void>.delayed(Duration.zero);c.open('TN-13');c.start();
    final t=privateTasks('nostalgia').first, key=(t['answerKeys'] as List).first as String;
    c.choose(key);await c.submit();expect(c.solved,isEmpty);expect(c.pending.containsKey(t['id']),true);c.dispose();
    final restored=TurkishNostalgiaController(catalog:catalog,store:store,gateway:gateway);
    addTearDown(restored.dispose);await restored.load();await Future<void>.delayed(Duration.zero);
    expect(restored.answers,[key]);gateway.offline=false;await restored.sync();
    expect(restored.phase,'result');expect(restored.confirmed,contains(t['id']));expect(restored.pending,isEmpty);
    restored.next();restored.choose(restored.task!.optionIds.firstWhere((id)=>!(privateTasks('nostalgia')[1]['answerKeys'] as List).contains(id)));
    await restored.submit();expect(restored.phase,'task');expect(restored.solved.length,1);expect(restored.pending,isEmpty);
  });
  test('Qatar route accepts two slots with distractors; all new national matches play',() async {
    final c=InternationalGloryController(catalog:await InternationalCatalog.load(),store:MemoryInternationalStore(),gateway:ExpansionGateway('international',2));
    addTearDown(c.dispose);await c.load();
    for(final t in privateTasks('international')) {
      c.open(t['id'] as String);c.start();final keys=List<String>.from(t['answerKeys'] as List);
      if(c.active!.type=='route'){for(var i=0;i<keys.length;i++){c.assign(i,keys[i]);}}
      else if(c.active!.type=='timeline'){for(var i=0;i<keys.length;i++){while(c.answers.indexOf(keys[i])>i){c.move(c.answers.indexOf(keys[i]),-1);}}}
      else{c.choose(keys.single);}
      expect(c.canSubmit,true);await c.submit();expect(c.phase,'result');
    }
    expect(c.count,4);expect(c.coins,0);
  });
  for(final light in [false,true]) {
    testWidgets('five new mode tasks open at 320px / 180%, light=$light',(tester)async{
      tester.view.physicalSize=const Size(320,844);tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      final loaded=await tester.runAsync(() async => <Object>[
        await loadJourneyChapter('chapter_5_expansion'), await UclCatalog.load(),
        await InternationalCatalog.load(), await DynastiesCatalog.load(), await NostalgiaCatalog.load(),
      ]);
      final pj=JourneyV2Controller(journey:(loaded![0] as List<JourneyV2Definition>).first,store:MemoryJourneyStore());
      final ucl=UclMomentsController(catalog:loaded[1] as UclCatalog,store:MemoryUclStore(),gateway:ExpansionGateway('ucl',1));
      final ig=InternationalGloryController(catalog:loaded[2] as InternationalCatalog,store:MemoryInternationalStore(),gateway:ExpansionGateway('international',2));
      final dy=DynastiesController(catalog:loaded[3] as DynastiesCatalog,store:MemoryDynastiesStore(),gateway:ExpansionGateway('dynastyTasks',2));
      final tn=TurkishNostalgiaController(catalog:loaded[4] as NostalgiaCatalog,store:MemoryStore(),gateway:ExpansionGateway('nostalgia',2));
      await pj.initialize();await ucl.load();await ig.load();await dy.load();await tn.load();
      ucl.open('UCL-36');ucl.start();ig.open('IG-42');ig.start();dy.open('DY-17-01');dy.start();tn.open('TN-15');tn.start();
      final screenKey=GlobalKey();
      for(final page in <Widget>[JourneyV2Page(journeyId:'PJ-33',chapterId:'chapter_5_expansion',controller:pj),UclMomentsPage(controller:ucl),InternationalGloryPage(controller:ig),DynastiesPage(controller:dy),TurkishNostalgiaPage(controller:tn)]) {
        await tester.pumpWidget(MaterialApp(theme:light?OrtakSahaTheme.light:OrtakSahaTheme.dark,builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:const TextScaler.linear(1.8)),child:RepaintBoundary(key:screenKey,child:child!)),home:page));
        await tester.pumpAndSettle();expect(tester.takeException(),isNull);
        if(page is JourneyV2Page){await tester.scrollUntilVisible(find.byKey(const ValueKey('journey-start-task')),200);await tester.tap(find.byKey(const ValueKey('journey-start-task')));await tester.pumpAndSettle();}
        await screenshot(tester,screenKey,'${page.runtimeType}-$light-start');
        await tester.drag(find.byType(ListView).first,const Offset(0,-600));await tester.pumpAndSettle();expect(tester.takeException(),isNull);
        await screenshot(tester,screenKey,'${page.runtimeType}-$light-options');
      }
      await tester.pumpWidget(const SizedBox());pj.dispose();ucl.dispose();ig.dispose();dy.dispose();tn.dispose();
    });
  }
}

Future<void> screenshot(WidgetTester tester,GlobalKey key,String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await tester.runAsync(() async {
    final image=await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio:1);
    final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
    final file=File('.dart_tool/expansion_qa/$name.png');
    await file.parent.create(recursive:true);await file.writeAsBytes(bytes!.buffer.asUint8List());image.dispose();
  });
}
