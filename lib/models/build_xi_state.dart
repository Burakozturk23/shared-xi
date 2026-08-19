import '../data/build_xi_formations.dart';
import '../data/build_xi_themes.dart';
import 'player.dart';

class BuildXiScoreBreakdown {
  final int chemistry;
  final int countryBonus;
  final int clubBonus;
  final int continentBonus;
  final int budgetBonus;

  const BuildXiScoreBreakdown({
    this.chemistry = 0,
    this.countryBonus = 0,
    this.clubBonus = 0,
    this.continentBonus = 0,
    this.budgetBonus = 0,
  });

  int get total => chemistry + countryBonus + clubBonus + continentBonus + budgetBonus;
}

class BuildXiState {
  static const int budgetLimit = 160;

  final bool isLoading;
  final BuildXiTheme? theme;
  final Formation? formation;

  final List<Player?> slotPlayers;
  final Map<int, int> costs;

  final int? activeSlotIndex;
  final bool isFinished;
  final BuildXiScoreBreakdown? breakdown;

  const BuildXiState({
    this.isLoading = true,
    this.theme,
    this.formation,
    this.slotPlayers = const [],
    this.costs = const {},
    this.activeSlotIndex,
    this.isFinished = false,
    this.breakdown,
  });

  int costOf(Player p) => costs[p.id] ?? 1;

  int get usedBudget =>
      slotPlayers.whereType<Player>().fold(0, (sum, p) => sum + costOf(p));

  int get remainingBudget => budgetLimit - usedBudget;

  int get filledCount => slotPlayers.where((p) => p != null).length;

  bool get isComplete =>
      slotPlayers.isNotEmpty && slotPlayers.every((p) => p != null);

  BuildXiState copyWith({
    bool? isLoading,
    BuildXiTheme? theme,
    Formation? formation,
    List<Player?>? slotPlayers,
    Map<int, int>? costs,
    int? activeSlotIndex,
    bool clearActiveSlot = false,
    bool? isFinished,
    BuildXiScoreBreakdown? breakdown,
  }) {
    return BuildXiState(
      isLoading: isLoading ?? this.isLoading,
      theme: theme ?? this.theme,
      formation: formation ?? this.formation,
      slotPlayers: slotPlayers ?? this.slotPlayers,
      costs: costs ?? this.costs,
      activeSlotIndex:
          clearActiveSlot ? null : (activeSlotIndex ?? this.activeSlotIndex),
      isFinished: isFinished ?? this.isFinished,
      breakdown: breakdown ?? this.breakdown,
    );
  }
}