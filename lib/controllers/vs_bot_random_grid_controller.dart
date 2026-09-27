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
  VsBotRandomGridController({RandomGridController? grid}) : grid = grid ?? RandomGridController() {
    this.grid.addListener(_safeNotify);
  }

  final RandomGridController grid;
  final Random _random = Random();

  VsBotRandomTurn turn = VsBotRandomTurn.user;
  final List<int> owners = List.filled(9, 0);
  int userScore = 0;
  int botScore = 0;
  int lineWinner = 0;
  String? feedback;
  bool feedbackOk = true;

  Timer? _botTimer;
  Timer? _feedbackTimer;
  bool _disposed = false;
  bool busy = false;

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
    grid.removeListener(_safeNotify);
    grid.dispose();
    super.dispose();
  }

  
  List<Player> get suggestions => grid.suggestions;

  void updateSuggestions(String query) {
    if (_disposed || busy || isLoading || turn != VsBotRandomTurn.user) {
      grid.clearSuggestions();
      _safeNotify();
      return;
    }
    grid.updateSuggestions(query);
    _safeNotify();
  }

  void clearSuggestions() {
    grid.clearSuggestions();
    _safeNotify();
  }

  bool userSubmitPendingPlayerObj(Player player) {
    if (_disposed || busy || isLoading || turn != VsBotRandomTurn.user) return false;
    // pending pair doğrula isim üzerinden
    final ok = userSubmitPendingPlayer(player.name);
    clearSuggestions();
    return ok;
  }

  bool userSubmitCellPlayer(int index, Player player) {
    if (_disposed || busy || isLoading || turn != VsBotRandomTurn.user) return false;
    if (index < 0 || index >= 9 || owners[index] != 0) return false;
    final resolved = grid.submitGuess(index, player.name);
    if (resolved == null) {
      _setFeedback('Yanlış.', false);
      clearSuggestions();
      _safeNotify();
      _schedulePassToBot();
      return false;
    }
    grid.assignPlayer(index, resolved);
    owners[index] = 1;
    userScore++;
    if (_hasLine(1)) {
      lineWinner = 1;
      turn = VsBotRandomTurn.gameOver;
      feedback = 'Üçlü tamam! Kazandın 🏆';
      feedbackOk = true;
      _safeNotify();
      return true;
    }
    clearSuggestions();
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

  Future<void> userGeneratePair() async {
    if (_disposed || busy || isLoading || turn != VsBotRandomTurn.user) return;
    busy = true;
    _safeNotify();
    try {
      await grid.generatePair();
      if (!_disposed && !puzzle.hasPendingPair) _setFeedback('Uygun çift bulunamadı. Tekrar dene.', false);
    } catch (_) {
      if (!_disposed) _setFeedback('Çift yüklenemedi. Tekrar dene.', false);
    } finally {
      busy = false;
      _safeNotify();
    }
  }

  bool userSubmitPendingPlayer(String answer) {
    if (_disposed || busy || isLoading || turn != VsBotRandomTurn.user) return false;
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

  Future<void> userPlaceAtAnchor(int anchorIndex,
      {required Club rowClub, required Club colClub}) async {
    if (_disposed || busy || isLoading || turn != VsBotRandomTurn.user) return;
    if (anchorIndex < 0 || anchorIndex >= 9 || owners[anchorIndex] != 0) return;
    busy = true;
    _safeNotify();
    bool placed = false;
    try {
      placed = await grid.placeAtAnchor(anchorIndex, rowClub: rowClub, colClub: colClub);
    } catch (_) {
      if (!_disposed) _setFeedback('Yerleştirme tamamlanamadı. Tekrar dene.', false);
    } finally {
      busy = false;
      _safeNotify();
    }
    if (_disposed || !placed) return;
    owners[anchorIndex] = 1;
    userScore++;
    if (_hasLine(1)) {
      lineWinner = 1;
      turn = VsBotRandomTurn.gameOver;
      feedback = 'Üçlü tamam! Kazandın 🏆';
      feedbackOk = true;
      _safeNotify();
      return;
    }
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
    if (_disposed || busy || isLoading || turn != VsBotRandomTurn.user) return false;
    if (index < 0 || index >= 9 || owners[index] != 0) return false;

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
    if (_hasLine(1)) {
      lineWinner = 1;
      turn = VsBotRandomTurn.gameOver;
      feedback = 'Üçlü tamam! Kazandın 🏆';
      feedbackOk = true;
      _safeNotify();
      return true;
    }
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
    if (_disposed || busy || turn != VsBotRandomTurn.user) return;
    grid.cancelPending();
    _safeNotify();
  }

  void _schedulePassToBot() {
    // Lock input immediately; the delay is only for the visual handover.
    turn = VsBotRandomTurn.bot;
    _safeNotify();
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

  Future<void> _botMove() async {
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
        if (_hasLine(2)) {
          lineWinner = 2;
          turn = VsBotRandomTurn.gameOver;
          _setFeedback('Bot üçlü yaptı: ${player.name}', false);
          _safeNotify();
          return;
        }
        _setFeedback('Bot doldurdu: ${player.name}', false);
        _finishBotTurn();
        return;
      }
    }

    if (puzzle.roundsUsed < 3) {
      try {
        await grid.generatePair();
      } catch (_) {
        if (!_disposed) { turn = VsBotRandomTurn.user; _safeNotify(); }
        return;
      }
      if (_disposed) return;
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
            bool placed;
            try {
              placed = await grid.placeAtAnchor(
              anchor,
              rowClub: asRow ? a : b,
              colClub: asRow ? b : a,
            );
            } catch (_) {
              if (!_disposed) { turn = VsBotRandomTurn.user; _safeNotify(); }
              return;
            }
            if (_disposed) return;
            if (!placed) { turn = VsBotRandomTurn.user; _safeNotify(); return; }
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
    if (_hasLine(2)) {
      lineWinner = 2;
      turn = VsBotRandomTurn.gameOver;
      _safeNotify();
      return;
    }
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


  static const _lines = <List<int>>[
    [0, 1, 2], [3, 4, 5], [6, 7, 8],
    [0, 3, 6], [1, 4, 7], [2, 5, 8],
    [0, 4, 8], [2, 4, 6],
  ];

  bool _hasLine(int owner) {
    for (final line in _lines) {
      if (line.every((i) => owners[i] == owner)) return true;
    }
    return false;
  }

  bool _wouldCompleteLine(int index, int owner) {
    for (final line in _lines) {
      if (!line.contains(index)) continue;
      var count = 0;
      for (final i in line) {
        if (i == index) continue;
        if (owners[i] == owner) {
          count++;
        } else if (owners[i] != 0) {
          count = -99;
          break;
        }
      }
      if (count == 2) return true;
    }
    return false;
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
