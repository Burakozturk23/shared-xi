import 'cinko_models.dart';
import 'player.dart';

class CinkoState {
  final List<CinkoCell> cells;
  final CinkoPhase phase;
  final Player? currentPlayer;
  final Set<int> usedPlayerIds;
  final int score;
  final String? feedback;
  final bool feedbackIsSuccess;
  final bool isLoading;

  const CinkoState({
    this.cells = const [],
    this.phase = CinkoPhase.enterPlayer,
    this.currentPlayer,
    this.usedPlayerIds = const {},
    this.score = 0,
    this.feedback,
    this.feedbackIsSuccess = true,
    this.isLoading = true,
  });

  int get gridSize {
    final n = cells.length;
    if (n == 0) return 5;
    return (n == 36) ? 6 : 5;
  }

  int get paintedCount =>
      cells.where((c) => c.status == CinkoCellStatus.correct).length;

  int get totalCells => cells.length;

  bool get allPainted =>
      cells.isNotEmpty &&
      cells.every((c) => c.status == CinkoCellStatus.correct);

  int get selectedCount =>
      cells.where((c) => c.status == CinkoCellStatus.selected).length;

  CinkoState copyWith({
    List<CinkoCell>? cells,
    CinkoPhase? phase,
    Player? currentPlayer,
    Set<int>? usedPlayerIds,
    int? score,
    String? feedback,
    bool? feedbackIsSuccess,
    bool? isLoading,
    bool clearPlayer = false,
    bool clearFeedback = false,
  }) {
    return CinkoState(
      cells: cells ?? this.cells,
      phase: phase ?? this.phase,
      currentPlayer: clearPlayer ? null : (currentPlayer ?? this.currentPlayer),
      usedPlayerIds: usedPlayerIds ?? this.usedPlayerIds,
      score: score ?? this.score,
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      feedbackIsSuccess: feedbackIsSuccess ?? this.feedbackIsSuccess,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}