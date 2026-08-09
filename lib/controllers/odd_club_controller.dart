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

  late List<Player> _pool;
  late List<Club> _clubPool;
  bool _ready = false;

  Future<void> initialize() async {
    _clubPool = chainClubPool
        .map((id) => Repository.instance.clubById(id))
        .whereType<Club>()
        .toList();

    final poolClubIds = _clubPool.map((c) => c.id).toSet();

    // Sıkı popüler havuz: yüksek zirve + en az 2 big-club
    _pool = Repository.instance.players.where((p) {
      final famous = p.clubs.where(poolClubIds.contains).length;
      if (famous < 2) return false;
      return p.peakMarketValue >= 40000000;
    }).toList();

    if (_pool.length < 60) {
      _pool = Repository.instance.players.where((p) {
        final famous = p.clubs.where(poolClubIds.contains).length;
        return famous >= 2 && p.peakMarketValue >= 25000000;
      }).toList();
    }

    // En ünlü isimlere ağırlık için sırala
    _pool.sort((a, b) => b.peakMarketValue.compareTo(a.peakMarketValue));
    if (_pool.length > 250) {
      _pool = _pool.take(250).toList();
    }

    final best = await HighScoreService.getHighScore(key: _highScoreKey);
    _ready = true;
    _state = _state.copyWith(isLoading: false, bestStreak: best);
    _nextQuestion(resetLives: true);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _nextTimer?.cancel();
    super.dispose();
  }

  /// Sahte kulüp: kolay / orta / zor tuzak.
  Club _pickFakeClub({
    required Player player,
    required List<Club> realClubs,
    required Set<int> realIds,
  }) {
    final candidates =
        _clubPool.where((c) => !realIds.contains(c.id)).toList();
    if (candidates.isEmpty) {
      return _clubPool.first;
    }

    final tier = _random.nextInt(3); // 0 easy, 1 mid, 2 hard
    final realLeagues = realClubs.map((c) => c.league).toSet();
    final realCountries = realClubs.map((c) => c.country).toSet();

    List<Club> hard = candidates
        .where((c) =>
            realLeagues.contains(c.league) ||
            realCountries.contains(c.country))
        .toList();
    List<Club> mid = candidates
        .where((c) =>
            c.country == (player.countries.isNotEmpty ? player.countries.first : '') ||
            realCountries.contains(c.country))
        .toList();
    List<Club> easy = candidates
        .where((c) =>
            !realLeagues.contains(c.league) &&
            !realCountries.contains(c.country))
        .toList();

    List<Club> pool;
    if (tier == 2 && hard.isNotEmpty) {
      pool = hard;
    } else if (tier == 1 && mid.isNotEmpty) {
      pool = mid;
    } else if (easy.isNotEmpty) {
      pool = easy;
    } else {
      pool = candidates;
    }

    return pool[_random.nextInt(pool.length)];
  }

  void _nextQuestion({bool resetLives = false}) {
    if (!_ready || _pool.isEmpty) return;
    _clockTimer?.cancel();

    final poolClubIds = _clubPool.map((c) => c.id).toSet();
    // Üst dilimden seç (daha tanınır)
    final topN = _pool.take((_pool.length * 0.5).ceil().clamp(40, _pool.length)).toList();
    final player = topN[_random.nextInt(topN.length)];

    final realIds = player.clubs.toSet().intersection(poolClubIds).toList()
      ..shuffle(_random);
    final realClubs = realIds
        .take(3)
        .map((id) => Repository.instance.clubById(id))
        .whereType<Club>()
        .toList();

    if (realClubs.length < 3) {
      // Nadir; tekrar dene
      _nextQuestion(resetLives: resetLives);
      return;
    }

    final fake = _pickFakeClub(
      player: player,
      realClubs: realClubs,
      realIds: realIds.toSet(),
    );

    final options = [...realClubs, fake]..shuffle(_random);
    final fakeIndex = options.indexWhere((c) => c.id == fake.id);

    _state = _state.copyWith(
      player: player,
      options: options,
      fakeIndex: fakeIndex,
      clearSelected: true,
      answered: false,
      wasCorrect: false,
      secondsLeft: OddClubState.questionSeconds,
      questionStartedAt: DateTime.now(),
      clearFact: true,
      clearFeedback: true,
      clearEliminated: true,
      clearCrowd: true,
      lives: resetLives ? OddClubState.maxLives : _state.lives,
      streak: resetLives ? 0 : _state.streak,
      score: resetLives ? 0 : _state.score,
      isGameOver: false,
      jokers5050Left: resetLives ? 2 : _state.jokers5050Left,
      jokersCrowdLeft: resetLives ? 2 : _state.jokersCrowdLeft,
    );
    notifyListeners();

    if (timed) _startClock();
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state.answered || _state.isGameOver) return;
      if (_state.secondsLeft <= 1) {
        _clockTimer?.cancel();
        _onTimeout();
        return;
      }
      _state = _state.copyWith(secondsLeft: _state.secondsLeft - 1);
      notifyListeners();
    });
  }

  void _onTimeout() {
    final lives = _state.lives - 1;
    _state = _state.copyWith(
      answered: true,
      wasCorrect: false,
      lives: lives,
      streak: 0,
      feedback: 'Süre doldu!',
      factLine: _buildFact(),
    );
    notifyListeners();
    if (lives <= 0) {
      _finish();
    } else {
      _nextTimer?.cancel();
      _nextTimer = Timer(const Duration(milliseconds: 1600), _nextQuestion);
    }
  }

  String _buildFact() {
    final p = _state.player;
    if (p == null) return '';
    final realNames = <String>[];
    for (var i = 0; i < _state.options.length; i++) {
      if (i == _state.fakeIndex) continue;
      if (_state.eliminatedIndex == i) continue;
      realNames.add(_state.options[i].name);
    }
    final fake = _state.options[_state.fakeIndex].name;
    final played = realNames.take(3).join(', ');
    return '${p.name}; $played formasında oynadı ama $fake formasını hiç giymedi.';
  }

  String _positionLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'goalkeeper':
      case 'gk':
        return 'Kaleci';
      case 'defender':
      case 'defence':
        return 'Defans';
      case 'midfield':
      case 'midfielder':
        return 'Orta saha';
      case 'attack':
      case 'forward':
        return 'Forvet';
      default:
        return raw.isEmpty ? '?' : raw;
    }
  }

  String positionLabel() =>
      _positionLabel(_state.player?.position ?? '');

  Future<void> _finish() async {
    _clockTimer?.cancel();
    final best =
        _state.streak > _state.bestStreak ? _state.streak : _state.bestStreak;
    await HighScoreService.saveHighScore(_state.score, key: _highScoreKey);
    _state = _state.copyWith(isGameOver: true, bestStreak: best);
    notifyListeners();
  }

  void selectOption(int index) {
    if (_state.answered || _state.isGameOver) return;
    if (_state.eliminatedIndex == index) return;

    _clockTimer?.cancel();
    final correct = index == _state.fakeIndex;

    if (!correct) {
      final lives = _state.lives - 1;
      _state = _state.copyWith(
        selectedIndex: index,
        answered: true,
        wasCorrect: false,
        lives: lives,
        streak: 0,
        feedback: '❌ Oynadı!',
        factLine: _buildFact(),
      );
      notifyListeners();
      if (lives <= 0) {
        _finish();
      } else {
        _nextTimer?.cancel();
        _nextTimer =
            Timer(const Duration(milliseconds: 1800), _nextQuestion);
      }
      return;
    }

    // Doğru: sahte kulüp
    var points = 50;
    final started = _state.questionStartedAt;
    final quick = started != null &&
        DateTime.now().difference(started).inSeconds <
            OddClubState.quickStrikeSeconds;
    if (quick) points *= 2;

    final newStreak = _state.streak + 1;
    final mult = () {
      if (newStreak >= 10) return 3.0;
      if (newStreak >= 5) return 2.0;
      if (newStreak >= 3) return 1.5;
      return 1.0;
    }();
    points = (points * mult).round();

    _state = _state.copyWith(
      selectedIndex: index,
      answered: true,
      wasCorrect: true,
      streak: newStreak,
      score: _state.score + points,
      feedback: quick ? '⚡ Quick Strike! +$points' : '✓ +$points',
      factLine: _buildFact(),
    );
    notifyListeners();

    _nextTimer?.cancel();
    _nextTimer = Timer(const Duration(milliseconds: 1200), _nextQuestion);
  }

  void use5050() {
    if (_state.answered || _state.jokers5050Left <= 0) return;
    if (_state.eliminatedIndex != null) return;

    // Gerçek kulüplerden birini ele
    final realIndexes = <int>[];
    for (var i = 0; i < _state.options.length; i++) {
      if (i != _state.fakeIndex) realIndexes.add(i);
    }
    if (realIndexes.isEmpty) return;
    final elim = realIndexes[_random.nextInt(realIndexes.length)];

    _state = _state.copyWith(
      eliminatedIndex: elim,
      jokers5050Left: _state.jokers5050Left - 1,
    );
    notifyListeners();
  }

  void useCrowd() {
    if (_state.answered || _state.jokersCrowdLeft <= 0) return;
    if (_state.crowdPercents != null) return;

    // Sahte "istatistik": doğru şık biraz daha yüksek ağırlık
    final weights = List<double>.generate(_state.options.length, (i) {
      if (_state.eliminatedIndex == i) return 0;
      return i == _state.fakeIndex ? 35 + _random.nextDouble() * 25 : 8 + _random.nextDouble() * 20;
    });
    final sum = weights.fold<double>(0, (a, b) => a + b);
    final percents = weights.map((w) => ((w / sum) * 100).round()).toList();
    // normalize to 100
    final diff = 100 - percents.fold<int>(0, (a, b) => a + b);
    if (percents.isNotEmpty) percents[0] += diff;

    _state = _state.copyWith(
      crowdPercents: percents,
      jokersCrowdLeft: _state.jokersCrowdLeft - 1,
    );
    notifyListeners();
  }

  void restart() {
    _nextTimer?.cancel();
    _clockTimer?.cancel();
    _nextQuestion(resetLives: true);
  }
}