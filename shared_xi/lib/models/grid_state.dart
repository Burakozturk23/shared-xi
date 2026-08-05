import 'grid_criterion.dart';
import 'player.dart';

class GridCellState {
  final Player? player;
  final int rarityBonus;

  const GridCellState({this.player, this.rarityBonus = 0});

  bool get isFilled => player != null;
}

class GridPuzzleState {
  final bool isLoading;
  final bool isFinished;

  final List<GridCriterion> rowCriteria;
  final List<GridCriterion> colCriteria;

  final List<GridCellState> cells;

  final int? activeCellIndex;

  const GridPuzzleState({
    this.isLoading = true,
    this.isFinished = false,
    this.rowCriteria = const [],
    this.colCriteria = const [],
    this.cells = const [
      GridCellState(),
      GridCellState(),
      GridCellState(),
      GridCellState(),
      GridCellState(),
      GridCellState(),
      GridCellState(),
      GridCellState(),
      GridCellState(),
    ],
    this.activeCellIndex,
  });

  int get filledCount => cells.where((c) => c.isFilled).length;

  int get totalScore =>
      cells.fold(0, (sum, c) => sum + (c.isFilled ? 20 + c.rarityBonus : 0));

  Set<int> get usedPlayerIds =>
      cells.where((c) => c.isFilled).map((c) => c.player!.id).toSet();

  GridPuzzleState copyWith({
    bool? isLoading,
    bool? isFinished,
    List<GridCriterion>? rowCriteria,
    List<GridCriterion>? colCriteria,
    List<GridCellState>? cells,
    int? activeCellIndex,
    bool clearActiveCell = false,
  }) {
    return GridPuzzleState(
      isLoading: isLoading ?? this.isLoading,
      isFinished: isFinished ?? this.isFinished,
      rowCriteria: rowCriteria ?? this.rowCriteria,
      colCriteria: colCriteria ?? this.colCriteria,
      cells: cells ?? this.cells,
      activeCellIndex:
          clearActiveCell ? null : (activeCellIndex ?? this.activeCellIndex),
    );
  }
}