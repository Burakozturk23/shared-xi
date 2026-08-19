import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/club.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/online_five_service.dart';
import '../services/search_service.dart';
import '../services/profile_service.dart';

class OnlineFiveController extends ChangeNotifier {
  OnlineFiveController({
    required this.matchId,
    required this.myUid,
    required this.myName,
  });

  final String matchId;
  final String myUid;
  final String myName;

  StreamSubscription<DatabaseEvent>? _sub;
  Timer? _tick;
  bool _finishSent = false;

  List<int> clubIds = const [];
  List<Club> clubs = const [];
  Map<String, int> scores = {};
  Set<int> usedPlayerIds = {};
  List<Map<String, dynamic>> myHistory = const [];
  String? player1Uid;
  String? player2Uid;
  String? player1Name;
  String? player2Name;
  String status = 'waiting';
  bool ranked = false;
  bool _eloRecorded = false;
  bool gameOver = false;
  String? winnerUid;
  int? startedAtMs;
  int durationSec = OnlineFiveService.durationSeconds;
  int secondsLeft = OnlineFiveService.durationSeconds;
  String? feedback;
  bool feedbackOk = true;
  List<Player> suggestions = const [];
  bool _busy = false;

  int get myScore => scores[myUid] ?? 0;
  String? get opponentUid =>
      player1Uid == myUid ? player2Uid : player1Uid;
  int get opponentScore {
    final o = opponentUid;
    return o == null ? 0 : (scores[o] ?? 0);
  }

  String get opponentName {
    if (player1Uid == myUid) return player2Name ?? 'Rakip';
    return player1Name ?? 'Rakip';
  }

  bool get canPlay =>
      status == 'playing' && !gameOver && !_busy && secondsLeft > 0;

  void start() {
    _sub = OnlineFiveService.watch(matchId).listen(_onData);
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

    final ids = data['clubIds'];
    if (ids is List) {
      clubIds = ids.map((e) => int.tryParse('$e') ?? 0).where((e) => e != 0).toList();
      clubs = clubIds
          .map((id) => Repository.instance.clubById(id))
          .whereType<Club>()
          .toList();
    }

    final game = data['game'];
    if (game is Map) {
      final g = Map<String, dynamic>.from(game);
      gameOver = g['gameOver'] == true;
      winnerUid = g['winnerUid']?.toString();
      durationSec =
          int.tryParse('${g['durationSec'] ?? durationSec}') ?? durationSec;

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
      final hist = g['history'];
      if (hist is Map) {
        final mine = hist[myUid];
        if (mine is List) {
          myHistory = mine
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }

      final started = g['startedAt'];
      if (started != null) {
        startedAtMs = int.tryParse('$started');
        _ensureTicker();
      }
    }
    if (gameOver && ranked && !_eloRecorded) {
      _eloRecorded = true;
      unawaited(_recordRankedElo());
    }
    notifyListeners();
  }

  void _ensureTicker() {
    if (_tick != null) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _onTick();
  }

  void _onTick() {
    if (startedAtMs == null || gameOver) return;
    final elapsed =
        (DateTime.now().millisecondsSinceEpoch - startedAtMs!) ~/ 1000;
    // startedAt is server ms; client clock skew — acceptable for MVP
    final left = durationSec - elapsed;
    secondsLeft = left < 0 ? 0 : left;
    notifyListeners();

    if (secondsLeft <= 0 && !_finishSent && status == 'playing') {
      _finishSent = true;
      _endByTime();
    }
  }

  Future<void> _endByTime() async {
    final s1 = myScore;
    final s2 = opponentScore;
    String? winner;
    if (s1 > s2) {
      winner = myUid;
    } else if (s2 > s1) {
      winner = opponentUid;
    } else {
      winner = null;
    }
    // İki client da yazabilir; transaction idempotent
    await OnlineFiveService.finishMatch(matchId: matchId, winnerUid: winner);
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

  void clearSuggestions() {
    suggestions = const [];
    notifyListeners();
  }

  Future<void> submitGuess(String raw) async {
    if (!canPlay) return;
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
    await submitResolved(resolved.player!);
  }

  Future<void> submitResolved(Player player) async {
    if (!canPlay) return;
    suggestions = const [];
    _busy = true;
    notifyListeners();

    final r = await OnlineFiveService.claimPlayer(
      matchId: matchId,
      uid: myUid,
      player: player,
      clubIds: clubIds,
    );

    _busy = false;
    _fb(r.message, r.ok);
    notifyListeners();
  }

  void _fb(String m, bool ok) {
    feedback = m;
    feedbackOk = ok;
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

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    super.dispose();
  }
}
