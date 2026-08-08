import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/reverse_grid_state.dart';
import 'reverse_grid_controller.dart';

enum VsBotReverseTurn { user, bot, gameOver }

class VsBotReverseGridController extends ChangeNotifier {
  final ReverseGridController grid = ReverseGridController();
  final Random _random = Random();

  VsBotReverseTurn turn = VsBotReverseTurn.user;
  final List<int> owners = List.filled(6, 0);
  int userScore = 0;
  int botScore = 0;
  String? feedback;
  bool feedbackOk = true;

  Timer? _botTimer;
  Timer? _feedbackTimer;
  bool _disposed = false;

  bool get isLoading => grid.state.isLoading;
  ReverseGridState get puzzle => grid.state;

  void initialize() {
    grid.initialize();
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _botTimer?.cancel();
    _feedbackTimer?.cancel();
    grid.dispose();
    super.dispose();
  }

  bool isAxisOpen(int axis) => owners[axis] == 0;

  bool submitUserGuess(int axis, String guess) {
    if (_disposed || turn != VsBotReverseTurn.user) return false;
    if (owners[axis] != 0) return false;

    final text = guess.trim();
    if (text.isEmpty) return false;

    bool ok = false;
    if (axis < 3) {
      grid.submitRowGuess(axis, text);
      ok = grid.state.rowCorrect[axis];
    } else {
      grid.submitColGuess(axis - 3, text);
      ok = grid.state.colCorrect[axis - 3];
    }

    if (ok) {
      owners[axis] = 1;
      userScore++;
      _setFeedback('Doğru! +1', true);
      _safeNotify();
      if (_allTaken()) {
        turn = VsBotReverseTurn.gameOver;
        _safeNotify();
        return true;
      }
      _schedulePassToBot();
      return true;
    }

    _setFeedback('Yanlış.', false);
    _safeNotify();
    _schedulePassToBot();
    return false;
  }

  void _schedulePassToBot() {
    _botTimer?.cancel();
    _botTimer = Timer(const Duration(milliseconds: 250), _passToBot);
  }

  void _passToBot() {
    if (_disposed || turn == VsBotReverseTurn.gameOver) return;
    turn = VsBotReverseTurn.bot;
    _safeNotify();

    _botTimer?.cancel();
    _botTimer = Timer(
      Duration(milliseconds: 800 + _random.nextInt(1000)),
      _botMove,
    );
  }

  void _botMove() {
    if (_disposed || turn != VsBotReverseTurn.bot) return;

    final open = <int>[];
    for (var i = 0; i < 6; i++) {
      if (owners[i] == 0) open.add(i);
    }
    if (open.isEmpty) {
      turn = VsBotReverseTurn.gameOver;
      _safeNotify();
      return;
    }

    final rows = puzzle.rowCriteria;
    final cols = puzzle.colCriteria;
    if (rows.length < 3 || cols.length < 3) {
      turn = VsBotReverseTurn.user;
      _safeNotify();
      return;
    }

    final axis = open[_random.nextInt(open.length)];
    final label = axis < 3 ? rows[axis].label : cols[axis - 3].label;

    if (axis < 3) {
      grid.submitRowGuess(axis, label);
    } else {
      grid.submitColGuess(axis - 3, label);
    }

    owners[axis] = 2;
    botScore++;
    _setFeedback('Bot: $label', false);

    turn = _allTaken() ? VsBotReverseTurn.gameOver : VsBotReverseTurn.user;
    _safeNotify();
  }

  bool _allTaken() => owners.every((o) => o != 0);

  void _setFeedback(String msg, bool ok) {
    if (_disposed) return;
    _feedbackTimer?.cancel();
    feedback = msg;
    feedbackOk = ok;
    _safeNotify();
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      if (_disposed) return;
      feedback = null;
      _safeNotify();
    });
  }
}
