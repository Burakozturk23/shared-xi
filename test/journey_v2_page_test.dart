import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/app/route_appearance.dart';
import 'package:shared_xi/controllers/journey_v2_controller.dart';
import 'package:shared_xi/models/journey_task.dart';
import 'package:shared_xi/screens/games_catalog_page.dart';
import 'package:shared_xi/screens/story_mode_selection_page.dart';
import 'package:shared_xi/screens/player_journey_chapter_list_page.dart';
import 'package:shared_xi/screens/player_journey_list_page.dart';
import 'package:shared_xi/screens/journey_v2_page.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'journey_v2_test.dart' show MemoryJourneyStore, journeyTestPack;

Future<void> goTo(WidgetTester tester, Key key) async {
  await tester.drag(find.byType(ListView).last, const Offset(0,5000));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.byKey(key), 250, scrollable: find.byType(Scrollable).last, maxScrolls: 60);
  await tester.pumpAndSettle();
}
Future<void> snapshot(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await tester.runAsync(() async {
    for (final widget in tester.widgetList<Image>(find.byType(Image))) {
      await precacheImage(widget.image,key.currentContext!);
    }
  });
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final image=await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio:1);
    final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
    final f=File('.dart_tool/journey_qa/$name.png');await f.parent.create(recursive:true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());image.dispose();
  });
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    // Complete real asset I/O before entering the widget tests' fake clock.
    await rootBundle.loadString('assets/data/player_journey_chapter_one.json');
    for (final (name,path) in [
      ('Satoshi','assets/fonts/Satoshi-Variable.ttf'),('Inter','assets/fonts/Inter-Body-Variable.ttf'),
      ('MaterialIcons','fonts/MaterialIcons-Regular.otf'),
    ]) { await (FontLoader(name)..addFont(rootBundle.load(path))).load(); }
  });
  for (final light in [false,true]) {
    for (final large in [false,true]) {
      final variant='${light ? "light" : "dark"}-${large ? "large" : "normal"}';
      void viewport(WidgetTester tester) {
        tester.view.physicalSize=Size(large?320:390,844);tester.view.devicePixelRatio=1;
        addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      }
      Widget app(Widget page, GlobalKey key, {NavigatorObserver? observer}) => MaterialApp(
        theme:light?OrtakSahaTheme.light:OrtakSahaTheme.dark,
        navigatorObservers:observer==null?[]:[observer],
        builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(large?1.8:1)),
          child:RepaintBoundary(key:key,child:child!)),home:page,
      );
      testWidgets('direct Story hub and chapter navigation $variant',(tester) async {
        viewport(tester);final key=GlobalKey(),observer=RouteAppearanceObserver();addTearDown(observer.dispose);
        await tester.pumpWidget(app(const Scaffold(body:GamesCatalogPage()),key,observer:observer));await tester.pumpAndSettle();
        for (var i=0;i<20 && find.text('Hikâye').hitTestable().evaluate().isEmpty;i++) {
          await tester.drag(find.byType(Scrollable).first,const Offset(0,-300));
          await tester.pumpAndSettle();
        }
        expect(find.text('Hikâye').hitTestable(),findsOneWidget);
        await tester.tap(find.text('Hikâye').hitTestable());await tester.pumpAndSettle();
        expect(find.byType(StoryModeSelectionPage),findsOneWidget);expect(find.text('Story Mode'),findsNothing);
        expect(observer.legacy.value,isFalse);await snapshot(tester,key,'hub-$variant');
        await tester.tap(find.byKey(const ValueKey('story-mode-0')));await tester.pumpAndSettle();
        expect(find.byType(PlayerJourneyChapterListPage),findsOneWidget);await snapshot(tester,key,'chapters-$variant');
        await tester.tap(find.byKey(const ValueKey('journey-chapter-1')));await tester.pumpAndSettle();
        expect(find.byType(PlayerJourneyListPage),findsOneWidget);await snapshot(tester,key,'players-$variant');
        await goTo(tester,const ValueKey('journey-player-ronaldo'));
        await tester.tap(find.byKey(const ValueKey('journey-player-ronaldo')));await tester.pumpAndSettle();
        expect(find.byType(JourneyV2Page),findsNothing);
        await goTo(tester,const ValueKey('journey-player-messi'));
        await tester.tap(find.byKey(const ValueKey('journey-player-messi')));await tester.pumpAndSettle();
        expect(find.byType(JourneyV2Page),findsOneWidget);expect(observer.legacy.value,isFalse);
        expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
      });
      testWidgets('no spoiler before solve and four task flow $variant',(tester) async {
        viewport(tester);final key=GlobalKey(),journey=journeyTestPack().first;
        final game=JourneyV2Controller(journey:journey,store:MemoryJourneyStore(),random:Random(4));addTearDown(game.dispose);
        await tester.pumpWidget(app(JourneyV2Page(journeyId:journey.id,controller:game),key));await tester.pumpAndSettle();
        await snapshot(tester,key,'task-$variant');
        for(var i=0;i<4;i++) {
          final task=game.task;
          expect(find.text(task.explanation),findsNothing);
          for(final future in journey.tasks.skip(i+1)) { expect(find.text(future.prompt),findsNothing);expect(find.text(future.explanation),findsNothing); }
          if(i==0) {
            await goTo(tester,const ValueKey('journey-hint'));await tester.tap(find.byKey(const ValueKey('journey-hint')));await tester.pumpAndSettle();
            expect(game.hintVisible,isTrue);expect(find.text(task.explanation),findsNothing);
            await goTo(tester,const ValueKey('choice-o1'));await tester.tap(find.byKey(const ValueKey('choice-o1')));
            await goTo(tester,const ValueKey('journey-submit'));await tester.tap(find.byKey(const ValueKey('journey-submit')));await tester.pumpAndSettle();
            expect(game.checkpoint!.solved,0);expect(find.text(task.explanation),findsNothing);
          }
          for(final choice in task.answerKeys.take(task.requiredCount)) {
            await goTo(tester,ValueKey('choice-$choice'));await tester.tap(find.byKey(ValueKey('choice-$choice')));await tester.pumpAndSettle();
          }
          if(task.isTimeline) {
            await tester.drag(find.byType(ListView).last,const Offset(0,5000));await tester.pumpAndSettle();
            await snapshot(tester,key,'timeline-$variant');
          }
          await goTo(tester,const ValueKey('journey-submit'));await tester.tap(find.byKey(const ValueKey('journey-submit')));await tester.pumpAndSettle();
          expect(game.checkpoint!.solved,i+1);expect(find.text(task.explanation),findsOneWidget);
          if(i==0) await snapshot(tester,key,'result-$variant');
          if(i<3) {
            await goTo(tester,const ValueKey('journey-next'));await tester.tap(find.byKey(const ValueKey('journey-next')));await tester.pumpAndSettle();
          }
        }
        expect(game.checkpoint!.complete,isTrue);await snapshot(tester,key,'complete-$variant');
        expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  testWidgets('missing club and duplicate six-stop route render without early explanations',(tester) async {
    final pack=journeyTestPack();
    for(final id in ['ronaldo','kaka']) {
      final journey=pack.firstWhere((j)=>j.id==id),store=MemoryJourneyStore();
      if(id=='kaka') store.value=const JourneyCheckpoint(index:3,solved:3).toJson(journey);
      final game=JourneyV2Controller(journey:journey,store:store);addTearDown(game.dispose);
      await tester.pumpWidget(MaterialApp(theme:OrtakSahaTheme.dark,home:JourneyV2Page(key:ValueKey(id),journeyId:id,controller:game)));await tester.pumpAndSettle();
      expect(find.text(game.task.explanation),findsNothing);
      expect(game.task.type,id=='kaka'?JourneyTaskType.timeline:JourneyTaskType.missingClub);
      expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
