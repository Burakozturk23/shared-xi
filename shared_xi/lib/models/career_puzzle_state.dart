import 'career_stop.dart';
import 'club.dart';
import 'player.dart';

enum CareerPuzzlePhase { guessingPlayer, orderingCareer, result }

class CareerPuzzleState {
  static const int stopCount = 5;

  final bool isLoading;
  final CareerPuzzlePhase phase;

  final Player? target;
  final List<CareerStop> correctStops; // kronolojik doğru sıra
  final List<Club> displayClubs; // kullanıcının o anki dizilişi

  final String? feedback;
  final bool feedbackSuccess;

  final List<bool>? resultCorrectness;

  const CareerPuzzleState({
    this.isLoading = true,
    this.phase = CareerPuzzlePhase.guessingPlayer,
    this.target,
    this.correctStops = const [],
    this.displayClubs = const [],
    this.feedback,
    this.feedbackSuccess = true,
    this.resultCorrectness,
  });

  int get orderScore {
    if (resultCorrectness == null) return 0;
    var sum = 0;
    for (final correct in resultCorrectness!) {
      if (correct) sum += 10;
    }
    return sum;
  }

  int get guessScore => phase == CareerPuzzlePhase.guessingPlayer ? 0 : 50;

  int get totalScore => guessScore + orderScore;

  CareerPuzzleState copyWith({
    bool? isLoading,
    CareerPuzzlePhase? phase,
    Player? target,
    List<CareerStop>? correctStops,
    List<Club>? displayClubs,
    String? feedback,
    bool? feedbackSuccess,
    List<bool>? resultCorrectness,
  }) {
    return CareerPuzzleState(
      isLoading: isLoading ?? this.isLoading,
      phase: phase ?? this.phase,
      target: target ?? this.target,
      correctStops: correctStops ?? this.correctStops,
      displayClubs: displayClubs ?? this.displayClubs,
      feedback: feedback,
      feedbackSuccess: feedbackSuccess ?? this.feedbackSuccess,
      resultCorrectness: resultCorrectness ?? this.resultCorrectness,
    );
  }
}