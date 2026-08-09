import 'club.dart';
import 'famous_transfer.dart';
import 'player.dart';

enum TransferHintKind {
  nationality,
  position,
  fromClub,
  careerGoals,
}

class TransferHint {
  final TransferHintKind kind;
  final String title;
  final String text;
  final int cost;
  final bool unlocked;
  final String? logoUrl;

  const TransferHint({
    required this.kind,
    required this.title,
    required this.text,
    required this.cost,
    this.unlocked = false,
    this.logoUrl,
  });

  TransferHint copyWith({bool? unlocked}) => TransferHint(
        kind: kind,
        title: title,
        text: text,
        cost: cost,
        unlocked: unlocked ?? this.unlocked,
        logoUrl: logoUrl,
      );
}

class TransferDetectiveState {
  static const int maxLives = 3;
  static const int baseRoundPoints = 100;
  static const int letterRevealCost = 15;
  static const int startingCoins = 80;

  final bool isLoading;
  final bool isSolved;
  final bool isFailed;

  final Player? target;
  final FamousTransfer? transfer;
  final Club? fromClub;
  final Club? toClub;

  final List<TransferHint> hints;

  final int lives;
  final int streak;
  final int sessionScore;
  final int coins;
  final int roundPoints;

  final List<String> wrongGuesses;
  final Set<int> revealedLetterIndexes;

  final String? feedback;
  final bool feedbackSuccess;

  const TransferDetectiveState({
    this.isLoading = true,
    this.isSolved = false,
    this.isFailed = false,
    this.target,
    this.transfer,
    this.fromClub,
    this.toClub,
    this.hints = const [],
    this.lives = maxLives,
    this.streak = 0,
    this.sessionScore = 0,
    this.coins = startingCoins,
    this.roundPoints = baseRoundPoints,
    this.wrongGuesses = const [],
    this.revealedLetterIndexes = const {},
    this.feedback,
    this.feedbackSuccess = false,
  });

  double get streakMultiplier {
    if (streak >= 4) return 2.0;
    if (streak >= 3) return 1.5;
    if (streak >= 2) return 1.2;
    return 1.0;
  }

  String get streakMultiplierLabel => '${streakMultiplier}x';

  int get potentialPoints => (roundPoints * streakMultiplier).round();

  /// Sıradaki kilitli ipucu indeksi (yoksa null).
  int? get nextLockedHintIndex {
    for (var i = 0; i < hints.length; i++) {
      if (!hints[i].unlocked) return i;
    }
    return null;
  }

  TransferDetectiveState copyWith({
    bool? isLoading,
    bool? isSolved,
    bool? isFailed,
    Player? target,
    FamousTransfer? transfer,
    Club? fromClub,
    Club? toClub,
    List<TransferHint>? hints,
    int? lives,
    int? streak,
    int? sessionScore,
    int? coins,
    int? roundPoints,
    List<String>? wrongGuesses,
    Set<int>? revealedLetterIndexes,
    String? feedback,
    bool clearFeedback = false,
    bool? feedbackSuccess,
  }) {
    return TransferDetectiveState(
      isLoading: isLoading ?? this.isLoading,
      isSolved: isSolved ?? this.isSolved,
      isFailed: isFailed ?? this.isFailed,
      target: target ?? this.target,
      transfer: transfer ?? this.transfer,
      fromClub: fromClub ?? this.fromClub,
      toClub: toClub ?? this.toClub,
      hints: hints ?? this.hints,
      lives: lives ?? this.lives,
      streak: streak ?? this.streak,
      sessionScore: sessionScore ?? this.sessionScore,
      coins: coins ?? this.coins,
      roundPoints: roundPoints ?? this.roundPoints,
      wrongGuesses: wrongGuesses ?? this.wrongGuesses,
      revealedLetterIndexes:
          revealedLetterIndexes ?? this.revealedLetterIndexes,
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      feedbackSuccess: feedbackSuccess ?? this.feedbackSuccess,
    );
  }
}