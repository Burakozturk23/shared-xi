import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/cinko_models.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/cinko_puzzle_factory.dart';
import '../services/online_cinko_service.dart';
import '../services/search_service.dart';
import '../services/profile_service.dart';

enum OnlineCinkoPhase { wait, enterPlayer, selecting, busy }

class OnlineCinkoController extends ChangeNotifier {
  OnlineCinkoController({
    required this.matchId,
    required this.myUid,
    required this.myName,
  });

  final String matchId;
  final String myUid;
  final String myName;

  StreamSubscription<DatabaseEvent>? _sub;
  Timer? _turnTick;
  bool _autoPassedThisTurn = false;
  int? _turnDeadlineMs;
  static const int turnSeconds = 45;
  int turnSecondsLeft = turnSeconds;


  List<CinkoCell> cells = const [];
  List<String> owners = List.filled(25, '');
  Map<String, int> scores = {};
  Set<int> usedPlayerIds = {};
  String? turnUid;
  String? player1Uid;
  String? player2Uid;
  String? player1Name;
  String? player2Name;
  String status = 'waiting';
  bool ranked = false;
  bool _eloRecorded = false;
  bool gameOver = false;
  String? winnerUid;
  String? reason;

  OnlineCinkoPhase phase = OnlineCinkoPhase.wait;
  Player? currentPlayer;
  final Set<int> selectedIndexes = {};
  List<Player> suggestions = const [];
  String? feedback;
  bool feedbackOk = true;

  bool get isMyTurn =>
      turnUid == myUid && !gameOver && status == 'playing';

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

  void start() {
    _sub = OnlineCinkoService.watch(matchId).listen(_onData);
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

    final seed = data['seed'];
    if (seed is List && cells.isEmpty) {
      cells = CinkoPuzzleFactory.cellsFromSeed(seed);
    }

    final game = data['game'];
    if (game is Map) {
      final g = Map<String, dynamic>.from(game);
      final prevTurn = turnUid;
      turnUid = g['turnUid']?.toString();
      final dl = g['turnDeadline'];
      if (dl != null) _turnDeadlineMs = int.tryParse('$dl');
      gameOver = g['gameOver'] == true;
      winnerUid = g['winnerUid']?.toString();
      reason = g['reason']?.toString();

      final o = g['owners'];
      if (o is List) {
        owners = List<String>.generate(
          25,
          (i) => i < o.length ? (o[i]?.toString() ?? '') : '',
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

      if (prevTurn != turnUid) {
        _autoPassedThisTurn = false;
        _turnDeadlineMs ??= DateTime.now().millisecondsSinceEpoch;
        turnSecondsLeft = turnSeconds;
      }
      if (status == 'playing' && !gameOver) {
        _ensureTurnTicker();
        _onTurnTick();
      }
    }

    if (status == 'waiting') {
      phase = OnlineCinkoPhase.wait;
    } else if (isMyTurn &&
        phase != OnlineCinkoPhase.selecting &&
        phase != OnlineCinkoPhase.busy) {
      phase = OnlineCinkoPhase.enterPlayer;
    } else if (!isMyTurn) {
      phase = OnlineCinkoPhase.wait;
      currentPlayer = null;
      selectedIndexes.clear();
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
    } catch (_) {}
  }

  void updateSuggestions(String q) {
    suggestions = SearchService.suggestions(
      players: Repository.instance.players,
      query: q,
      excludedPlayerIds: usedPlayerIds,
      limit: 8,
    );
    notifyListeners();
  }

  Future<void> submitGuess(String raw) async {
    if (!isMyTurn || phase == OnlineCinkoPhase.busy) return;

    final resolved = SearchService.resolve(
      players: Repository.instance.players,
      answer: raw,
      excludedPlayerIds: usedPlayerIds,
    );
    if (resolved.status == ResolveStatus.ambiguous) {
      suggestions = resolved.candidates;
      _fb('Birden fazla oyuncu. Listeden seç.', false);
      return;
    }
    if (!resolved.isFound) {
      _fb('Oyuncu bulunamadı.', false);
      return;
    }
    await _acceptPlayer(resolved.player!);
  }

  Future<void> submitResolved(Player player) async {
    if (!isMyTurn) return;
    suggestions = const [];
    await _acceptPlayer(player);
  }

  Future<void> _acceptPlayer(Player player) async {
    final hasMatch = cells.asMap().entries.any((e) {
      final i = e.key;
      if (owners[i].isNotEmpty) return false;
      return _matches(player, e.value);
    });
    if (!hasMatch) {
      _fb('Bu oyuncunun açık kutusu yok.', false);
      return;
    }
    currentPlayer = player;
    selectedIndexes.clear();
    phase = OnlineCinkoPhase.selecting;
    _fb('${player.name} — eşleşen kutuları seç', true);
    notifyListeners();
  }

  void toggleCell(int index) {
    if (phase != OnlineCinkoPhase.selecting) return;
    if (index < 0 || index >= cells.length) return;
    if (owners[index].isNotEmpty) return;
    final p = currentPlayer;
    if (p == null) return;
    if (!_matches(p, cells[index])) {
      _fb('Bu kutu bu oyuncuya uymuyor.', false);
      return;
    }
    if (selectedIndexes.contains(index)) {
      selectedIndexes.remove(index);
    } else {
      selectedIndexes.add(index);
    }
    notifyListeners();
  }

  void cancelSelection() {
    currentPlayer = null;
    selectedIndexes.clear();
    phase = isMyTurn ? OnlineCinkoPhase.enterPlayer : OnlineCinkoPhase.wait;
    notifyListeners();
  }

  Future<void> confirmSelection() async {
    if (phase != OnlineCinkoPhase.selecting) return;
    final p = currentPlayer;
    final opp = opponentUid;
    if (p == null || opp == null) return;
    if (selectedIndexes.isEmpty) {
      _fb('En az bir kutu seç.', false);
      return;
    }

    // Sadece gerçekten uyan indeksler
    final valid = selectedIndexes
        .where((i) => owners[i].isEmpty && _matches(p, cells[i]))
        .toList();
    if (valid.isEmpty) {
      _fb('Geçerli kutu yok.', false);
      return;
    }

    phase = OnlineCinkoPhase.busy;
    notifyListeners();

    final ok = await OnlineCinkoService.claimCells(
      matchId: matchId,
      uid: myUid,
      opponentUid: opp,
      playerId: p.id,
      indexes: valid,
    );

    currentPlayer = null;
    selectedIndexes.clear();

    if (!ok) {
      _fb('Hamle alınamadı.', false);
      phase = isMyTurn ? OnlineCinkoPhase.enterPlayer : OnlineCinkoPhase.wait;
    } else {
      _fb('+${valid.length} kutu!', true);
    }
    notifyListeners();
  }

  Future<void> pass() async {
    if (!isMyTurn) return;
    final opp = opponentUid;
    if (opp == null) return;
    phase = OnlineCinkoPhase.busy;
    notifyListeners();
    await OnlineCinkoService.passTurn(
      matchId: matchId,
      uid: myUid,
      nextUid: opp,
    );
    currentPlayer = null;
    selectedIndexes.clear();
    _fb('Pas.', true);
    notifyListeners();
  }

  bool _matches(Player player, CinkoCell cell) {
    switch (cell.type) {
      case CinkoCellType.club:
        return cell.clubId != null && player.clubs.contains(cell.clubId);
      case CinkoCellType.country:
        return player.countries.any(
          (c) => c.toLowerCase() == cell.label.toLowerCase(),
        );
      case CinkoCellType.league:
        for (final clubId in player.clubs) {
          final club = Repository.instance.clubById(clubId);
          if (club != null &&
              club.league.toLowerCase() == cell.label.toLowerCase()) {
            return true;
          }
        }
        return false;
    }
  }

  void _fb(String m, bool ok) {
    feedback = m;
    feedbackOk = ok;
    notifyListeners();
  }


  void _ensureTurnTicker() {
    _turnTick ??= Timer.periodic(const Duration(seconds: 1), (_) => _onTurnTick());
  }

  void _onTurnTick() {
    if (gameOver || status != 'playing' || turnUid == null) {
      turnSecondsLeft = turnSeconds;
      return;
    }
    int left = turnSeconds;
    if (_turnDeadlineMs != null) {
      final elapsed =
          (DateTime.now().millisecondsSinceEpoch - _turnDeadlineMs!) ~/ 1000;
      left = (turnSeconds - elapsed).clamp(0, turnSeconds);
    }
    if (left != turnSecondsLeft) {
      turnSecondsLeft = left;
      notifyListeners();
    }
    if (turnUid == myUid &&
        turnSecondsLeft <= 0 &&
        !_autoPassedThisTurn &&
        phase != OnlineCinkoPhase.busy) {
      _autoPassedThisTurn = true;
      _fb('Süre doldu — pas.', false);
      pass();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _turnTick?.cancel();
    super.dispose();
  }
}
