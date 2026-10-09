import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/controllers/journey_v2_controller.dart';
import 'package:shared_xi/models/journey_task.dart';
import 'package:shared_xi/screens/journey_v2_page.dart';
import 'package:shared_xi/services/journey_v2_store.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'journey_v2_test.dart' show journeyTestPack, MemoryJourneyStore, solveJourneyTask;
import 'journey_v2_page_test.dart' show goTo, startTask, snapshot;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('two choices per chapter; out-of-order wins open one more, replay never locks', () {
    final ids = journeyTestPack().map((j) => j.id).toList();
    bool unlocked(int i, Set<String> done, [Map<String,(int,bool)> progress = const {}]) =>
      journeyUnlocked(ids: ids, index: i, completed: done, progress: progress);
    expect(unlocked(0, {}), isTrue);
    expect(unlocked(1, {}), isTrue);
    expect(unlocked(2, {}), isFalse);
    expect(unlocked(2, {'ronaldo'}), isTrue);
    expect(unlocked(3, {'ronaldo'}), isFalse);
    expect(unlocked(2, {'vardy'}), isFalse); // another chapter is not currency
    expect(unlocked(7, {'maldini'}), isTrue); // legacy completion
    expect(unlocked(7, {}, {'maldini': (0, true)}), isTrue); // replay
    expect(unlocked(6, {}, {'benzema': (2, false)}), isTrue); // resume
    expect(unlocked(-1, {}), isFalse);
    expect(unlocked(8, ids.toSet()), isFalse);
  });
  test('every stage has distinct narrative without changing save identity', () {
    final journeys = [for (final chapter in ['one','two','three','four']) ...journeyTestPack(chapter: chapter)];
    final texts = journeys.expand((j) => j.tasks).map((t) => t.introNarrative);
    expect(texts.length, 128);
    expect(texts.toSet().length, 128);
    expect(texts.every((t) => t.length >= 80 && t.length <= 450), isTrue);
    for (final j in journeys) {
      final old = {'version': 2, 'taskIds': j.tasks.map((t) => t.id).toList(),
        'index': 2, 'solved': 2, 'completed': false};
      expect(JourneyCheckpoint.fromJson(old, j).index, 2);
    }
  });
  for (final light in [false,true]) {
    testWidgets('story/task/result separation and resume at 320px, large text, light=$light', (tester) async {
      tester.view.physicalSize = const Size(320,844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final journey = journeyTestPack().first, store = MemoryJourneyStore();
      final game = JourneyV2Controller(journey: journey, store: store);
      addTearDown(game.dispose);
      final key = GlobalKey();
      Widget app(JourneyV2Controller controller) => MaterialApp(
        theme: light ? OrtakSahaTheme.light : OrtakSahaTheme.dark,
        builder: (context,child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.8)),
          child: RepaintBoundary(key:key,child:child!)),
        home: JourneyV2Page(journeyId: journey.id, controller: controller));
      await tester.pumpWidget(app(game));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('journey-intro')), findsOneWidget);
      expect(find.text(game.task.prompt), findsNothing);
      expect(find.text(game.task.explanation), findsNothing);
      for (final o in game.task.options) { expect(find.text(o.label), findsNothing); }
      await snapshot(tester,key,'narrative-${light ? "light" : "dark"}-large');
      await startTask(tester);
      final picked = game.options.first.key;
      game.choose(picked);
      await tester.pumpAndSettle();
      await goTo(tester,const ValueKey('journey-read-story'));
      await tester.tap(find.byKey(const ValueKey('journey-read-story')));
      await tester.pumpAndSettle();
      expect(find.text(game.task.prompt), findsNothing);
      await startTask(tester);
      expect(game.selected, [picked]); // rereading does not clear an answer
      await solveJourneyTask(game);
      await tester.pumpAndSettle();
      await goTo(tester,const ValueKey('journey-result'));
      expect(find.text(game.task.explanation), findsOneWidget);
      await goTo(tester,const ValueKey('journey-next'));
      await tester.tap(find.byKey(const ValueKey('journey-next')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('journey-intro')), findsOneWidget);
      expect(game.checkpoint!.index, 1);
      expect(find.text(journey.tasks[1].prompt), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      final resumed = JourneyV2Controller(journey:journey,store:store);
      addTearDown(resumed.dispose);
      await tester.pumpWidget(app(resumed));
      await tester.pumpAndSettle();
      expect(resumed.checkpoint!.index, 1);
      expect(find.byKey(const ValueKey('journey-intro')), findsOneWidget);
      await startTask(tester);
      await goTo(tester,const ValueKey('journey-prompt'));
      expect(find.byKey(const ValueKey('journey-intro')), findsNothing);
      expect(find.text(journey.tasks[1].prompt), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
