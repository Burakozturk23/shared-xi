import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/transfer_detective_state.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';

class TransferDetectiveController extends ChangeNotifier {
  final Random _random = Random();

  TransferDetectiveState _state = const TransferDetectiveState();
  TransferDetectiveState get state => _state;

  void initialize() {
    final transfers = Repository.instance.famousTransfers;
    if (transfers.isEmpty) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return;
    }

    final transfer = transfers[_random.nextInt(transfers.length)];
    final target = Repository.instance.playerById(transfer.playerId);
    final fromClub = Repository.instance.clubById(transfer.fromClubId);
    final toClub = Repository.instance.clubById(transfer.toClubId);

    if (target == null || fromClub == null || toClub == null) {
      // nadiren veri eksik olabilir, tekrar dene
      initialize();
      return;
    }

    _state = TransferDetectiveState(
      isLoading: false,
      target: target,
      transfer: transfer,
      fromClub: fromClub,
      toClub: toClub,
    );

    notifyListeners();
  }

  void revealNextClue() {
    if (_state.isSolved || _state.isFailed) return;
    if (_state.cluesRevealed >= TransferDetectiveState.maxClues) return;

    final revealed = _state.cluesRevealed + 1;
    final failed = revealed > TransferDetectiveState.maxClues;

    _state = _state.copyWith(cluesRevealed: revealed, isFailed: failed);
    notifyListeners();
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

    final wrong = List<String>.from(_state.wrongGuesses)..add(answer);
    _state = _state.copyWith(wrongGuesses: wrong);
    notifyListeners();

    revealNextClue();
  }

  void restart() {
    initialize();
  }
}