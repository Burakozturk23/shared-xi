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
    testWidgets('UCL five mechanics, sources and keepsakes at 320px / 180% light=$light',(t) async {
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
      c.archive(); await t.pumpAndSettle(); expect(t.takeException(),isNull);
    });
  }
}
