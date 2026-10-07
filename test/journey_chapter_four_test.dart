import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/app/route_appearance.dart';
import 'package:shared_xi/screens/player_journey_chapter_list_page.dart';
import 'package:shared_xi/screens/player_journey_list_page.dart';
import 'package:shared_xi/screens/journey_v2_page.dart';
import 'package:shared_xi/services/player_journey_progress_service.dart';
import 'package:shared_xi/models/journey_task.dart';
import 'package:shared_xi/services/journey_v2_store.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'journey_v2_test.dart' show journeyTestPack;
import 'journey_v2_page_test.dart' show goTo, snapshot;
import 'package:flutter/services.dart';

import 'journey_chapter_two_test.dart' show openJourney;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'player_journey_completed_ids':['messi']}));
  setUpAll(() async {
    for (final (name,path) in [
      ('Satoshi','assets/fonts/Satoshi-Variable.ttf'),('Inter','assets/fonts/Inter-Body-Variable.ttf'),
      ('MaterialIcons','fonts/MaterialIcons-Regular.otf'),
    ]) { await (FontLoader(name)..addFont(rootBundle.load(path))).load(); }
  });
  test('four chapter checkpoints stay separate and final completion survives replay',() async {
    final store=LocalJourneyV2Store();
    final journeys=[for(final chapter in ['one','two','three','four']) journeyTestPack(chapter:chapter).first];
    for(final journey in journeys) {
      await store.write(journey.id,const JourneyCheckpoint(index:1,solved:1).toJson(journey));
    }
    final last=journeyTestPack(chapter:'four').last;
    await store.write(last.id,const JourneyCheckpoint(index:3,solved:4).toJson(last));
    for(final journey in journeys) {
      expect((await store.read(journey.id))!['solved'],1);
    }
    expect(await PlayerJourneyProgressService.getCompletedIds(),{'messi','mbappe'});
    await store.write(last.id,const JourneyCheckpoint(everCompleted:true).toJson(last));
    expect(await PlayerJourneyProgressService.getCompletedIds(),{'messi','mbappe'});
  });
  for (final light in [false,true]) {
    for (final large in [false,true]) {
      final variant='${light?"light":"dark"}-${large?"large":"normal"}';
      testWidgets('chapter four pilot opens, resumes and completes $variant',(tester) async {
        final pack=journeyTestPack(chapter:'four');
        final id=light ? (large ? 'mbappe' : 'adriano') : (large ? 'rooney' : 'pirlo');
        final index=pack.indexWhere((j)=>j.id==id);
        final journey=pack[index];
        final nextId=index+1<pack.length ? pack[index+1].id : null;
        final previousIds = [
          for (final chapter in ['one','two','three'])
            ...journeyTestPack(chapter:chapter).map((j)=>j.id),
        ];
        SharedPreferences.setMockInitialValues({'player_journey_completed_ids':[...previousIds,...pack.take(index).map((j)=>j.id)]});
        tester.view.physicalSize=Size(large?320:390,844);tester.view.devicePixelRatio=1;
        addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
        final key=GlobalKey(),observer=RouteAppearanceObserver();addTearDown(observer.dispose);
        await tester.pumpWidget(MaterialApp(
          theme:light?OrtakSahaTheme.light:OrtakSahaTheme.dark,navigatorObservers:[observer],
          builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(large?1.8:1)),
            child:RepaintBoundary(key:key,child:child!)),home:const PlayerJourneyChapterListPage(),
        ));
        await tester.pumpAndSettle();
        await goTo(tester,const ValueKey('journey-chapter-4'));
        await tester.tap(find.byKey(const ValueKey('journey-chapter-4')));await tester.pumpAndSettle();
        expect(find.byType(PlayerJourneyListPage),findsOneWidget);
        await snapshot(tester,key,'chapter-four-players-$variant');
        if (nextId!=null) {
          await goTo(tester,ValueKey('journey-player-$nextId'));
          await tester.tap(find.byKey(ValueKey('journey-player-$nextId')));await tester.pumpAndSettle();
          expect(find.byType(JourneyV2Page),findsNothing);
        }
        await openJourney(tester,id);
        expect(find.text('BÖLÜM 4'),findsOneWidget);expect(find.text('BÖLÜM 1'),findsNothing);
        expect(observer.legacy.value,isFalse);
        await snapshot(tester,key,'chapter-four-task-$variant');
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
            await openJourney(tester,id);
            expect(find.text(journey.tasks[1].prompt),findsOneWidget);
            expect(find.text(journey.tasks[0].prompt),findsNothing);
          }
        }
        await snapshot(tester,key,'chapter-four-complete-$variant');
        await goTo(tester,const ValueKey('journey-finish'));
        await tester.tap(find.byKey(const ValueKey('journey-finish')));await tester.pumpAndSettle();
        if (nextId!=null) {
          await openJourney(tester,nextId);
          expect(find.text('BÖLÜM 4'),findsOneWidget);
        }
        final completed = await PlayerJourneyProgressService.getCompletedIds();
        expect(completed,containsAll([...previousIds,id]));
        if (id=='mbappe') {
          expect(completed.length,32);
          expect(completed,containsAll(pack.map((j)=>j.id)));
        }
        expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
