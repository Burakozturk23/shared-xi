import 'player.dart';

enum MysteryHintKind {
  nationality, // -10
  position, // -10
  clubCount, // -10
  leagues, // -15
  careerStats, // -20
  oneClub, // -15
  marketValue, // -15
  starTeammate, // -25
}

class MysteryHint {
  final MysteryHintKind kind;
  final String title;
  final String text;
  final int cost;
  final bool unlocked;

  const MysteryHint({
    required this.kind,
    required this.title,
    required this.text,
    required this.cost,
    this.unlocked = false,
  });

  MysteryHint copyWith({bool? unlocked}) => MysteryHint(
        kind: kind,
        title: title,
        text: text,
        cost: cost,
        unlocked: unlocked ?? this.unlocked,
      );
}

class MysteryPlayerState {
  static const int maxLives = 3;
  static const int baseRoundPoints = 100;
  static const int startingCoins = 100;
  static const int letterRevealCost = 20;
  static const int speedBonusSeconds = 10;

  final bool isLoading;
  final Player? target;

  final List<MysteryHint> hints;

  /// Yanlış tahmin hakkı (kalp).
  final int lives;

  final int streak;
  final int sessionScore;

  final int coins;

  /// Bu turda kalan ham puan (100 - açılan ipuçları).
  final int roundPoints;

  final bool isSolved;
  final bool isFailed;

  final List<String> wrongGuesses;

  /// Harf jokerinden açılan harf indeksleri (ismdeki).
  final Set<int> revealedLetterIndexes;

  /// Tur başlangıç zamanı (hız çarpanı için).
  final DateTime? roundStartedAt;

  final String? feedback;
  final bool feedbackSuccess;

  const MysteryPlayerState({
    this.isLoading = true,
    this.target,
    this.hints = const [],
    this.lives = maxLives,
    this.streak = 0,
    this.sessionScore = 0,
    this.coins = startingCoins,
    this.roundPoints = baseRoundPoints,
    this.isSolved = false,
    this.isFailed = false,
    this.wrongGuesses = const [],
    this.revealedLetterIndexes = const {},
    this.roundStartedAt,
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

  int get unlockedHintCount => hints.where((h) => h.unlocked).length;

  /// Hız bonusu hâlâ geçerli mi (tur başından 10 sn).
  bool get speedBonusActive {
    final start = roundStartedAt;
    if (start == null) return false;
    return DateTime.now().difference(start).inSeconds < speedBonusSeconds;
  }

  /// Tahmin doğru olursa kazanılacak tahmini puan (çarpanlar hariç ham * seri; hız UI'da gösterilir).
  int get potentialPoints {
    final withStreak = (roundPoints * streakMultiplier).round();
    return withStreak;
  }

  MysteryPlayerState copyWith({
    bool? isLoading,
    Player? target,
    List<MysteryHint>? hints,
    int? lives,
    int? streak,
    int? sessionScore,
    int? coins,
    int? roundPoints,
    bool? isSolved,
    bool? isFailed,
    List<String>? wrongGuesses,
    Set<int>? revealedLetterIndexes,
    DateTime? roundStartedAt,
    bool clearRoundStarted = false,
    String? feedback,
    bool clearFeedback = false,
    bool? feedbackSuccess,
  }) {
    return MysteryPlayerState(
      isLoading: isLoading ?? this.isLoading,
      target: target ?? this.target,
      hints: hints ?? this.hints,
      lives: lives ?? this.lives,
      streak: streak ?? this.streak,
      sessionScore: sessionScore ?? this.sessionScore,
      coins: coins ?? this.coins,
      roundPoints: roundPoints ?? this.roundPoints,
      isSolved: isSolved ?? this.isSolved,
      isFailed: isFailed ?? this.isFailed,
      wrongGuesses: wrongGuesses ?? this.wrongGuesses,
      revealedLetterIndexes:
          revealedLetterIndexes ?? this.revealedLetterIndexes,
      roundStartedAt:
          clearRoundStarted ? null : (roundStartedAt ?? this.roundStartedAt),
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      feedbackSuccess: feedbackSuccess ?? this.feedbackSuccess,
    );
  }
}