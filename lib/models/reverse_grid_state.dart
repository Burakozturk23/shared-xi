import 'grid_criterion.dart';
import 'player.dart';

class ReverseGridState {
  final bool isLoading;
  final bool isFinished;

  final List<GridCriterion> rowCriteria;
  final List<GridCriterion> colCriteria;
  final List<Player> cellPlayers;

  final List<String?> rowGuessText;
  final List<bool> rowCorrect;
  final List<String?> colGuessText;
  final List<bool> colCorrect;

  const ReverseGridState({
    this.isLoading = true,
    this.isFinished = false,
    this.rowCriteria = const [],
    this.colCriteria = const [],
    this.cellPlayers = const [],
    this.rowGuessText = const [null, null, null],
    this.rowCorrect = const [false, false, false],
    this.colGuessText = const [null, null, null],
    this.colCorrect = const [false, false, false],
  });

  int get correctCount =>
      rowCorrect.where((c) => c).length + colCorrect.where((c) => c).length;

  int get totalScore => correctCount * 40;

  ReverseGridState copyWith({
    bool? isLoading,
    bool? isFinished,
    List<GridCriterion>? rowCriteria,
    List<GridCriterion>? colCriteria,
    List<Player>? cellPlayers,
    List<String?>? rowGuessText,
    List<bool>? rowCorrect,
    List<String?>? colGuessText,
    List<bool>? colCorrect,
  }) {
    return ReverseGridState(
      isLoading: isLoading ?? this.isLoading,
      isFinished: isFinished ?? this.isFinished,
      rowCriteria: rowCriteria ?? this.rowCriteria,
      colCriteria: colCriteria ?? this.colCriteria,
      cellPlayers: cellPlayers ?? this.cellPlayers,
      rowGuessText: rowGuessText ?? this.rowGuessText,
      rowCorrect: rowCorrect ?? this.rowCorrect,
      colGuessText: colGuessText ?? this.colGuessText,
      colCorrect: colCorrect ?? this.colCorrect,
    );
  }
}