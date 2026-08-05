import 'club.dart';
import 'player.dart';

class OddClubState {
  final bool isLoading;
  final bool isGameOver;

  final Player? player;
  final List<Club> options;
  final int fakeIndex;

  final int? selectedIndex;
  final bool answered;

  final int streak;
  final int bestStreak;

  final int secondsLeft;

  const OddClubState({
    this.isLoading = true,
    this.isGameOver = false,
    this.player,
    this.options = const [],
    this.fakeIndex = -1,
    this.selectedIndex,
    this.answered = false,
    this.streak = 0,
    this.bestStreak = 0,
    this.secondsLeft = 5,
  });

  OddClubState copyWith({
    bool? isLoading,
    bool? isGameOver,
    Player? player,
    List<Club>? options,
    int? fakeIndex,
    int? selectedIndex,
    bool clearSelected = false,
    bool? answered,
    int? streak,
    int? bestStreak,
    int? secondsLeft,
  }) {
    return OddClubState(
      isLoading: isLoading ?? this.isLoading,
      isGameOver: isGameOver ?? this.isGameOver,
      player: player ?? this.player,
      options: options ?? this.options,
      fakeIndex: fakeIndex ?? this.fakeIndex,
      selectedIndex:
          clearSelected ? null : (selectedIndex ?? this.selectedIndex),
      answered: answered ?? this.answered,
      streak: streak ?? this.streak,
      bestStreak: bestStreak ?? this.bestStreak,
      secondsLeft: secondsLeft ?? this.secondsLeft,
    );
  }
}