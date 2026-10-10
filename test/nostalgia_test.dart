import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/controllers/turkish_nostalgia_controller.dart';
import 'package:shared_xi/models/turkish_nostalgia_state.dart';
import 'package:shared_xi/services/turkish_nostalgia_service.dart';

Map<String, dynamic> privatePack() => nostalgiaMap(
  jsonDecode(
    File('functions/config/nostalgia_catalog.json').readAsStringSync(),
  ),
);
NostalgiaCatalog nostalgiaPack() => NostalgiaCatalog(
  nostalgiaMap(
    jsonDecode(File('assets/data/nostalgia_v2.json').readAsStringSync()),
  ),
);
Map<String, dynamic> privateTask(String id) => (privatePack()['tasks'] as List)
    .map(nostalgiaMap)
    .firstWhere((t) => t['id'] == id);

class MemoryNostalgiaStore implements NostalgiaStore {
  Map<String, dynamic> data = {};
  bool fail = false;
  @override
  Future<Map<String, dynamic>> read() async =>
      nostalgiaMap(jsonDecode(jsonEncode(data)));
  @override
  Future<void> write(Map<String, dynamic> value) async {
    if (fail) throw StateError('disk');
    data = nostalgiaMap(jsonDecode(jsonEncode(value)));
  }
}

class FakeNostalgiaGateway implements NostalgiaGateway {
  bool offline = false;
  final Map<String, dynamic> results = {},
      rewards = {},
      albums = {},
      hints = {};
  final List<String> submissions = [];
  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> input = const {},
  ]) async {
    if (offline) throw StateError('offline');
    if (action == 'submit') {
      final task = privateTask(input['taskId'] as String);
      final chapter = (privatePack()['chapters'] as List)
          .map(nostalgiaMap)
          .firstWhere((c) => c['id'] == task['chapterId']);
      final ids = nostalgiaStrings(chapter['taskIds']);
      if (task['id'] != ids.first && !results.containsKey(ids.first)) {
        throw StateError('first task required');
      }
      submissions.add(task['id'] as String);
      if (jsonEncode(input['answers']) != jsonEncode(task['answerKeys'])) {
        return {'correct': false};
      }
      results[task['id'] as String] = task['result'];
      rewards[task['id'] as String] = {'coins': 6, 'xp': 15, 'settled': true};
      if (ids.every(results.containsKey)) {
        albums[chapter['id'] as String] = chapter['album'];
        rewards[chapter['id'] as String] = {
          'coins': 15,
          'xp': 30,
          'settled': true,
        };
      }
    }
    if (action == 'hint') {
      hints[input['taskId'] as String] = privateTask(
        input['taskId'] as String,
      )['strongHint'];
    }
    return {
      'version': 1,
      'correct': true,
      'results': Map<String, dynamic>.from(results),
      'rewards': Map<String, dynamic>.from(rewards),
      'albums': Map<String, dynamic>.from(albums),
      'hints': Map<String, dynamic>.from(hints),
      'hintPrice': 6,
      'rewardEligible': true,
      'badge': albums.length == 12 ? 'nostalgia_archivist_v1' : null,
    };
  }
}

void selectNostalgia(NostalgiaController c) {
  final keys = nostalgiaStrings(privateTask(c.activeId!)['answerKeys']);
  if (c.active!.type == 'timeline') {
    for (var i = 0; i < keys.length; i++) {
      while (c.answers.indexOf(keys[i]) > i) {
        c.move(c.answers.indexOf(keys[i]), -1);
      }
    }
  } else {
    for (var i = 0; i < keys.length; i++) {
      c.slot(i, keys[i]);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    '24 tasks wrong/retry/replay, 12 albums and isolated public answer data',
    () async {
      final c = NostalgiaController(
        catalog: nostalgiaPack(),
        store: MemoryNostalgiaStore(),
        gateway: FakeNostalgiaGateway(),
      );
      addTearDown(c.dispose);
      await c.load();
      for (final chapter in c.catalog.chapters) {
        c.openChapter(chapter.id);
        c.start();
        for (var i = 0; i < 2; i++) {
          expect(c.active!.data.containsKey('answerKeys'), false);
          expect(c.active!.data.containsKey('result'), false);
          if (c.active!.required == 1) {
            c.choose(
              c.active!.optionIds.firstWhere(
                (id) =>
                    !nostalgiaStrings(privateTask(c.activeId!)['answerKeys'])
                        .contains(id),
              ),
            );
            await c.submit();
            expect(c.phase, 'task');
          }
          selectNostalgia(c);
          await c.submit();
          expect(c.phase, 'result');
          c.next();
        }
        expect(c.phase, 'album');
        c.openChapter(chapter.id, replay: true);
        c.start();
        for (var i = 0; i < 2; i++) {
          expect(c.phase, 'task');
          selectNostalgia(c);
          await c.submit();
          c.next();
        }
        expect(c.phase, 'album');
      }
      expect(c.count, 24);
      expect(c.albums.length, 12);
      expect(c.badge, 'nostalgia_archivist_v1');
    },
  );
  test('All 24 offline submissions survive restart and flush in chapter order', () async {
    final store = MemoryNostalgiaStore(),
        gateway = FakeNostalgiaGateway()..offline = true;
    final c = NostalgiaController(
      catalog: nostalgiaPack(),
      store: store,
      gateway: gateway,
    );
    await c.load();
    for (final chapter in c.catalog.chapters) {
      c.openChapter(chapter.id);
      c.start();
      for (var i = 0; i < 2; i++) {
        selectNostalgia(c);
        await c.submit();
        expect(c.phase, 'queued');
        c.next();
      }
    }
    expect(c.count, 0);
    expect(c.albums, isEmpty);
    expect(c.pending.length, 24);
    // A final awaited write captures navigation before simulating process exit.
    await Future<void>.delayed(Duration.zero);
    c.dispose();
    final restored = NostalgiaController(
      catalog: nostalgiaPack(),
      store: store,
      gateway: gateway,
    );
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.pending.length, 24);
    gateway.offline = false;
    await restored.sync();
    expect(restored.pending, isEmpty);
    expect(restored.count, 24);
    expect(restored.albums.length, 12);
    expect(
      gateway.submissions,
      restored.catalog.tasks.map((t) => t.id).toList(),
    );
  });
  test(
    'Wrong queued first task leaves dependent answer intact until retry',
    () async {
      final gateway = FakeNostalgiaGateway()..offline = true;
      final c = NostalgiaController(
        catalog: nostalgiaPack(),
        store: MemoryNostalgiaStore(),
        gateway: gateway,
      );
      addTearDown(c.dispose);
      await c.load();
      c.openChapter('nostalgia_01');
      c.start();
      c.choose(
        c.active!.optionIds.firstWhere(
          (id) =>
              id !=
              nostalgiaStrings(privateTask(c.activeId!)['answerKeys']).single,
        ),
      );
      await c.submit();
      c.next();
      selectNostalgia(c);
      await c.submit();
      gateway.offline = false;
      await c.sync();
      expect(c.count, 0);
      expect(c.pending.keys, ['nostalgia_01_2']);
      c.openChapter('nostalgia_01');
      c.start();
      selectNostalgia(c);
      await c.submit();
      await c.sync();
      expect(c.count, 2);
      expect(c.pending, isEmpty);
    },
  );
  test(
    'UID persistence separates users; failed disk save never submits',
    () async {
      SharedPreferences.setMockInitialValues({});
      final a = LocalNostalgiaStore('a'), b = LocalNostalgiaStore('b');
      await a.write({'version': 1});
      expect(await b.read(), isEmpty);
      final store = MemoryNostalgiaStore(), gateway = FakeNostalgiaGateway();
      final c = NostalgiaController(
        catalog: nostalgiaPack(),
        store: store,
        gateway: gateway,
      );
      addTearDown(c.dispose);
      await c.load();
      store.fail = true;
      c.openChapter('nostalgia_01');
      c.start();
      selectNostalgia(c);
      await c.submit();
      expect(gateway.submissions, isEmpty);
      expect(c.phase, 'task');
      expect(c.count, 0);
    },
  );
}
