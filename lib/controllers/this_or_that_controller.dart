import 'package:flutter/foundation.dart';

import '../data/bracket_registry.dart';
import '../data/prime_battles_32_data.dart';
import '../models/bracket_candidate.dart';
import '../models/this_or_that_state.dart';

class ThisOrThatController extends ChangeNotifier {
  late ThisOrThatState _state;
  late final BracketDefinition _def;

  ThisOrThatState get state => _state;

  ThisOrThatController({String bracketId = PrimeBattles32Data.bracketId}) {
    final def = BracketRegistry.byId(bracketId);
    if (def == null) {
      throw ArgumentError('Geçersiz bracket: $bracketId');
    }
    final n = def.seeds.length;
    if (n < 2 || (n & (n - 1)) != 0) {
      throw ArgumentError('Bracket boyutu 2\'nin kuvveti olmalı (32/64/128). Gelen: $n');
    }
    _def = def;
    _start();
  }

  static ThisOrThatRound _openingRound(int fieldSize) {
    switch (fieldSize) {
      case 128:
        return ThisOrThatRound.roundOf128;
      case 64:
        return ThisOrThatRound.roundOf64;
      case 32:
        return ThisOrThatRound.roundOf32;
      case 16:
        return ThisOrThatRound.roundOf16;
      default:
        return ThisOrThatRound.roundOf32;
    }
  }

  static List<ThisOrThatRound> _stepsFor(int fieldSize) {
    final all = <ThisOrThatRound>[
      if (fieldSize >= 128) ThisOrThatRound.roundOf128,
      if (fieldSize >= 64) ThisOrThatRound.roundOf64,
      if (fieldSize >= 32) ThisOrThatRound.roundOf32,
      if (fieldSize >= 16) ThisOrThatRound.roundOf16,
      ThisOrThatRound.quarterFinal,
      ThisOrThatRound.semiFinal,
      ThisOrThatRound.finalMatch,
    ];
    // 32'lik bracket'te QF = 8 kişi sonrası; opening zaten R32
    // steps list is fine for progress UI
    return all;
  }

  void _start() {
    final seeds = List<BracketCandidate>.from(_def.seeds);
    final opening = _openingRound(seeds.length);
    _state = ThisOrThatState(
      bracketId: _def.id,
      title: _def.title,
      subtitle: _def.subtitle,
      fieldSize: seeds.length,
      totalDecisions: seeds.length - 1,
      progressSteps: _stepsFor(seeds.length),
      round: opening,
      matchIndexInRound: 0,
      globalMatchNumber: 1,
      history: [],
      currentRoundCandidates: seeds,
      left: seeds[0],
      right: seeds[1],
    );
  }

  void reset() {
    _start();
    notifyListeners();
  }

  void pick(bool leftWins) {
    if (_state.isFinished) return;
    final left = _state.left;
    final right = _state.right;
    if (left == null || right == null) return;

    final winner = leftWins ? left : right;
    final match = ThisOrThatMatch(
      matchNumber: _state.globalMatchNumber,
      left: left,
      right: right,
      winner: winner,
    );

    final history = List<ThisOrThatMatch>.from(_state.history)..add(match);
    final candidates =
        List<BracketCandidate>.from(_state.currentRoundCandidates);

    final matchesInRound = candidates.length ~/ 2;
    final nextMatchIndex = _state.matchIndexInRound + 1;

    if (nextMatchIndex < matchesInRound) {
      final i = nextMatchIndex * 2;
      _state = _state.copyWith(
        matchIndexInRound: nextMatchIndex,
        globalMatchNumber: _state.globalMatchNumber + 1,
        history: history,
        left: candidates[i],
        right: candidates[i + 1],
      );
      notifyListeners();
      return;
    }

    final winners = <BracketCandidate>[];
    final roundMatches = history.sublist(history.length - matchesInRound);
    for (final m in roundMatches) {
      if (m.winner != null) winners.add(m.winner!);
    }

    if (winners.length == 1) {
      _state = _state.copyWith(
        history: history,
        round: ThisOrThatRound.finished,
        champion: winners.first,
        isFinished: true,
        clearSides: true,
        currentRoundCandidates: winners,
      );
      notifyListeners();
      return;
    }

    final nextRound = _roundForRemaining(winners.length);
    _state = _state.copyWith(
      history: history,
      round: nextRound,
      matchIndexInRound: 0,
      globalMatchNumber: _state.globalMatchNumber + 1,
      currentRoundCandidates: winners,
      left: winners[0],
      right: winners[1],
    );
    notifyListeners();
  }

  ThisOrThatRound _roundForRemaining(int remainingPlayers) {
    switch (remainingPlayers) {
      case 128:
        return ThisOrThatRound.roundOf128;
      case 64:
        return ThisOrThatRound.roundOf64;
      case 32:
        return ThisOrThatRound.roundOf32;
      case 16:
        return ThisOrThatRound.roundOf16;
      case 8:
        return ThisOrThatRound.quarterFinal;
      case 4:
        return ThisOrThatRound.semiFinal;
      case 2:
        return ThisOrThatRound.finalMatch;
      default:
        return ThisOrThatRound.finished;
    }
  }
}
