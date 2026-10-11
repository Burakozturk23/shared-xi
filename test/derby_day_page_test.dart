import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/controllers/derby_day_controller.dart';
import 'package:shared_xi/models/derby_task.dart';
import 'package:shared_xi/screens/derby_day_page.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'derby_day_test.dart';

Future<void> go(WidgetTester t,Key key)async{
  // Walk the lazy list without flings or gesture competition from task cards.
  final list=t.widget<ListView>(find.byType(ListView));
  final scroll=list.controller!;
  scroll.jumpTo(0);
  await t.pumpAndSettle();
  for(var i=0;i<200&&find.byKey(key).evaluate().isEmpty;i++){
    scroll.jumpTo((scroll.offset+120).clamp(0,scroll.position.maxScrollExtent));
    await t.pumpAndSettle();
  }
  expect(find.byKey(key),findsOneWidget,reason:'Missing $key at ${scroll.offset}/${scroll.position.maxScrollExtent}; children: ${(list.childrenDelegate as SliverChildListDelegate).children.map((w)=>w.key).toList()}');
  await t.ensureVisible(find.byKey(key));
  await t.pumpAndSettle();
}
Future<void> shot(WidgetTester t,GlobalKey key,String name)async{
  if(!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS'))return;
  await t.pumpAndSettle();await t.runAsync(()async{
    final im=await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio:1);
    final bytes=await im.toByteData(format:ui.ImageByteFormat.png);
    final file=File('.dart_tool/derby_day_qa/$name.png');await file.parent.create(recursive:true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());im.dispose();
  });
}
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(()async{
    for(final (name,path) in [('Satoshi','assets/fonts/Satoshi-Variable.ttf'),('Inter','assets/fonts/Inter-Body-Variable.ttf'),('MaterialIcons','fonts/MaterialIcons-Regular.otf')]){
      await (FontLoader(name)..addFont(rootBundle.load(path))).load();
    }
  });
  for(final light in [false,true]){
    testWidgets('DerbyDay five mechanics and archive fit 320px / 180% light=$light',(t)async{
      t.view.physicalSize=const Size(320,844);t.view.devicePixelRatio=1;
      addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
      final c=DerbyDayController(catalog:derbyPack(),store:MemoryDerbyDayStore(),gateway:FakeDerbyDayGateway());addTearDown(c.dispose);await c.load();
      final key=GlobalKey();
      await t.pumpWidget(MaterialApp(theme:light?OrtakSahaTheme.light:OrtakSahaTheme.dark,
        builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(1.8)),child:RepaintBoundary(key:key,child:child!)),home:DerbyDayPage(controller:c)));
      await t.pumpAndSettle();await shot(t,key,'archive-$light');
      for(final id in ['DER-01','DER-02','DER-03','DER-04','DER-05']){
        c.open(id);await t.pumpAndSettle();
        expect(find.text(derbyPrivate(id)['result']['answer'] as String),findsNothing);
        await go(t,const ValueKey('derby-start'));await t.tap(find.byKey(const ValueKey('derby-start')));await t.pumpAndSettle();
        await shot(t,key,'${c.active!.mechanic}-$light');
        final first=c.active!.interaction=='match'?const ValueKey('match-slot-0'):c.active!.interaction=='order'?const ValueKey('up-0'):ValueKey('option-${c.active!.optionIds.first}');
        await go(t,first);await shot(t,key,'cards-${c.active!.mechanic}-$light');
        await go(t,const ValueKey('derby-hint'));await t.tap(find.byKey(const ValueKey('derby-hint')));await t.pumpAndSettle();expect(c.hintOpen,true);
        solve(c);await t.pumpAndSettle();await go(t,const ValueKey('derby-submit'));await t.tap(find.byKey(const ValueKey('derby-submit')));await t.pumpAndSettle();
        expect(c.phase,'result');await go(t,const ValueKey('derby-result'));await shot(t,key,'result-${c.active!.mechanic}-$light');
        {await go(t,PageStorageKey('derby-sources-$id'));await t.tap(find.text('Tarihsel kaynaklar'));await t.pumpAndSettle();}expect(t.takeException(),isNull);
      }
      c.archive();await t.pumpAndSettle();await go(t,const ValueKey('derby-collection'));await t.tap(find.byKey(const ValueKey('derby-collection')));await t.pumpAndSettle();
      await go(t,const ValueKey('badge-48'));await shot(t,key,'passport-$light');expect(t.takeException(),isNull);
    });
  }
  testWidgets('All five mechanics submit through actual controls, including wrong-answer retry',(t)async{
    final c=DerbyDayController(catalog:derbyPack(),store:MemoryDerbyDayStore(),gateway:FakeDerbyDayGateway());addTearDown(c.dispose);await c.load();
    await t.pumpWidget(MaterialApp(home:DerbyDayPage(controller:c)));await t.pumpAndSettle();
    for(final id in ['DER-01','DER-02','DER-03','DER-04','DER-05']){
      c.open(id);c.start();await t.pumpAndSettle();final keys=derbyStrings(derbyPrivate(id)['answerKeys']);
      if(c.active!.interaction=='single'){
        final wrong=c.active!.optionIds.firstWhere((x)=>!keys.contains(x));
        await go(t,ValueKey('option-$wrong'));await t.tap(find.byKey(ValueKey('option-$wrong')));await t.pumpAndSettle();
        await go(t,const ValueKey('derby-submit'));await t.tap(find.byKey(const ValueKey('derby-submit')));await t.pumpAndSettle();expect(c.phase,'task');
      }
      for(var i=0;i<keys.length;i++){
        if(c.active!.interaction=='match'){
          await go(t,ValueKey('match-slot-$i'));await t.tap(find.byKey(ValueKey('match-slot-$i')));await t.pumpAndSettle();
          await t.tap(find.text(c.active!.optionLabel(keys[i])).last);await t.pumpAndSettle();
        }else if(c.active!.interaction=='order'){
          while(c.answers.indexOf(keys[i])>i){final index=c.answers.indexOf(keys[i]);await go(t,ValueKey('up-$index'));await t.tap(find.byKey(ValueKey('up-$index')));await t.pumpAndSettle();}
        }else{
          await go(t,ValueKey('option-${keys[i]}'));await t.tap(find.byKey(ValueKey('option-${keys[i]}')));await t.pumpAndSettle();
        }
      }
      await go(t,const ValueKey('derby-submit'));await t.tap(find.byKey(const ValueKey('derby-submit')));await t.pumpAndSettle();expect(c.phase,'result');expect(t.takeException(),isNull);
    }
  });
  testWidgets('Long-press dragging actually reorders the timeline',(t)async{
    t.view.physicalSize=const Size(800,1800);t.view.devicePixelRatio=1;
    addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
    final c=DerbyDayController(catalog:derbyPack(),store:MemoryDerbyDayStore(),gateway:FakeDerbyDayGateway());
    addTearDown(c.dispose);await c.load();c.open('DER-04');c.start();
    await t.pumpWidget(MaterialApp(home:DerbyDayPage(controller:c)));await t.pumpAndSettle();
    final before=List<String>.from(c.answers);
    final gesture=await t.startGesture(t.getCenter(find.byKey(ValueKey('event-${before.first}'))));
    await t.pump(const Duration(milliseconds:600));
    await gesture.moveTo(t.getCenter(find.byKey(ValueKey('event-${before[1]}'))));
    await t.pump();await gesture.up();await t.pumpAndSettle();
    expect(c.answers,[before[1],before[0],...before.skip(2)]);
    expect(t.takeException(),isNull);
  });
  testWidgets('Paid help requires consent and preserves displayed free Pro price',(t)async{
    final gateway=FakeDerbyDayGateway();final c=DerbyDayController(catalog:derbyPack(),store:MemoryDerbyDayStore(),gateway:gateway);addTearDown(c.dispose);await c.load();c.open('DER-01');c.start();
    await t.pumpWidget(MaterialApp(home:DerbyDayPage(controller:c)));await t.pumpAndSettle();
    await go(t,const ValueKey('derby-extra-help'));await t.tap(find.byKey(const ValueKey('derby-extra-help')));await t.pumpAndSettle();
    await t.tap(find.text('Vazgeç'));await t.pumpAndSettle();expect(gateway.hintRequests,isEmpty);
    await t.tap(find.byKey(const ValueKey('derby-extra-help')));await t.pumpAndSettle();await t.tap(find.text('Aç'));await t.pumpAndSettle();expect(gateway.hintRequests.single['maxPrice'],6);
    c.pro=true;c.hint();await t.pumpAndSettle();await go(t,const ValueKey('derby-extra-help'));await t.tap(find.byKey(const ValueKey('derby-extra-help')));await t.pumpAndSettle();c.pro=false;
    await t.tap(find.text('Aç'));await t.pumpAndSettle();expect(gateway.hintRequests.last['maxPrice'],0);expect(t.takeException(),isNull);
  });
  testWidgets('Turkish search and country entry find the new rivalries',(t)async{
    final c=DerbyDayController(catalog:derbyPack(),store:MemoryDerbyDayStore(),gateway:FakeDerbyDayGateway());addTearDown(c.dispose);await c.load();
    await t.pumpWidget(MaterialApp(home:DerbyDayPage(controller:c)));await t.pumpAndSettle();
    await go(t,const ValueKey('derby-search'));await t.enterText(find.byKey(const ValueKey('derby-search')),'KIZILYILDIZ');await t.pumpAndSettle();
    await go(t,const ValueKey('open-DER-41'));expect(find.text('1 rekabet'),findsOneWidget);
    await t.tap(find.byKey(const ValueKey('open-DER-41')));await t.pumpAndSettle();expect(c.activeId,'DER-41');expect(c.phase,'intro');
    c.archive();await t.pumpAndSettle();await go(t,const ValueKey('derby-search'));await t.enterText(find.byKey(const ValueKey('derby-search')),'penarol');await t.pumpAndSettle();
    await go(t,const ValueKey('open-DER-47'));expect(find.text('1 rekabet'),findsOneWidget);expect(t.takeException(),isNull);
  });
  testWidgets('All 48 stamps and final badge survive passport navigation',(t)async{
    final c=DerbyDayController(catalog:derbyPack(),store:MemoryDerbyDayStore(),gateway:FakeDerbyDayGateway());addTearDown(c.dispose);await c.load();
    for(final task in c.catalog.tasks){c.open(task.id);c.start();solve(c);await c.submit();}
    c.archive();await t.pumpWidget(MaterialApp(home:DerbyDayPage(controller:c,openCollection:true)));await t.pumpAndSettle();
    await go(t,const ValueKey('badge-48'));expect(find.text('Derbi Ustası · 48 damga'),findsOneWidget);
    await go(t,const ValueKey('open-DER-48'));await t.tap(find.byKey(const ValueKey('open-DER-48')));await t.pumpAndSettle();
    expect(c.phase,'result');expect(c.stampCount,48);await go(t,const ValueKey('derby-result'));expect(t.takeException(),isNull);
  });
}
