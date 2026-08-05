import 'player.dart';

class MysteryPlayerState {
  static const int maxGuesses = 6;

  final bool isLoading;
  final Player? target;
  final List<String> allClues;

  final int guessesUsed;
  final int cluesRevealed;

  final bool isSolved;
  final bool isFailed;

  final List<String> wrongGuesses;

  const MysteryPlayerState({
    this.isLoading = true,
    this.target,
    this.allClues = const [],
    this.guessesUsed = 0,
    this.cluesRevealed = 1,
    this.isSolved = false,
    this.isFailed = false,
    this.wrongGuesses = const [],
  });

  int get stars {
    if (guessesUsed <= 2) return 3;
    if (guessesUsed <= 4) return 2;
    return 1;
  }

  int get score {
    if (!isSolved) return 0;
    final base = 100 - (guessesUsed) * 15;
    return base < 20 ? 20 : base;
  }

  MysteryPlayerState copyWith({
    bool? isLoading,
    Player? target,
    List<String>? allClues,
    int? guessesUsed,
    int? cluesRevealed,
    bool? isSolved,
    bool? isFailed,
    List<String>? wrongGuesses,
  }) {
    return MysteryPlayerState(
      isLoading: isLoading ?? this.isLoading,
      target: target ?? this.target,
      allClues: allClues ?? this.allClues,
      guessesUsed: guessesUsed ?? this.guessesUsed,
      cluesRevealed: cluesRevealed ?? this.cluesRevealed,
      isSolved: isSolved ?? this.isSolved,
      isFailed: isFailed ?? this.isFailed,
      wrongGuesses: wrongGuesses ?? this.wrongGuesses,
    );
  }
}