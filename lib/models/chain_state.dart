import 'club.dart';
import 'player.dart';

enum ChainPhase { pickingPlayer, pickingNextClub }

class ChainLink {
  final Player player;
  final Club fromClub;
  final Club toClub;
  final int rarityBonus;

  const ChainLink({
    required this.player,
    required this.fromClub,
    required this.toClub,
    required this.rarityBonus,
  });
}

class ChainState {
  final Club? startClub;
  final Club? targetClub;
  final Club? currentClub;

  final bool isLoading;
  final bool isSolved;
  final bool isFailed;

  final ChainPhase phase;

  final List<ChainLink> links;
  final Set<int> visitedClubIds;

  final String playerQuery;
  final List<Player> playerCandidates;

  final Player? selectedPlayer;
  final List<Club> nextClubOptions;

  static const int maxMoves = 6;

  const ChainState({
    this.startClub,
    this.targetClub,
    this.currentClub,
    this.isLoading = true,
    this.isSolved = false,
    this.isFailed = false,
    this.phase = ChainPhase.pickingPlayer,
    this.links = const [],
    this.visitedClubIds = const {},
    this.playerQuery = '',
    this.playerCandidates = const [],
    this.selectedPlayer,
    this.nextClubOptions = const [],
  });

  int get moves => links.length;

  int get stars {
    if (moves <= 2) return 3;
    if (moves == 3) return 2;
    return 1;
  }

  int get basePoints {
    final base = 100 - (moves - 2) * 20;
    return base < 20 ? 20 : base;
  }

  int get rarityBonusTotal =>
      links.fold(0, (sum, link) => sum + link.rarityBonus);

  int get totalScore => isSolved ? basePoints + rarityBonusTotal : 0;

  ChainState copyWith({
    Club? startClub,
    Club? targetClub,
    Club? currentClub,
    bool? isLoading,
    bool? isSolved,
    bool? isFailed,
    ChainPhase? phase,
    List<ChainLink>? links,
    Set<int>? visitedClubIds,
    String? playerQuery,
    List<Player>? playerCandidates,
    Player? selectedPlayer,
    bool clearSelectedPlayer = false,
    List<Club>? nextClubOptions,
  }) {
    return ChainState(
      startClub: startClub ?? this.startClub,
      targetClub: targetClub ?? this.targetClub,
      currentClub: currentClub ?? this.currentClub,
      isLoading: isLoading ?? this.isLoading,
      isSolved: isSolved ?? this.isSolved,
      isFailed: isFailed ?? this.isFailed,
      phase: phase ?? this.phase,
      links: links ?? this.links,
      visitedClubIds: visitedClubIds ?? this.visitedClubIds,
      playerQuery: playerQuery ?? this.playerQuery,
      playerCandidates: playerCandidates ?? this.playerCandidates,
      selectedPlayer:
          clearSelectedPlayer ? null : (selectedPlayer ?? this.selectedPlayer),
      nextClubOptions: nextClubOptions ?? this.nextClubOptions,
    );
  }
}