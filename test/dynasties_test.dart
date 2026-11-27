import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/controllers/dynasties_controller.dart';
import 'package:shared_xi/models/dynasty_task.dart';
import 'package:shared_xi/services/dynasties_service.dart';

Map<String, dynamic> privatePack() => dyMap(
  jsonDecode(
    File('functions/config/dynasties_catalog.json').readAsStringSync(),
  ),
);
DynastiesCatalog dyPack() => DynastiesCatalog(
  dyMap(jsonDecode(File('assets/data/dynasties_v2.json').readAsStringSync())),
);
Map<String, dynamic> dyPrivate(String id) => (privatePack()['tasks'] as List)
    .map(dyMap)
    .firstWhere((t) => t['id'] == id);

class MemoryDynastiesStore implements DynastiesStore {
  Map<String, dynamic> data = {};
  @override
  Future<Map<String, dynamic>> read() async =>
      dyMap(jsonDecode(jsonEncode(data)));
  @override
  Future<void> write(Map<String, dynamic> value) async {
    data = dyMap(jsonDecode(jsonEncode(value)));
  }
}

class FakeDynastiesGateway implements DynastiesGateway {
  bool offline = false;
  final List<Map<String, dynamic>> hintRequests = [];
  final Map<String, dynamic> results = {}, rewards = {};
  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> input = const {},
  ]) async {
    if (offline) throw StateError('offline');
    if (action == 'hint') hintRequests.add(Map<String, dynamic>.from(input));
    if (action == 'submit') {
      final t = dyPrivate(input['taskId'] as String);
      final a = dyStrings(input['answers']), b = dyStrings(t['answerKeys']);
      if (t['stage'] == 2 && !results.containsKey('${t['dynastyId']}-01'))
        throw StateError('locked');
      if (t['interaction'] == 'multi') {
        a.sort();
        b.sort();
      }
      if (jsonEncode(a) != jsonEncode(b)) return {'correct': false};
      results[t['id'] as String] = t['result'];
      rewards[t['id'] as String] = {'coins': 8, 'xp': 20, 'settled': true};
    }
    final seals = <String, dynamic>{};
    for (final d in (privatePack()['dynasties'] as List).map(dyMap)) {
      if (dyStrings(d['taskIds']).every(results.containsKey))
        seals[d['id'] as String] = {'story': d['story']};
    }
    return {
      'version': 2,
      'correct': true,
      'results': Map<String, dynamic>.from(results),
      'seals': seals,
      'rewards': Map<String, dynamic>.from(rewards),
      'rewardEligible': true,
    };
  }
}

void solve(DynastiesController c) {
  final keys = dyStrings(dyPrivate(c.activeId!)['answerKeys']);
  switch (c.active!.interaction) {
    case 'order':
      for (var i = 0; i < keys.length; i++) {
        while (c.answers.indexOf(keys[i]) > i) {
          c.move(c.answers.indexOf(keys[i]), -1);
        }
      }
    case 'match':
      for (var i = 0; i < keys.length; i++) {
        c.assign(i, keys[i]);
      }
    case 'multi':
      for (final a in List<String>.from(c.answers)) {
        c.choose(a);
      }
      for (final a in keys) {
        c.choose(a);
      }
    default:
      c.choose(keys.single);
  }
}

class FailingDynastiesStore extends MemoryDynastiesStore {
  bool fail = true;
  @override
  Future<void> write(Map<String, dynamic> value) async {
    if (fail) throw StateError('disk');
    await super.write(value);
  }
}

class DelayedDynastiesGateway extends FakeDynastiesGateway {
  final response = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> input = const {},
  ]) async => response.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'All 32 tasks complete and replay; 16 seals require both stages',
    () async {
      final c = DynastiesController(
        catalog: dyPack(),
        store: MemoryDynastiesStore(),
        gateway: FakeDynastiesGateway(),
      );
      addTearDown(c.dispose);
      await c.load();
      for (final t in c.catalog.tasks) {
        expect(t.data.containsKey('answerKeys'), false);
        expect(t.data.containsKey('result'), false);
        c.open(t.id);
        c.start();
        if (t.interaction == 'single') {
          c.choose(
            t.optionIds.firstWhere(
              (x) => !dyStrings(dyPrivate(t.id)['answerKeys']).contains(x),
            ),
          );
          await c.submit();
          expect(c.phase, 'task');
        }
        solve(c);
        await c.submit();
        expect(c.phase, 'result');
        expect(c.sealCount, t.data['number'] ~/ 2);
        c.open(t.id, replay: true);
        c.start();
        solve(c);
        await c.submit();
      }
      expect(c.count, 32);
      expect(c.coins, 256);
      expect(c.sealCount, 16);
    },
  );
  test(
    'Offline ordering survives reopening; queued answer syncs once',
    () async {
      final store = MemoryDynastiesStore(),
          gateway = FakeDynastiesGateway()..offline = true;
      final c = DynastiesController(
        catalog: dyPack(),
        store: store,
        gateway: gateway,
      );
      await c.load();
      c.open('DY-02-01');
      c.start();
      solve(c);
      await c.submit();
      expect(c.count, 0);
      expect(c.pending, isNotEmpty);
      c.dispose();
      final restored = DynastiesController(
        catalog: dyPack(),
        store: store,
        gateway: gateway,
      );
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.answers, dyStrings(dyPrivate('DY-02-01')['answerKeys']));
      gateway.offline = false;
      await restored.sync();
      expect(restored.count, 1);
      expect(restored.pending, isEmpty);
      expect(restored.phase, 'result');
    },
  );
  test(
    'Multiselect exact count, deselection and match slots enforce unique cards',
    () async {
      final c = DynastiesController(
        catalog: dyPack(),
        store: MemoryDynastiesStore(),
        gateway: FakeDynastiesGateway(),
      );
      addTearDown(c.dispose);
      await c.load();
      c.open('DY-09-01');
      c.start();
      for (final id in c.active!.optionIds.take(3)) {
        c.choose(id);
      }
      expect(c.canSubmit, true);
      c.choose(c.active!.optionIds[3]);
      expect(c.answers.length, 3);
      c.choose(c.answers.first);
      expect(c.canSubmit, false);
      c.open('DY-15-01');
      c.start();
      expect(c.answers, ['', '', '']);
      c.assign(0, c.active!.optionIds.first);
      c.assign(2, c.active!.optionIds.first);
      expect(c.answers[0], '');
      expect(c.canSubmit, false);
      solve(c);
      expect(c.canSubmit, true);
    },
  );
  test(
    'All dynasties accessible but summit locks until ascent is verified',
    () async {
      final c = DynastiesController(
        catalog: dyPack(),
        store: MemoryDynastiesStore(),
        gateway: FakeDynastiesGateway(),
      );
      addTearDown(c.dispose);
      await c.load();
      c.open('DY-01-02');
      expect(c.activeId, isNull);
      for (final d in c.catalog.dynasties) {
        c.openDynasty(d.id);
        expect(c.activeId, d.taskIds.first);
      }
      c.open('DY-01-01');
      c.start();
      solve(c);
      await c.submit();
      c.open('DY-01-02');
      expect(c.activeId, 'DY-01-02');
    },
  );
  test(
    'UID stores and stable storage version retain drafts across content updates',
    () async {
      SharedPreferences.setMockInitialValues({});
      final a = LocalDynastiesStore('alice'), b = LocalDynastiesStore('bob');
      await a.write({
        'storageVersion': 1,
        'drafts': {
          'DY-15-01': ['fake'],
        },
        'activeId': 'DY-15-01',
        'phase': 'task',
      });
      expect(await b.read(), isEmpty);
      final data = dyMap(
        jsonDecode(File('assets/data/dynasties_v2.json').readAsStringSync()),
      )..['version'] = 3;
      final c = DynastiesController(
        catalog: DynastiesCatalog(data),
        store: a,
        gateway: FakeDynastiesGateway()..offline = true,
      );
      addTearDown(c.dispose);
      await c.load();
      expect(c.activeId, 'DY-15-01');
      expect(c.answers, ['', '', '']);
      expect(c.count, 0);
    },
  );
  test('Completed seals survive an offline restart', () async {
    final store = MemoryDynastiesStore(), gateway = FakeDynastiesGateway();
    final c = DynastiesController(
      catalog: dyPack(),
      store: store,
      gateway: gateway,
    );
    await c.load();
    for (final id in ['DY-01-01', 'DY-01-02']) {
      c.open(id);
      c.start();
      solve(c);
      await c.submit();
    }
    c.dispose();
    gateway.offline = true;
    final reopened = DynastiesController(
      catalog: dyPack(),
      store: store,
      gateway: gateway,
    );
    addTearDown(reopened.dispose);
    await reopened.load();
    expect(reopened.sealCount, 1);
    expect(reopened.count, 2);
  });
  test(
    'Failed disk write prevents sending; disposed controller ignores late replies',
    () async {
      final store = FailingDynastiesStore(), gateway = FakeDynastiesGateway();
      final c = DynastiesController(
        catalog: dyPack(),
        store: store,
        gateway: gateway,
      );
      addTearDown(c.dispose);
      await c.load();
      c.open('DY-01-01');
      c.start();
      solve(c);
      await c.submit();
      expect(gateway.results, isEmpty);
      store.fail = false;
      await c.submit();
      expect(c.count, 1);
      final late = DelayedDynastiesGateway();
      final old = DynastiesController(
        catalog: dyPack(),
        store: MemoryDynastiesStore(),
        gateway: late,
      );
      final loading = old.load();
      await Future<void>.delayed(Duration.zero);
      old.dispose();
      late.response.complete({
        'version': 2,
        'results': {
          'DY-01-01': {'answer': 'late'},
        },
      });
      await loading;
      expect(old.count, 0);
    },
  );
  test('Corrupt persisted JSON is not discarded', () async {
    SharedPreferences.setMockInitialValues({'dynasties.v1.alice': '{broken'});
    await expectLater(
      LocalDynastiesStore('alice').read(),
      throwsFormatException,
    );
    expect(
      (await SharedPreferences.getInstance()).getString('dynasties.v1.alice'),
      '{broken',
    );
  });
}
