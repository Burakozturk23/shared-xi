import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/controllers/international_glory_controller.dart';
import 'package:shared_xi/screens/international_glory_page.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'international_glory_test.dart';

Future<void> go(WidgetTester t, Key key) async {
  await t.drag(find.byType(ListView), const Offset(0,5000)); await t.pumpAndSettle();
  await t.scrollUntilVisible(find.byKey(key),200,scrollable:find.byType(Scrollable).last,maxScrolls:80);
  await t.pumpAndSettle();
}
Future<void> shot(WidgetTester t,GlobalKey key,String name) async {
  if(!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS'))return;
  await t.pumpAndSettle(); await t.runAsync(() async {
    final im=await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio:1);
    final data=await im.toByteData(format:ui.ImageByteFormat.png);
    final file=File('.dart_tool/ig2_qa/$name.png'); await file.parent.create(recursive:true);
    await file.writeAsBytes(data!.buffer.asUint8List()); im.dispose();
  });
}
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for(final (name,path) in [('Satoshi','assets/fonts/Satoshi-Variable.ttf'),('Inter','assets/fonts/Inter-Body-Variable.ttf'),('MaterialIcons','fonts/MaterialIcons-Regular.otf')]) {
      await (FontLoader(name)..addFont(rootBundle.load(path))).load();
    }
  });
  for(final light in [false,true]) {
    testWidgets('International Glory five mechanics, sources and keepsakes at 320px / 180% light=$light',(t) async {
      t.view.physicalSize=const Size(320,844); t.view.devicePixelRatio=1;
      addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
      final c=InternationalGloryController(catalog:igPack(),store:MemoryInternationalStore(),gateway:FakeInternationalGateway());
      addTearDown(c.dispose); await c.load();
      final key=GlobalKey();
      await t.pumpWidget(MaterialApp(theme:light?OrtakSahaTheme.light:OrtakSahaTheme.dark,
        builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(1.8)),
          child:RepaintBoundary(key:key,child:child!)),home:InternationalGloryPage(controller:c)));
      await t.pumpAndSettle(); await shot(t,key,'archive-$light');
      for(final id in ['ig2_01','ig2_03','ig2_15','ig2_02','ig2_36']) {
        c.open(id); await t.pumpAndSettle();
        expect(find.text(igPrivate(id)['result']['story'] as String),findsNothing);
        await go(t,const ValueKey('ig-start')); await t.tap(find.byKey(const ValueKey('ig-start'))); await t.pumpAndSettle();
        await shot(t,key,'${c.active!.type}-$light');
        await go(t,const ValueKey('ig-hint')); await t.tap(find.byKey(const ValueKey('ig-hint'))); await t.pumpAndSettle();
        expect(c.hintOpen,true);
        selectCorrect(c); await t.pumpAndSettle();
        await go(t,const ValueKey('ig-submit')); await t.tap(find.byKey(const ValueKey('ig-submit'))); await t.pumpAndSettle();
        expect(c.phase,'result'); expect(c.count,greaterThan(0));
        await go(t,const ValueKey('ig-result')); await shot(t,key,'result-${c.active!.type}-$light');
        await go(t,PageStorageKey('ig-sources-$id')); await t.tap(find.text('Maçın kaynakları')); await t.pumpAndSettle();
        expect(t.takeException(),isNull);
      }
      c.archive(); await t.pumpAndSettle();
      await go(t, const ValueKey('ig-album')); await t.tap(find.byKey(const ValueKey('ig-album'))); await t.pumpAndSettle();
      await shot(t,key,'album-$light'); expect(t.takeException(),isNull);
    });
  }
  testWidgets('Route dropdowns and critical choices submit through actual controls', (t) async {
    final c=InternationalGloryController(catalog:igPack(),store:MemoryInternationalStore(),gateway:FakeInternationalGateway());
    addTearDown(c.dispose); await c.load(); c.open('ig2_36'); c.start();
    await t.pumpWidget(MaterialApp(home:InternationalGloryPage(controller:c))); await t.pumpAndSettle();
    final route=igPrivate('ig2_36')['answerKeys'] as List;
    for(var i=0;i<route.length;i++) {
      await go(t,ValueKey('route-slot-$i')); await t.tap(find.byKey(ValueKey('route-slot-$i'))); await t.pumpAndSettle();
      await t.tap(find.text(c.active!.optionLabel(route[i] as String)).last); await t.pumpAndSettle();
    }
    await go(t,const ValueKey('ig-submit')); await t.tap(find.byKey(const ValueKey('ig-submit'))); await t.pumpAndSettle();
    expect(c.phase,'result');
    c.open('ig2_01'); c.start(); await t.pumpAndSettle();
    final answer=(igPrivate('ig2_01')['answerKeys'] as List).single as String;
    final wrong=c.active!.optionIds.firstWhere((id)=>id!=answer);
    await go(t,ValueKey('option-$wrong')); await t.tap(find.byKey(ValueKey('option-$wrong'))); await t.pumpAndSettle();
    await go(t,const ValueKey('ig-submit')); await t.tap(find.byKey(const ValueKey('ig-submit'))); await t.pumpAndSettle();
    expect(c.phase,'task');
    await go(t,ValueKey('option-$answer')); await t.tap(find.byKey(ValueKey('option-$answer'))); await t.pumpAndSettle();
    await go(t,const ValueKey('ig-submit')); await t.tap(find.byKey(const ValueKey('ig-submit'))); await t.pumpAndSettle();
    expect(c.phase,'result'); expect(t.takeException(),isNull);
  });

  testWidgets('Help requires consent and sends the price shown before the dialog', (t) async {
    final gateway=FakeInternationalGateway();
    final c=InternationalGloryController(catalog:igPack(),store:MemoryInternationalStore(),gateway:gateway);
    addTearDown(c.dispose); await c.load(); c.open('ig2_01'); c.start();
    await t.pumpWidget(MaterialApp(home:InternationalGloryPage(controller:c))); await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Ek yardım · 6 coin'),200,scrollable:find.byType(Scrollable).last);
    await t.tap(find.text('Ek yardım · 6 coin')); await t.pumpAndSettle();
    await t.tap(find.text('Vazgeç')); await t.pumpAndSettle();
    expect(gateway.hintRequests,isEmpty);
    await t.tap(find.text('Ek yardım · 6 coin')); await t.pumpAndSettle();
    await t.tap(find.text('Aç')); await t.pumpAndSettle();
    expect(gateway.hintRequests.single['maxPrice'],6);
    c.pro=true; await t.pumpWidget(const SizedBox());
    await t.pumpWidget(MaterialApp(home:InternationalGloryPage(controller:c))); await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Pro · Ek yardım'),200,scrollable:find.byType(Scrollable).last);
    await t.tap(find.text('Pro · Ek yardım')); await t.pumpAndSettle();
    c.pro=false; // Entitlement changed while the free-price confirmation was open.
    await t.tap(find.text('Aç')); await t.pumpAndSettle();
    expect(gateway.hintRequests.last['maxPrice'],0);
    expect(t.takeException(),isNull);
  });

}
