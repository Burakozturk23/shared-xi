import 'package:flutter/foundation.dart';

import '../models/pyramid_models.dart';
import '../services/pyramid_generator.dart';

class PyramidState {
  final PyramidBoard? board;
  final Map<int, PyramidEntity> filled;
  final int? activeSlotId;
  final int lives;
  final int score;
  final bool isComplete;
  final bool isFailed;
  final bool isLoading;
  final String? feedback;
  final bool feedbackOk;
  final List<PyramidEntity> hints;
  final String? error;

  const PyramidState({
    this.board,
    this.filled = const {},
    this.activeSlotId,
    this.lives = 5,
    this.score = 0,
    this.isComplete = false,
    this.isFailed = false,
    this.isLoading = false,
    this.feedback,
    this.feedbackOk = false,
    this.hints = const [],
    this.error,
  });

  PyramidState copyWith({
    PyramidBoard? board,
    Map<int, PyramidEntity>? filled,
    int? activeSlotId,
    int? lives,
    int? score,
    bool? isComplete,
    bool? isFailed,
    bool? isLoading,
    String? feedback,
    bool? feedbackOk,
    List<PyramidEntity>? hints,
    String? error,
    bool clearActive = false,
    bool clearFeedback = false,
    bool clearError = false,
  }) {
    return PyramidState(
      board: board ?? this.board,
      filled: filled ?? this.filled,
      activeSlotId: clearActive ? null : (activeSlotId ?? this.activeSlotId),
      lives: lives ?? this.lives,
      score: score ?? this.score,
      isComplete: isComplete ?? this.isComplete,
      isFailed: isFailed ?? this.isFailed,
      isLoading: isLoading ?? this.isLoading,
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      feedbackOk: feedbackOk ?? this.feedbackOk,
      hints: hints ?? this.hints,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PyramidController extends ChangeNotifier {
  PyramidState _state = const PyramidState(isLoading: true);
  PyramidState get state => _state;

  PyramidDifficulty _difficulty = PyramidDifficulty.normal;
  PyramidDifficulty get difficulty => _difficulty;

  void setDifficulty(PyramidDifficulty d) {
    _difficulty = d;
    startNew();
  }

  void startNew() {
    try {
      _state = const PyramidState(isLoading: true);
      notifyListeners();

      final board = PyramidGenerator.generate(difficulty: _difficulty);
      _state = PyramidState(
        board: board,
        filled: Map<int, PyramidEntity>.from(board.initialFilled),
        lives: board.lives,
        score: 0,
        isLoading: false,
      );
      notifyListeners();
    } catch (e, st) {
      debugPrint('Pyramid start error: $e\n$st');
      _state = PyramidState(
        isLoading: false,
        error: 'Tahta üretilemedi: $e',
      );
      notifyListeners();
    }
  }

  void selectSlot(int slotId) {
    final board = _state.board;
    if (board == null || _state.isComplete || _state.isFailed) return;
    if (_state.filled.containsKey(slotId)) return;

    final slot = board.slots.firstWhere((s) => s.id == slotId);
    final need = <int>[
      if (slot.leftSupportId != null) slot.leftSupportId!,
      if (slot.rightSupportId != null) slot.rightSupportId!,
    ];
    if (need.any((id) => !_state.filled.containsKey(id))) {
      _state = _state.copyWith(
        feedback: 'Önce alttaki destekleri doldur.',
        feedbackOk: false,
        clearActive: true,
        hints: const [],
      );
      notifyListeners();
      return;
    }

    final supports = <PyramidEntity>[];
    for (final id in need) {
      final e = _state.filled[id];
      if (e != null) supports.add(e);
    }

    _state = _state.copyWith(
      activeSlotId: slotId,
      hints: supports,
      clearFeedback: true,
    );
    notifyListeners();
  }

  void submitAnswer(String input) {
    final board = _state.board;
    final slotId = _state.activeSlotId;
    if (board == null || slotId == null) return;
    if (_state.isComplete || _state.isFailed) return;

    PyramidEntity? match;
    for (final e in board.answerPool) {
      if (!e.matchesQuery(input)) continue;
      if (_state.filled.values.any((x) => x.id == e.id)) continue;
      match = e;
      break;
    }

    if (match == null) {
      _loseLife('Geçersiz veya kullanılmış cevap.');
      return;
    }

    final slot = board.slots.firstWhere((s) => s.id == slotId);
    final supports = <PyramidEntity>[];
    if (slot.leftSupportId != null) {
      final e = _state.filled[slot.leftSupportId!];
      if (e != null) supports.add(e);
    }
    if (slot.rightSupportId != null) {
      final e = _state.filled[slot.rightSupportId!];
      if (e != null) supports.add(e);
    }

    PyramidEntity? alsoPeak;
    if (slot.level == 1) {
      alsoPeak = _state.filled[board.peakSlotId];
    }

    final ok = PyramidLinkRules.fitsSupports(
      candidate: match,
      supports: supports,
      alsoLinkTo: alsoPeak,
      difficulty: board.difficulty,
    );

    if (!ok) {
      _loseLife('Alt desteklerle bağ yok.');
      return;
    }

    final map = Map<int, PyramidEntity>.from(_state.filled);
    map[slotId] = match;

    final emptyTotal = board.slots.length - board.initialFilled.length;
    final filledEmpty = map.length - board.initialFilled.length;
    final score = ((filledEmpty / emptyTotal) * board.maxScore)
        .round()
        .clamp(0, board.maxScore);
    final complete = filledEmpty >= emptyTotal;

    _state = _state.copyWith(
      filled: map,
      score: score,
      isComplete: complete,
      feedback: complete ? 'Tamam! Skor: $score' : 'Doğru!',
      feedbackOk: true,
      clearActive: true,
      hints: const [],
    );
    notifyListeners();
  }

  void _loseLife(String msg) {
    final lives = _state.lives - 1;
    _state = _state.copyWith(
      lives: lives < 0 ? 0 : lives,
      isFailed: lives <= 0,
      feedback: lives <= 0 ? 'Can bitti. $msg' : msg,
      feedbackOk: false,
      clearActive: true,
      hints: const [],
    );
    notifyListeners();
  }
}
