import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/loto_models.dart';
import '../models/player.dart';
import '../services/loto_bot_session.dart';

enum LotoBotPhase { setup, loading, ready, playing, paused, finished, error }
enum LotoSkipReason { pass, timeout }

class LotoBotScore {
  const LotoBotScore({required this.correct, required this.wrong,
    required this.passed, required this.timedOut});
  final int correct, wrong, passed, timedOut;
  int get points => correct * 10;
}

/// Bot-only lifecycle; online Loto retains its separate shared-match controller.
class LotoBotController extends ChangeNotifier {
  LotoBotController({LotoSessionLoader? loadSession, Random? random,
    Duration Function()? clock})
      : _loadSession = loadSession ?? LotoBotSession.load,
        _random = random ?? Random() {
    final stopwatch = Stopwatch()..start();
    _clock = clock ?? (() => stopwatch.elapsed);
  }

  final LotoSessionLoader _loadSession;
  final Random _random;
  late final Duration Function() _clock;
  Timer? _ticker;
  bool _disposed = false;
  int _generation = 0;
  LotoBotPhase _phase = LotoBotPhase.setup;
  LotoBotSession? _session;
  String? _league;
  LotoDifficulty _difficulty = LotoDifficulty.medium;
  final Map<int, int> _human = {}, _bot = {};
  final Map<int, LotoSkipReason> _skips = {};
  int _humanIndex = 0, _botIndex = 0, _seconds = 15;
  Duration _humanDeadline = Duration.zero, _botDeadline = Duration.zero;
  Duration _humanRemaining = Duration.zero, _botRemaining = Duration.zero;
  String _notice = '';

  LotoBotPhase get phase => _phase;
  LotoBotSession? get session => _session;
  String? get league => _league;
  LotoDifficulty get difficulty => _difficulty;
  Map<int, int> get humanPlacements => Map.unmodifiable(_human);
  Map<int, int> get botPlacements => Map.unmodifiable(_bot);
  Map<int, LotoSkipReason> get skips => Map.unmodifiable(_skips);
  int get humanIndex => _humanIndex;
  int get botIndex => _botIndex;
  int get seconds => _seconds;
  bool get humanFinished => _humanIndex >= 16;
  bool get botFinished => _botIndex >= 16;
  String get notice => _notice;
  Player? get currentPlayer => _session == null || humanFinished ? null
      : _session!.players[_session!.board.playerQueue[_humanIndex]];

  Future<void> prepare({String? league,
    LotoDifficulty difficulty = LotoDifficulty.medium}) async {
    if (_disposed) return;
    final generation = ++_generation;
    _ticker?.cancel();
    _session = null;
    _human.clear();
    _bot.clear();
    _skips.clear();
    _humanIndex = _botIndex = 0;
    _notice = '';
    _league = league;
    _difficulty = difficulty;
    _seconds = difficulty.secondsPerPlayer;
    _phase = LotoBotPhase.loading;
    notifyListeners();
    try {
      final session = await _loadSession(league, difficulty);
      if (_disposed || generation != _generation) return;
      if (!session.isPlayable || session.board.leagueFilter != league ||
          session.board.difficulty != difficulty) {
        throw StateError('Incomplete or mismatched Loto session.');
      }
      _session = session;
      _phase = LotoBotPhase.ready;
    } catch (error) {
      if (_disposed || generation != _generation) return;
      debugPrint('[LotoBot] preparation failed: $error');
      _phase = LotoBotPhase.error;
    }
    notifyListeners();
  }

  void begin() {
    if (_disposed || _phase != LotoBotPhase.ready) return;
    _phase = LotoBotPhase.playing;
    _humanDeadline = _clock() + Duration(seconds: _difficulty.secondsPerPlayer);
    _scheduleBot();
    _startTicker();
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  void _tick() {
    if (_disposed || _phase != LotoBotPhase.playing) return;
    var changed = false;
    if (!humanFinished && _clock() >= _humanDeadline) {
      _advanceHuman(null, LotoSkipReason.timeout);
      changed = true;
    }
    if (!botFinished && _clock() >= _botDeadline) {
      _moveBot();
      changed = true;
    }
    final left = humanFinished ? 0 : max(0,
        ((_humanDeadline - _clock()).inMicroseconds /
            Duration.microsecondsPerSecond).ceil());
    if (left != _seconds) {
      _seconds = left;
      changed = true;
    }
    _finishIfReady();
    if (changed) notifyListeners();
  }

  bool _canAct(int expectedIndex) {
    if (_disposed || _phase != LotoBotPhase.playing ||
        humanFinished || expectedIndex != _humanIndex) return false;
    if (_clock() >= _humanDeadline) {
      _advanceHuman(null, LotoSkipReason.timeout);
      _finishIfReady();
      notifyListeners();
      return false;
    }
    return true;
  }

  /// Reject taps from the previous rendered player during a handover.
  bool place(int cell, {required int expectedIndex}) {
    if (!_canAct(expectedIndex) || cell < 0 || cell >= 16 ||
        _human.containsKey(cell)) return false;
    _advanceHuman(cell, null);
    _finishIfReady();
    notifyListeners();
    return true;
  }

  bool pass({required int expectedIndex}) {
    if (!_canAct(expectedIndex)) return false;
    _advanceHuman(null, LotoSkipReason.pass);
    _finishIfReady();
    notifyListeners();
    return true;
  }

  void _advanceHuman(int? cell, LotoSkipReason? reason) {
    final playerId = _session!.board.playerQueue[_humanIndex];
    final player = _session!.players[playerId]!;
    if (cell != null) {
      _human[cell] = playerId;
      _notice = '${player.name} yerleştirildi.';
    } else {
      _skips[playerId] = reason!;
      _notice = reason == LotoSkipReason.timeout
          ? 'Süre doldu. Sıradaki oyuncu geldi.' : 'Pas geçildi.';
    }
    _humanIndex++;
    _seconds = humanFinished ? 0 : _difficulty.secondsPerPlayer;
    _humanDeadline = _clock() + Duration(seconds: _difficulty.secondsPerPlayer);
  }

  void _scheduleBot() {
    final milliseconds = switch (_difficulty) {
      LotoDifficulty.easy => 1800 + _random.nextInt(1200),
      LotoDifficulty.medium => 1200 + _random.nextInt(1000),
      LotoDifficulty.hard => 800 + _random.nextInt(700),
    };
    _botDeadline = _clock() + Duration(milliseconds: milliseconds);
  }

  void _moveBot() {
    final board = _session!.board;
    final playerId = board.playerQueue[_botIndex];
    final valid = board.validCellsForPlayer[playerId]!;
    final empty = List.generate(16, (i) => i)
        .where((i) => !_bot.containsKey(i)).toList();
    final correct = empty.where(valid.contains).toList();
    final wrong = empty.where((i) => !valid.contains(i)).toList();
    final accuracy = switch (_difficulty) {
      LotoDifficulty.easy => .35,
      LotoDifficulty.medium => .55,
      LotoDifficulty.hard => .75,
    };
    final aimsCorrectly = _random.nextDouble() < accuracy;
    final candidates = correct.isEmpty ? wrong
        : wrong.isEmpty || aimsCorrectly ? correct : wrong;
    if (candidates.isNotEmpty) {
      _bot[candidates[_random.nextInt(candidates.length)]] = playerId;
    }
    _botIndex++;
    if (!botFinished) _scheduleBot();
  }

  /// Only thinking delays are skipped; scoring and choices use the same policy.
  void completeBot() {
    if (_disposed || _phase != LotoBotPhase.playing || !humanFinished) return;
    while (!botFinished) { _moveBot(); }
    _finishIfReady();
    notifyListeners();
  }

  void _finishIfReady() {
    if (humanFinished && botFinished) {
      _phase = LotoBotPhase.finished;
      _ticker?.cancel();
    }
  }

  void pause() {
    if (_disposed || _phase != LotoBotPhase.playing) return;
    _tick();
    if (_phase != LotoBotPhase.playing) return;
    _humanRemaining = _humanDeadline - _clock();
    _botRemaining = _botDeadline - _clock();
    _ticker?.cancel();
    _phase = LotoBotPhase.paused;
    notifyListeners();
  }

  void resume() {
    if (_disposed || _phase != LotoBotPhase.paused) return;
    _humanDeadline = _clock() + _humanRemaining;
    _botDeadline = _clock() + _botRemaining;
    _phase = LotoBotPhase.playing;
    _startTicker();
    notifyListeners();
  }

  LotoBotScore score({bool bot = false}) {
    final board = _session!.board;
    final placements = bot ? _bot : _human;
    var correct = 0;
    for (final entry in placements.entries) {
      if (board.validCellsForPlayer[entry.value]!.contains(entry.key)) correct++;
    }
    return LotoBotScore(correct: correct, wrong: placements.length - correct,
      passed: bot ? 0 : _skips.values.where((r) => r == LotoSkipReason.pass).length,
      timedOut: bot ? 0 : _skips.values.where((r) => r == LotoSkipReason.timeout).length);
  }

  void reset() {
    if (_disposed) return;
    _generation++;
    _ticker?.cancel();
    _session = null;
    _human.clear();
    _bot.clear();
    _skips.clear();
    _humanIndex = _botIndex = 0;
    _seconds = _difficulty.secondsPerPlayer;
    _humanDeadline = _botDeadline = Duration.zero;
    _humanRemaining = _botRemaining = Duration.zero;
    _notice = '';
    _phase = LotoBotPhase.setup;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _ticker?.cancel();
    super.dispose();
  }
}
