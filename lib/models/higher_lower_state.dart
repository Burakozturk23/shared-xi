import 'player.dart';

enum HigherLowerCriterion { marketValue, goals }

class HigherLowerState {
  final bool isLoading;
  final bool isGameOver;

  final HigherLowerCriterion criterion;

  final Player? currentPlayer;
  final Player? nextPlayer;

  final int? selectedGuessIsHigher; // 1 = daha yüksek, 0 = daha düşük, null = henüz cevap yok
  final bool answered;
  final bool? wasCorrect;

  final int streak;
  final int bestStreak;

  const HigherLowerState({
    this.isLoading = true,
    this.isGameOver = false,
    this.criterion = HigherLowerCriterion.marketValue,
    this.currentPlayer,
    this.nextPlayer,
    this.selectedGuessIsHigher,
    this.answered = false,
    this.wasCorrect,
    this.streak = 0,
    this.bestStreak = 0,
  });

  double valueOf(Player p) {
    return criterion == HigherLowerCriterion.marketValue
        ? p.peakMarketValue
        : p.careerGoals.toDouble();
  }

  String get criterionLabel => criterion == HigherLowerCriterion.marketValue
      ? 'Zirve Piyasa Değeri'
      : 'Kariyer Golü';

  HigherLowerState copyWith({
    bool? isLoading,
    bool? isGameOver,
    HigherLowerCriterion? criterion,
    Player? currentPlayer,
    Player? nextPlayer,
    int? selectedGuessIsHigher,
    bool clearSelected = false,
    bool? answered,
    bool? wasCorrect,
    bool clearWasCorrect = false,
    int? streak,
    int? bestStreak,
  }) {
    return HigherLowerState(
      isLoading: isLoading ?? this.isLoading,
      isGameOver: isGameOver ?? this.isGameOver,
      criterion: criterion ?? this.criterion,
      currentPlayer: currentPlayer ?? this.currentPlayer,
      nextPlayer: nextPlayer ?? this.nextPlayer,
      selectedGuessIsHigher: clearSelected
          ? null
          : (selectedGuessIsHigher ?? this.selectedGuessIsHigher),
      answered: answered ?? this.answered,
      wasCorrect: clearWasCorrect ? null : (wasCorrect ?? this.wasCorrect),
      streak: streak ?? this.streak,
      bestStreak: bestStreak ?? this.bestStreak,
    );
  }
}