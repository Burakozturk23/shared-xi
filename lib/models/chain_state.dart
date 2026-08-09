import 'club.dart';
import 'player.dart';

enum ChainGameMode { blitz, mastermind }

enum ChainPhase { pickingPlayer, pickingNextClub }

class ChainLink {
  final Player player;
  final Club fromClub;
  final Club toClub;

  const ChainLink({
    required this.player,
    required this.fromClub,
    required this.toClub,
  });
}

class ChainState {
  static const int blitzStartSeconds = 60;
  static const int blitzBonusSeconds = 5;
  static const int maxMastermindMoves = 8;

  final ChainGameMode mode;
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

  /// Mastermind: en kısa yol (oyuncu sayısı).
  final int par;

  final int secondsLeft;
  final int streak;
  final int sessionScore;
  final int coins;

  final String? feedback;
  final bool feedbackSuccess;
  final String? bridgeHint;

  /// Milli takım joker: bir sonraki seçimde milli bağa izin.
  final bool nationalWildcardActive;

  const ChainState({
    this.mode = ChainGameMode.mastermind,
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
    this.par = 2,
    this.secondsLeft = blitzStartSeconds,
    this.streak = 0,
    this.sessionScore = 0,
    this.coins = 40,
    this.feedback,
    this.feedbackSuccess = false,
    this.bridgeHint,
    this.nationalWildcardActive = false,
  });

  int get moves => links.length;

  int get mastermindScore {
    if (!isSolved) return 0;
    final over = moves - par;
    if (over <= 0) return 100;
    if (over == 1) return 70;
    return 40;
  }

  ChainState copyWith({
    ChainGameMode? mode,
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
    int? par,
    int? secondsLeft,
    int? streak,
    int? sessionScore,
    int? coins,
    String? feedback,
    bool clearFeedback = false,
    bool? feedbackSuccess,
    String? bridgeHint,
    bool clearBridgeHint = false,
    bool? nationalWildcardActive,
  }) {
    return ChainState(
      mode: mode ?? this.mode,
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
      par: par ?? this.par,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      streak: streak ?? this.streak,
      sessionScore: sessionScore ?? this.sessionScore,
      coins: coins ?? this.coins,
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      feedbackSuccess: feedbackSuccess ?? this.feedbackSuccess,
      bridgeHint: clearBridgeHint ? null : (bridgeHint ?? this.bridgeHint),
      nationalWildcardActive:
          nationalWildcardActive ?? this.nationalWildcardActive,
    );
  }
}