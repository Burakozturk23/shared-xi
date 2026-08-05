import 'club.dart';
import 'grid_state.dart';
import 'player.dart';

class RandomGridState {
  static const List<int> anchorIndices = [2, 4, 6]; // sağ üst, orta, sol alt

  final bool isLoading;
  final bool isFinished;

  final int roundsUsed;
  final List<Club?> rowClubs;
  final List<Club?> colClubs;
  final List<GridCellState> cells;

  final Club? pendingClubA;
  final Club? pendingClubB;
  final Player? pendingPlayer;

  const RandomGridState({
    this.isLoading = true,
    this.isFinished = false,
    this.roundsUsed = 0,
    this.rowClubs = const [null, null, null],
    this.colClubs = const [null, null, null],
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
    this.pendingClubA,
    this.pendingClubB,
    this.pendingPlayer,
  });

  List<int> get availableAnchors =>
      anchorIndices.where((i) => !cells[i].isFilled).toList();

  bool get hasPendingPair => pendingClubA != null && pendingClubB != null;
  bool get hasPendingPlayer => pendingPlayer != null;

  int get filledCount => cells.where((c) => c.isFilled).length;

  int get totalScore =>
      cells.fold(0, (sum, c) => sum + (c.isFilled ? 20 + c.rarityBonus : 0));

  Set<int> get usedPlayerIds =>
      cells.where((c) => c.isFilled).map((c) => c.player!.id).toSet();

  RandomGridState copyWith({
    bool? isLoading,
    bool? isFinished,
    int? roundsUsed,
    List<Club?>? rowClubs,
    List<Club?>? colClubs,
    List<GridCellState>? cells,
    Club? pendingClubA,
    Club? pendingClubB,
    Player? pendingPlayer,
    bool clearPending = false,
  }) {
    return RandomGridState(
      isLoading: isLoading ?? this.isLoading,
      isFinished: isFinished ?? this.isFinished,
      roundsUsed: roundsUsed ?? this.roundsUsed,
      rowClubs: rowClubs ?? this.rowClubs,
      colClubs: colClubs ?? this.colClubs,
      cells: cells ?? this.cells,
      pendingClubA: clearPending ? null : (pendingClubA ?? this.pendingClubA),
      pendingClubB: clearPending ? null : (pendingClubB ?? this.pendingClubB),
      pendingPlayer:
          clearPending ? null : (pendingPlayer ?? this.pendingPlayer),
    );
  }
}