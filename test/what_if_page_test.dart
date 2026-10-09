import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/controllers/what_if_controller.dart';
import 'package:shared_xi/screens/what_if_selection_page.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'what_if_test.dart';

Future<void> go(WidgetTester t,Key key) async {
  await t.drag(find.byType(ListView).last,const Offset(0,5000));await t.pumpAndSettle();
  await t.scrollUntilVisible(find.byKey(key),200,scrollable:find.byType(Scrollable).last,maxScrolls:50);await t.pumpAndSettle();
}
Future<void> shot(WidgetTester t,GlobalKey key,String name) async {
  if(!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS'))return;
  await t.pumpAndSettle();await t.runAsync(() async {
    final im=await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio:1);
    final data=await im.toByteData(format:ui.ImageByteFormat.png);
    final file=File('.dart_tool/what_if_qa/$name.png');await file.parent.create(recursive:true);
    await file.writeAsBytes(data!.buffer.asUint8List());im.dispose();
  });
}
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for(final (name,path) in [('Satoshi','assets/fonts/Satoshi-Variable.ttf'),('Inter','assets/fonts/Inter-Body-Variable.ttf'),('MaterialIcons','fonts/MaterialIcons-Regular.otf')]){
      await (FontLoader(name)..addFont(rootBundle.load(path))).load();
    }
  });
  for(final light in [false,true]){
    testWidgets('What If story/decision/task/result/archive at 320px large type light=$light',(t) async {
      t.view.physicalSize=const Size(320,844);t.view.devicePixelRatio=1;
      addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
      final c=WhatIfController(catalog:whatIfPack(),store:MemoryWhatIfStore());addTearDown(c.dispose);
      final key=GlobalKey();
      Widget app(Widget home)=>MaterialApp(theme:light?OrtakSahaTheme.light:OrtakSahaTheme.dark,
        builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(1.8)),child:RepaintBoundary(key:key,child:child!)),home:home);
      await t.pumpWidget(app(WhatIfPage(controller:c)));await t.pumpAndSettle();
      await shot(t,key,'hub-$light');await go(t,const ValueKey('what-if-chapter-1'));
      await t.tap(find.byKey(const ValueKey('what-if-chapter-1')));await t.pumpAndSettle();
      await go(t,const ValueKey('what-if-open-messi'));await t.tap(find.byKey(const ValueKey('what-if-open-messi')));await t.pumpAndSettle();
      final s=c.catalog.scenarios.first;
      expect(find.text(s.routes.first.ending),findsNothing);expect(find.text(s.routes.first.task.prompt),findsNothing);
      await shot(t,key,'intro-$light');await go(t,const ValueKey('what-if-to-choice'));
      await t.tap(find.byKey(const ValueKey('what-if-to-choice')));await t.pumpAndSettle();
      await shot(t,key,'choice-$light');await go(t,const ValueKey('what-if-route-alternate'));
      await t.tap(find.byKey(const ValueKey('what-if-route-alternate')));await t.pumpAndSettle();
      expect(find.text(s.routes.last.ending),findsNothing);expect(find.text(s.routes.last.task.explanation),findsNothing);
      await go(t,const ValueKey('what-if-prompt'));await shot(t,key,'task-$light');
      await go(t,const ValueKey('what-if-option-o0'));await t.tap(find.byKey(const ValueKey('what-if-option-o0')));await t.pumpAndSettle();
      await go(t,const ValueKey('what-if-submit'));await t.tap(find.byKey(const ValueKey('what-if-submit')));await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('what-if-ending')),findsOneWidget);expect(c.ends(s),{'alternate'});
      await t.drag(find.byType(ListView).last,const Offset(0,5000));await t.pumpAndSettle();await shot(t,key,'ending-$light');
      expect(t.takeException(),isNull);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }
}
