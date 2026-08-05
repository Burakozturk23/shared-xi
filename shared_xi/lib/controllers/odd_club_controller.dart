import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/chain_pool.dart';
import '../models/club.dart';
import '../models/odd_club_state.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/high_score_service.dart';

class OddClubController extends ChangeNotifier {
  static const int _questionSeconds = 5;

  final bool timed;
  final String _highScoreKey;

  OddClubController({required this.timed})
      : _highScoreKey =
            timed ? 'odd_club_timed_best' : 'odd_club_endless_best';

  final Random _random = Random();

  OddClubState _state = const OddClubState();
  OddClubState get state => _state;

  Timer? _clockTimer;
  Timer? _nextTimer;

  late final List<Player> _pool;
  late final List<Club> _clubPool;

  Future<void> initialize() async {
    final players = Repository.instance.players;

    _clubPool = chainClubPool
        .map((id) => Repository.instance.clubById(id))
        .whereType<Club>()
        .toList();

    final poolClubIds = _clubPool.map((c) => c.id).toSet();

    _pool = players
        .where((p) => p.clubs.toSet().intersection(poolClubIds).length >= 3)
        .toList();

    final bestStreak = await HighScoreService.getHighScore(key: _highScoreKey);

    _state = _state.copyWith(isLoading: false, bestStreak: bestStreak);

    _nextQuestion();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _nextTimer?.cancel();
    super.dispose();
  }

  void _nextQuestion() {
    if (_pool.isEmpty) return;

    final poolClubIds = _clubPool.map((c) => c.id).toSet();
    final player = _pool[_random.nextInt(_pool.length)];

    final realClubIds = player.clubs.toSet().intersection(poolClubIds).toList()
      ..shuffle(_random);
    final realClubs =
        realClubIds.take(3).map((id) => Repository.instance.clubById(id)!).toList();

    final fakeCandidates =
        _clubPool.where((c) => !player.clubs.contains(c.id)).toList()
          ..shuffle(_random);
    final fakeClub = fakeCandidates.first;

    final options = [...realClubs, fakeClub]..shuffle(_random);
    final fakeIndex = options.indexOf(fakeClub);

    _state = _state.copyWith(
      player: player,
      options: options,
      fakeIndex: fakeIndex,
      clearSelected: true,
      answered: false,
      secondsLeft: _questionSeconds,
    );

    notifyListeners();

    if (timed) _startClock();
  }

  void _startClock() {
    _clockTimer?.cancel();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state.answered) return;

      if (_state.secondsLeft <= 1) {
        _clockTimer?.cancel();
        _finish();
        return;
      }

      _state = _state.copyWith(secondsLeft: _state.secondsLeft - 1);
      notifyListeners();
    });
  }

  Future<void> _finish() async {
    final best =
        _state.streak > _state.bestStreak ? _state.streak : _state.bestStreak;

    await HighScoreService.saveHighScore(_state.streak, key: _highScoreKey);

    _state = _state.copyWith(isGameOver: true, bestStreak: best, answered: true);
    notifyListeners();
  }

  void selectOption(int index) {
    if (_state.answered) return;

    _clockTimer?.cancel();

    final correct = index == _state.fakeIndex;

    _state = _state.copyWith(selectedIndex: index, answered: true);
    notifyListeners();

    if (!correct) {
      _finish();
      return;
    }

    _state = _state.copyWith(streak: _state.streak + 1);
    notifyListeners();

    _nextTimer?.cancel();
    _nextTimer = Timer(const Duration(milliseconds: 900), _nextQuestion);
  }

  void restart() {
    _state = OddClubState(bestStreak: _state.bestStreak, isLoading: false);
    _nextQuestion();
  }
}