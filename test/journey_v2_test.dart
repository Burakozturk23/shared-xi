import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/controllers/journey_v2_controller.dart';
import 'package:shared_xi/models/journey_task.dart';
import 'package:shared_xi/services/journey_v2_store.dart';
import 'package:shared_xi/services/player_journey_progress_service.dart';

List<JourneyV2Definition> journeyTestPack({String chapter = 'one'}) {
  final j = jsonDecode(File('assets/data/player_journey_chapter_$chapter.json').readAsStringSync()) as Map<String,dynamic>;
  return (j['journeys'] as List).map((v) => JourneyV2Definition.fromJson(Map<String,dynamic>.from(v as Map))).toList();
}
class MemoryJourneyStore implements JourneyV2Store {
  Map<String,dynamic>? value;
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<Map<String,dynamic>?> read(String id) async => value;
  @override
  Future<void> write(String id, Map<String,dynamic> checkpoint) async {
    if (fail) throw StateError('disk full');
    if (pending != null) await pending!.future;
    value = jsonDecode(jsonEncode(checkpoint)) as Map<String,dynamic>;
  }
}
Future<void> solveJourneyTask(JourneyV2Controller game) async {
  game.clear();
  for (final key in game.task.answerKeys.take(game.task.requiredCount)) { game.choose(key); }
  await game.submit();
}
void main() {
  final chapterOne = journeyTestPack();
  final chapterTwo = journeyTestPack(chapter: 'two');
  final chapterThree = journeyTestPack(chapter: 'three');
  final chapterFour = journeyTestPack(chapter: 'four');
  final pack = [...chapterOne, ...chapterTwo, ...chapterThree, ...chapterFour];
  test('32 canonical journeys across all four chapters and all five task templates', () {
    expect(pack.length, 32);
    expect(pack.expand((j) => j.tasks).length, 128);
    expect(pack.expand((j) => j.tasks).map((t) => t.type).toSet(), JourneyTaskType.values.toSet());
    expect(pack.firstWhere((j) => j.id == 'kaka').playerId, 4000000028);
    expect(chapterOne.last.playerId, 4000000024);
    expect(chapterTwo[1].playerId,225083);
    expect(chapterTwo[3].playerId,4000000018);
    expect(chapterFour[6].playerId,5876); // The Inter striker, not another Adriano.
    expect(chapterFour.last.playerId,342229);
  });
  test('all reviewed tasks accept intended answers and reject distractors/incomplete selections', () {
    for (final task in pack.expand((j) => j.tasks)) {
      expect(task.accepts(task.answerKeys.take(task.requiredCount).toList()), isTrue, reason: task.id);
      expect(task.accepts([]), isFalse);
      expect(task.accepts(['unknown']), isFalse);
      if (task.type == JourneyTaskType.teammate) {
        expect(task.accepts(task.answerKeys.skip(1).take(2).toList()), isTrue);
        expect(task.accepts([task.answerKeys.first,task.answerKeys.first]), isFalse);
        expect(task.accepts([task.answerKeys.first,task.options.last.key]), isFalse);
      } else if (!task.isTimeline) {
        for (final option in task.options.where((o) => !task.answerKeys.contains(o.key))) {
          expect(task.accepts([option.key]), isFalse);
        }
      }
    }
  });
  test('timeline shuffle never supplies the solution; repeated clubs are interchangeable', () {
    for (final task in pack.expand((j) => j.tasks).where((t) => t.isTimeline)) {
      for (var seed=0;seed<25;seed++) {
        final shuffled = task.shuffled(Random(seed));
        expect(task.accepts(shuffled.map((o) => o.key).toList()), isFalse);
        expect(shuffled.map((o) => o.key).toSet(), task.answerKeys.toSet());
      }
      final keys = [...task.answerKeys];
      for (var i=0;i<keys.length;i++) {
        for (var k=i+1;k<keys.length;k++) {
          if (task.option(keys[i]).label == task.option(keys[k]).label) {
            final old = keys[i]; keys[i]=keys[k];keys[k]=old;
          }
        }
      }
      expect(task.accepts(keys), isTrue);
    }
    expect(pack.firstWhere((j) => j.id == 'kaka').tasks.last.requiredCount,6);
  });
  test('wrong answers and hint never advance; solved stage is explicit and cannot repeat', () async {
    final game=JourneyV2Controller(journey:pack.first,store:MemoryJourneyStore());
    addTearDown(game.dispose); await game.initialize();
    await game.next(); expect(game.checkpoint!.index,0);
    game.hint(); game.choose('o1'); await game.submit();
    expect(game.checkpoint!.solved,0); expect(game.message,isNotNull);
    await solveJourneyTask(game); expect(game.checkpoint!.reviewing,isTrue);
    await game.submit(); expect(game.checkpoint!.solved,1);
    game.choose('o1'); expect(game.selected,['o0']);
    await game.next(); expect(game.checkpoint!.index,1); expect(game.selected,isEmpty); expect(game.hintVisible,isFalse);
  });
  test('save failure retains selection and stage for retry', () async {
    final store=MemoryJourneyStore();
    final tested=JourneyV2Controller(journey:pack.first,store:store);addTearDown(tested.dispose);
    await tested.initialize();store.fail=true;await solveJourneyTask(tested);
    expect(tested.checkpoint!.solved,0);expect(tested.selected,['o0']);expect(tested.message,isNotNull);
    store.fail=false;await tested.submit();expect(tested.checkpoint!.solved,1);
    store.fail=true;await tested.next();expect(tested.checkpoint!.index,0);expect(tested.checkpoint!.reviewing,isTrue);
  });
  test('all 32 stories can finish, restore results and preserve unlock after replay', () async {
    for (final journey in pack) {
      final store=MemoryJourneyStore();
      final c=JourneyV2Controller(journey:journey,store:store);addTearDown(c.dispose);await c.initialize();
      for (var i=0;i<4;i++) {
        await solveJourneyTask(c);expect(c.checkpoint!.solved,i+1);await c.next();
      }
      expect(c.checkpoint!.complete,isTrue);
      final restored=JourneyV2Controller(journey:journey,store:store);addTearDown(restored.dispose);await restored.initialize();
      expect(restored.checkpoint!.complete,isTrue);
      await restored.restart();expect(restored.checkpoint!.solved,0);expect(store.value!['completed'],isTrue);
    }
  });
  test('concurrent inputs cannot skip a stage during storage', () async {
    final store=MemoryJourneyStore();
    final game=JourneyV2Controller(journey:pack.first,store:store);addTearDown(game.dispose);await game.initialize();
    game.choose('o0');store.pending=Completer<void>();final pending=game.submit();
    await Future<void>.delayed(Duration.zero);game.choose('o1');await game.next();await game.submit();
    expect(game.selected,['o0']);store.pending!.complete();await pending;
    expect(game.checkpoint!.solved,1);expect(game.checkpoint!.index,0);
  });
  test('corrupt save requires explicit restart and does not get overwritten on open', () async {
    final store=MemoryJourneyStore()..value={'version':900};
    final game=JourneyV2Controller(journey:pack.first,store:store);addTearDown(game.dispose);await game.initialize();
    expect(game.checkpoint,isNull);expect(store.value,{'version':900});
    await game.restart();expect(game.checkpoint!.solved,0);
  });
  test('timeline ordering controls change only selected legal positions', () async {
    final store=MemoryJourneyStore()..value=const JourneyCheckpoint(index:3,solved:3).toJson(pack.first);
    final game=JourneyV2Controller(journey:pack.first,store:store);addTearDown(game.dispose);await game.initialize();
    game.choose('o2');game.choose('o1');game.choose('o0');game.move(2,-1);game.move(1,-1);game.move(2,-1);
    expect(game.selected,['o0','o1','o2']);await game.submit();expect(game.checkpoint!.complete,isTrue);
  });
  test('legacy completion and v2 completion merge without progress loss', () async {
    SharedPreferences.setMockInitialValues({'player_journey_completed_ids':['messi']});
    final store=LocalJourneyV2Store();
    await store.write('ronaldo',const JourneyCheckpoint(index:3,solved:4).toJson(pack[1]));
    expect(await PlayerJourneyProgressService.getCompletedIds(),{'messi','ronaldo'});
    await store.write('ronaldo',const JourneyCheckpoint(everCompleted:true).toJson(pack[1]));
    expect(await PlayerJourneyProgressService.isUnlocked(orderedJourneyIds:['messi','ronaldo','ronaldinho'],index:2),isTrue);
  });
}
