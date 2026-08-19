import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/grid_criterion.dart';
import '../models/grid_sub_type.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/grid_puzzle_factory.dart';
import '../services/online_grid_service.dart';
import '../services/search_service.dart';
import '../services/profile_service.dart';

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
  Timer? _turnTick;
  bool _busy = false;
  bool _autoPassedThisTurn = false;
  int? _turnDeadlineMs; // server ms

  /// Tur süresi (saniye)
  static const int turnSeconds = 45;
  int turnSecondsLeft = turnSeconds;

  GridSubType subType = GridSubType.classic;

  List<GridCriterion> rows = const [];
  List<GridCriterion> cols = const [];
  List<String> owners = List.filled(9, '');
  List<int> cellPlayerIds = List.filled(9, 0);
  int? activeCell;

  List<Map<String, dynamic>> randomRounds = const [];
  int roundIndex = 0;

  List<int> reverseCellPlayerIds = const [];
  List<String> rowAnswers = const [];
  List<String> colAnswers = const [];
  Map<String, String> axisOwners = {};
  String? activeAxisKey;

  Map<String, int> scores = {};
  Set<int> usedPlayerIds = {};
  String? turnUid;
  String? player1Uid;
  String? player2Uid;
  String? player1Name;
  String? player2Name;
  bool gameOver = false;
  String? winnerUid;
  String? reason;
  String status = 'waiting';
  bool ranked = false;
  bool _eloRecorded = false;
  int? lastEloDelta;
  String? feedback;
  bool feedbackOk = true;
  List<Player> suggestions = const [];

  bool get isMyTurn =>
      turnUid == myUid && !gameOver && status == 'playing' && !_busy;

  String? get opponentUid =>
      player1Uid == myUid ? player2Uid : player1Uid;

  int get myScore => scores[myUid] ?? 0;

  int get opponentScore {
    final o = opponentUid;
    return o == null ? 0 : (scores[o] ?? 0);
  }

  String get opponentName {
    if (player1Uid == myUid) return player2Name ?? 'Rakip';
    return player1Name ?? 'Rakip';
  }

  Map<String, dynamic>? get currentRandomRound {
    if (roundIndex < 0 || roundIndex >= randomRounds.length) return null;
    return randomRounds[roundIndex];
  }

  void start() {
    _sub = OnlineGridService.watch(matchId).listen(_onData);
  }

  void _ensureTurnTicker() {
    _turnTick ??=
        Timer.periodic(const Duration(seconds: 1), (_) => _onTurnTick());
  }

  void _onTurnTick() {
    if (gameOver || status != 'playing' || turnUid == null) {
      if (turnSecondsLeft != turnSeconds) {
        turnSecondsLeft = turnSeconds;
        notifyListeners();
      }
      return;
    }

    int left;
    if (_turnDeadlineMs != null) {
      // turnDeadline = turun başladığı server timestamp
      final elapsed =
          (DateTime.now().millisecondsSinceEpoch - _turnDeadlineMs!) ~/ 1000;
      left = (turnSeconds - elapsed).clamp(0, turnSeconds);
    } else {
      left = turnSeconds;
    }

    if (left != turnSecondsLeft) {
      turnSecondsLeft = left;
      notifyListeners();
    }

    if (turnUid == myUid &&
        turnSecondsLeft <= 0 &&
        !_autoPassedThisTurn &&
        !_busy &&
        !gameOver) {
      _autoPassedThisTurn = true;
      _fb('Süre doldu — pas.', false);
      unawaited(pass());
    }
  }

  void _onData(DatabaseEvent event) {
    final v = event.snapshot.value;
    if (v is! Map) return;
    final data = Map<String, dynamic>.from(v);

    status = data['status']?.toString() ?? 'waiting';
    ranked = data['ranked'] == true;
    player1Uid = data['player1Uid']?.toString();
    player2Uid = data['player2Uid']?.toString();
    player1Name = data['player1Name']?.toString();
    player2Name = data['player2Name']?.toString();
    subType = GridSubType.fromId(data['subType']?.toString());

    final seed = data['seed'];
    if (seed is Map) {
      final s = Map<String, dynamic>.from(seed);
      switch (subType) {
        case GridSubType.classic:
          if (rows.isEmpty) {
            final parsed = GridPuzzleFactory.classicFromSeed(s);
            rows = parsed.rows;
            cols = parsed.cols;
          }
        case GridSubType.random:
          if (randomRounds.isEmpty) {
            final list = s['rounds'] as List? ?? [];
            randomRounds = list
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          }
        case GridSubType.reverse:
          if (reverseCellPlayerIds.isEmpty) {
            reverseCellPlayerIds = (s['cellPlayerIds'] as List? ?? [])
                .map((e) => int.tryParse('$e') ?? 0)
                .toList();
            rowAnswers = (s['rowAnswers'] as List? ?? [])
                .map((e) => e.toString())
                .toList();
            colAnswers = (s['colAnswers'] as List? ?? [])
                .map((e) => e.toString())
                .toList();
          }
      }
    }

    final game = data['game'];
    if (game is Map) {
      final g = Map<String, dynamic>.from(game);
      final prevTurn = turnUid;
      turnUid = g['turnUid']?.toString();
      gameOver = g['gameOver'] == true;
      winnerUid = g['winnerUid']?.toString();
      reason = g['reason']?.toString();
      roundIndex = int.tryParse('${g['roundIndex'] ?? 0}') ?? 0;

      final deadline = g['turnDeadline'];
      if (deadline != null) {
        _turnDeadlineMs = int.tryParse('$deadline');
      }

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
          (i) => i < cp.length ? int.tryParse('${cp[i] ?? 0}') ?? 0 : 0,
        );
      }
      final sc = g['scores'];
      if (sc is Map) {
        scores = sc.map(
          (k, v) => MapEntry(k.toString(), int.tryParse('$v') ?? 0),
        );
      }
      final used = g['usedPlayerIds'];
      if (used is Map) {
        usedPlayerIds = used.keys
            .map((k) => int.tryParse(k.toString()) ?? 0)
            .where((e) => e != 0)
            .toSet();
      }
      final ax = g['axisOwners'];
      if (ax is Map) {
        axisOwners = ax.map(
          (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
        );
      }

      if (prevTurn != turnUid) {
        _autoPassedThisTurn = false;
        // Deadline yoksa client fallback
        if (_turnDeadlineMs == null) {
          _turnDeadlineMs = DateTime.now().millisecondsSinceEpoch;
        }
        turnSecondsLeft = turnSeconds;
      }
      if (status == 'playing' && !gameOver) {
        _ensureTurnTicker();
        _onTurnTick();
      }
    }

    if (gameOver && ranked && !_eloRecorded) {
      _eloRecorded = true;
      unawaited(_recordRankedElo());
    }
    notifyListeners();
  }

  Future<void> _recordRankedElo() async {
    final RankedResult rr;
    if (winnerUid == null) {
      rr = RankedResult.draw;
    } else if (winnerUid == myUid) {
      rr = RankedResult.win;
    } else {
      rr = RankedResult.loss;
    }
    try {
      await ProfileService.recordMatchResult(
        matchId: matchId,
        result: rr,
        opponentName: opponentName,
        opponentUid: opponentUid,
        myScore: myScore,
        opponentScore: opponentScore,
      );
      // Delta UI için profili yeniden okumuyoruz; yaklaşık hesap
      lastEloDelta = rr == RankedResult.win
          ? 16
          : (rr == RankedResult.loss ? -16 : 0);
      notifyListeners();
    } catch (_) {}
  }

  void selectCell(int index) {
    if (subType != GridSubType.classic || !isMyTurn) return;
    if (owners[index].isNotEmpty) return;
    activeCell = index;
    suggestions = const [];
    notifyListeners();
  }

  void cancelCell() {
    activeCell = null;
    activeAxisKey = null;
    suggestions = const [];
    notifyListeners();
  }

  void selectAxis(String key) {
    if (subType != GridSubType.reverse || !isMyTurn) return;
    if ((axisOwners[key] ?? '').isNotEmpty) return;
    activeAxisKey = key;
    suggestions = const [];
    notifyListeners();
  }

  void updateSuggestions(String query) {
    suggestions = SearchService.suggestions(
      players: Repository.instance.players,
      query: query,
      excludedPlayerIds: usedPlayerIds,
      limit: 8,
    );
    notifyListeners();
  }

  Future<void> submitGuess(String raw) async {
    if (!isMyTurn) return;
    switch (subType) {
      case GridSubType.classic:
        await _classicGuess(raw);
      case GridSubType.random:
        await _randomGuess(raw);
      case GridSubType.reverse:
        await _reverseGuess(raw);
    }
  }

  Future<void> submitResolved(Player player) async {
    if (!isMyTurn) return;
    suggestions = const [];
    switch (subType) {
      case GridSubType.classic:
        await _classicPlayer(player);
      case GridSubType.random:
        await _randomPlayer(player);
      case GridSubType.reverse:
        _fb('Ters Grid’de kulüp/ülke adı yaz.', false);
    }
  }

  Future<void> _classicGuess(String raw) async {
    final index = activeCell;
    if (index == null) return;
    final resolved = SearchService.resolve(
      players: Repository.instance.players,
      answer: raw,
      excludedPlayerIds: usedPlayerIds,
    );
    if (resolved.status == ResolveStatus.ambiguous) {
      suggestions = resolved.candidates;
      _fb('Listeden seç.', false);
      return;
    }
    if (!resolved.isFound) {
      _fb('Oyuncu yok.', false);
      await pass();
      return;
    }
    await _classicPlayer(resolved.player!);
  }

  Future<void> _classicPlayer(Player player) async {
    final index = activeCell;
    if (index == null) return;
    final row = rows[index ~/ 3];
    final col = cols[index % 3];
    if (!row.matches(player) || !col.matches(player)) {
      _fb('Hücreye uymuyor.', false);
      await pass();
      return;
    }
    final opp = opponentUid;
    if (opp == null) return;
    _busy = true;
    notifyListeners();
    final ok = await OnlineGridService.claimClassicCell(
      matchId: matchId,
      uid: myUid,
      opponentUid: opp,
      cellIndex: index,
      playerId: player.id,
    );
    _busy = false;
    activeCell = null;
    _fb(ok ? 'Doğru! ${player.name}' : 'Hamle alınamadı.', ok);
    notifyListeners();
  }

  Future<void> _randomGuess(String raw) async {
    final round = currentRandomRound;
    if (round == null) return;
    final aId = int.tryParse('${round['clubAId']}') ?? 0;
    final bId = int.tryParse('${round['clubBId']}') ?? 0;

    final resolved = SearchService.resolve(
      players: Repository.instance.players,
      answer: raw,
      excludedPlayerIds: usedPlayerIds,
    );
    if (resolved.status == ResolveStatus.ambiguous) {
      suggestions = resolved.candidates
          .where((p) => p.clubs.contains(aId) && p.clubs.contains(bId))
          .toList();
      if (suggestions.isEmpty) suggestions = resolved.candidates;
      _fb('Listeden seç.', false);
      return;
    }
    if (!resolved.isFound) {
      _fb('Oyuncu yok.', false);
      await pass();
      return;
    }
    await _randomPlayer(resolved.player!);
  }

  Future<void> _randomPlayer(Player player) async {
    final round = currentRandomRound;
    if (round == null) return;
    final aId = int.tryParse('${round['clubAId']}') ?? 0;
    final bId = int.tryParse('${round['clubBId']}') ?? 0;
    if (!player.clubs.contains(aId) || !player.clubs.contains(bId)) {
      _fb('Bu iki kulübü de oynamamış.', false);
      await pass();
      return;
    }
    final opp = opponentUid;
    if (opp == null) return;
    _busy = true;
    notifyListeners();
    final ok = await OnlineGridService.claimRandomRound(
      matchId: matchId,
      uid: myUid,
      opponentUid: opp,
      playerId: player.id,
      expectedRoundIndex: roundIndex,
    );
    _busy = false;
    _fb(ok ? '+1 · ${player.name}' : 'Hamle alınamadı.', ok);
    notifyListeners();
  }

  Future<void> _reverseGuess(String raw) async {
    final key = activeAxisKey;
    if (key == null) {
      _fb('Önce satır veya sütun seç.', false);
      return;
    }
    final isRow = key.startsWith('r');
    final idx = int.tryParse(key.substring(1)) ?? -1;
    if (idx < 0 || idx > 2) return;

    final answer = isRow ? rowAnswers[idx] : colAnswers[idx];
    final ok = SearchService.equals(answer, raw.trim());
    if (!ok) {
      _fb('Yanlış.', false);
      await pass();
      return;
    }

    final opp = opponentUid;
    if (opp == null) return;
    _busy = true;
    notifyListeners();
    final claimed = await OnlineGridService.claimReverseAxis(
      matchId: matchId,
      uid: myUid,
      opponentUid: opp,
      axisKey: key,
    );
    _busy = false;
    activeAxisKey = null;
    _fb(claimed ? 'Doğru eksen!' : 'Alınamadı.', claimed);
    notifyListeners();
  }

  Future<void> pass() async {
    if (turnUid != myUid || gameOver || status != 'playing') return;
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
    activeCell = null;
    activeAxisKey = null;
    notifyListeners();
  }

  void _fb(String m, bool ok) {
    feedback = m;
    feedbackOk = ok;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _turnTick?.cancel();
    super.dispose();
  }
}
