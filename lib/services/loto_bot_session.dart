import '../models/loto_models.dart';
import '../models/player.dart';
import 'loto_generator.dart';
import 'runtime_v4/game_data_v4_query_service.dart';

typedef LotoSessionLoader = Future<LotoBotSession> Function(
  String? league,
  LotoDifficulty difficulty,
);

/// Identity and scoring use the same V4 generation pass, not the legacy matcher.
class LotoBotSession {
  LotoBotSession({required this.board, required Map<int, Player> players})
      : players = Map.unmodifiable(players);

  final LotoBoard board;
  final Map<int, Player> players;

  static Future<LotoBotSession> load(
    String? league,
    LotoDifficulty difficulty,
  ) async {
    final board = await LotoGenerator.generateRuntime(
      leagueFilter: league,
      difficulty: difficulty,
    );
    if (board == null) throw StateError('No complete V4 Loto board.');
    final players = <int, Player>{};
    for (final id in board.playerQueue) {
      final rows = await GameDataV4QueryService.instance.playersByIds(<int>[id]);
      if (rows.isEmpty) throw StateError('Missing Loto player $id.');
      // V4 may remap a legacy exposed id while hydrating a Player. Keep the
      // board's exposed id as the session key so queue, answer map and UI stay
      // aligned even when that bridge is used.
      players[id] = rows.first;
    }
    return LotoBotSession(
      board: board,
      players: players,
    );
  }

  /// A complete one-player-per-cell solution must exist before clocks start.
  bool get isPlayable {
    if (board.cells.length != 16 || board.playerQueue.length != 16 ||
        board.playerQueue.toSet().length != 16) return false;
    for (var i = 0; i < 16; i++) {
      if (board.cells[i].cellIndex != i ||
          board.cells[i].label.trim().isEmpty) return false;
    }
    for (final id in board.playerQueue) {
      final player = players[id];
      final cells = board.validCellsForPlayer[id];
      if (player == null || player.name.trim().isEmpty ||
          cells == null || cells.isEmpty ||
          cells.any((cell) => cell < 0 || cell >= 16)) return false;
    }
    final owners = <int, int>{};
    bool assign(int id, Set<int> visited) {
      for (final cell in board.validCellsForPlayer[id]!) {
        if (!visited.add(cell)) continue;
        final owner = owners[cell];
        if (owner == null || assign(owner, visited)) {
          owners[cell] = id;
          return true;
        }
      }
      return false;
    }
    return board.playerQueue.every((id) => assign(id, <int>{}));
  }
}
