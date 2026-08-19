import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/grid_criterion.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/grid_puzzle_factory.dart';
import '../services/online_grid_service.dart';
import '../services/search_service.dart';

class OnlineGridController extends ChangeNotifier {
  OnlineGridController({
    required this.matchId,
    required this.myUid,
    required this.myName,
  });

  final String matchId;
  final String myUid;
  final String myName;

  StreamSubscription<DatabaseEvent>? _sub;
  bool _busy = false;

  List<GridCriterion> rows = const [];
  List<GridCriterion> cols = const [];
  List<String> owners = List.filled(9, '');
  List<int> cellPlayerIds = List.filled(9, 0);
  Map<String, int> scores = {};
  String? turnUid;
  String? player1Uid;
  String? player2Uid;
  String? player1Name;
  String? player2Name;
  bool gameOver = false;
  String? winnerUid;
  String? reason;
  String status = 'waiting';
  String? feedback;
  bool feedbackOk = true;
  int? activeCell;
  List<Player> suggestions = const [];

  bool get isMyTurn =>
      turnUid == myUid && !gameOver && status == 'playing' && !_busy;

  String? get opponentUid =>
      player1Uid == myUid ? player2Uid : player1Uid;

  int get myScore => scores[myUid] ?? 0;

  int get opponentScore {
    final opp = opponentUid;
    if (opp == null) return 0;
    return scores[opp] ?? 0;
  }

  String get opponentName {
    if (player1Uid == myUid) return player2Name ?? 'Rakip';
    return player1Name ?? 'Rakip';
  }

  void start() {
    _sub = OnlineGridService.watch(matchId).listen(_onData);
  }

  void _onData(DatabaseEvent event) {
    final v = event.snapshot.value;
    if (v is! Map) return;
    final data = Map<String, dynamic>.from(v);

    status = data['status']?.toString() ?? 'waiting';
    player1Uid = data['player1Uid']?.toString();
    player2Uid = data['player2Uid']?.toString();
    player1Name = data['player1Name']?.toString();
    player2Name = data['player2Name']?.toString();

    final seed = data['seed'];
    if (seed is Map && (rows.isEmpty || cols.isEmpty)) {
      final parsed = GridPuzzleFactory.fromSeedMap(
        Map<String, dynamic>.from(seed),
      );
      rows = parsed.rows;
      cols = parsed.cols;
    }

    final game = data['game'];
    if (game is Map) {
      final g = Map<String, dynamic>.from(game);
      turnUid = g['turnUid']?.toString();
      gameOver = g['gameOver'] == true;
      winnerUid = g['winnerUid']?.toString();
      reason = g['reason']?.toString();

      final o = g['owners'];
      if (o is List) {
        owners = List<String>.generate(
          9,
          (i) => i < o.length ? (o[i]?.toString() ?? '') : '',
        );
      }
      final cp = g['cellPlayerIds'];
      if (cp is List) {
        cellPlayerIds = List<int>.generate(
          9,
          (i) =>
              i < cp.length ? int.tryParse('${cp[i] ?? 0}') ?? 0 : 0,
        );
      }
      final sc = g['scores'];
      if (sc is Map) {
        scores = sc.map(
          (k, v) => MapEntry(k.toString(), int.tryParse('$v') ?? 0),
        );
      }
    }
    notifyListeners();
  }

  void selectCell(int index) {
    if (!isMyTurn) return;
    if (owners[index].isNotEmpty) return;
    activeCell = index;
    suggestions = const [];
    notifyListeners();
  }

  void cancelCell() {
    activeCell = null;
    suggestions = const [];
    notifyListeners();
  }

  void updateSuggestions(String query) {
    if (activeCell == null) return;
    final used = cellPlayerIds.where((id) => id != 0).toSet();
    suggestions = SearchService.suggestions(
      players: Repository.instance.players,
      query: query,
      excludedPlayerIds: used,
      limit: 8,
    );
    notifyListeners();
  }

  void clearSuggestions() {
    if (suggestions.isEmpty) return;
    suggestions = const [];
    notifyListeners();
  }

  Future<void> submitGuess(String rawName) async {
    final index = activeCell;
    if (index == null || !isMyTurn) return;

    final resolved = SearchService.resolve(
      players: Repository.instance.players,
      answer: rawName,
      excludedPlayerIds: cellPlayerIds.where((id) => id != 0).toSet(),
    );

    if (resolved.status == ResolveStatus.ambiguous) {
      suggestions = resolved.candidates;
      _fb('Birden fazla oyuncu. Listeden seç.', false);
      return;
    }
    if (!resolved.isFound) {
      _fb('Oyuncu bulunamadı.', false);
      await _failAndPass();
      return;
    }
    await _tryPlayer(index, resolved.player!);
  }

  Future<void> submitResolved(Player player) async {
    final index = activeCell;
    if (index == null || !isMyTurn) return;
    suggestions = const [];
    await _tryPlayer(index, player);
  }

  Future<void> _tryPlayer(int index, Player player) async {
    final row = rows[index ~/ 3];
    final col = cols[index % 3];
    if (!row.matches(player) || !col.matches(player)) {
      _fb('Bu hücreye uymuyor.', false);
      await _failAndPass();
      return;
    }

    final opp = opponentUid;
    if (opp == null) {
      _fb('Rakip yok.', false);
      return;
    }

    _busy = true;
    notifyListeners();

    final ok = await OnlineGridService.claimCell(
      matchId: matchId,
      uid: myUid,
      opponentUid: opp,
      cellIndex: index,
      playerId: player.id,
    );

    _busy = false;
    activeCell = null;
    suggestions = const [];

    if (!ok) {
      _fb('Hamle alınamadı (sıra veya hücre dolu).', false);
    } else {
      _fb('Doğru! ${player.name}', true);
    }
    notifyListeners();
  }

  Future<void> _failAndPass() async {
    activeCell = null;
    suggestions = const [];
    final opp = opponentUid;
    if (opp == null) return;
    _busy = true;
    notifyListeners();
    await OnlineGridService.passTurn(
      matchId: matchId,
      uid: myUid,
      nextUid: opp,
    );
    _busy = false;
    notifyListeners();
  }

  Future<void> pass() async {
    if (!isMyTurn) return;
    final opp = opponentUid;
    if (opp == null) return;
    _busy = true;
    notifyListeners();
    await OnlineGridService.passTurn(
      matchId: matchId,
      uid: myUid,
      nextUid: opp,
    );
    _busy = false;
    _fb('Pas.', true);
    notifyListeners();
  }

  void _fb(String msg, bool ok) {
    feedback = msg;
    feedbackOk = ok;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
