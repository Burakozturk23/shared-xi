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

  /// final DEĞİL — restart initialize'ı tekrar çağırabilsin diye.
  late List<Player> _pool;
  bool _poolReady = false;

  String get _highScoreKey => criterion == HigherLowerCriterion.marketValue
      ? 'higher_lower_value_best'
      : 'higher_lower_goals_best';

  /// Tanınır oyuncu eşiği.
  /// Piyasa: zirve değer ≥ 20M € (~1500 isim)
  /// Gol: kariyer ≥ 80 gol (~4500 isim)
  static const double _minPeakValue = 20000000;
  static const int _minCareerGoals = 80;

  Future<void> initialize() async {
    if (!_poolReady) {
      _pool = Repository.instance.players.where((p) {
        if (criterion == HigherLowerCriterion.marketValue) {
          return p.peakMarketValue >= _minPeakValue;
        }
        return p.careerGoals >= _minCareerGoals;
      }).toList();

      // Aşırı daralırsa eşiği gevşet
      if (_pool.length < 80) {
        _pool = Repository.instance.players.where((p) {
          if (criterion == HigherLowerCriterion.marketValue) {
            return p.peakMarketValue >= 10000000;
          }
          return p.careerGoals >= 50;
        }).toList();
      }

      // Hâlâ boşsa en azından değeri/golü olanlar
      if (_pool.isEmpty) {
        _pool = Repository.instance.players.where((p) {
          final v = criterion == HigherLowerCriterion.marketValue
              ? p.peakMarketValue
              : p.careerGoals.toDouble();
          return v > 0;
        }).toList();
      }

      _poolReady = true;
    }

    final bestStreak = await HighScoreService.getHighScore(key: _highScoreKey);
    _startNewGame(bestStreak: bestStreak);
  }

  void _startNewGame({required int bestStreak}) {
    _nextTimer?.cancel();

    final first = _pool[_random.nextInt(_pool.length)];
    final next = _pickNext(exclude: first);

    _state = HigherLowerState(
      isLoading: false,
      isGameOver: false,
      criterion: criterion,
      currentPlayer: first,
      nextPlayer: next,
      streak: 0,
      bestStreak: bestStreak,
      answered: false,
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
    } while (candidate.id == exclude.id && _pool.length > 1);
    return candidate;
  }

  void guess(bool guessedHigher) {
    if (_state.answered || _state.isGameOver) return;

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

  /// Tekrar dene — pool'u yeniden atamaz, sadece yeni maç başlatır.
  void restart() {
    _nextTimer?.cancel();
    _startNewGame(bestStreak: _state.bestStreak);
  }
}