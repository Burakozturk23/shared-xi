import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/grid_state.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import 'grid_controller.dart';

enum VsBotGridTurn { user, bot, gameOver }

class VsBotGridController extends ChangeNotifier {
  final GridController grid = GridController();
  final Random _random = Random();

  VsBotGridTurn turn = VsBotGridTurn.user;
  final List<int> owners = List.filled(9, 0);
  int userScore = 0;
  int botScore = 0;
  String? feedback;
  bool feedbackOk = true;

  Timer? _botTimer;
  Timer? _feedbackTimer;
  bool _disposed = false;

  bool get isLoading => grid.state.isLoading;
  GridPuzzleState get puzzle => grid.state;

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

  void selectCell(int index) {
    if (_disposed || turn != VsBotGridTurn.user) return;
    if (owners[index] != 0) return;
    grid.openCell(index);
    _safeNotify();
  }

  void cancelCell() {
    if (_disposed) return;
    grid.closeCell();
    _safeNotify();
  }

  bool submitUserGuess(int index, String answer) {
    if (_disposed || turn != VsBotGridTurn.user) return false;
    if (owners[index] != 0) return false;

    final player = grid.submitGuess(index, answer);
    if (player == null) {
      grid.closeCell();
      feedback = 'Yanlış veya uymuyor.';
      feedbackOk = false;
      _safeNotify();
      _scheduleFeedbackClear();
      _schedulePassToBot();
      return false;
    }

    grid.assignPlayer(index, player);
    owners[index] = 1;
    userScore++;
    grid.closeCell();
    feedback = 'Doğru! +1';
    feedbackOk = true;

    if (_boardFull()) {
      turn = VsBotGridTurn.gameOver;
      _safeNotify();
      _scheduleFeedbackClear();
      return true;
    }

    _safeNotify();
    _scheduleFeedbackClear();
    _schedulePassToBot();
    return true;
  }


  bool submitUserPlayer(int index, Player player) {
    if (_disposed || turn != VsBotGridTurn.user) return false;
    if (owners[index] != 0) return false;

    final resolved = grid.submitPlayer(index, player);
    if (resolved == null) {
      grid.closeCell();
      feedback = 'Yanlış veya uymuyor.';
      feedbackOk = false;
      _safeNotify();
      _scheduleFeedbackClear();
      _schedulePassToBot();
      return false;
    }

    grid.assignPlayer(index, resolved);
    owners[index] = 1;
    userScore++;
    grid.closeCell();
    feedback = 'Doğru! +1';
    feedbackOk = true;

    if (_boardFull()) {
      turn = VsBotGridTurn.gameOver;
      _safeNotify();
      _scheduleFeedbackClear();
      return true;
    }

    _safeNotify();
    _scheduleFeedbackClear();
    _schedulePassToBot();
    return true;
  }

  void _schedulePassToBot() {
    _botTimer?.cancel();
    _botTimer = Timer(const Duration(milliseconds: 250), _passToBot);
  }

  void _scheduleFeedbackClear() {
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      if (_disposed) return;
      feedback = null;
      _safeNotify();
    });
  }

  void _passToBot() {
    if (_disposed) return;
    if (turn == VsBotGridTurn.gameOver) return;

    turn = VsBotGridTurn.bot;
    _safeNotify();

    final empty = <int>[];
    for (var i = 0; i < 9; i++) {
      if (owners[i] == 0) empty.add(i);
    }
    if (empty.isEmpty) {
      turn = VsBotGridTurn.gameOver;
      _safeNotify();
      return;
    }

    _botTimer?.cancel();
    _botTimer = Timer(Duration(milliseconds: 900 + _random.nextInt(900)), () {
      if (!_disposed) _botMove(List<int>.from(empty));
    });
  }

  void _botMove(List<int> emptyIndexes) {
    if (_disposed || turn != VsBotGridTurn.bot) return;

    final shuffled = emptyIndexes..shuffle(_random);
    int? chosenIndex;
    Player? chosenPlayer;

    for (final index in shuffled) {
      if (owners[index] != 0) continue;
      final player = _findAnyMatch(index);
      if (player != null) {
        chosenIndex = index;
        chosenPlayer = player;
        break;
      }
    }

    if (chosenIndex == null || chosenPlayer == null) {
      _setFeedback('Bot pas geçti.', true);
      turn = VsBotGridTurn.user;
      _safeNotify();
      return;
    }

    grid.assignPlayer(chosenIndex, chosenPlayer);
    owners[chosenIndex] = 2;
    botScore++;
    _setFeedback('Bot doldurdu: ${chosenPlayer.name}', false);

    if (_boardFull()) {
      turn = VsBotGridTurn.gameOver;
    } else {
      turn = VsBotGridTurn.user;
    }
    _safeNotify();
  }

  Player? _findAnyMatch(int index) {
    final rows = puzzle.rowCriteria;
    final cols = puzzle.colCriteria;
    if (rows.length < 3 || cols.length < 3) return null;

    final row = rows[index ~/ 3];
    final col = cols[index % 3];
    final used = puzzle.usedPlayerIds;

    final candidates = Repository.instance.players
        .where((p) => !used.contains(p.id))
        .where((p) => row.matches(p) && col.matches(p))
        .toList();

    if (candidates.isEmpty) return null;
    return candidates[_random.nextInt(candidates.length)];
  }

  bool _boardFull() => owners.every((o) => o != 0);

  void _setFeedback(String msg, bool ok) {
    if (_disposed) return;
    feedback = msg;
    feedbackOk = ok;
    _safeNotify();
    _scheduleFeedbackClear();
  }
}