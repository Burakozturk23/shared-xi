import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/grid_criterion.dart';
import '../models/mystery_player_state.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';

class MysteryPlayerController extends ChangeNotifier {
  final Random _random = Random();

  MysteryPlayerState _state = const MysteryPlayerState();
  MysteryPlayerState get state => _state;

  void initialize() {
    final pool = Repository.instance.players
        .where((p) => p.marketValue >= 3000000 && p.clubs.length >= 2)
        .toList()
      ..sort((a, b) => b.marketValue.compareTo(a.marketValue));

    if (pool.isEmpty) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return;
    }

    final topPool = pool.take(300).toList();
    final target = topPool[_random.nextInt(topPool.length)];
    final clues = _buildClues(target);

    _state = MysteryPlayerState(
      isLoading: false,
      target: target,
      allClues: clues,
    );

    notifyListeners();
  }

  String _positionLabel(String value) {
    for (final p in gridPositions) {
      if (p.value == value) return p.label;
    }
    return value;
  }

  String _valueBucket(double value) {
    if (value <= 0) return 'Bilinmiyor';
    if (value < 1000000) return '€1M altı';
    if (value < 5000000) return '€1M - €5M arası';
    if (value < 20000000) return '€5M - €20M arası';
    if (value < 50000000) return '€20M - €50M arası';
    return '€50M üzeri';
  }

  List<String> _buildClues(Player p) {
    final clubNames = p.clubs
        .map((id) => Repository.instance.clubById(id)?.name)
        .whereType<String>()
        .toList();

    final revealedClub = clubNames.isNotEmpty
        ? clubNames[_random.nextInt(clubNames.length)]
        : 'Bilinmiyor';

    return [
      'Uyruk: ${p.countryLabel.isEmpty ? "Bilinmiyor" : p.countryLabel}',
      'Pozisyon: ${_positionLabel(p.position)}',
      'Kariyer boyunca ${p.clubs.length} farklı kulüpte forma giymiş',
      'Kariyer golü: ${p.careerGoals}',
      'Oynadığı kulüplerden biri: $revealedClub',
      'Piyasa değeri: ${_valueBucket(p.marketValue)}',
    ];
  }

  void newRound() {
    initialize();
  }

  void submitGuess(String answer) {
    final target = _state.target;
    if (target == null || _state.isSolved || _state.isFailed) return;
    if (answer.trim().isEmpty) return;

    if (SearchService.matches(target, answer)) {
      _state = _state.copyWith(isSolved: true);
      notifyListeners();
      return;
    }

    final guesses = _state.guessesUsed + 1;
    final wrong = List<String>.from(_state.wrongGuesses)..add(answer);
    final clueCount = (guesses + 1).clamp(1, _state.allClues.length);
    final failed = guesses >= MysteryPlayerState.maxGuesses;

    _state = _state.copyWith(
      guessesUsed: guesses,
      wrongGuesses: wrong,
      cluesRevealed: clueCount,
      isFailed: failed,
    );

    notifyListeners();
  }
  void revealNextClue() {
    if (_state.isSolved || _state.isFailed) return;
    if (_state.cluesRevealed >= _state.allClues.length) return;

    final guesses = _state.guessesUsed + 1;
    final clueCount = (guesses + 1).clamp(1, _state.allClues.length);
    final failed = guesses >= MysteryPlayerState.maxGuesses;

    _state = _state.copyWith(
      guessesUsed: guesses,
      cluesRevealed: clueCount,
      isFailed: failed,
    );

    notifyListeners();
  }



}