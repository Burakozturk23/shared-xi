import 'grid_criterion.dart';
import 'player.dart';

enum VsBotGridFilledBy { user, bot }

class VsBotGridCell {
  final Player? player;
  final VsBotGridFilledBy? filledBy;
  final int rarityBonus;

  const VsBotGridCell({
    this.player,
    this.filledBy,
    this.rarityBonus = 0,
  });

  bool get isFilled => player != null;

  VsBotGridCell copyWith({
    Player? player,
    VsBotGridFilledBy? filledBy,
    int? rarityBonus,
  }) {
    return VsBotGridCell(
      player: player ?? this.player,
      filledBy: filledBy ?? this.filledBy,
      rarityBonus: rarityBonus ?? this.rarityBonus,
    );
  }
}

enum VsBotGridPhase { countdown, racing, finished }

class VsBotGridState {
  final bool isLoading;
  final VsBotGridPhase phase;
  final int countdownLeft;

  final List<GridCriterion> rowCriteria;
  final List<GridCriterion> colCriteria;
  final List<VsBotGridCell> cells;

  final int userScore;
  final int botScore;
  final String? feedback;
  final bool feedbackIsSuccess;
  final int? activeCellIndex;

  const VsBotGridState({
    this.isLoading = true,
    this.phase = VsBotGridPhase.countdown,
    this.countdownLeft = 3,
    this.rowCriteria = const [],
    this.colCriteria = const [],
    this.cells = const [
      VsBotGridCell(),
      VsBotGridCell(),
      VsBotGridCell(),
      VsBotGridCell(),
      VsBotGridCell(),
      VsBotGridCell(),
      VsBotGridCell(),
      VsBotGridCell(),
      VsBotGridCell(),
    ],
    this.userScore = 0,
    this.botScore = 0,
    this.feedback,
    this.feedbackIsSuccess = true,
    this.activeCellIndex,
  });

  int get filledCount => cells.where((c) => c.isFilled).length;

  int get userFilledCount =>
      cells.where((c) => c.filledBy == VsBotGridFilledBy.user).length;

  int get botFilledCount =>
      cells.where((c) => c.filledBy == VsBotGridFilledBy.bot).length;

  Set<int> get usedPlayerIds =>
      cells.where((c) => c.isFilled).map((c) => c.player!.id).toSet();

  List<int> get emptyIndexes {
    final list = <int>[];
    for (var i = 0; i < cells.length; i++) {
      if (!cells[i].isFilled) list.add(i);
    }
    return list;
  }

  VsBotGridState copyWith({
    bool? isLoading,
    VsBotGridPhase? phase,
    int? countdownLeft,
    List<GridCriterion>? rowCriteria,
    List<GridCriterion>? colCriteria,
    List<VsBotGridCell>? cells,
    int? userScore,
    int? botScore,
    String? feedback,
    bool? feedbackIsSuccess,
    int? activeCellIndex,
    bool clearFeedback = false,
    bool clearActiveCell = false,
  }) {
    return VsBotGridState(
      isLoading: isLoading ?? this.isLoading,
      phase: phase ?? this.phase,
      countdownLeft: countdownLeft ?? this.countdownLeft,
      rowCriteria: rowCriteria ?? this.rowCriteria,
      colCriteria: colCriteria ?? this.colCriteria,
      cells: cells ?? this.cells,
      userScore: userScore ?? this.userScore,
      botScore: botScore ?? this.botScore,
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      feedbackIsSuccess: feedbackIsSuccess ?? this.feedbackIsSuccess,
      activeCellIndex:
          clearActiveCell ? null : (activeCellIndex ?? this.activeCellIndex),
    );
  }
}