import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/blind_ranking_state.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/runtime_v3/hybrid_gameplay_data_service.dart';

class BlindRankingController extends ChangeNotifier {
  final Random _random = Random();

  BlindRankingState _state = const BlindRankingState();
  BlindRankingState get state => _state;

  void initialize() {
    unawaited(_initializeHybrid());
  }

  Future<void> _initializeHybrid() async {
    final hybrid = HybridGameplayDataService.instance;

    if (hybrid.isGameplayEnabled) {
      final ordered = await hybrid.playersInPool('normal_v3');

      if (ordered.length >= 500) {
        // normal_v3 is already ordered by selectionRankV3.
        //
        // Pick one player from ten rank bands. This avoids getting ten almost
        // identical superstars while keeping all names recognizable.
        final envelopeSize = ordered.length.clamp(500, 1200);
        final envelope = ordered.take(envelopeSize).toList();
        final chosen = <Player>[];

        final bandSize =
            (envelope.length / BlindRankingState.slotCount).floor();

        for (var band = 0;
            band < BlindRankingState.slotCount;
            band++) {
          final start = band * bandSize;
          final end = band == BlindRankingState.slotCount - 1
              ? envelope.length
              : ((band + 1) * bandSize).clamp(0, envelope.length);

          if (start >= envelope.length || end <= start) continue;

          final slice = envelope.sublist(start, end);
          chosen.add(slice[_random.nextInt(slice.length)]);
        }

        if (chosen.length == BlindRankingState.slotCount) {
          // `chosen` is still rank-band ordered, therefore this is the
          // authoritative true order before presentation shuffle.
          final trueOrderIds = chosen.map((p) => p.id).toList();
          final presentationOrder = List<Player>.from(chosen)
            ..shuffle(_random);

          _state = BlindRankingState(
            isLoading: false,
            players: presentationOrder,
            trueOrderPlayerIds: trueOrderIds,
          );

          debugPrint(
            '[HybridV3] BlindRanking SQLite '
            'players=${chosen.length} source=normal_v3 '
            'envelope=$envelopeSize',
          );

          notifyListeners();
          return;
        }
      }

      debugPrint(
        '[HybridV3] BlindRanking SQLite pool too small; legacy fallback.',
      );
    }

    _initializeLegacy();
  }

  void _initializeLegacy() {
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