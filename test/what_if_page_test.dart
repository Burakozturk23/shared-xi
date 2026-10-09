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
      // The result's large hero can put this lazily built ListView child below
      // the viewport. Check game state independently, then reveal the ending.
      expect(c.phase(s),'result');expect(c.ends(s),{'alternate'});
      await go(t,const ValueKey('what-if-ending'));
      expect(find.byKey(const ValueKey('what-if-ending')),findsOneWidget);
      await shot(t,key,'ending-text-$light');
      await t.drag(find.byType(ListView).last,const Offset(0,5000));await t.pumpAndSettle();await shot(t,key,'ending-$light');
      const sources=PageStorageKey('what-if-sources-messi-alternate');
      await go(t,sources);await t.tap(find.text('Kaynaklar ve kurgu notu'));await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text(s.note),200,scrollable:find.byType(Scrollable).last,maxScrolls:50);
      await t.pumpAndSettle();await shot(t,key,'sources-$light');
      expect(t.takeException(),isNull);
      await go(t,const ValueKey('what-if-other-route'));
      await t.tap(find.byKey(const ValueKey('what-if-other-route')));await t.pumpAndSettle();
      await go(t,const ValueKey('what-if-route-real'));
      await t.tap(find.byKey(const ValueKey('what-if-route-real')));await t.pumpAndSettle();
      await go(t,const ValueKey('what-if-free-hint'));
      await t.tap(find.byKey(const ValueKey('what-if-free-hint')));await t.pumpAndSettle();
      expect(c.freeHintShown(s),isTrue);
      await go(t,const ValueKey('what-if-option-o1'));
      await t.tap(find.byKey(const ValueKey('what-if-option-o1')));await t.pumpAndSettle();
      await go(t,const ValueKey('what-if-submit'));
      await t.tap(find.byKey(const ValueKey('what-if-submit')));await t.pumpAndSettle();
      expect(c.phase(s),'task');expect(c.feedback,isNotNull);
      await go(t,const ValueKey('what-if-option-o0'));
      await t.tap(find.byKey(const ValueKey('what-if-option-o0')));await t.pumpAndSettle();
      await go(t,const ValueKey('what-if-submit'));
      await t.tap(find.byKey(const ValueKey('what-if-submit')));await t.pumpAndSettle();
      expect(c.ends(s),{'real','alternate'});
      await t.pageBack();await t.pumpAndSettle();
      await t.drag(find.byType(ListView).last,const Offset(0,5000));await t.pumpAndSettle();
      final archive=find.widgetWithText(ChoiceChip,'Kader Arşivi');
      await t.scrollUntilVisible(archive,200,scrollable:find.byType(Scrollable).last);
      await t.tap(archive);await t.pumpAndSettle();
      await go(t,const ValueKey('what-if-open-messi'));
      expect(find.text('Çift evren'),findsWidgets);
      await go(t,const ValueKey('what-if-favorite-messi'));
      await t.tap(find.byKey(const ValueKey('what-if-favorite-messi')));await t.pumpAndSettle();
      expect(c.favorites,{s.id});
      await go(t,const ValueKey('what-if-open-messi'));await shot(t,key,'archive-$light');
      expect(t.takeException(),isNull);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }

  for(final chapter in [1,2,3]){
    testWidgets('chapter $chapter timeline resumes mid-task and opens both endings',(t) async {
      t.view.physicalSize=const Size(390,844);t.view.devicePixelRatio=1;
      addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
      final pack=whatIfPack(),store=MemoryWhatIfStore();
      final s=pack.scenarios.firstWhere((s)=>s.chapter==chapter&&s.routes.first.task.timeline);
      final c=WhatIfController(catalog:pack,store:store);addTearDown(c.dispose);
      await c.initialize();await c.selectRoute(s,'real');
      Widget app(WhatIfController controller)=>MaterialApp(theme:OrtakSahaTheme.dark,
        home:WhatIfPlayPage(controller:controller,scenario:s));
      await t.pumpWidget(app(c));await t.pumpAndSettle();
      final first=s.routes.first.task.answers.first;
      await go(t,ValueKey('what-if-option-$first'));
      await t.tap(find.byKey(ValueKey('what-if-option-$first')));await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox.shrink());
      final restored=WhatIfController(catalog:pack,store:store);addTearDown(restored.dispose);
      await restored.initialize();expect(restored.picked(s),[first]);
      await t.pumpWidget(app(restored));await t.pumpAndSettle();
      for(final answer in s.routes.first.task.answers.skip(1)){
        await go(t,ValueKey('what-if-option-$answer'));
        await t.tap(find.byKey(ValueKey('what-if-option-$answer')));await t.pumpAndSettle();
      }
      await go(t,const ValueKey('what-if-submit'));
      await t.tap(find.byKey(const ValueKey('what-if-submit')));await t.pumpAndSettle();
      expect(restored.phase(s),'result');expect(restored.ends(s),{'real'});
      await go(t,const ValueKey('what-if-ending'));
      expect(find.text(s.routes.first.ending),findsOneWidget);
      await go(t,const ValueKey('what-if-other-route'));
      await t.tap(find.byKey(const ValueKey('what-if-other-route')));await t.pumpAndSettle();
      await go(t,const ValueKey('what-if-route-alternate'));
      await t.tap(find.byKey(const ValueKey('what-if-route-alternate')));await t.pumpAndSettle();
      for(final answer in s.routes.last.task.answers){
        await go(t,ValueKey('what-if-option-$answer'));
        await t.tap(find.byKey(ValueKey('what-if-option-$answer')));await t.pumpAndSettle();
      }
      await go(t,const ValueKey('what-if-submit'));
      await t.tap(find.byKey(const ValueKey('what-if-submit')));await t.pumpAndSettle();
      expect(restored.phase(s),'result');expect(restored.ends(s),{'real','alternate'});
      expect(t.takeException(),isNull);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }
}
