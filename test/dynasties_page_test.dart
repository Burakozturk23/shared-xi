import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/controllers/dynasties_controller.dart';
import 'package:shared_xi/models/dynasty_task.dart';
import 'package:shared_xi/screens/dynasties_page.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'dynasties_test.dart';

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
    final file=File('.dart_tool/dynasties_qa/$name.png');await file.parent.create(recursive:true);
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
    testWidgets('Dynasties five mechanics and Atlas fit 320px / 180% light=$light',(t)async{
      t.view.physicalSize=const Size(320,844);t.view.devicePixelRatio=1;
      addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
      final c=DynastiesController(catalog:dyPack(),store:MemoryDynastiesStore(),gateway:FakeDynastiesGateway());addTearDown(c.dispose);await c.load();
      final key=GlobalKey();
      await t.pumpWidget(MaterialApp(theme:light?OrtakSahaTheme.light:OrtakSahaTheme.dark,
        builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(1.8)),child:RepaintBoundary(key:key,child:child!)),home:DynastiesPage(controller:c)));
      await t.pumpAndSettle();await shot(t,key,'archive-$light');
      for(final id in ['DY-01-01','DY-01-02','DY-02-01','DY-03-01','DY-15-01']){
        c.open(id);await t.pumpAndSettle();
        expect(find.text(dyPrivate(id)['result']['answer'] as String),findsNothing);
        await go(t,const ValueKey('dy-start'));await t.tap(find.byKey(const ValueKey('dy-start')));await t.pumpAndSettle();
        await shot(t,key,'${c.active!.mechanic}-$light');
        final first=c.active!.interaction=='match'?const ValueKey('match-slot-0'):c.active!.interaction=='order'?const ValueKey('up-0'):ValueKey('option-${c.active!.optionIds.first}');
        await go(t,first);await shot(t,key,'cards-${c.active!.mechanic}-$light');
        await go(t,const ValueKey('dy-hint'));await t.tap(find.byKey(const ValueKey('dy-hint')));await t.pumpAndSettle();expect(c.hintOpen,true);
        solve(c);await t.pumpAndSettle();await go(t,const ValueKey('dy-submit'));await t.tap(find.byKey(const ValueKey('dy-submit')));await t.pumpAndSettle();
        expect(c.phase,'result');await go(t,const ValueKey('dy-result'));await shot(t,key,'result-${c.active!.mechanic}-$light');
        await go(t,PageStorageKey('dy-sources-$id'));await t.tap(find.text('Tarihsel kaynaklar'));await t.pumpAndSettle();expect(t.takeException(),isNull);
      }
      c.archive();await t.pumpAndSettle();await go(t,const ValueKey('dy-atlas'));await t.tap(find.byKey(const ValueKey('dy-atlas')));await t.pumpAndSettle();
      await go(t,const ValueKey('dy-historian'));await shot(t,key,'atlas-$light');expect(t.takeException(),isNull);
    });
  }
  testWidgets('All four interactions submit through actual controls, including wrong-answer retry',(t)async{
    final c=DynastiesController(catalog:dyPack(),store:MemoryDynastiesStore(),gateway:FakeDynastiesGateway());addTearDown(c.dispose);await c.load();
    await t.pumpWidget(MaterialApp(home:DynastiesPage(controller:c)));await t.pumpAndSettle();
    for(final id in ['DY-01-01','DY-01-02','DY-02-01','DY-15-01']){
      c.open(id);c.start();await t.pumpAndSettle();final keys=dyStrings(dyPrivate(id)['answerKeys']);
      if(c.active!.interaction=='single'){
        final wrong=c.active!.optionIds.firstWhere((x)=>!keys.contains(x));
        await go(t,ValueKey('option-$wrong'));await t.tap(find.byKey(ValueKey('option-$wrong')));await t.pumpAndSettle();
        await go(t,const ValueKey('dy-submit'));await t.tap(find.byKey(const ValueKey('dy-submit')));await t.pumpAndSettle();expect(c.phase,'task');
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
      await go(t,const ValueKey('dy-submit'));await t.tap(find.byKey(const ValueKey('dy-submit')));await t.pumpAndSettle();expect(c.phase,'result');expect(t.takeException(),isNull);
    }
  });
  testWidgets('Paid help requires consent and preserves displayed free Pro price',(t)async{
    final gateway=FakeDynastiesGateway();final c=DynastiesController(catalog:dyPack(),store:MemoryDynastiesStore(),gateway:gateway);addTearDown(c.dispose);await c.load();c.open('DY-01-01');c.start();
    await t.pumpWidget(MaterialApp(home:DynastiesPage(controller:c)));await t.pumpAndSettle();
    await go(t,const ValueKey('dy-extra-help'));await t.tap(find.byKey(const ValueKey('dy-extra-help')));await t.pumpAndSettle();
    await t.tap(find.text('Vazgeç'));await t.pumpAndSettle();expect(gateway.hintRequests,isEmpty);
    await t.tap(find.byKey(const ValueKey('dy-extra-help')));await t.pumpAndSettle();await t.tap(find.text('Aç'));await t.pumpAndSettle();expect(gateway.hintRequests.single['maxPrice'],6);
    c.pro=true;c.hint();await t.pumpAndSettle();await go(t,const ValueKey('dy-extra-help'));await t.tap(find.byKey(const ValueKey('dy-extra-help')));await t.pumpAndSettle();c.pro=false;
    await t.tap(find.text('Aç'));await t.pumpAndSettle();expect(gateway.hintRequests.last['maxPrice'],0);expect(t.takeException(),isNull);
  });
}
