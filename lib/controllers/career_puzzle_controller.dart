import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/chain_pool.dart';
import '../models/career_puzzle_state.dart';
import '../models/career_stop.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';

class CareerPuzzleController extends ChangeNotifier {
  final CareerPuzzleDifficulty difficulty;
  final Random _random = Random();

  CareerPuzzleController({this.difficulty = CareerPuzzleDifficulty.normal});

  CareerPuzzleState _state = const CareerPuzzleState();
  CareerPuzzleState get state => _state;

  Timer? _feedbackTimer;

  (int minStops, int maxStops) get _stopRange {
    switch (difficulty) {
      case CareerPuzzleDifficulty.beginner:
        return (3, 4);
      case CareerPuzzleDifficulty.normal:
        return (5, 7);
      case CareerPuzzleDifficulty.legend:
        return (8, 12);
    }
  }

  void initialize() {
    _startRound(keepSession: false);
  }

  void restart() {
    _startRound(keepSession: true);
  }

  void disposeController() {
    _feedbackTimer?.cancel();
  }

  void _startRound({required bool keepSession}) {
    final (minS, maxS) = _stopRange;
    final famousIds = chainClubPool.toSet();

    bool isPopularEnough(Player p, int uniqueClubs) {
      final famousCount = p.clubs.where(famousIds.contains).length;
      if (famousCount < 1) return false;

      switch (difficulty) {
        case CareerPuzzleDifficulty.beginner:
          // Kısa ama tanınır kariyerler
          return p.peakMarketValue >= 30000000 ||
              (famousCount >= 2 && p.peakMarketValue >= 18000000);
        case CareerPuzzleDifficulty.normal:
          return p.peakMarketValue >= 20000000 ||
              (famousCount >= 2 && p.peakMarketValue >= 12000000);
        case CareerPuzzleDifficulty.legend:
          // Daha uzun kariyer; yine bilinen kulüp şart
          return p.peakMarketValue >= 15000000 || famousCount >= 3;
      }
    }

    var pool = Repository.instance.players.where((p) {
      final unique = <int>{};
      for (final stop in p.careerTimeline) {
        unique.add(stop.clubId);
      }
      final n = unique.length;
      if (n < minS) return false;
      if (difficulty == CareerPuzzleDifficulty.beginner && n > maxS + 2) {
        return false;
      }
      return isPopularEnough(p, n);
    }).toList();

    if (pool.length < 25) {
      pool = Repository.instance.players.where((p) {
        final unique = <int>{};
        for (final stop in p.careerTimeline) {
          unique.add(stop.clubId);
        }
        final n = unique.length;
        if (n < minS) return false;
        final famousCount = p.clubs.where(famousIds.contains).length;
        return famousCount >= 1 && p.peakMarketValue >= 10000000;
      }).toList();
    }

    if (pool.isEmpty) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return;
    }

    pool.sort((a, b) => b.peakMarketValue.compareTo(a.peakMarketValue));
    final top = pool.take((pool.length * 0.55).ceil().clamp(20, pool.length)).toList()
      ..shuffle(_random);
    final target = top[_random.nextInt(top.length)];

    final seen = <int>{};
    final uniqueStops = <CareerStop>[];
    for (final stop in target.careerTimeline) {
      if (seen.add(stop.clubId)) uniqueStops.add(stop);
    }

    final desired = minS +
        (maxS > minS ? _random.nextInt(maxS - minS + 1) : 0);
    final take = desired.clamp(minS, uniqueStops.length);

    final maxStart = uniqueStops.length - take;
    final startIndex = maxStart > 0 ? _random.nextInt(maxStart + 1) : 0;
    final chosenStops =
        uniqueStops.skip(startIndex).take(take).toList();

    final displayClubs = chosenStops
        .map((s) => Repository.instance.clubById(s.clubId))
        .whereType<Club>()
        .toList()
      ..shuffle(_random);

    // Nadiren kulüp eksikse turu yenile
    if (displayClubs.length != chosenStops.length) {
      _startRound(keepSession: keepSession);
      return;
    }

    _state = CareerPuzzleState(
      isLoading: false,
      phase: CareerPuzzlePhase.guessingPlayer,
      difficulty: difficulty,
      target: target,
      correctStops: chosenStops,
      displayClubs: displayClubs,
      lives: keepSession ? _state.lives : CareerPuzzleState.maxLives,
      coins: keepSession ? _state.coins : CareerPuzzleState.startingCoins,
      sessionScore: keepSession ? _state.sessionScore : 0,
      roundScore: 0,
      playerGuessed: false,
      orderUntouched: true,
      orderCheckedOnce: false,
      revealedEraIndexes: const {},
      shortStayMarkedClubIds: const {},
      connectedPairs: const [],
    );
    notifyListeners();
  }

  void submitPlayerGuess(String answer) {
    if (_state.phase != CareerPuzzlePhase.guessingPlayer) return;
    final target = _state.target;
    if (target == null) return;

    final resolved = SearchService.resolve(
      players: Repository.instance.players,
      answer: answer,
    );

    if (resolved.status == ResolveStatus.ambiguous) {
      _feedback(resolved.message, false);
      return;
    }

    if (resolved.isFound && resolved.player!.id == target.id) {
      _state = _state.copyWith(
        phase: CareerPuzzlePhase.orderingCareer,
        playerGuessed: true,
        roundScore: CareerPuzzleState.playerGuessPoints,
        feedback: 'Doğru! +${CareerPuzzleState.playerGuessPoints} — şimdi sırala',
        feedbackSuccess: true,
      );
      notifyListeners();
      return;
    }

    final lives = _state.lives - 1;
    if (lives <= 0) {
      _state = _state.copyWith(
        lives: 0,
        phase: CareerPuzzlePhase.result,
        feedback: 'Can bitti: ${target.name}',
        feedbackSuccess: false,
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(lives: lives);
    _feedback('Yanlış, tekrar dene.', false);
  }

  void reorder(int oldIndex, int newIndex) {
    if (_state.phase != CareerPuzzlePhase.orderingCareer) return;
    final list = List<Club>.from(_state.displayClubs);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    _state = _state.copyWith(
      displayClubs: list,
      orderUntouched: false,
    );
    notifyListeners();
  }

  void confirmOrder() {
    if (_state.phase != CareerPuzzlePhase.orderingCareer) return;

    final correctness = <bool>[];
    for (var i = 0; i < _state.displayClubs.length; i++) {
      correctness.add(
        _state.displayClubs[i].id == _state.correctStops[i].clubId,
      );
    }

    final allCorrect = correctness.every((c) => c);
    var gained = 0;
    if (allCorrect) {
      gained += CareerPuzzleState.perfectOrderPoints;
      // İlk kontrol + hiç sürüklemeden doğruya yakın: bonus
      // orderUntouched = hiç reorder yoktu (şans); veya ilk denemede doğru
      if (!_state.orderCheckedOnce) {
        gained += CareerPuzzleState.perfectBonusPoints;
      }
    } else {
      // Kısmi: doğru pozisyon başına puan
      final per = (CareerPuzzleState.perfectOrderPoints / correctness.length)
          .floor();
      for (final c in correctness) {
        if (c) gained += per;
      }
    }

    final round = _state.roundScore + gained;
    _state = _state.copyWith(
      phase: CareerPuzzlePhase.result,
      resultCorrectness: correctness,
      orderCheckedOnce: true,
      roundScore: round,
      sessionScore: _state.sessionScore + round,
      coins: allCorrect ? _state.coins + 15 : _state.coins,
      feedback: allCorrect
          ? 'Mükemmel sıralama! +$gained'
          : 'Sıralama kontrol edildi. +$gained',
      feedbackSuccess: allCorrect,
    );
    notifyListeners();
  }

  // --- Jokers ---

  bool _spendJoker() {
    if (_state.coins < CareerPuzzleState.jokerCost) {
      _feedback('Yetersiz coin.', false);
      return false;
    }
    _state = _state.copyWith(coins: _state.coins - CareerPuzzleState.jokerCost);
    return true;
  }

  /// Rastgele doğru ardışık iki kulübü bağlar.
  void jokerShowConnect() {
    if (_state.phase != CareerPuzzlePhase.orderingCareer) return;
    if (_state.correctStops.length < 2) return;
    if (!_spendJoker()) return;

    final i = _random.nextInt(_state.correctStops.length - 1);
    final a = _state.correctStops[i].clubId;
    final b = _state.correctStops[i + 1].clubId;
    final pairs = List<(int, int)>.from(_state.connectedPairs)..add((a, b));

    _state = _state.copyWith(
      connectedPairs: pairs,
      feedback: 'Bağlantı gösterildi.',
      feedbackSuccess: true,
    );
    notifyListeners();
  }

  /// Kısa dönem (≤1 yıl) kulüpleri işaretle — veri setinde loan yok, proxy.
  void jokerMarkShortStays() {
    if (_state.phase != CareerPuzzlePhase.orderingCareer) return;
    if (!_spendJoker()) return;

    final ids = <int>{};
    for (final stop in _state.correctStops) {
      final end = stop.endYear ?? stop.startYear;
      if (end - stop.startYear <= 1) {
        ids.add(stop.clubId);
      }
    }

    _state = _state.copyWith(
      shortStayMarkedClubIds: ids,
      feedback: ids.isEmpty
          ? 'Kısa dönem kulüp yok.'
          : 'Kısa dönemler işaretlendi.',
      feedbackSuccess: true,
    );
    notifyListeners();
  }

  /// Rastgele bir kulübün yıl aralığını göster.
  void jokerShowEra() {
    if (_state.phase != CareerPuzzlePhase.orderingCareer) return;
    if (!_spendJoker()) return;

    final closed = <int>[];
    for (var i = 0; i < _state.displayClubs.length; i++) {
      if (!_state.revealedEraIndexes.contains(i)) closed.add(i);
    }
    if (closed.isEmpty) {
      _feedback('Tüm yıllar açık.', false);
      // coin iade
      _state = _state.copyWith(coins: _state.coins + CareerPuzzleState.jokerCost);
      notifyListeners();
      return;
    }

    final pick = closed[_random.nextInt(closed.length)];
    final revealed = Set<int>.from(_state.revealedEraIndexes)..add(pick);

    _state = _state.copyWith(
      revealedEraIndexes: revealed,
      feedback: 'Zaman aralığı açıldı.',
      feedbackSuccess: true,
    );
    notifyListeners();
  }

  String? eraLabelForDisplayIndex(int index) {
    if (!_state.revealedEraIndexes.contains(index)) return null;
    if (index < 0 || index >= _state.displayClubs.length) return null;
    final clubId = _state.displayClubs[index].id;
    for (final stop in _state.correctStops) {
      if (stop.clubId == clubId) return stop.yearsLabel;
    }
    return null;
  }

  bool isPairConnected(int clubA, int clubB) {
    for (final (a, b) in _state.connectedPairs) {
      if ((a == clubA && b == clubB) || (a == clubB && b == clubA)) {
        return true;
      }
    }
    return false;
  }


  Club? clubById(int id) => Repository.instance.clubById(id);

  List<Player> suggestions(String query) {
    return SearchService.suggestions(
      players: Repository.instance.players,
      query: query,
    );
  }

  void _feedback(String message, bool success) {
    _feedbackTimer?.cancel();
    _state = _state.copyWith(feedback: message, feedbackSuccess: success);
    notifyListeners();
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      _state = _state.copyWith(clearFeedback: true);
      notifyListeners();
    });
  }
}