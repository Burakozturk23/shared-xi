import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/chain_pool.dart';
import '../models/club.dart';
import '../models/random_five_state.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';

class RandomFiveController extends ChangeNotifier {
  final Random _random = Random();

  RandomFiveState _state = const RandomFiveState();
  RandomFiveState get state => _state;

  Timer? _feedbackTimer;

  void initialize() {
    _pickNewClubs();
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _pickNewClubs() {
    final pool = chainClubPool
        .map((id) => Repository.instance.clubById(id))
        .whereType<Club>()
        .toList()
      ..shuffle(_random);

    final clubs = pool.take(5).toList();

    _state = _state.copyWith(isLoading: false, clubs: clubs);
    notifyListeners();
  }

  void newRound() {
    _pickNewClubs();
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

  void submitGuess(String answer) {
    if (answer.trim().isEmpty) return;

    final resolved = SearchService.resolve(
      players: Repository.instance.players,
      answer: answer,
      excludedPlayerIds: _state.usedPlayerIds,
    );

    if (resolved.status == ResolveStatus.ambiguous) {
      _feedback(resolved.message, false);
      return;
    }

    if (!resolved.isFound) {
      _feedback('Böyle bir oyuncu bulunamadı.', false);
      return;
    }

    final player = resolved.player!;

    final matched =
        _state.clubs.where((c) => player.clubs.contains(c.id)).toList();

    if (matched.isEmpty) {
      _feedback('${player.name} bu 5 kulübün hiçbirinde oynamamış.', false);
      return;
    }

    final entry = RandomFiveEntry(player: player, matchedClubs: matched);
    final newHistory = List<RandomFiveEntry>.from(_state.history)..add(entry);
    final newUsed = Set<int>.from(_state.usedPlayerIds)..add(player.id);

    _state = _state.copyWith(history: newHistory, usedPlayerIds: newUsed);

    _feedback(
      '${player.name}: ${matched.length} kulüp! (+${matched.length} puan)',
      true,
    );
  }
}