import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/controllers/football_docu_controller.dart';
import 'package:shared_xi/models/docu_task.dart';
import 'package:shared_xi/services/football_docu_service.dart';

Map<String, dynamic> privatePack() => docuMap(
  jsonDecode(
    File('functions/config/football_docu_catalog.json').readAsStringSync(),
  ),
);
FootballDocuCatalog docuPack() => FootballDocuCatalog(
  docuMap(
    jsonDecode(File('assets/data/football_docu_v2.json').readAsStringSync()),
  ),
);
Map<String, dynamic> docuPrivate(String id) => (privatePack()['tasks'] as List)
    .map(docuMap)
    .firstWhere((t) => t['id'] == id);

class MemoryFootballDocuStore implements FootballDocuStore {
  Map<String, dynamic> data = {};
  @override
  Future<Map<String, dynamic>> read() async =>
      docuMap(jsonDecode(jsonEncode(data)));
  @override
  Future<void> write(Map<String, dynamic> value) async {
    data = docuMap(jsonDecode(jsonEncode(value)));
  }
}

class FakeFootballDocuGateway implements FootballDocuGateway {
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
      final t = docuPrivate(input['taskId'] as String);
      final a = docuStrings(input['answers']), b = docuStrings(t['answerKeys']);
      if (t['stage'] == 2 && !results.containsKey('${t['episodeId']}-01'))
        throw StateError('locked');
      if (t['interaction'] == 'multi') {
        a.sort();
        b.sort();
      }
      if (jsonEncode(a) != jsonEncode(b)) return {'correct': false};
      results[t['id'] as String] = t['result'];
      rewards[t['id'] as String] = {'coins': 8, 'xp': 20, 'settled': true};
    }
    final files = <String, dynamic>{};
    for (final d in (privatePack()['episodes'] as List).map(docuMap)) {
      if (docuStrings(d['taskIds']).every(results.containsKey))
        files[d['id'] as String] = {'story': d['story']};
    }
    return {
      'version': 2,
      'correct': true,
      'results': Map<String, dynamic>.from(results),
      'files': files,
      'rewards': Map<String, dynamic>.from(rewards),
      'rewardEligible': true,
    };
  }
}

void solve(FootballDocuController c) {
  final keys = docuStrings(docuPrivate(c.activeId!)['answerKeys']);
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

class FailingFootballDocuStore extends MemoryFootballDocuStore {
  bool fail = true;
  @override
  Future<void> write(Map<String, dynamic> value) async {
    if (fail) throw StateError('disk');
    await super.write(value);
  }
}

class DelayedFootballDocuGateway extends FakeFootballDocuGateway {
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
    'All 48 tasks complete and replay; 24 files require both stages',
    () async {
      final c = FootballDocuController(
        catalog: docuPack(),
        store: MemoryFootballDocuStore(),
        gateway: FakeFootballDocuGateway(),
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
              (x) => !docuStrings(docuPrivate(t.id)['answerKeys']).contains(x),
            ),
          );
          await c.submit();
          expect(c.phase, 'task');
        }
        solve(c);
        await c.submit();
        expect(c.phase, 'result');
        expect(c.fileCount, t.data['number'] ~/ 2);
        c.open(t.id, replay: true);
        c.start();
        solve(c);
        await c.submit();
      }
      expect(c.count, 48);
      expect(c.coins, 384);
      expect(c.fileCount, 24);
    },
  );
  test(
    'Offline ordering survives reopening; queued answer syncs once',
    () async {
      final store = MemoryFootballDocuStore(),
          gateway = FakeFootballDocuGateway()..offline = true;
      final c = FootballDocuController(
        catalog: docuPack(),
        store: store,
        gateway: gateway,
      );
      await c.load();
      c.open('DOC-03-01');
      c.start();
      solve(c);
      await c.submit();
      expect(c.count, 0);
      expect(c.pending, isNotEmpty);
      c.dispose();
      final restored = FootballDocuController(
        catalog: docuPack(),
        store: store,
        gateway: gateway,
      );
      addTearDown(restored.dispose);
      await restored.load();
      expect(
        restored.answers,
        docuStrings(docuPrivate('DOC-03-01')['answerKeys']),
      );
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
      final c = FootballDocuController(
        catalog: docuPack(),
        store: MemoryFootballDocuStore(),
        gateway: FakeFootballDocuGateway(),
      );
      addTearDown(c.dispose);
      await c.load();
      c.open('DOC-10-01');
      c.start();
      for (final id in c.active!.optionIds.take(3)) {
        c.choose(id);
      }
      expect(c.canSubmit, true);
      c.choose(c.active!.optionIds[3]);
      expect(c.answers.length, 3);
      c.choose(c.answers.first);
      expect(c.canSubmit, false);
      c.open('DOC-01-01');
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
    'All football_docu accessible but second research locks until first research is verified',
    () async {
      final c = FootballDocuController(
        catalog: docuPack(),
        store: MemoryFootballDocuStore(),
        gateway: FakeFootballDocuGateway(),
      );
      addTearDown(c.dispose);
      await c.load();
      c.open('DOC-01-02');
      expect(c.activeId, isNull);
      for (final d in c.catalog.episodes) {
        c.openEpisode(d.id);
        expect(c.activeId, d.taskIds.first);
      }
      c.open('DOC-01-01');
      c.start();
      solve(c);
      await c.submit();
      c.open('DOC-01-02');
      expect(c.activeId, 'DOC-01-02');
    },
  );
  test(
    'UID stores and stable storage version retain drafts across content updates',
    () async {
      SharedPreferences.setMockInitialValues({});
      final a = LocalFootballDocuStore('alice'),
          b = LocalFootballDocuStore('bob');
      await a.write({
        'storageVersion': 1,
        'drafts': {
          'DOC-01-01': ['fake'],
        },
        'activeId': 'DOC-01-01',
        'phase': 'task',
      });
      expect(await b.read(), isEmpty);
      final data = docuMap(
        jsonDecode(
          File('assets/data/football_docu_v2.json').readAsStringSync(),
        ),
      )..['version'] = 3;
      final c = FootballDocuController(
        catalog: FootballDocuCatalog(data),
        store: a,
        gateway: FakeFootballDocuGateway()..offline = true,
      );
      addTearDown(c.dispose);
      await c.load();
      expect(c.activeId, 'DOC-01-01');
      expect(c.answers, ['', '', '']);
      expect(c.count, 0);
    },
  );
  test('Completed files survive an offline restart', () async {
    final store = MemoryFootballDocuStore(),
        gateway = FakeFootballDocuGateway();
    final c = FootballDocuController(
      catalog: docuPack(),
      store: store,
      gateway: gateway,
    );
    await c.load();
    for (final id in ['DOC-01-01', 'DOC-01-02']) {
      c.open(id);
      c.start();
      solve(c);
      await c.submit();
    }
    c.dispose();
    gateway.offline = true;
    final reopened = FootballDocuController(
      catalog: docuPack(),
      store: store,
      gateway: gateway,
    );
    addTearDown(reopened.dispose);
    await reopened.load();
    expect(reopened.fileCount, 1);
    expect(reopened.count, 2);
  });
  test(
    'Failed disk write prevents sending; disposed controller ignores late replies',
    () async {
      final store = FailingFootballDocuStore(),
          gateway = FakeFootballDocuGateway();
      final c = FootballDocuController(
        catalog: docuPack(),
        store: store,
        gateway: gateway,
      );
      addTearDown(c.dispose);
      await c.load();
      c.open('DOC-01-01');
      c.start();
      solve(c);
      await c.submit();
      expect(gateway.results, isEmpty);
      store.fail = false;
      await c.submit();
      expect(c.count, 1);
      final late = DelayedFootballDocuGateway();
      final old = FootballDocuController(
        catalog: docuPack(),
        store: MemoryFootballDocuStore(),
        gateway: late,
      );
      final loading = old.load();
      await Future<void>.delayed(Duration.zero);
      old.dispose();
      late.response.complete({
        'version': 2,
        'results': {
          'DOC-01-01': {'answer': 'late'},
        },
      });
      await loading;
      expect(old.count, 0);
    },
  );
  test('Corrupt persisted JSON is not discarded', () async {
    SharedPreferences.setMockInitialValues({
      'football_docu.v1.alice': '{broken',
    });
    await expectLater(
      LocalFootballDocuStore('alice').read(),
      throwsFormatException,
    );
    expect(
      (await SharedPreferences.getInstance()).getString(
        'football_docu.v1.alice',
      ),
      '{broken',
    );
  });
}
