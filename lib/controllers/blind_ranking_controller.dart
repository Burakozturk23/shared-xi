import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/blind_ranking_state.dart';
import '../models/player.dart';
import '../repositories/repository.dart';

class BlindRankingController extends ChangeNotifier {
  final Random _random = Random();

  BlindRankingState _state = const BlindRankingState();
  BlindRankingState get state => _state;

  void initialize() {
    final pool = Repository.instance.players
        .where((p) => p.marketValue >= 2000000)
        .toList()
      ..sort((a, b) => b.marketValue.compareTo(a.marketValue));

    final topPool = pool.take(250).toList()..shuffle(_random);
    final chosen = topPool.take(BlindRankingState.slotCount).toList();

    final presentationOrder = List<Player>.from(chosen)..shuffle(_random);

    _state = BlindRankingState(
      isLoading: false,
      players: presentationOrder,
    );

    notifyListeners();
  }

  bool isSlotFilled(int slotIndex) => _state.slots[slotIndex] != null;

  void placeCurrentPlayerAt(int slotIndex) {
    if (_state.isFinished) return;
    if (isSlotFilled(slotIndex)) return;

    final player = _state.currentPlayer;
    if (player == null) return;

    final newSlots = List<Player?>.from(_state.slots);
    newSlots[slotIndex] = player;

    final nextIndex = _state.currentIndex + 1;
    final finished = nextIndex >= _state.players.length;

    _state = _state.copyWith(
      slots: newSlots,
      currentIndex: nextIndex,
      isFinished: finished,
    );

    notifyListeners();
  }

  void restart() {
    initialize();
  }
}