import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/controllers/vs_bot_controller.dart';
import 'package:shared_xi/controllers/vs_bot_random_five_controller.dart';
import 'package:shared_xi/models/player.dart';
import 'package:shared_xi/services/random_five_session.dart';
import 'package:shared_xi/services/search_service.dart';

import 'support/random_five_fixture.dart';

VsBotRandomFiveController controller({
  VsBotDifficulty difficulty = VsBotDifficulty.hard,
}) => VsBotRandomFiveController(
  loadSession: () async => fiveFixture(),
  random: Random(4),
  difficulty: difficulty,
);

Future<void> start(WidgetTester tester, VsBotRandomFiveController c) async {
  await tester.runAsync(c.initialize);
  expect(c.phase, FiveMatchPhase.ready);
  c.begin();
}

void main() {
  setUp(SearchService.clearIndex);
  tearDown(SearchService.clearIndex);

  test('Seeded boards have five distinct connected clubs and ten answers', () {
    final session = fiveFixture();
    for (var seed = 0; seed < 30; seed++) {
      final random = Random(seed);
      var previous = <int>{};
      for (var round = 0; round < 5; round++) {
        final board = session.createRound(random: random, previous: previous);
        final clubIds = board.clubs.map((c) => c.id).toSet();
        expect(clubIds.length, 5);
        expect(board.matches.length, greaterThanOrEqualTo(10));
        expect(board.matches.values.any((ids) => ids.length >= 3), isTrue);
        if (previous.isNotEmpty)
          expect(clubIds.difference(previous), isNotEmpty);
        for (final entry in board.matches.entries) {
          expect(
            entry.value,
            session.clubIdsByPlayer[entry.key]!.intersection(clubIds),
          );
        }
        // Any eight prior answers still leave two different current answers.
        final used = board.matches.keys.take(8).toSet();
        expect(
          board.matches.keys.where((id) => !used.contains(id)).length,
          greaterThanOrEqualTo(2),
        );
        previous = clubIds;
      }
    }
  });

  test(
    'Sparse data fails explicitly instead of producing an unusable board',
    () {
      final source = fiveFixture();
      final sparse = RandomFiveSession(
        clubs: source.clubs.take(4).toList(),
        players: source.players,
        clubIdsByPlayer: source.clubIdsByPlayer,
      );
      expect(() => sparse.createRound(random: Random(1)), throwsStateError);
    },
  );

  test(
    'Failed initialization retries and stale or disposed loads cannot win',
    () async {
      final pending = Completer<RandomFiveSession>();
      var calls = 0;
      final c = VsBotRandomFiveController(
        loadSession: () async {
          calls++;
          if (calls == 1) throw StateError('offline');
          if (calls == 2) return pending.future;
          return fiveFixture();
        },
      );
      await c.initialize();
      expect(c.phase, FiveMatchPhase.error);
      final old = c.initialize();
      await c.initialize();
      final current = c.session;
      pending.complete(fiveFixture());
      await old;
      expect(c.phase, FiveMatchPhase.ready);
      expect(c.session, same(current));
      expect(c.pass(), isFalse);
      c.dispose();
      final delayed = Completer<RandomFiveSession>();
      final disposed = VsBotRandomFiveController(
        loadSession: () => delayed.future,
      );
      final future = disposed.initialize();
      disposed.dispose();
      delayed.complete(fiveFixture());
      await future;
      expect(disposed.session, isNull);
    },
  );

  testWidgets('Invalid, ambiguous and forged identities preserve the turn', (
    tester,
  ) async {
    final c = controller();
    addTearDown(c.dispose);
    await start(tester, c);
    expect(c.submitGuess('Unknown player'), isFalse);
    expect(c.submitGuess('Ronaldo'), isFalse);
    expect(c.suggestions.map((p) => p.id), containsAll([2, 3]));
    expect(
      c.submitPlayer(
        Player.fromJson({
          'id': 9000,
          'name': 'Fake',
          'clubs': c.clubs.map((c) => c.id).toList(),
        }),
      ),
      isFalse,
    );
    expect(c.submitGuess('No Matching Club'), isFalse);
    expect(c.canAnswer, isTrue);
    expect(c.userScore, 0);
    expect(c.usedPlayerIds, isEmpty);
    expect(
      c.submitPlayer(
        Player.fromJson({'id': 1, 'name': 'Fake Henry', 'clubs': []}),
      ),
      isTrue,
    );
    expect(c.userMove!.player!.name, 'Thierry Henry');
    expect(c.userMove!.score, 5);
    expect(c.userScore, 5);
  });

  testWidgets(
    'Scoped suggestions ignore another mode and accept accented names',
    (tester) async {
      SearchService.buildIndex([
        Player.fromJson({'id': 9999, 'name': 'Thierry Other'}),
      ]);
      await tester.pump();
      final c = controller();
      addTearDown(c.dispose);
      await start(tester, c);
      c.updateSuggestions('Thierry');
      expect(c.suggestions.map((p) => p.id), [1]);
      expect(c.submitGuess('Ronaldo Nazario'), isTrue);
      expect(c.userMove!.player!.id, 3);
    },
  );

  testWidgets(
    'User turn locks before listeners, bot shares board and waits for next',
    (tester) async {
      final c = controller();
      addTearDown(c.dispose);
      await start(tester, c);
      final board = c.board;
      var reentryAttempted = false;
      c.addListener(() {
        if (c.userMove != null && !reentryAttempted) {
          reentryAttempted = true;
          expect(c.submitGuess('Cristiano Ronaldo'), isFalse);
          expect(c.pass(), isFalse);
        }
      });
      c.submitGuess('Thierry Henry');
      expect(c.submitGuess('Cristiano Ronaldo'), isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(c.phase, FiveMatchPhase.roundResult);
      expect(c.board, same(board));
      expect(c.history.length, 1);
      expect(c.userScore, 5);
      expect(c.botScore, 5);
      expect(c.botMove!.player!.id, isNot(1));
      await tester.pump(const Duration(minutes: 1));
      expect(c.roundNumber, 1);
      c.nextRound();
      c.nextRound();
      expect(c.roundNumber, 2);
      expect(c.submitGuess('Thierry Henry'), isFalse);
      expect(c.submitPlayer(c.history.first.bot.player!), isFalse);
      expect(c.canAnswer, isTrue);
      expect(c.userScore, 5);
    },
  );

  for (final difficulty in VsBotDifficulty.values) {
    testWidgets(
      'Bot $difficulty scores real memberships within its preference',
      (tester) async {
        final c = controller(difficulty: difficulty);
        addTearDown(c.dispose);
        await start(tester, c);
        final cap = switch (difficulty) {
          VsBotDifficulty.easy => 2,
          VsBotDifficulty.medium => 3,
          VsBotDifficulty.hard => 5,
        };
        final scores = c.board!.matches.values.map((v) => v.length).toList();
        final preferred = scores.where((s) => s <= cap);
        final expected = preferred.isEmpty
            ? scores.reduce(min)
            : preferred.reduce(max);
        c.pass();
        await tester.pump(const Duration(seconds: 2));
        expect(c.botMove!.score, expected);
        expect(
          c.botMove!.score,
          c.board!.matches[c.botMove!.player!.id]!.length,
        );
      },
    );
  }

  testWidgets(
    'Five pairs finish once; pass, totals and restart are consistent',
    (tester) async {
      final c = controller();
      addTearDown(c.dispose);
      await start(tester, c);
      var expected = 0;
      for (var round = 1; round <= 5; round++) {
        expect(c.roundNumber, round);
        if (round.isOdd) {
          expect(c.pass(), isTrue);
        } else {
          final id = c.board!.matches.keys.firstWhere(
            (id) => !c.usedPlayerIds.contains(id),
          );
          expected += c.board!.matchedClubs(id).length;
          expect(c.submitPlayer(c.session!.playersById[id]!), isTrue);
        }
        await tester.pump(const Duration(seconds: 2));
        expect(c.history.length, round);
        expect(c.userScore, expected);
        expect(c.userScore, inInclusiveRange(0, 25));
        expect(c.botScore, inInclusiveRange(0, 25));
        c.nextRound();
      }
      expect(c.phase, FiveMatchPhase.finished);
      expect(c.history.where((h) => h.user.passed).length, 3);
      expect(c.usedPlayerIds.length, 7);
      expect(c.submitGuess('Thierry Henry'), isFalse);
      c.nextRound();
      expect(c.roundNumber, 5);
      await tester.runAsync(c.initialize);
      expect(c.phase, FiveMatchPhase.ready);
      expect(c.history, isEmpty);
      expect(c.usedPlayerIds, isEmpty);
      expect(c.userScore, 0);
      expect(c.botScore, 0);
    },
  );

  testWidgets(
    'Pause freezes the bot; restart and disposal cancel pending turns',
    (tester) async {
      final c = controller();
      await start(tester, c);
      c.pass();
      c.pause();
      await tester.pump(const Duration(seconds: 10));
      expect(c.history, isEmpty);
      c.resume();
      await tester.pump(const Duration(seconds: 2));
      expect(c.history.length, 1);
      c.nextRound();
      c.pass();
      await tester.runAsync(c.initialize);
      await tester.pump(const Duration(seconds: 10));
      expect(c.phase, FiveMatchPhase.ready);
      expect(c.history, isEmpty);
      c.begin();
      c.pass();
      c.dispose();
      await tester.pump(const Duration(seconds: 10));
      expect(c.history, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
