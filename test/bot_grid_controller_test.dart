import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/controllers/grid_controller.dart';
import 'package:shared_xi/controllers/random_grid_controller.dart';
import 'package:shared_xi/controllers/reverse_grid_controller.dart';
import 'package:shared_xi/controllers/vs_bot_grid_controller.dart';
import 'package:shared_xi/controllers/vs_bot_random_grid_controller.dart';
import 'package:shared_xi/controllers/vs_bot_reverse_grid_controller.dart';
import 'package:shared_xi/models/grid_state.dart';
import 'package:shared_xi/models/player.dart';
import 'package:shared_xi/models/random_grid_state.dart';
import 'package:shared_xi/models/reverse_grid_state.dart';

final _player = Player.fromJson({
  'id': 14,
  'name': 'Thierry Henry',
  'position': 'Attack',
  'countries': ['France'],
  'clubIds': [11, 131],
});

mixin _DeferredLoad on ChangeNotifier {
  final ready = Completer<void>();
  bool loaded = false;
  bool closed = false;

  void initialize() {
    unawaited(ready.future.then((_) {
      if (closed) return;
      loaded = true;
      notifyListeners();
    }));
  }

  @override
  void dispose() {
    closed = true;
    super.dispose();
  }
}

class _Grid extends GridController with _DeferredLoad {
  int attempts = 0;
  Player? answer;

  @override
  GridPuzzleState get state => super.state.copyWith(isLoading: !loaded);
  @override
  Player? submitGuess(int index, String text) {
    attempts++;
    return answer;
  }
  @override
  Player? submitPlayer(int index, Player player) {
    attempts++;
    return answer;
  }
  @override
  void assignPlayer(int index, Player player) {}
}

class _RandomGrid extends RandomGridController with _DeferredLoad {
  int attempts = 0;
  Player? answer;

  @override
  RandomGridState get state => super.state.copyWith(isLoading: !loaded);
  @override
  Player? submitGuess(int index, String text) {
    attempts++;
    return answer;
  }
  @override
  void assignPlayer(int index, Player player) {}
}

class _ReverseGrid extends ReverseGridController with _DeferredLoad {
  int attempts = 0;
  bool accept = false;
  final correct = List<bool>.filled(3, false);

  @override
  ReverseGridState get state => super.state.copyWith(
    isLoading: !loaded,
    rowCorrect: correct,
  );
  @override
  void submitRowGuess(int row, String text) {
    attempts++;
    correct[row] = accept;
    notifyListeners();
  }
}

void main() {
  test('All bot grids publish delayed puzzle readiness', () async {
    final classic = _Grid();
    final random = _RandomGrid();
    final reverse = _ReverseGrid();
    final classicBot = VsBotGridController(grid: classic);
    final randomBot = VsBotRandomGridController(grid: random);
    final reverseBot = VsBotReverseGridController(grid: reverse);

    for (final (inner, bot, initialize, loading) in <
      (_DeferredLoad, ChangeNotifier, VoidCallback, bool Function())
    >[
      (classic, classicBot, classicBot.initialize, () => classicBot.isLoading),
      (random, randomBot, randomBot.initialize, () => randomBot.isLoading),
      (reverse, reverseBot, reverseBot.initialize, () => reverseBot.isLoading),
    ]) {
      final states = <bool>[];
      bot.addListener(() => states.add(loading()));
      initialize();
      expect(loading(), isTrue);
      inner.ready.complete();
      await Future<void>.delayed(Duration.zero);
      expect(loading(), isFalse);
      expect(states.last, isFalse,
          reason: 'The page must hear about asynchronous board completion.');
      bot.dispose();
      expect(inner.closed, isTrue);
    }
  });

  testWidgets('Classic grid locks correct and wrong turns immediately', (tester) async {
    for (final correct in [true, false]) {
      for (final selectPlayer in [true, false]) {
        final inner = _Grid()..answer = correct ? _player : null;
        final bot = VsBotGridController(grid: inner);
        bot.initialize();
        inner.ready.complete();
        await tester.pump();

        bool submit(int index) => selectPlayer
            ? bot.submitUserPlayer(index, _player)
            : bot.submitUserGuess(index, 'Henry');
        expect(submit(0), correct);
        expect(bot.turn, VsBotGridTurn.bot);
        expect(submit(1), isFalse);
        expect(inner.attempts, 1);
        expect(bot.userScore, correct ? 1 : 0);
        expect(bot.owners[1], 0);
        bot.dispose();
      }
    }
  });

  testWidgets('Random grid locks correct and wrong turns immediately', (tester) async {
    for (final correct in [true, false]) {
      final inner = _RandomGrid()..answer = correct ? _player : null;
      final bot = VsBotRandomGridController(grid: inner);
      bot.initialize();
      inner.ready.complete();
      await tester.pump();

      expect(bot.userSubmitCell(0, 'Henry'), correct);
      expect(bot.turn, VsBotRandomTurn.bot);
      expect(bot.userSubmitCell(1, 'Henry'), isFalse);
      expect(inner.attempts, 1);
      expect(bot.userScore, correct ? 1 : 0);
      expect(bot.owners[1], 0);
      bot.dispose();
    }
  });

  testWidgets('Reverse grid locks correct and wrong turns immediately', (tester) async {
    for (final correct in [true, false]) {
      final inner = _ReverseGrid()..accept = correct;
      final bot = VsBotReverseGridController(grid: inner);
      bot.initialize();
      inner.ready.complete();
      await tester.pump();

      expect(bot.submitUserGuess(0, 'Arsenal'), correct);
      expect(bot.turn, VsBotReverseTurn.bot);
      expect(bot.submitUserGuess(1, 'Arsenal'), isFalse);
      expect(inner.attempts, 1);
      expect(bot.userScore, correct ? 1 : 0);
      expect(bot.owners[1], 0);
      bot.dispose();
    }
  });

  testWidgets('Disposing during the handover cancels the pending bot move', (tester) async {
    final inner = _Grid()..answer = _player;
    final bot = VsBotGridController(grid: inner);
    bot.initialize();
    inner.ready.complete();
    await tester.pump();
    bot.submitUserGuess(0, 'Henry');
    bot.dispose();
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
    expect(inner.closed, isTrue);
  });
}
