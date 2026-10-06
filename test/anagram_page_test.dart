import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/app/game_catalog.dart';
import 'package:shared_xi/controllers/anagram_controller.dart';
import 'package:shared_xi/models/anagram.dart';
import 'package:shared_xi/screens/anagram_page.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'anagram_test.dart' show MemoryAnagramStore, testAnagramCatalog;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (family, path) in [
      ('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'),
      ('Inter', 'assets/fonts/Inter-Body-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) { await (FontLoader(family)..addFont(rootBundle.load(path))).load(); }
  });
  test('Anagram is beside the other word games, with no account or database gate', () {
    final words = GameCatalog.games.where((g) => g.category == 'Harf & Kelime').toList();
    expect(words.map((g) => g.title), ['Futbol Lingo', 'Passaparola', 'Anagram']);
    expect(words.last.page, isA<AnagramPage>());
    expect(words.last.requiresRepository, isFalse);
    expect(words.last.requiresAuth, isFalse);
    expect(words.last.modern, isTrue);
  });
  for (final light in [false, true]) {
    for (final large in [false, true]) {
      testWidgets('play, hints and results fit ${light ? 'light' : 'dark'} ${large ? 'large' : 'normal'}', (tester) async {
        tester.view.physicalSize = Size(large ? 320 : 390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final catalog = testAnagramCatalog(), store = MemoryAnagramStore();
        // Fixed Guler round includes accent handling and repeated letter checks in UI.
        final deck = [861410, ...catalog.players.where((p) => p.id != 861410).take(7).map((p) => p.id)];
        store.value = jsonEncode(AnagramSession(deck: deck, rounds: [
          AnagramRound(playerId: deck.first, letters: 'REGUL'),
        ]).toJson());
        final game = AnagramController(catalog: catalog, store: store, random: Random(4));
        addTearDown(game.dispose);
        final key = GlobalKey();
        await tester.pumpWidget(MaterialApp(theme: light ? OrtakSahaTheme.light : OrtakSahaTheme.dark,
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(large ? 1.8 : 1)), child: child!),
          home: RepaintBoundary(key: key, child: AnagramPage(controller: game))));
        await tester.pumpAndSettle();
        Future<void> capture(String state) async {
          if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
          await tester.runAsync(() async {
            final image = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio: 1);
            final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('.dart_tool/anagram_qa/$state-${light ? 'light' : 'dark'}-${large ? 'large' : 'normal'}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List()); image.dispose();
          });
        }
        Future<void> scrollTo(Key key) async {
          await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(find.byKey(key), 150, scrollable: find.byType(Scrollable).first);
          await tester.pumpAndSettle();
        }
        await capture('start');
        await tester.tap(find.byKey(const ValueKey('anagram-tile-0')));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(find.byKey(const ValueKey('anagram-answer'))).controller!.text, 'R');
        await scrollTo(const ValueKey('anagram-bio'));
        await tester.tap(find.byKey(const ValueKey('anagram-bio')));
        await tester.pumpAndSettle();
        expect(game.session!.current.bioHint, isTrue);
        await scrollTo(const ValueKey('anagram-answer'));
        await tester.enterText(find.byKey(const ValueKey('anagram-answer')), 'güler');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(game.session!.score(catalog), 85);
        await scrollTo(const ValueKey('anagram-result'));
        await capture('result');
        expect(find.text('Arda Güler'), findsOneWidget);
        await scrollTo(const ValueKey('anagram-next'));
        await tester.tap(find.byKey(const ValueKey('anagram-next')));
        await tester.pumpAndSettle();
        expect(game.session!.rounds.length, 2);
        await tester.tap(find.byTooltip('Nasıl oynanır?'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Hadi çözelim'), 250, scrollable: find.byType(Scrollable).last);
        await tester.tap(find.text('Hadi çözelim')); await tester.pumpAndSettle();
        await scrollTo(const ValueKey('anagram-reveal'));
        await tester.tap(find.byKey(const ValueKey('anagram-reveal'))); await tester.pumpAndSettle();
        await tester.tap(find.text('Vazgeç')); await tester.pumpAndSettle();
        expect(game.session!.current.revealed, isFalse);
        for (var i = 1; i < 8; i++) { await game.reveal(); await game.next(); }
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
        await tester.pumpAndSettle();
        await capture('summary');
        expect(find.text('Seri tamamlandı!'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
