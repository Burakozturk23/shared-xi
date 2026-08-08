import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/club.dart';
import '../models/player.dart';
import '../models/random_grid_state.dart';
import '../repositories/repository.dart';
import 'random_grid_controller.dart';

enum VsBotRandomTurn { user, bot, gameOver }

class VsBotRandomGridController extends ChangeNotifier {
  final RandomGridController grid = RandomGridController();
  final Random _random = Random();

  VsBotRandomTurn turn = VsBotRandomTurn.user;
  final List<int> owners = List.filled(9, 0);
  int userScore = 0;
  int botScore = 0;
  String? feedback;
  bool feedbackOk = true;

  Timer? _botTimer;
  Timer? _feedbackTimer;
  bool _disposed = false;

  bool get isLoading => grid.state.isLoading;
  RandomGridState get puzzle => grid.state;

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

  void userGeneratePair() {
    if (_disposed || turn != VsBotRandomTurn.user) return;
    grid.generatePair();
    _safeNotify();
  }

  bool userSubmitPendingPlayer(String answer) {
    if (_disposed || turn != VsBotRandomTurn.user) return false;
    final player = grid.submitPendingPlayerGuess(answer);
    if (player == null) {
      _setFeedback('Oyuncu uymuyor.', false);
      grid.cancelPending();
      _safeNotify();
      _schedulePassToBot();
      return false;
    }
    grid.confirmPendingPlayer(player);
    _safeNotify();
    return true;
  }

  void userPlaceAtAnchor(int anchorIndex,
      {required Club rowClub, required Club colClub}) {
    if (_disposed || turn != VsBotRandomTurn.user) return;
    if (owners[anchorIndex] != 0) return;
    grid.placeAtAnchor(anchorIndex, rowClub: rowClub, colClub: colClub);
    owners[anchorIndex] = 1;
    userScore++;
    _setFeedback('Yerleştirildi! +1', true);
    _safeNotify();
    if (_boardFull()) {
      turn = VsBotRandomTurn.gameOver;
      _safeNotify();
      return;
    }
    _schedulePassToBot();
  }

  bool userSubmitCell(int index, String answer) {
    if (_disposed || turn != VsBotRandomTurn.user) return false;
    if (owners[index] != 0) return false;

    final player = grid.submitGuess(index, answer);
    if (player == null) {
      _setFeedback('Yanlış.', false);
      _safeNotify();
      _schedulePassToBot();
      return false;
    }
    grid.assignPlayer(index, player);
    owners[index] = 1;
    userScore++;
    _setFeedback('Doğru! +1', true);
    _safeNotify();
    if (_boardFull()) {
      turn = VsBotRandomTurn.gameOver;
      _safeNotify();
      return true;
    }
    _schedulePassToBot();
    return true;
  }

  void userCancelPending() {
    if (_disposed) return;
    grid.cancelPending();
    _safeNotify();
  }

  void _schedulePassToBot() {
    _botTimer?.cancel();
    _botTimer = Timer(const Duration(milliseconds: 250), _passToBot);
  }

  void _passToBot() {
    if (_disposed || turn == VsBotRandomTurn.gameOver) return;
    turn = VsBotRandomTurn.bot;
    _safeNotify();

    _botTimer?.cancel();
    _botTimer = Timer(
      Duration(milliseconds: 900 + _random.nextInt(900)),
      _botMove,
    );
  }

  void _botMove() {
    if (_disposed || turn != VsBotRandomTurn.bot) return;

    for (var i = 0; i < 9; i++) {
      if (owners[i] != 0) continue;
      final row = puzzle.rowClubs[i ~/ 3];
      final col = puzzle.colClubs[i % 3];
      if (row == null || col == null) continue;

      final player = _anyMatch(row.id, col.id);
      if (player != null) {
        grid.assignPlayer(i, player);
        owners[i] = 2;
        botScore++;
        _setFeedback('Bot doldurdu: ${player.name}', false);
        _finishBotTurn();
        return;
      }
    }

    if (puzzle.roundsUsed < 3) {
      grid.generatePair();
      final a = puzzle.pendingClubA;
      final b = puzzle.pendingClubB;
      if (a != null && b != null) {
        final player = _anyMatch(a.id, b.id);
        if (player != null) {
          grid.confirmPendingPlayer(player);
          final anchors = puzzle.availableAnchors;
          if (anchors.isNotEmpty) {
            final anchor = anchors[_random.nextInt(anchors.length)];
            final asRow = _random.nextBool();
            grid.placeAtAnchor(
              anchor,
              rowClub: asRow ? a : b,
              colClub: asRow ? b : a,
            );
            owners[anchor] = 2;
            botScore++;
            _setFeedback('Bot çapa: ${player.name}', false);
            _finishBotTurn();
            return;
          }
        }
        grid.cancelPending();
      }
    }

    _setFeedback('Bot pas.', true);
    turn = VsBotRandomTurn.user;
    _safeNotify();
  }

  void _finishBotTurn() {
    turn = _boardFull() ? VsBotRandomTurn.gameOver : VsBotRandomTurn.user;
    _safeNotify();
  }

  Player? _anyMatch(int clubA, int clubB) {
    final used = puzzle.usedPlayerIds;
    final list = Repository.instance.players
        .where((p) => !used.contains(p.id))
        .where((p) => p.clubs.contains(clubA) && p.clubs.contains(clubB))
        .toList();
    if (list.isEmpty) return null;
    return list[_random.nextInt(list.length)];
  }

  bool _boardFull() => owners.every((o) => o != 0) || puzzle.isFinished;

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
