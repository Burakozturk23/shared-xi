import 'career_stop.dart';
import 'club.dart';
import 'player.dart';

enum CareerPuzzlePhase { guessingPlayer, orderingCareer, result }

enum CareerPuzzleDifficulty {
  beginner, // 3–4 kulüp
  normal, // 5–7
  legend, // 8+
}

class CareerPuzzleState {
  static const int playerGuessPoints = 25;
  static const int perfectOrderPoints = 75;
  static const int perfectBonusPoints = 50;
  static const int maxLives = 3;
  static const int startingCoins = 60;
  static const int jokerCost = 20;

  final bool isLoading;
  final CareerPuzzlePhase phase;
  final CareerPuzzleDifficulty difficulty;

  final Player? target;
  final List<CareerStop> correctStops;
  final List<Club> displayClubs;

  final int lives;
  final int coins;
  final int sessionScore;
  final int roundScore;

  /// Oyuncu doğru bilindi mi (+25 işlendi).
  final bool playerGuessed;

  /// Sıralama hiç bozulmadan ilk kontrol mü (mükemmel bonus için).
  final bool orderUntouched;
  final bool orderCheckedOnce;

  final Set<int> revealedEraIndexes; // display index → yıl göster
  final Set<int> shortStayMarkedClubIds; // kısa dönem / kiralık proxy
  final List<(int, int)> connectedPairs; // doğru ardışık çiftler (clubId, clubId)

  final List<bool>? resultCorrectness;

  final String? feedback;
  final bool feedbackSuccess;

  const CareerPuzzleState({
    this.isLoading = true,
    this.phase = CareerPuzzlePhase.guessingPlayer,
    this.difficulty = CareerPuzzleDifficulty.normal,
    this.target,
    this.correctStops = const [],
    this.displayClubs = const [],
    this.lives = maxLives,
    this.coins = startingCoins,
    this.sessionScore = 0,
    this.roundScore = 0,
    this.playerGuessed = false,
    this.orderUntouched = true,
    this.orderCheckedOnce = false,
    this.revealedEraIndexes = const {},
    this.shortStayMarkedClubIds = const {},
    this.connectedPairs = const [],
    this.resultCorrectness,
    this.feedback,
    this.feedbackSuccess = true,
  });

  int get stopCount => correctStops.length;

  CareerPuzzleState copyWith({
    bool? isLoading,
    CareerPuzzlePhase? phase,
    CareerPuzzleDifficulty? difficulty,
    Player? target,
    List<CareerStop>? correctStops,
    List<Club>? displayClubs,
    int? lives,
    int? coins,
    int? sessionScore,
    int? roundScore,
    bool? playerGuessed,
    bool? orderUntouched,
    bool? orderCheckedOnce,
    Set<int>? revealedEraIndexes,
    Set<int>? shortStayMarkedClubIds,
    List<(int, int)>? connectedPairs,
    List<bool>? resultCorrectness,
    String? feedback,
    bool clearFeedback = false,
    bool? feedbackSuccess,
  }) {
    return CareerPuzzleState(
      isLoading: isLoading ?? this.isLoading,
      phase: phase ?? this.phase,
      difficulty: difficulty ?? this.difficulty,
      target: target ?? this.target,
      correctStops: correctStops ?? this.correctStops,
      displayClubs: displayClubs ?? this.displayClubs,
      lives: lives ?? this.lives,
      coins: coins ?? this.coins,
      sessionScore: sessionScore ?? this.sessionScore,
      roundScore: roundScore ?? this.roundScore,
      playerGuessed: playerGuessed ?? this.playerGuessed,
      orderUntouched: orderUntouched ?? this.orderUntouched,
      orderCheckedOnce: orderCheckedOnce ?? this.orderCheckedOnce,
      revealedEraIndexes: revealedEraIndexes ?? this.revealedEraIndexes,
      shortStayMarkedClubIds:
          shortStayMarkedClubIds ?? this.shortStayMarkedClubIds,
      connectedPairs: connectedPairs ?? this.connectedPairs,
      resultCorrectness: resultCorrectness ?? this.resultCorrectness,
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      feedbackSuccess: feedbackSuccess ?? this.feedbackSuccess,
    );
  }
}