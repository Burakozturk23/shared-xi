import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/controllers/vs_bot_cinko_controller.dart';
import 'package:shared_xi/controllers/vs_bot_controller.dart';
import 'package:shared_xi/models/cinko_models.dart';
import 'package:shared_xi/models/player.dart';
import 'package:shared_xi/services/cinko_bot_session.dart';
import 'package:shared_xi/services/search_service.dart';

import 'support/cinko_fixture.dart';

VsBotCinkoController controller(
  CinkoBotSession session, {
  int size = 2,
  VsBotDifficulty difficulty = VsBotDifficulty.hard,
}) => VsBotCinkoController(
  gridSize: size,
  loadSession: (_) async => session,
  random: Random(2),
  difficulty: difficulty,
);

Future<void> start(VsBotCinkoController c) async {
  await c.initialize();
  expect(c.phase, CinkoMatchPhase.ready);
  c.begin();
}

void main() {
  setUp(SearchService.clearIndex);
  tearDown(SearchService.clearIndex);

  test(
    'Search ignores another mode\'s cached pool and handles ambiguity',
    () async {
      SearchService.buildIndex([
        Player.fromJson({'id': 99999, 'name': 'Thierry Other'}),
      ]);
      await Future<void>.delayed(Duration.zero);
      final c = controller(cinkoFixture(), size: 5);
      addTearDown(c.dispose);
      await start(c);
      c.updateSuggestions('Thierry');
      expect(c.suggestions.map((p) => p.name), ['Thierry Henry']);
      expect(c.submitPlayerName('Ronaldo'), isFalse);
      expect(
        c.suggestions.map((p) => p.name),
        containsAll(['Ronaldo Nazário', 'Cristiano Ronaldo']),
      );
      expect(c.canChoosePlayer, isTrue);
      expect(c.moves, isEmpty);
    },
  );
  test('Every board needs a distinct initial answer per cell', () {
    expect(cinkoFixture(size: 2).isPlayable(2), isTrue);
    expect(
      cinkoFixture(
        size: 2,
        answers: {
          0: {1},
          1: {1},
          2: {1},
          3: {1},
        },
      ).isPlayable(2),
      isFalse,
    );
    expect(cinkoFixture(size: 2).isPlayable(5), isFalse);
  });

  testWidgets('Loading is deferred and a ready board does not start itself', (
    tester,
  ) async {
    final pending = Completer<CinkoBotSession>();
    final c = VsBotCinkoController(
      gridSize: 2,
      loadSession: (_) => pending.future,
    );
    addTearDown(c.dispose);
    final future = c.initialize();
    expect(c.phase, CinkoMatchPhase.loading);
    c.begin();
    c.pass();
    pending.complete(cinkoFixture(size: 2));
    await future;
    await tester.pump(const Duration(seconds: 30));
    expect(c.phase, CinkoMatchPhase.ready);
    expect(c.moves, isEmpty);
    expect(c.submitPlayerName('Thierry Henry'), isFalse);
  });

  test(
    'A failed load can retry; late loads cannot replace a new session',
    () async {
      final old = Completer<CinkoBotSession>();
      var calls = 0;
      final c = VsBotCinkoController(
        gridSize: 2,
        loadSession: (_) async {
          calls++;
          if (calls == 1) throw StateError('offline');
          if (calls == 2) return old.future;
          return cinkoFixture(size: 2);
        },
      );
      await c.initialize();
      expect(c.phase, CinkoMatchPhase.error);
      final late = c.initialize();
      await c.initialize();
      final current = c.session;
      old.complete(cinkoFixture(size: 2));
      await late;
      expect(c.session, same(current));
      c.dispose();
    },
  );

  test('Disposal discards a pending load', () async {
    final pending = Completer<CinkoBotSession>();
    final c = VsBotCinkoController(
      gridSize: 2,
      loadSession: (_) => pending.future,
    );
    final future = c.initialize();
    c.dispose();
    pending.complete(cinkoFixture(size: 2));
    await future;
    expect(c.session, isNull);
  });

  test('L shapes work; diagonals and removing a bridge do not', () async {
    final session = cinkoFixture(
      size: 3,
      answers: {
        for (var i = 0; i < 9; i++) i: {i + 1, 1},
      },
    );
    final c = controller(session, size: 3);
    addTearDown(c.dispose);
    await start(c);
    expect(c.submitPlayerName('Thierry Henry'), isTrue);
    expect(c.toggleCell(0), isTrue);
    expect(c.toggleCell(4), isFalse);
    expect(c.toggleCell(1), isTrue);
    expect(c.toggleCell(4), isTrue);
    expect(c.toggleCell(1), isFalse);
    expect(c.selectedIndexes, [0, 1, 4]);
    c.cancelSelection();
    expect(c.state.selectedCount, 0);
    expect(c.state.usedPlayerIds, isEmpty);
    expect(c.canChoosePlayer, isTrue);
  });

  testWidgets('Mixed choices score +1/-1 and lock immediately', (tester) async {
    final c = controller(cinkoFixture(size: 2));
    addTearDown(c.dispose);
    await start(c);
    c.submitPlayerName('Thierry Henry');
    c.toggleCell(0);
    c.toggleCell(1);
    expect(c.confirmSelection(), isTrue);
    expect(c.confirmSelection(), isFalse);
    c.pass();
    expect(c.moves.length, 1);
    expect(c.userScore, 0);
    expect(c.state.usedPlayerIds, {1});
    expect(c.state.cells[0].owner, 1);
    expect(c.state.cells[1].status, CinkoCellStatus.wrongFlash);
    await tester.pump(
      const Duration(milliseconds: VsBotCinkoController.revealMs),
    );
    expect(c.state.cells[1].status, CinkoCellStatus.open);
    expect(c.turn, VsBotCinkoTurn.bot);
    c.pause();
  });

  test(
    'Resolved objects use canonical identities; invalid names retain the turn',
    () async {
      final session = cinkoFixture(size: 2);
      final c = controller(session);
      addTearDown(c.dispose);
      await start(c);
      expect(c.submitPlayerName('No such player'), isFalse);
      expect(c.canChoosePlayer, isTrue);
      expect(c.moves, isEmpty);
      expect(
        c.submitResolvedPlayer(
          Player.fromJson({'id': 1, 'name': 'Fake identity'}),
        ),
        isTrue,
      );
      expect(c.state.currentPlayer, same(session.players.first));
      c.cancelSelection();
      expect(
        c.submitResolvedPlayer(
          Player.fromJson({'id': 99999, 'name': 'Thierry Henry'}),
        ),
        isFalse,
      );
    },
  );

  testWidgets('Passing releases selections and triggers exactly one bot move', (
    tester,
  ) async {
    final c = controller(cinkoFixture(size: 2));
    addTearDown(c.dispose);
    await start(c);
    c.submitPlayerName('Thierry Henry');
    c.toggleCell(0);
    c.pass();
    c.pass();
    expect(c.state.selectedCount, 0);
    expect(c.state.usedPlayerIds, isEmpty);
    expect(c.userScore, 0);
    await tester.pump(const Duration(seconds: 2));
    expect(c.moves.length, 2);
    expect(c.moves.first.passed, isTrue);
    expect(c.moves.last.byUser, isFalse);
    c.pause();
  });

  testWidgets('Bot ranks connected cells, not scattered matches', (
    tester,
  ) async {
    final answers = {
      for (var i = 0; i < 9; i++) i: <int>{i + 1},
    };
    for (final i in [0, 2, 4, 6, 8]) {
      answers[i]!.add(10);
    }
    for (final i in [0, 1, 3]) {
      answers[i]!.add(11);
    }
    final c = controller(cinkoFixture(size: 3, answers: answers), size: 3);
    addTearDown(c.dispose);
    await start(c);
    c.pass();
    await tester.pump(const Duration(seconds: 2));
    expect(c.lastMove!.player!.id, 11);
    expect(c.lastMove!.correct.toSet(), {0, 1, 3});
    expect(c.botScore, 3);
    c.pause();
  });

  testWidgets('All difficulty caps keep selected bot cells connected', (
    tester,
  ) async {
    for (final difficulty in VsBotDifficulty.values) {
      final c = controller(
        cinkoFixture(
          size: 2,
          answers: {
            0: {1, 5},
            1: {2, 5},
            2: {3, 5},
            3: {4, 5},
          },
        ),
        difficulty: difficulty,
      );
      await start(c);
      c.pass();
      await tester.pump(const Duration(seconds: 2));
      expect(c.botScore, switch (difficulty) {
        VsBotDifficulty.easy => 1,
        VsBotDifficulty.medium => 3,
        VsBotDifficulty.hard => 4,
      });
      expect(c.lastMove!.wrong, isEmpty);
      c.dispose();
    }
  });

  testWidgets('Exhausted answers end a match with unpainted cells', (
    tester,
  ) async {
    final c = controller(
      cinkoFixture(
        size: 2,
        answers: {
          0: {1, 2},
          1: {1},
          2: {3},
          3: {4},
        },
      ),
    );
    addTearDown(c.dispose);
    await start(c);
    c.submitPlayerName('Thierry Henry');
    c.toggleCell(0);
    c.confirmSelection();
    await tester.pump(
      const Duration(milliseconds: VsBotCinkoController.revealMs),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(
      const Duration(milliseconds: VsBotCinkoController.revealMs),
    );
    expect(c.isCellPlayable(1), isFalse);
    expect(c.submitPlayerName('Thierry Henry'), isFalse);
    expect(c.canChoosePlayer, isTrue);
    c.pass();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(
      const Duration(milliseconds: VsBotCinkoController.revealMs),
    );
    expect(c.phase, CinkoMatchPhase.finished);
    expect(c.endReason, CinkoEndReason.noMoves);
    expect(c.state.paintedCount, 3);
  });

  testWidgets('Completing the board records its own finish reason', (
    tester,
  ) async {
    final c = controller(
      cinkoFixture(
        size: 2,
        answers: {
          0: {1},
          1: {1, 2},
          2: {1, 3},
          3: {1, 4},
        },
      ),
    );
    addTearDown(c.dispose);
    await start(c);
    c.submitPlayerName('Thierry Henry');
    for (final i in [0, 1, 3, 2]) {
      c.toggleCell(i);
    }
    c.confirmSelection();
    await tester.pump(
      const Duration(milliseconds: VsBotCinkoController.revealMs),
    );
    expect(c.phase, CinkoMatchPhase.finished);
    expect(c.endReason, CinkoEndReason.boardCompleted);
    expect(c.userScore, 4);
  });

  testWidgets(
    'Pause freezes both bot and reveal; restart clears pending work',
    (tester) async {
      final c = controller(cinkoFixture(size: 2));
      await start(c);
      c.pass();
      c.pause();
      await tester.pump(const Duration(seconds: 20));
      expect(c.moves.length, 1);
      c.resume();
      c.resume();
      await tester.pump(const Duration(seconds: 2));
      expect(c.moves.length, 2);
      c.pause();
      await tester.pump(const Duration(seconds: 20));
      expect(c.state.phase, CinkoPhase.revealing);
      c.resume();
      await tester.pump(
        const Duration(milliseconds: VsBotCinkoController.revealMs),
      );
      expect(c.turn, VsBotCinkoTurn.user);
      c.pass();
      await c.initialize();
      await tester.pump(const Duration(seconds: 20));
      expect(c.phase, CinkoMatchPhase.ready);
      expect(c.moves, isEmpty);
      expect(c.state.usedPlayerIds, isEmpty);
      c.begin();
      c.pass();
      c.dispose();
      await tester.pump(const Duration(seconds: 20));
      expect(tester.takeException(), isNull);
    },
  );
}
