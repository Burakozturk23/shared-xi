import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/app/route_appearance.dart';
import 'package:shared_xi/data/player_journey_chapters.dart';
import 'package:shared_xi/models/journey_task.dart';
import 'package:shared_xi/screens/player_journey_chapter_list_page.dart';
import 'package:shared_xi/screens/player_journey_list_page.dart';
import 'package:shared_xi/screens/journey_v2_page.dart';
import 'package:shared_xi/services/journey_v2_store.dart';
import 'package:shared_xi/services/player_journey_progress_service.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'package:shared_xi/widgets/pitch_ui.dart';
import 'journey_v2_test.dart' show journeyTestPack;
import 'journey_v2_page_test.dart' show goTo, snapshot;
import 'package:flutter/services.dart';

Future<void> openJourney(WidgetTester tester, String id) async {
  final row = find.byKey(ValueKey('journey-player-$id'));
  await goTo(tester, ValueKey('journey-player-$id'));
  expect(tester.widget<PitchRow>(row).onTap, isNotNull,
    reason: '$id must be unlocked before navigating');
  // Keep navigation in the test clock so the pop continuation refreshes
  // unlocks before the next tap. Only asset I/O needs real async time.
  await tester.tap(row);
  await tester.runAsync(() async {
    for (var i=0;i<100;i++) {
      await tester.pump();
      if (find.byKey(const ValueKey('journey-prompt')).evaluate().isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds:50));
    }
  });
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('journey-prompt')),findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'player_journey_completed_ids':['messi']}));
  setUpAll(() async {
    for (final (name,path) in [
      ('Satoshi','assets/fonts/Satoshi-Variable.ttf'),('Inter','assets/fonts/Inter-Body-Variable.ttf'),
      ('MaterialIcons','fonts/MaterialIcons-Regular.otf'),
    ]) { await (FontLoader(name)..addFont(rootBundle.load(path))).load(); }
  });
  test('chapter registry matches menu order, canonical subjects and both assets',() async {
    for (final chapter in playerJourneyChapters.take(2)) {
      final pack=await loadJourneyChapter(chapter.id);
      expect(pack.map((j)=>j.id),chapter.journeys.map((j)=>j.id));
      expect(pack.map((j)=>j.playerId),chapter.journeys.map((j)=>j.subjectPlayerId));
      expect(journeyV2Chapters[chapter.id]!.number,chapter.number);
    }
    await expectLater(loadJourneyChapter('chapter_3_architects'),throwsFormatException);
  });
  test('second chapter saves remain separate and legacy completions survive replay',() async {
    final one=journeyTestPack().first,two=journeyTestPack(chapter:'two').first,store=LocalJourneyV2Store();
    await store.write(one.id,const JourneyCheckpoint(index:1,solved:1).toJson(one));
    await store.write(two.id,const JourneyCheckpoint(index:3,solved:4).toJson(two));
    expect((await store.read(one.id))!['solved'],1);
    expect(await PlayerJourneyProgressService.getCompletedIds(),{'messi','vardy'});
    await store.write(two.id,const JourneyCheckpoint(everCompleted:true).toJson(two));
    expect(await PlayerJourneyProgressService.getCompletedIds(),{'messi','vardy'});
  });
  for (final light in [false,true]) {
    for (final large in [false,true]) {
      final variant='${light?"light":"dark"}-${large?"large":"normal"}';
      testWidgets('chapter two opens offline, resumes, completes and unlocks next player $variant',(tester) async {
        tester.view.physicalSize=Size(large?320:390,844);tester.view.devicePixelRatio=1;
        addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
        final key=GlobalKey(),observer=RouteAppearanceObserver();addTearDown(observer.dispose);
        await tester.pumpWidget(MaterialApp(
          theme:light?OrtakSahaTheme.light:OrtakSahaTheme.dark,navigatorObservers:[observer],
          builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(large?1.8:1)),
            child:RepaintBoundary(key:key,child:child!)),home:const PlayerJourneyChapterListPage(),
        ));
        await tester.pumpAndSettle();
        await goTo(tester,const ValueKey('journey-chapter-2'));
        await tester.tap(find.byKey(const ValueKey('journey-chapter-2')));await tester.pumpAndSettle();
        expect(find.byType(PlayerJourneyListPage),findsOneWidget);
        await snapshot(tester,key,'chapter-two-players-$variant');
        await goTo(tester,const ValueKey('journey-player-kante'));
        await tester.tap(find.byKey(const ValueKey('journey-player-kante')));await tester.pumpAndSettle();
        expect(find.byType(JourneyV2Page),findsNothing);
        await openJourney(tester,'vardy');
        expect(find.text('BÖLÜM 2'),findsOneWidget);expect(find.text('BÖLÜM 1'),findsNothing);
        expect(observer.legacy.value,isFalse);
        await snapshot(tester,key,'chapter-two-task-$variant');
        final journey=journeyTestPack(chapter:'two').first;
        for (var i=0;i<4;i++) {
          final task=journey.tasks[i];
          expect(find.text(task.explanation),findsNothing);
          for (final future in journey.tasks.skip(i+1)) {
            expect(find.text(future.prompt),findsNothing);expect(find.text(future.explanation),findsNothing);
          }
          for (final answer in task.answerKeys.take(task.requiredCount)) {
            await goTo(tester,ValueKey('choice-$answer'));
            await tester.tap(find.byKey(ValueKey('choice-$answer')));await tester.pumpAndSettle();
          }
          await goTo(tester,const ValueKey('journey-submit'));
          await tester.tap(find.byKey(const ValueKey('journey-submit')));await tester.pumpAndSettle();
          expect(find.text(task.explanation),findsOneWidget);
          if (i<3) {
            await goTo(tester,const ValueKey('journey-next'));
            await tester.tap(find.byKey(const ValueKey('journey-next')));await tester.pumpAndSettle();
          }
          if (i==0) {
            await tester.pageBack();await tester.pumpAndSettle();
            await openJourney(tester,'vardy');
            expect(find.text(journey.tasks[1].prompt),findsOneWidget);
            expect(find.text(journey.tasks[0].prompt),findsNothing);
          }
        }
        await snapshot(tester,key,'chapter-two-complete-$variant');
        await goTo(tester,const ValueKey('journey-finish'));
        await tester.tap(find.byKey(const ValueKey('journey-finish')));await tester.pumpAndSettle();
        await openJourney(tester,'kante');
        expect(find.text("N'Golo Kanté"),findsWidgets);expect(find.text('BÖLÜM 2'),findsOneWidget);
        expect(await PlayerJourneyProgressService.getCompletedIds(),containsAll(['messi','vardy']));
        expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
