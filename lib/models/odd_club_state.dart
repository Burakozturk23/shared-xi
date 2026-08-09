import 'club.dart';
import 'player.dart';

class OddClubState {
  static const int maxLives = 3;
  static const int questionSeconds = 10;
  static const int quickStrikeSeconds = 3;

  final bool isLoading;
  final bool isGameOver;

  final Player? player;
  final List<Club> options; // 4 options
  final int fakeIndex;

  final int? selectedIndex;
  final bool answered;
  final bool wasCorrect;

  final int lives;
  final int streak;
  final int bestStreak;
  final int score;

  final int secondsLeft;
  /// Soru başlangıcı — quick strike için.
  final DateTime? questionStartedAt;

  final String? factLine;
  final String? feedback;

  /// 50% joker: gizlenen gerçek kulüp indeksi.
  final int? eliminatedIndex;

  /// Sahte "milletin tercihi" yüzdeleri (options ile aynı uzunluk).
  final List<int>? crowdPercents;

  final int jokers5050Left;
  final int jokersCrowdLeft;

  const OddClubState({
    this.isLoading = true,
    this.isGameOver = false,
    this.player,
    this.options = const [],
    this.fakeIndex = -1,
    this.selectedIndex,
    this.answered = false,
    this.wasCorrect = false,
    this.lives = maxLives,
    this.streak = 0,
    this.bestStreak = 0,
    this.score = 0,
    this.secondsLeft = questionSeconds,
    this.questionStartedAt,
    this.factLine,
    this.feedback,
    this.eliminatedIndex,
    this.crowdPercents,
    this.jokers5050Left = 2,
    this.jokersCrowdLeft = 2,
  });

  double get streakMultiplier {
    if (streak >= 10) return 3.0;
    if (streak >= 5) return 2.0;
    if (streak >= 3) return 1.5;
    return 1.0;
  }

  OddClubState copyWith({
    bool? isLoading,
    bool? isGameOver,
    Player? player,
    List<Club>? options,
    int? fakeIndex,
    int? selectedIndex,
    bool clearSelected = false,
    bool? answered,
    bool? wasCorrect,
    int? lives,
    int? streak,
    int? bestStreak,
    int? score,
    int? secondsLeft,
    DateTime? questionStartedAt,
    String? factLine,
    bool clearFact = false,
    String? feedback,
    bool clearFeedback = false,
    int? eliminatedIndex,
    bool clearEliminated = false,
    List<int>? crowdPercents,
    bool clearCrowd = false,
    int? jokers5050Left,
    int? jokersCrowdLeft,
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
      wasCorrect: wasCorrect ?? this.wasCorrect,
      lives: lives ?? this.lives,
      streak: streak ?? this.streak,
      bestStreak: bestStreak ?? this.bestStreak,
      score: score ?? this.score,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      questionStartedAt: questionStartedAt ?? this.questionStartedAt,
      factLine: clearFact ? null : (factLine ?? this.factLine),
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      eliminatedIndex:
          clearEliminated ? null : (eliminatedIndex ?? this.eliminatedIndex),
      crowdPercents: clearCrowd ? null : (crowdPercents ?? this.crowdPercents),
      jokers5050Left: jokers5050Left ?? this.jokers5050Left,
      jokersCrowdLeft: jokersCrowdLeft ?? this.jokersCrowdLeft,
    );
  }
}