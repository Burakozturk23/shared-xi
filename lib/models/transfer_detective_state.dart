import 'club.dart';
import 'famous_transfer.dart';
import 'player.dart';

class TransferDetectiveState {
  static const int maxClues = 5;

  final bool isLoading;
  final bool isSolved;
  final bool isFailed;

  final Player? target;
  final FamousTransfer? transfer;
  final Club? fromClub;
  final Club? toClub;

  final int cluesRevealed;
  final List<String> wrongGuesses;

  const TransferDetectiveState({
    this.isLoading = true,
    this.isSolved = false,
    this.isFailed = false,
    this.target,
    this.transfer,
    this.fromClub,
    this.toClub,
    this.cluesRevealed = 1,
    this.wrongGuesses = const [],
  });

  int get score {
    if (!isSolved) return 0;
    final s = 125 - cluesRevealed * 25;
    return s < 0 ? 0 : s;
  }

  TransferDetectiveState copyWith({
    bool? isLoading,
    bool? isSolved,
    bool? isFailed,
    Player? target,
    FamousTransfer? transfer,
    Club? fromClub,
    Club? toClub,
    int? cluesRevealed,
    List<String>? wrongGuesses,
  }) {
    return TransferDetectiveState(
      isLoading: isLoading ?? this.isLoading,
      isSolved: isSolved ?? this.isSolved,
      isFailed: isFailed ?? this.isFailed,
      target: target ?? this.target,
      transfer: transfer ?? this.transfer,
      fromClub: fromClub ?? this.fromClub,
      toClub: toClub ?? this.toClub,
      cluesRevealed: cluesRevealed ?? this.cluesRevealed,
      wrongGuesses: wrongGuesses ?? this.wrongGuesses,
    );
  }
}