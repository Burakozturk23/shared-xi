import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/passaparola_seed.dart';
import '../models/passaparola_question.dart';

class PassaparolaState {
  final List<PassaparolaQuestion> questions;
  final Map<String, LetterStatus> statuses;
  final int currentIndex;
  final int remainingSeconds;
  final int correctCount;
  final int wrongCount;
  final bool isRunning;
  final bool isFinished;
  final String? feedback;
  final bool feedbackSuccess;

  const PassaparolaState({
    this.questions = const [],
    this.statuses = const {},
    this.currentIndex = 0,
    this.remainingSeconds = 180,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.isRunning = false,
    this.isFinished = false,
    this.feedback,
    this.feedbackSuccess = false,
  });

  PassaparolaQuestion? get currentQuestion {
    if (currentIndex < 0 || currentIndex >= questions.length) return null;
    return questions[currentIndex];
  }

  String? get currentLetter => currentQuestion?.letter;

  PassaparolaState copyWith({
    List<PassaparolaQuestion>? questions,
    Map<String, LetterStatus>? statuses,
    int? currentIndex,
    int? remainingSeconds,
    int? correctCount,
    int? wrongCount,
    bool? isRunning,
    bool? isFinished,
    String? feedback,
    bool? feedbackSuccess,
    bool clearFeedback = false,
  }) {
    return PassaparolaState(
      questions: questions ?? this.questions,
      statuses: statuses ?? this.statuses,
      currentIndex: currentIndex ?? this.currentIndex,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      isRunning: isRunning ?? this.isRunning,
      isFinished: isFinished ?? this.isFinished,
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      feedbackSuccess: feedbackSuccess ?? this.feedbackSuccess,
    );
  }
}

class PassaparolaController extends ChangeNotifier {
  static const int defaultDurationSeconds = 180;

  PassaparolaState _state = const PassaparolaState();
  PassaparolaState get state => _state;

  Timer? _timer;
  Timer? _feedbackTimer;

  void startNewRound({int durationSeconds = defaultDurationSeconds}) {
    _timer?.cancel();
    final questions = PassaparolaSeed.pickRound();
    final statuses = <String, LetterStatus>{
      for (final q in questions) q.letter: LetterStatus.pending,
    };
    if (questions.isNotEmpty) {
      statuses[questions.first.letter] = LetterStatus.current;
    }
    _state = PassaparolaState(
      questions: questions,
      statuses: statuses,
      currentIndex: 0,
      remainingSeconds: durationSeconds,
      isRunning: true,
      isFinished: false,
    );
    notifyListeners();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_state.isRunning || _state.isFinished) return;
      final left = _state.remainingSeconds - 1;
      if (left <= 0) {
        _state = _state.copyWith(
          remainingSeconds: 0,
          isRunning: false,
          isFinished: true,
        );
        _timer?.cancel();
        notifyListeners();
        return;
      }
      _state = _state.copyWith(remainingSeconds: left);
      notifyListeners();
    });
  }

  void submitAnswer(String input) {
    if (!_state.isRunning || _state.isFinished) return;
    final q = _state.currentQuestion;
    if (q == null) return;

    if (q.matchesAnswer(input)) {
      _markCurrent(LetterStatus.correct);
      _state = _state.copyWith(
        correctCount: _state.correctCount + 1,
        feedback: 'Doğru!',
        feedbackSuccess: true,
      );
      notifyListeners();
      _flashFeedback();
      _advance();
    } else {
      _markCurrent(LetterStatus.wrong);
      _state = _state.copyWith(
        wrongCount: _state.wrongCount + 1,
        feedback: 'Yanlış',
        feedbackSuccess: false,
      );
      notifyListeners();
      _flashFeedback();
      _advance();
    }
  }

  void pass() {
    if (!_state.isRunning || _state.isFinished) return;
    final q = _state.currentQuestion;
    if (q == null) return;
    _markCurrent(LetterStatus.passed);
    _state = _state.copyWith(
      feedback: 'Pas',
      feedbackSuccess: false,
    );
    notifyListeners();
    _flashFeedback();
    _advance();
  }

  void _markCurrent(LetterStatus status) {
    final q = _state.currentQuestion;
    if (q == null) return;
    final map = Map<String, LetterStatus>.from(_state.statuses);
    map[q.letter] = status;
    _state = _state.copyWith(statuses: map);
  }

  void _advance() {
    final qs = _state.questions;
    if (qs.isEmpty) return;

    // Önce sıradaki pending/passed harfi bul
    final n = qs.length;
    for (var step = 1; step <= n; step++) {
      final idx = (_state.currentIndex + step) % n;
      final letter = qs[idx].letter;
      final st = _state.statuses[letter];
      if (st == LetterStatus.pending || st == LetterStatus.passed) {
        final map = Map<String, LetterStatus>.from(_state.statuses);
        // eski current pending değilse dokunma
        map[letter] = LetterStatus.current;
        _state = _state.copyWith(statuses: map, currentIndex: idx);
        notifyListeners();
        return;
      }
    }

    // Hepsi doğru/yanlış → bitti
    _state = _state.copyWith(isRunning: false, isFinished: true);
    _timer?.cancel();
    notifyListeners();
  }

  void _flashFeedback() {
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 900), () {
      _state = _state.copyWith(clearFeedback: true);
      notifyListeners();
    });
  }

  void disposeController() {
    _timer?.cancel();
    _feedbackTimer?.cancel();
  }
}
