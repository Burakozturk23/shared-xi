import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/loto_models.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../services/loto_generator.dart';

/// Bot veya online rakip için skor durumu.
class LotoSideState {
  final Map<int, int> placements; // cell → playerId
  final int queueIndex;
  final int correct;
  final int wrong;
  final int score;
  final bool finished;

  const LotoSideState({
    this.placements = const {},
    this.queueIndex = 0,
    this.correct = 0,
    this.wrong = 0,
    this.score = 0,
    this.finished = false,
  });

  LotoSideState copyWith({
    Map<int, int>? placements,
    int? queueIndex,
    int? correct,
    int? wrong,
    int? score,
    bool? finished,
  }) {
    return LotoSideState(
      placements: placements ?? this.placements,
      queueIndex: queueIndex ?? this.queueIndex,
      correct: correct ?? this.correct,
      wrong: wrong ?? this.wrong,
      score: score ?? this.score,
      finished: finished ?? this.finished,
    );
  }
}

class LotoVersusState {
  final LotoBoard? board;
  final LotoSideState human;
  final LotoSideState opponent;
  final int playerSeconds; // mevcut oyuncu süresi
  final int matchSecondsLeft; // online: 180
  final bool matchTimerEnabled;
  final bool isPlaying;
  final bool isFinished;
  final String? league;
  final LotoDifficulty difficulty;
  final bool vsBot;

  const LotoVersusState({
    this.board,
    this.human = const LotoSideState(),
    this.opponent = const LotoSideState(),
    this.playerSeconds = 15,
    this.matchSecondsLeft = 180,
    this.matchTimerEnabled = false,
    this.isPlaying = false,
    this.isFinished = false,
    this.league,
    this.difficulty = LotoDifficulty.medium,
    this.vsBot = true,
  });

  Player? currentHumanPlayer() {
    final b = board;
    if (b == null || human.finished) return null;
    if (human.queueIndex < 0 || human.queueIndex >= b.playerQueue.length) {
      return null;
    }
    return Repository.instance.playerById(b.playerQueue[human.queueIndex]);
  }

  LotoVersusState copyWith({
    LotoBoard? board,
    LotoSideState? human,
    LotoSideState? opponent,
    int? playerSeconds,
    int? matchSecondsLeft,
    bool? matchTimerEnabled,
    bool? isPlaying,
    bool? isFinished,
    String? league,
    LotoDifficulty? difficulty,
    bool? vsBot,
  }) {
    return LotoVersusState(
      board: board ?? this.board,
      human: human ?? this.human,
      opponent: opponent ?? this.opponent,
      playerSeconds: playerSeconds ?? this.playerSeconds,
      matchSecondsLeft: matchSecondsLeft ?? this.matchSecondsLeft,
      matchTimerEnabled: matchTimerEnabled ?? this.matchTimerEnabled,
      isPlaying: isPlaying ?? this.isPlaying,
      isFinished: isFinished ?? this.isFinished,
      league: league ?? this.league,
      difficulty: difficulty ?? this.difficulty,
      vsBot: vsBot ?? this.vsBot,
    );
  }
}

class LotoVersusController extends ChangeNotifier {
  LotoVersusState _state = const LotoVersusState();
  LotoVersusState get state => _state;

  Timer? _playerTimer;
  Timer? _matchTimer;
  Timer? _botTimer;
  final _rng = Random();

  /// [vsBot] true → bot rakip. Online için false (rakip RTDB’den güncellenir).
  /// [matchTimer] online’da 180 sn.
  void start({
    String? leagueFilter,
    LotoDifficulty difficulty = LotoDifficulty.medium,
    bool vsBot = true,
    bool matchTimer = false,
    int matchSeconds = 180,
    LotoBoard? fixedBoard,
  }) {
    disposeTimers();
    final board = fixedBoard ??
        LotoGenerator.generate(
          leagueFilter: leagueFilter,
          difficulty: difficulty,
        );
    _state = LotoVersusState(
      board: board,
      playerSeconds: difficulty.secondsPerPlayer,
      matchSecondsLeft: matchSeconds,
      matchTimerEnabled: matchTimer,
      isPlaying: true,
      league: leagueFilter,
      difficulty: difficulty,
      vsBot: vsBot,
    );
    notifyListeners();
    _armPlayerTimer();
    if (matchTimer) _armMatchTimer();
    if (vsBot) _scheduleBot();
  }

  void _armPlayerTimer() {
    _playerTimer?.cancel();
    _playerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_state.isPlaying || _state.isFinished) return;
      if (_state.human.finished) return;
      final left = _state.playerSeconds - 1;
      if (left <= 0) {
        _humanSkip();
        return;
      }
      _state = _state.copyWith(playerSeconds: left);
      notifyListeners();
    });
  }

  void _armMatchTimer() {
    _matchTimer?.cancel();
    _matchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_state.isPlaying || _state.isFinished) return;
      final left = _state.matchSecondsLeft - 1;
      if (left <= 0) {
        _finishMatch();
        return;
      }
      _state = _state.copyWith(matchSecondsLeft: left);
      notifyListeners();
    });
  }

  void humanPass() {
    if (!_state.isPlaying || _state.human.finished) return;
    _humanSkip();
  }

  void humanTapCell(int cellIndex) {
    if (!_state.isPlaying || _state.isFinished) return;
    if (_state.human.finished) return;
    if (_state.human.placements.containsKey(cellIndex)) return;
    final board = _state.board;
    final player = _state.currentHumanPlayer();
    if (board == null || player == null) return;

    final map = Map<int, int>.from(_state.human.placements);
    map[cellIndex] = player.id;

    // Anlık skor yok; sadece yerleştir. Doğruluk sonda (veya maç bitince).
    var human = _state.human.copyWith(placements: map);
    human = _advanceSide(human, board);
    _state = _state.copyWith(
      human: human,
      playerSeconds: _state.difficulty.secondsPerPlayer,
    );
    notifyListeners();
    if (human.finished && (!_state.vsBot || _state.opponent.finished)) {
      _finishMatch();
    } else if (human.finished && _state.vsBot) {
      // bot bitsin diye bekle
    }
  }

  void _humanSkip() {
    final board = _state.board;
    if (board == null) return;
    var human = _advanceSide(_state.human, board);
    _state = _state.copyWith(
      human: human,
      playerSeconds: _state.difficulty.secondsPerPlayer,
    );
    notifyListeners();
    if (human.finished && (!_state.vsBot || _state.opponent.finished)) {
      _finishMatch();
    }
  }

  LotoSideState _advanceSide(LotoSideState side, LotoBoard board) {
    final next = side.queueIndex + 1;
    if (next >= board.playerQueue.length) {
      return _scoreSide(side.copyWith(finished: true, queueIndex: next), board);
    }
    return side.copyWith(queueIndex: next);
  }

  LotoSideState _scoreSide(LotoSideState side, LotoBoard board) {
    var correct = 0;
    var wrong = 0;
    for (final e in side.placements.entries) {
      final p = Repository.instance.playerById(e.value);
      final cell = board.cells[e.key];
      if (p != null && LotoGenerator.matches(p, cell)) {
        correct++;
      } else {
        wrong++;
      }
    }
    final placed = side.placements.values.toSet();
    for (final pid in board.playerQueue) {
      if (!placed.contains(pid)) wrong++;
    }
    return side.copyWith(
      correct: correct,
      wrong: wrong,
      score: correct * 10,
      finished: true,
    );
  }

  void _scheduleBot() {
    _botTimer?.cancel();
    if (!_state.vsBot || _state.opponent.finished || _state.isFinished) return;
    // Bot düşünme süresi zorluğa göre
    final think = _state.difficulty == LotoDifficulty.easy
        ? 1800 + _rng.nextInt(1200)
        : _state.difficulty == LotoDifficulty.medium
            ? 1200 + _rng.nextInt(1000)
            : 800 + _rng.nextInt(700);
    _botTimer = Timer(Duration(milliseconds: think), _botMove);
  }

  void _botMove() {
    if (!_state.vsBot || _state.isFinished) return;
    final board = _state.board;
    if (board == null || _state.opponent.finished) return;

    final idx = _state.opponent.queueIndex;
    if (idx >= board.playerQueue.length) return;
    final pid = board.playerQueue[idx];
    final player = Repository.instance.playerById(pid);
    if (player == null) {
      final opp = _advanceSide(_state.opponent, board);
      _state = _state.copyWith(opponent: opp);
      notifyListeners();
      _scheduleBot();
      return;
    }

    // Boş hücreler
    final empty = <int>[];
    for (var i = 0; i < 16; i++) {
      if (!_state.opponent.placements.containsKey(i)) empty.add(i);
    }
    if (empty.isEmpty) {
      final opp = _scoreSide(
        _state.opponent.copyWith(finished: true),
        board,
      );
      _state = _state.copyWith(opponent: opp);
      notifyListeners();
      if (_state.human.finished) _finishMatch();
      return;
    }

    // Doğru hücreleri bul
    final correctCells = empty
        .where((i) => LotoGenerator.matches(player, board.cells[i]))
        .toList();

    // Zorluk: bot isabet oranı
    final accuracy = _state.difficulty == LotoDifficulty.easy
        ? 0.35
        : _state.difficulty == LotoDifficulty.medium
            ? 0.55
            : 0.75;

    int chosen;
    if (correctCells.isNotEmpty && _rng.nextDouble() < accuracy) {
      chosen = correctCells[_rng.nextInt(correctCells.length)];
    } else {
      chosen = empty[_rng.nextInt(empty.length)];
    }

    final map = Map<int, int>.from(_state.opponent.placements);
    map[chosen] = pid;
    var opp = _state.opponent.copyWith(placements: map);
    opp = _advanceSide(opp, board);
    _state = _state.copyWith(opponent: opp);
    notifyListeners();

    if (opp.finished && _state.human.finished) {
      _finishMatch();
    } else if (!opp.finished) {
      _scheduleBot();
    }
  }

  /// Online: rakip durumunu RTDB’den uygula.
  void applyOpponentRemote({
    required Map<int, int> placements,
    required int queueIndex,
    bool finished = false,
  }) {
    final board = _state.board;
    if (board == null) return;
    var opp = LotoSideState(
      placements: placements,
      queueIndex: queueIndex,
      finished: finished,
    );
    if (finished) opp = _scoreSide(opp, board);
    _state = _state.copyWith(opponent: opp);
    notifyListeners();
    if (finished && _state.human.finished) _finishMatch();
  }

  void _finishMatch() {
    disposeTimers();
    final board = _state.board;
    if (board == null) return;
    var human = _state.human;
    var opp = _state.opponent;
    if (!human.finished) human = _scoreSide(human, board);
    if (!opp.finished) opp = _scoreSide(opp, board);
    _state = _state.copyWith(
      human: human,
      opponent: opp,
      isFinished: true,
      isPlaying: false,
    );
    notifyListeners();
  }

  /// Board’u JSON’a (RTDB host yazar).
  Map<String, dynamic> boardToWire() {
    final b = _state.board!;
    return {
      'league': b.leagueFilter,
      'difficulty': b.difficulty.name,
      'queue': b.playerQueue,
      'cells': b.cells
          .map((c) => {
                'i': c.cellIndex,
                'type': c.type.name,
                'label': c.label,
                'subtitle': c.subtitle,
                'key': c.key,
              })
          .toList(),
    };
  }

  static LotoBoard boardFromWire(Map data) {
    final diffName = data['difficulty'] as String? ?? 'medium';
    final difficulty = LotoDifficulty.values.firstWhere(
      (d) => d.name == diffName,
      orElse: () => LotoDifficulty.medium,
    );
    final cellsRaw = (data['cells'] as List?) ?? [];
    final cells = <LotoCriterion>[];
    for (final raw in cellsRaw) {
      final m = Map<String, dynamic>.from(raw as Map);
      final typeName = m['type'] as String? ?? 'club';
      final type = LotoCriterionType.values.firstWhere(
        (t) => t.name == typeName,
        orElse: () => LotoCriterionType.club,
      );
      cells.add(LotoCriterion(
        cellIndex: m['i'] as int? ?? cells.length,
        type: type,
        label: m['label'] as String? ?? '',
        subtitle: m['subtitle'] as String? ?? '',
        key: m['key'] as String? ?? '',
      ));
    }
    while (cells.length < 16) {
      cells.add(LotoCriterion(
        cellIndex: cells.length,
        type: LotoCriterionType.position,
        label: 'Orta saha',
        subtitle: 'Mevki',
        key: 'MID',
      ));
    }
    final queue = ((data['queue'] as List?) ?? [])
        .map((e) => e is int ? e : int.tryParse('$e') ?? 0)
        .toList();
    return LotoBoard(
      leagueFilter: data['league'] as String?,
      difficulty: difficulty,
      cells: cells.take(16).toList(),
      playerQueue: queue,
      validCellsForPlayer: const {},
    );
  }

  void disposeTimers() {
    _playerTimer?.cancel();
    _matchTimer?.cancel();
    _botTimer?.cancel();
  }

  @override
  void dispose() {
    disposeTimers();
    super.dispose();
  }
}
