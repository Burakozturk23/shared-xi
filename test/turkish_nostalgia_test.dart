import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/controllers/turkish_nostalgia_controller.dart';
import 'package:shared_xi/models/turkish_nostalgia_state.dart';
import 'package:shared_xi/screens/turkish_nostalgia_page.dart';
import 'package:shared_xi/services/nostalgia_service.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';

class MemoryStore implements NostalgiaStore {
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

class Gateway implements NostalgiaGateway {
  bool offline = false;
  Completer<Map<String, dynamic>>? delayed;
  final List<String> submitted = [];
  final Map<String, dynamic> completed = {}, hints = {};
  Map<String, dynamic> get status => {
    'version': 2,
    'completed': completed,
    'hints': hints,
    'rewards': <String, dynamic>{},
    'rewardEligible': true,
  };
  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> input = const {},
  ]) async {
    if (offline) throw Exception('offline');
    if (delayed != null) return delayed!.future;
    if (action == 'submit') {
      final id = input['taskId'] as String;
      submitted.add(id);
      completed[id] = 1;
      return {'correct': true, ...status};
    }
    if (action == 'hint') hints[input['taskId'] as String] = true;
    return status;
  }
}

Future<void> drained(TurkishNostalgiaController c) async {
  for (var i = 0; i < 50 && c.syncing; i++) {
    await Future<void>.value();
  }
}

void solve(TurkishNostalgiaController c) {
  final t = c.task!;
  if (t.mechanic == 'timeline') {
    for (var i = 0; i < t.answerKeys.length; i++) {
      var from = c.answers.indexOf(t.answerKeys[i]);
      while (from > i) {
        c.move(from, -1);
        from--;
      }
    }
  } else {
    for (var i = 0; i < t.answerKeys.length; i++) {
      c.choose(t.answerKeys[i], slot: i);
    }
  }
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('.dart_tool/nostalgia_qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late NostalgiaCatalog catalog;
  setUpAll(() async {
    catalog = await NostalgiaCatalog.load();
    for (final (name, path) in [
      ('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'),
      ('Inter', 'assets/fonts/Inter-Body-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(name)..addFont(rootBundle.load(path))).load();
    }
  });
  test(
    'all tasks survive offline checkpoint and sync in task order without local money',
    () async {
      final store = MemoryStore(), gateway = Gateway()..offline = true;
      final c = TurkishNostalgiaController(
        catalog: catalog,
        store: store,
        gateway: gateway,
      );
      await c.load();
      await drained(c);
      for (final chapter in catalog.chapters) {
        c.open(chapter.id);
        c.start();
        solve(c);
        await c.submit();
        await drained(c);
        c.next();
        solve(c);
        await c.submit();
        await drained(c);
        c.next();
      }
      expect(c.solved.length, 24);
      expect(c.albums, 12);
      expect(c.coins, 0);
      expect(c.pending.length, 24);
      c.dispose();
      final restored = TurkishNostalgiaController(
        catalog: catalog,
        store: store,
        gateway: gateway,
      );
      await restored.load();
      await drained(restored);
      expect(restored.solved.length, 24);
      expect(restored.pending.length, 24);
      gateway.offline = false;
      await restored.sync();
      expect(gateway.submitted, catalog.tasks.map((t) => t.id).toList());
      expect(restored.pending, isEmpty);
      expect(restored.confirmed.length, 24);
      restored.open(catalog.chapters.first.id, replay: true);
      expect(restored.phase, 'intro');
      expect(restored.solved.length, 24);
      restored.start();
      expect(restored.phase, 'task');
      expect(restored.answers, isEmpty);
      restored.dispose();
    },
  );
  test(
    'incorrect answers retry, route partial draft persists, hints and sequence resume',
    () async {
      final store = MemoryStore(), gateway = Gateway()..offline = true;
      final c = TurkishNostalgiaController(
        catalog: catalog,
        store: store,
        gateway: gateway,
      );
      await c.load();
      await drained(c);
      c.open(catalog.chapters[5].id);
      c.start();
      c.choose('o3', slot: 0);
      c.choose('o4', slot: 1);
      await c.submit();
      expect(c.phase, 'task');
      expect(c.solved, isEmpty);
      c.choose('o2', slot: 0);
      c.hint();
      await c.sync();
      final restored = TurkishNostalgiaController(
        catalog: catalog,
        store: store,
        gateway: gateway,
      );
      await restored.load();
      await drained(restored);
      expect(restored.answers, ['o2', 'o4']);
      expect(restored.hintOpen, true);
      solve(restored);
      await restored.submit();
      await drained(restored);
      restored.next();
      expect(restored.task!.mechanic, 'timeline');
      solve(restored);
      await restored.submit();
      await drained(restored);
      expect(restored.albums, 1);
      c.dispose();
      restored.dispose();
    },
  );
  test('failed checkpoint does not show success and can be retried', () async {
    final store = MemoryStore(), gateway = Gateway()..offline = true;
    final c = TurkishNostalgiaController(
      catalog: catalog,
      store: store,
      gateway: gateway,
    );
    await c.load();
    await drained(c);
    c.open(catalog.chapters.first.id);
    c.start();
    solve(c);
    store.fail = true;
    await c.submit();
    expect(c.phase, 'task');
    expect(c.solved, isEmpty);
    store.fail = false;
    await c.submit();
    await drained(c);
    expect(c.phase, 'result');
    expect(c.solved.length, 1);
    c.dispose();
  });
  test(
    'UID stores stay isolated and malformed save is not silently overwritten',
    () async {
      SharedPreferences.setMockInitialValues({});
      final a = LocalNostalgiaStore('alice'), b = LocalNostalgiaStore('bob');
      await a.write({
        'schema': 2,
        'solved': ['tn2_c01_t1'],
      });
      expect(await b.read(), isEmpty);
      expect((await a.read())['solved'], ['tn2_c01_t1']);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(a.key, '{broken');
      await expectLater(a.read(), throwsFormatException);
      expect(prefs.getString(a.key), '{broken');
    },
  );
  test(
    'disposed account controller cannot apply late cloud response',
    () async {
      final gateway = Gateway()..delayed = Completer();
      final store = MemoryStore();
      final c = TurkishNostalgiaController(
        catalog: catalog,
        store: store,
        gateway: gateway,
      );
      await c.load();
      c.dispose();
      gateway.delayed!.complete({
        'version': 2,
        'completed': {'tn2_c01_t1': 1},
      });
      await Future<void>.value();
      expect(c.solved, isEmpty);
      expect(store.data['solved'], isEmpty);
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'all five mechanics, archive and album fit 320px large text ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 820);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = TurkishNostalgiaController(
          catalog: catalog,
          store: MemoryStore(),
          gateway: Gateway(),
        );
        await c.load();
        await drained(c);
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.dark
                ? OrtakSahaTheme.dark
                : OrtakSahaTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.8)),
              child: RepaintBoundary(key: key, child: child!),
            ),
            home: TurkishNostalgiaPage(controller: c),
          ),
        );
        await tester.pumpAndSettle();
        await capture(tester, key, 'archive-${brightness.name}');
        expect(tester.takeException(), isNull);
        for (final kind in ['season', 'squad', 'legend', 'route', 'timeline']) {
          final ch = catalog.chapters.firstWhere(
            (ch) => ch.tasks.any((t) => t.mechanic == kind),
          );
          c.open(ch.id);
          c.taskIndex = ch.tasks.indexWhere((t) => t.mechanic == kind);
          c.start();
          await tester.pumpAndSettle();
          await capture(tester, key, '$kind-${brightness.name}');
          expect(tester.takeException(), isNull);
          solve(c);
          await tester.runAsync(() async {
            await c.submit();
            await drained(c);
          });
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(find.text('Kaynak kaydı'), 300);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // Reset scroll by returning through the screen's own navigation.
          await tester.tap(find.byTooltip('Arşive dön'));
          await tester.pumpAndSettle();
        }
        c.archive(album: true);
        await tester.pumpAndSettle();
        await capture(tester, key, 'album-${brightness.name}');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        c.dispose();
      },
    );
  }
  testWidgets(
    'real controls support wrong answer, hint, success and second task',
    (tester) async {
      final c = TurkishNostalgiaController(
        catalog: catalog,
        store: MemoryStore(),
        gateway: Gateway(),
      );
      await c.load();
      await drained(c);
      c.open(catalog.chapters.first.id);
      c.start();
      await tester.pumpWidget(
        MaterialApp(home: TurkishNostalgiaPage(controller: c)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('1966–67'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Cevabı kontrol et'), 200);
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Cevabı kontrol et'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cevabı kontrol et'));
      await tester.pumpAndSettle();
      expect(c.solved, isEmpty);
      expect(c.message, contains('Henüz doğru değil'));
      await tester.scrollUntilVisible(find.text('Ücretsiz ipucu'), -200);
      await tester.tap(find.text('Ücretsiz ipucu'));
      await tester.pumpAndSettle();
      expect(c.hintOpen, true);
      await tester.scrollUntilVisible(find.text('1968–69'), -200);
      await tester.tap(find.text('1968–69'));
      await tester.scrollUntilVisible(find.text('Cevabı kontrol et'), 200);
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Cevabı kontrol et'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cevabı kontrol et'));
      await tester.pumpAndSettle();
      expect(c.phase, 'result');
      await tester.scrollUntilVisible(find.text('İkinci göreve geç'), 300);
      await tester.tap(find.text('İkinci göreve geç'));
      await tester.pumpAndSettle();
      expect(c.taskIndex, 1);
      expect(find.text('1. Yarı final'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    },
  );
}
