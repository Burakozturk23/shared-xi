import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/loto_models.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/loto_generator.dart';

class LotoState {
  final LotoBoard? board;
  final int queueIndex;
  /// Kullanıcı seçimleri: cellIndex → playerId (doğruluk henüz yok)
  final Map<int, int> placements;
  final int remainingSeconds;
  final bool isPlaying;
  final bool isFinished;
  final int? finalCorrect;
  final int? finalWrong;
  final int? finalScore;

  const LotoState({
    this.board,
    this.queueIndex = 0,
    this.placements = const {},
    this.remainingSeconds = 15,
    this.isPlaying = false,
    this.isFinished = false,
    this.finalCorrect,
    this.finalWrong,
    this.finalScore,
  });

  Player? get currentPlayer {
    final b = board;
    if (b == null || queueIndex < 0 || queueIndex >= b.playerQueue.length) {
      return null;
    }
    return Repository.instance.playerById(b.playerQueue[queueIndex]);
  }

  int get totalPlayers => board?.playerQueue.length ?? 16;

  LotoState copyWith({
    LotoBoard? board,
    int? queueIndex,
    Map<int, int>? placements,
    int? remainingSeconds,
    bool? isPlaying,
    bool? isFinished,
    int? finalCorrect,
    int? finalWrong,
    int? finalScore,
  }) {
    return LotoState(
      board: board ?? this.board,
      queueIndex: queueIndex ?? this.queueIndex,
      placements: placements ?? this.placements,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isPlaying: isPlaying ?? this.isPlaying,
      isFinished: isFinished ?? this.isFinished,
      finalCorrect: finalCorrect ?? this.finalCorrect,
      finalWrong: finalWrong ?? this.finalWrong,
      finalScore: finalScore ?? this.finalScore,
    );
  }
}

class LotoController extends ChangeNotifier {
  LotoState _state = const LotoState();
  LotoState get state => _state;
  Timer? _timer;
  String? _lastLeague;
  LotoDifficulty _lastDiff = LotoDifficulty.medium;

  void start({
    String? leagueFilter,
    LotoDifficulty difficulty = LotoDifficulty.medium,
  }) {
    _timer?.cancel();
    _lastLeague = leagueFilter;
    _lastDiff = difficulty;
    final board = LotoGenerator.generate(
      leagueFilter: leagueFilter,
      difficulty: difficulty,
    );
    _state = LotoState(
      board: board,
      remainingSeconds: difficulty.secondsPerPlayer,
      isPlaying: true,
    );
    notifyListeners();
    _armTimer();
  }

  void restartSame() =>
      start(leagueFilter: _lastLeague, difficulty: _lastDiff);

  void _armTimer() {
    _timer?.cancel();
    final b = _state.board;
    if (b == null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_state.isPlaying || _state.isFinished) return;
      final left = _state.remainingSeconds - 1;
      if (left <= 0) {
        _advance(); // yerleştirmeden geç = sonunda yanlış
        return;
      }
      _state = _state.copyWith(remainingSeconds: left);
      notifyListeners();
    });
  }

  void pass() {
    if (!_state.isPlaying || _state.isFinished) return;
    _advance();
  }

  /// Seçim = sadece yerleştirme. Doğru/yanlış en sonda.
  void tapCell(int cellIndex) {
    if (!_state.isPlaying || _state.isFinished) return;
    final board = _state.board;
    final player = _state.currentPlayer;
    if (board == null || player == null) return;
    if (_state.placements.containsKey(cellIndex)) return; // dolu

    final map = Map<int, int>.from(_state.placements);
    map[cellIndex] = player.id;
    _state = _state.copyWith(placements: map);
    notifyListeners();
    _advance();
  }

  void _advance() {
    final board = _state.board;
    if (board == null) return;
    final next = _state.queueIndex + 1;
    if (next >= board.playerQueue.length) {
      _timer?.cancel();
      _finish();
      return;
    }
    _state = _state.copyWith(
      queueIndex: next,
      remainingSeconds: board.difficulty.secondsPerPlayer,
    );
    notifyListeners();
  }

  void _finish() {
    final board = _state.board;
    if (board == null) return;
    var correct = 0;
    var wrong = 0;

    // Yerleştirilenler
    for (final e in _state.placements.entries) {
      final cellIndex = e.key;
      final playerId = e.value;
      final player = Repository.instance.playerById(playerId);
      final cell = board.cells[cellIndex];
      if (player != null && LotoGenerator.matches(player, cell)) {
        correct++;
      } else {
        wrong++;
      }
    }
    // Yerleştirilmeyen oyuncular (pas / süre)
    final placedPlayers = _state.placements.values.toSet();
    for (final pid in board.playerQueue) {
      if (!placedPlayers.contains(pid)) wrong++;
    }

    _state = _state.copyWith(
      isFinished: true,
      isPlaying: false,
      finalCorrect: correct,
      finalWrong: wrong,
      finalScore: correct * 10,
    );
    notifyListeners();
  }

  void disposeController() => _timer?.cancel();
}
