import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/higher_lower_state.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/high_score_service.dart';

class HigherLowerController extends ChangeNotifier {
  final HigherLowerCriterion criterion;
  final Random _random = Random();

  HigherLowerController({required this.criterion});

  HigherLowerState _state = const HigherLowerState();
  HigherLowerState get state => _state;

  Timer? _nextTimer;

  late final List<Player> _pool;

  String get _highScoreKey => criterion == HigherLowerCriterion.marketValue
      ? 'higher_lower_value_best'
      : 'higher_lower_goals_best';

  Future<void> initialize() async {
    _pool = Repository.instance.players.where((p) {
      final v = criterion == HigherLowerCriterion.marketValue
          ? p.peakMarketValue
          : p.careerGoals.toDouble();
      return v > 0;
    }).toList();

    final bestStreak = await HighScoreService.getHighScore(key: _highScoreKey);

    final first = _pool[_random.nextInt(_pool.length)];
    final next = _pickNext(exclude: first);

    _state = HigherLowerState(
      isLoading: false,
      criterion: criterion,
      currentPlayer: first,
      nextPlayer: next,
      bestStreak: bestStreak,
    );

    notifyListeners();
  }

  @override
  void dispose() {
    _nextTimer?.cancel();
    super.dispose();
  }

  Player _pickNext({required Player exclude}) {
    Player candidate;
    do {
      candidate = _pool[_random.nextInt(_pool.length)];
    } while (candidate.id == exclude.id);
    return candidate;
  }

  void guess(bool guessedHigher) {
    if (_state.answered) return;

    final current = _state.currentPlayer!;
    final next = _state.nextPlayer!;

    final currentValue = _state.valueOf(current);
    final nextValue = _state.valueOf(next);

    final actuallyHigher = nextValue >= currentValue;
    final correct = guessedHigher == actuallyHigher;

    _state = _state.copyWith(
      answered: true,
      wasCorrect: correct,
      selectedGuessIsHigher: guessedHigher ? 1 : 0,
    );
    notifyListeners();

    if (!correct) {
      _finish();
      return;
    }

    final newStreak = _state.streak + 1;
    _state = _state.copyWith(streak: newStreak);

    _nextTimer?.cancel();
    _nextTimer = Timer(const Duration(milliseconds: 1200), () {
      final newNext = _pickNext(exclude: next);
      _state = _state.copyWith(
        currentPlayer: next,
        nextPlayer: newNext,
        clearSelected: true,
        answered: false,
        clearWasCorrect: true,
      );
      notifyListeners();
    });
  }

  Future<void> _finish() async {
    final best =
        _state.streak > _state.bestStreak ? _state.streak : _state.bestStreak;

    await HighScoreService.saveHighScore(_state.streak, key: _highScoreKey);

    _nextTimer?.cancel();
    _nextTimer = Timer(const Duration(milliseconds: 1400), () {
      _state = _state.copyWith(isGameOver: true, bestStreak: best);
      notifyListeners();
    });
  }

  void restart() {
    initialize();
  }
}