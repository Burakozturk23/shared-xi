import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/app/bot_game_catalog.dart';
import 'package:shared_xi/controllers/classic_grid_bot_controller.dart';
import 'package:shared_xi/controllers/random_grid_controller.dart';
import 'package:shared_xi/controllers/reverse_grid_controller.dart';
import 'package:shared_xi/controllers/vs_bot_random_grid_controller.dart';
import 'package:shared_xi/controllers/vs_bot_reverse_grid_controller.dart';
import 'package:shared_xi/models/club.dart';
import 'package:shared_xi/models/player.dart';
import 'package:shared_xi/models/grid_criterion.dart';
import 'package:shared_xi/models/random_grid_state.dart';
import 'package:shared_xi/models/reverse_grid_state.dart';
import 'package:shared_xi/screens/classic_grid_page.dart';
import 'package:shared_xi/screens/vs_bot_random_grid_page.dart';
import 'package:shared_xi/screens/vs_bot_reverse_grid_page.dart';
import 'package:shared_xi/services/classic_grid_session.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';

final a = Club(id: 11, name: 'Arsenal', league: '', country: 'England');
final b = Club(id: 131, name: 'Barcelona', league: '', country: 'Spain');
final players = List.generate(9, (i) => Player.fromJson({
  'id': i + 1, 'name': 'Test Futbolcu ${i + 1}', 'position': 'Attack',
  'countries': ['Turkey'], 'clubIds': [11, 131],
}));

class ReadyReverse extends ReverseGridController {
  @override
  void initialize() {}
  @override
  ReverseGridState get state => ReverseGridState(
    isLoading: false, cellPlayers: players,
    rowCriteria: List.generate(3, (_) => GridCriterion.club(a)),
    colCriteria: List.generate(3, (_) => GridCriterion.club(b)),
  );
}

class ReadyRandom extends RandomGridController {
  @override
  void initialize() {}
  @override
  RandomGridState get state => const RandomGridState(isLoading: false);
}

class DelayedPlacement extends ReadyRandom {
  final completed = Completer<bool>();
  int calls = 0;
  @override
  RandomGridState get state => RandomGridState(isLoading: false,
    pendingClubA: a, pendingClubB: b, pendingPlayer: players.first);
  @override
  Future<bool> placeAtAnchor(int index, {required Club rowClub, required Club colClub}) {
    calls++;
    return completed.future;
  }
}

void main() {
  test('all three bot Grid routes use the current theme', () {
    expect(BotGameCatalog.classicGrid.entry.page, isA<ClassicGridPage>());
    expect(BotGameCatalog.classicGrid.entry.requiresRepository, isFalse);
    for (final mode in BotGameCatalog.gridVariants) {
      expect(mode.entry.modern, isTrue);
    }
  });

  test('random score waits for committed placement and duplicate taps are ignored', () async {
    for (final accepted in [true, false]) {
      final inner = DelayedPlacement();
      final bot = VsBotRandomGridController(grid: inner);
      final pending = bot.userPlaceAtAnchor(2, rowClub: a, colClub: b);
      await bot.userPlaceAtAnchor(2, rowClub: a, colClub: b);
      expect(inner.calls, 1);
      expect(bot.userScore, 0);
      expect(bot.busy, isTrue);
      inner.completed.complete(accepted);
      await pending;
      expect(bot.userScore, accepted ? 1 : 0);
      expect(bot.owners[2], accepted ? 1 : 0);
      expect(bot.busy, isFalse);
      bot.dispose();
    }
  });

  test('reverse ignores invalid axis before accessing owners', () {
    final bot = VsBotReverseGridController(grid: ReadyReverse());
    expect(bot.submitUserGuess(-1, 'Arsenal'), isFalse);
    expect(bot.submitUserGuess(6, 'Arsenal'), isFalse);
    bot.dispose();
  });

  for (final dark in [false, true]) {
    for (final mode in ['classic', 'reverse', 'random']) {
      testWidgets('$mode board fits 320px with keyboard and large text, dark=$dark', (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        final classic = ClassicGridBotController(loadSession: () async => ClassicGridSession(
          rows: List.generate(3, (_) => GridCriterion.club(a)),
          cols: List.generate(3, (_) => GridCriterion.club(b)),
          players: players,
          validPlayerIdsByCell: {for (var i = 0; i < 9; i++) i: {players[i].id}},
        ));
        final Widget page = switch (mode) {
          'classic' => ClassicGridPage(controllerFactory: () => classic),
          'reverse' => VsBotReverseGridPage(controllerFactory: () => VsBotReverseGridController(grid: ReadyReverse())),
          _ => VsBotRandomGridPage(controllerFactory: () => VsBotRandomGridController(grid: ReadyRandom())),
        };
        if (mode != 'classic') classic.dispose();
        await tester.pumpWidget(MaterialApp(
          theme: dark ? OrtakSahaTheme.dark : OrtakSahaTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.8),
              viewInsets: const EdgeInsets.only(bottom: 240)), child: child!),
          home: RepaintBoundary(key: key, child: page),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (mode == 'classic') {
          expect(classic.phase, ClassicGridPhase.ready);
          classic.begin();
          classic.openCell(0);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        if (const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) {
          await tester.runAsync(() async {
            final image = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
            final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('.dart_tool/grid_qa/$mode-$dark.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
