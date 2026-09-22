import 'squad_challenge.dart';

class BuildXiScoreBreakdown {
  const BuildXiScoreBreakdown({
    this.chemistry = 0,
    this.countryBonus = 0,
    this.clubBonus = 0,
    this.continentBonus = 0,
    this.budgetBonus = 0,
    this.links = 0,
    this.countries = 0,
    this.cost = 0,
  });
  final int chemistry, countryBonus, clubBonus, continentBonus, budgetBonus;
  final int links, countries, cost;
  int get total =>
      chemistry + countryBonus + clubBonus + continentBonus + budgetBonus;
}

class BuildXiState {
  const BuildXiState({
    required this.slotPlayers,
    required this.costs,
    this.budgetLimit = 160,
    this.isFinished = false,
    this.breakdown,
  });
  final List<SquadPlayer?> slotPlayers;
  final Map<int, int> costs;
  final int budgetLimit;
  final bool isFinished;
  final BuildXiScoreBreakdown? breakdown;
  int costOf(SquadPlayer p) => costs[p.id]!;
  int get usedBudget =>
      slotPlayers.whereType<SquadPlayer>().fold(0, (sum, p) => sum + costOf(p));
  int get remainingBudget => budgetLimit - usedBudget;
  int get filledCount => slotPlayers.whereType<SquadPlayer>().length;
  bool get isComplete => slotPlayers.length == 11 && filledCount == 11;
  BuildXiState copyWith({
    List<SquadPlayer?>? slotPlayers,
    bool? isFinished,
    BuildXiScoreBreakdown? breakdown,
  }) => BuildXiState(
    slotPlayers: slotPlayers ?? this.slotPlayers,
    costs: costs,
    budgetLimit: budgetLimit,
    isFinished: isFinished ?? this.isFinished,
    breakdown: breakdown ?? this.breakdown,
  );
}
