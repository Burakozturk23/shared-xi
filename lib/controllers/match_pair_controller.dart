import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/match_pair_models.dart';
import '../services/match_pair_generator.dart';

class MatchPairState {
  final MatchBoard? board;
  final Set<int> matchedPairIds;
  final List<int> flippedIndices;
  final int moves;
  final int seconds;
  final bool isComplete;
  final bool isLoading;
  final String? error;
  final bool lockInput;

  const MatchPairState({
    this.board,
    this.matchedPairIds = const {},
    this.flippedIndices = const [],
    this.moves = 0,
    this.seconds = 0,
    this.isComplete = false,
    this.isLoading = false,
    this.error,
    this.lockInput = false,
  });

  bool isFaceUp(int index) {
    final board = this.board;
    if (board == null) return false;
    if (matchedPairIds.contains(board.cards[index].pairId)) return true;
    return flippedIndices.contains(index);
  }

  MatchPairState copyWith({
    MatchBoard? board,
    Set<int>? matchedPairIds,
    List<int>? flippedIndices,
    int? moves,
    int? seconds,
    bool? isComplete,
    bool? isLoading,
    String? error,
    bool? lockInput,
  }) {
    return MatchPairState(
      board: board ?? this.board,
      matchedPairIds: matchedPairIds ?? this.matchedPairIds,
      flippedIndices: flippedIndices ?? this.flippedIndices,
      moves: moves ?? this.moves,
      seconds: seconds ?? this.seconds,
      isComplete: isComplete ?? this.isComplete,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      lockInput: lockInput ?? this.lockInput,
    );
  }
}

class MatchPairController extends ChangeNotifier {
  MatchPairState _state = const MatchPairState();
  MatchPairState get state => _state;

  Timer? _timer;
  Timer? _flipBackTimer;
  MatchDifficulty _diff = MatchDifficulty.medium;

  /// UI'yı bloklamadan üret (microtask).
  Future<void> startNew(MatchDifficulty difficulty) async {
    _timer?.cancel();
    _flipBackTimer?.cancel();
    _diff = difficulty;
    _state = const MatchPairState(isLoading: true);
    notifyListeners();

    try {
      // Bir frame nefes al
      await Future<void>.delayed(Duration.zero);
      var board = await MatchPairGenerator.generateRuntime(
        difficulty: difficulty,
      );

      if (board != null) {
        debugPrint(
          '[HybridV3] MatchPair controller runtime board active '
          'pairs=${board.pairCount} difficulty=${difficulty.name}',
        );
      } else {
        board = MatchPairGenerator.generate(difficulty: difficulty);
      }

      _state = MatchPairState(board: board, isLoading: false);
      notifyListeners();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_state.isComplete) return;
        _state = _state.copyWith(seconds: _state.seconds + 1);
        notifyListeners();
      });
    } catch (e) {
      _state = MatchPairState(isLoading: false, error: e.toString());
      notifyListeners();
    }
  }

  void restart() => startNew(_diff);

  void tapCard(int index) {
    final board = _state.board;
    if (board == null || _state.lockInput || _state.isComplete) return;
    if (index < 0 || index >= board.cards.length) return;

    final card = board.cards[index];
    if (_state.matchedPairIds.contains(card.pairId)) return;
    if (_state.flippedIndices.contains(index)) return;
    if (_state.flippedIndices.length >= 2) return;

    final flipped = [..._state.flippedIndices, index];
    _state = _state.copyWith(flippedIndices: flipped);
    notifyListeners();

    if (flipped.length < 2) return;

    final a = board.cards[flipped[0]];
    final b = board.cards[flipped[1]];
    final moves = _state.moves + 1;

    if (a.pairId == b.pairId) {
      final matched = {..._state.matchedPairIds, a.pairId};
      final done = matched.length >= board.pairCount;
      _state = _state.copyWith(
        matchedPairIds: matched,
        flippedIndices: const [],
        moves: moves,
        isComplete: done,
      );
      notifyListeners();
      if (done) _timer?.cancel();
    } else {
      _state = _state.copyWith(moves: moves, lockInput: true);
      notifyListeners();
      _flipBackTimer?.cancel();
      _flipBackTimer = Timer(const Duration(milliseconds: 650), () {
        _state = _state.copyWith(
          flippedIndices: const [],
          lockInput: false,
        );
        notifyListeners();
      });
    }
  }

  void disposeController() {
    _timer?.cancel();
    _flipBackTimer?.cancel();
  }
}
