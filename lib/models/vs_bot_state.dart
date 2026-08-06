import 'club.dart';
import 'player.dart';

enum VsBotPhase {
  countdown,
  racing,
  roundOver,
  matchOver,
}

class VsBotState {
  final Club? userClub;
  final Club? opponentClub;

  final List<Player> matchingPlayers;
  final Set<int> foundByUser;
  final Set<int> foundByBot;
  final List<Player> userFoundList;
  final List<Player> botFoundList;

  final int userScore;
  final int botScore;
  final int userRoundWins;
  final int botRoundWins;

  final int countdownLeft;
  final VsBotPhase phase;

  final String? feedback;
  final bool feedbackIsSuccess;
  final String? lastBotFind;

  final bool isLoading;

  const VsBotState({
    this.userClub,
    this.opponentClub,
    this.matchingPlayers = const [],
    this.foundByUser = const {},
    this.foundByBot = const {},
    this.userFoundList = const [],
    this.botFoundList = const [],
    this.userScore = 0,
    this.botScore = 0,
    this.userRoundWins = 0,
    this.botRoundWins = 0,
    this.countdownLeft = 3,
    this.phase = VsBotPhase.countdown,
    this.feedback,
    this.feedbackIsSuccess = true,
    this.lastBotFind,
    this.isLoading = true,
  });

  Set<int> get allFoundIds => {...foundByUser, ...foundByBot};

  int get remainingCount =>
      matchingPlayers.where((p) => !allFoundIds.contains(p.id)).length;

  VsBotState copyWith({
    Club? userClub,
    Club? opponentClub,
    List<Player>? matchingPlayers,
    Set<int>? foundByUser,
    Set<int>? foundByBot,
    List<Player>? userFoundList,
    List<Player>? botFoundList,
    int? userScore,
    int? botScore,
    int? userRoundWins,
    int? botRoundWins,
    int? countdownLeft,
    VsBotPhase? phase,
    String? feedback,
    bool? feedbackIsSuccess,
    String? lastBotFind,
    bool? isLoading,
    bool clearFeedback = false,
    bool clearLastBotFind = false,
  }) {
    return VsBotState(
      userClub: userClub ?? this.userClub,
      opponentClub: opponentClub ?? this.opponentClub,
      matchingPlayers: matchingPlayers ?? this.matchingPlayers,
      foundByUser: foundByUser ?? this.foundByUser,
      foundByBot: foundByBot ?? this.foundByBot,
      userFoundList: userFoundList ?? this.userFoundList,
      botFoundList: botFoundList ?? this.botFoundList,
      userScore: userScore ?? this.userScore,
      botScore: botScore ?? this.botScore,
      userRoundWins: userRoundWins ?? this.userRoundWins,
      botRoundWins: botRoundWins ?? this.botRoundWins,
      countdownLeft: countdownLeft ?? this.countdownLeft,
      phase: phase ?? this.phase,
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      feedbackIsSuccess: feedbackIsSuccess ?? this.feedbackIsSuccess,
      lastBotFind: clearLastBotFind ? null : (lastBotFind ?? this.lastBotFind),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}