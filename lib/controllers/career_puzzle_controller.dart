import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/career_puzzle_state.dart';
import '../models/career_stop.dart';
import '../models/club.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';

class CareerPuzzleController extends ChangeNotifier {
  final Random _random = Random();

  CareerPuzzleState _state = const CareerPuzzleState();
  CareerPuzzleState get state => _state;

  Timer? _feedbackTimer;

  void initialize() {
    final pool = Repository.instance.players.where((p) {
      final uniqueClubIds = <int>{};
      for (final stop in p.careerTimeline) {
        uniqueClubIds.add(stop.clubId);
      }
      return p.marketValue >= 3000000 && uniqueClubIds.length >= CareerPuzzleState.stopCount;
    }).toList();

    if (pool.isEmpty) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return;
    }

    final target = pool[_random.nextInt(pool.length)];

    // Aynı kulübe birden fazla kez dönüşleri tekilleştir (ilk gidişi tut).
    final seen = <int>{};
    final uniqueStops = <CareerStop>[];
    for (final stop in target.careerTimeline) {
      if (seen.add(stop.clubId)) uniqueStops.add(stop);
    }

    // Ardışık 5 durak seç (kariyerin rastgele bir bölümü).
    final maxStart = uniqueStops.length - CareerPuzzleState.stopCount;
    final startIndex = maxStart > 0 ? _random.nextInt(maxStart + 1) : 0;
    final chosenStops =
        uniqueStops.skip(startIndex).take(CareerPuzzleState.stopCount).toList();

    final displayClubs = chosenStops
        .map((s) => Repository.instance.clubById(s.clubId))
        .whereType<Club>()
        .toList()
      ..shuffle(_random);

    _state = CareerPuzzleState(
      isLoading: false,
      target: target,
      correctStops: chosenStops,
      displayClubs: displayClubs,
    );

    notifyListeners();
  }

  void _feedback(String message, bool success) {
    _feedbackTimer?.cancel();

    _state = _state.copyWith(feedback: message, feedbackSuccess: success);
    notifyListeners();

    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      _state = _state.copyWith(feedback: null);
      notifyListeners();
    });
  }

  void submitPlayerGuess(String answer) {
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
      _state = _state.copyWith(phase: CareerPuzzlePhase.orderingCareer);
      notifyListeners();
    } else {
      _feedback('Yanlış, tekrar dene.', false);
    }
  }

  void reorder(int oldIndex, int newIndex) {
    final list = List<Club>.from(_state.displayClubs);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    _state = _state.copyWith(displayClubs: list);
    notifyListeners();
  }

  void confirmOrder() {
    final correctness = <bool>[];
    for (var i = 0; i < _state.displayClubs.length; i++) {
      final club = _state.displayClubs[i];
      final correctClubId = _state.correctStops[i].clubId;
      correctness.add(club.id == correctClubId);
    }

    _state = _state.copyWith(
      phase: CareerPuzzlePhase.result,
      resultCorrectness: correctness,
    );

    notifyListeners();
  }

  void restart() {
    initialize();
  }
}