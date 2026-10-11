import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/controllers/football_docu_controller.dart';
import 'package:shared_xi/models/docu_task.dart';
import 'package:shared_xi/screens/football_docu_page.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'football_docu_test.dart';

Future<void> go(WidgetTester t,Key key)async{
  await t.drag(find.byType(ListView),const Offset(0,6000));await t.pumpAndSettle();
  await t.scrollUntilVisible(find.byKey(key),200,scrollable:find.byType(Scrollable).last,maxScrolls:100);
  await t.pumpAndSettle();
}
Future<void> shot(WidgetTester t,GlobalKey key,String name)async{
  if(!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS'))return;
  await t.pumpAndSettle();await t.runAsync(()async{
    final im=await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio:1);
    final bytes=await im.toByteData(format:ui.ImageByteFormat.png);
    final file=File('.dart_tool/football_docu_qa/$name.png');await file.parent.create(recursive:true);
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
    testWidgets('FootballDocu five mechanics and Atlas fit 320px / 180% light=$light',(t)async{
      t.view.physicalSize=const Size(320,844);t.view.devicePixelRatio=1;
      addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
      final c=FootballDocuController(catalog:docuPack(),store:MemoryFootballDocuStore(),gateway:FakeFootballDocuGateway());addTearDown(c.dispose);await c.load();
      final key=GlobalKey();
      await t.pumpWidget(MaterialApp(theme:light?OrtakSahaTheme.light:OrtakSahaTheme.dark,
        builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(1.8)),child:RepaintBoundary(key:key,child:child!)),home:FootballDocuPage(controller:c)));
      await t.pumpAndSettle();await shot(t,key,'archive-$light');
      for(final id in ['DOC-01-01','DOC-01-02','DOC-03-01','DOC-04-01','DOC-02-01']){
        c.open(id);await t.pumpAndSettle();
        expect(find.text(docuPrivate(id)['result']['answer'] as String),findsNothing);
        await go(t,const ValueKey('docu-start'));await t.tap(find.byKey(const ValueKey('docu-start')));await t.pumpAndSettle();
        await shot(t,key,'${c.active!.mechanic}-$light');
        final first=c.active!.interaction=='match'?const ValueKey('match-slot-0'):c.active!.interaction=='order'?const ValueKey('up-0'):ValueKey('option-${c.active!.optionIds.first}');
        await go(t,first);await shot(t,key,'cards-${c.active!.mechanic}-$light');
        await go(t,const ValueKey('docu-hint'));await t.tap(find.byKey(const ValueKey('docu-hint')));await t.pumpAndSettle();expect(c.hintOpen,true);
        solve(c);await t.pumpAndSettle();await go(t,const ValueKey('docu-submit'));await t.tap(find.byKey(const ValueKey('docu-submit')));await t.pumpAndSettle();
        expect(c.phase,'result');await go(t,const ValueKey('docu-result'));await shot(t,key,'result-${c.active!.mechanic}-$light');
        if(c.files.containsKey(c.active!.episodeId)){await go(t,PageStorageKey('docu-sources-$id'));await t.tap(find.text('Tarihsel kaynaklar'));await t.pumpAndSettle();}expect(t.takeException(),isNull);
      }
      c.archive();await t.pumpAndSettle();await go(t,const ValueKey('docu-collection'));await t.tap(find.byKey(const ValueKey('docu-collection')));await t.pumpAndSettle();
      await go(t,const ValueKey('docu-archivist'));await shot(t,key,'atlas-$light');expect(t.takeException(),isNull);
    });
  }
  testWidgets('All four interactions submit through actual controls, including wrong-answer retry',(t)async{
    final c=FootballDocuController(catalog:docuPack(),store:MemoryFootballDocuStore(),gateway:FakeFootballDocuGateway());addTearDown(c.dispose);await c.load();
    await t.pumpWidget(MaterialApp(home:FootballDocuPage(controller:c)));await t.pumpAndSettle();
    for(final id in ['DOC-01-01','DOC-01-02','DOC-03-01','DOC-04-01','DOC-10-01','DOC-02-01']){
      c.open(id);c.start();await t.pumpAndSettle();final keys=docuStrings(docuPrivate(id)['answerKeys']);
      if(c.active!.interaction=='single'){
        final wrong=c.active!.optionIds.firstWhere((x)=>!keys.contains(x));
        await go(t,ValueKey('option-$wrong'));await t.tap(find.byKey(ValueKey('option-$wrong')));await t.pumpAndSettle();
        await go(t,const ValueKey('docu-submit'));await t.tap(find.byKey(const ValueKey('docu-submit')));await t.pumpAndSettle();expect(c.phase,'task');
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
      await go(t,const ValueKey('docu-submit'));await t.tap(find.byKey(const ValueKey('docu-submit')));await t.pumpAndSettle();expect(c.phase,'result');expect(t.takeException(),isNull);
    }
  });
  testWidgets('Paid help requires consent and preserves displayed free Pro price',(t)async{
    final gateway=FakeFootballDocuGateway();final c=FootballDocuController(catalog:docuPack(),store:MemoryFootballDocuStore(),gateway:gateway);addTearDown(c.dispose);await c.load();c.open('DOC-01-01');c.start();
    await t.pumpWidget(MaterialApp(home:FootballDocuPage(controller:c)));await t.pumpAndSettle();
    await go(t,const ValueKey('docu-extra-help'));await t.tap(find.byKey(const ValueKey('docu-extra-help')));await t.pumpAndSettle();
    await t.tap(find.text('Vazgeç'));await t.pumpAndSettle();expect(gateway.hintRequests,isEmpty);
    await t.tap(find.byKey(const ValueKey('docu-extra-help')));await t.pumpAndSettle();await t.tap(find.text('Aç'));await t.pumpAndSettle();expect(gateway.hintRequests.single['maxPrice'],6);
    c.pro=true;c.hint();await t.pumpAndSettle();await go(t,const ValueKey('docu-extra-help'));await t.tap(find.byKey(const ValueKey('docu-extra-help')));await t.pumpAndSettle();c.pro=false;
    await t.tap(find.text('Aç'));await t.pumpAndSettle();expect(gateway.hintRequests.last['maxPrice'],0);expect(t.takeException(),isNull);
  });
}
