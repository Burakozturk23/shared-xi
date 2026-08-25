import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../controllers/loto_versus_controller.dart';
import '../models/loto_models.dart';
import '../repositories/repository.dart';
import '../services/loto_generator.dart';

/// Online Football Loto — ortak tahta, 3 dk maç süresi.
/// Host tahtayı üretir; her iki oyuncu bağımsız yerleştirir.
class LotoOnlinePage extends StatefulWidget {
  final String roomCode;
  final String playerName;
  final bool isHost;
  final String? league;
  final LotoDifficulty difficulty;

  const LotoOnlinePage({
    super.key,
    required this.roomCode,
    required this.playerName,
    required this.isHost,
    this.league,
    this.difficulty = LotoDifficulty.medium,
  });

  @override
  State<LotoOnlinePage> createState() => _LotoOnlinePageState();
}

class _LotoOnlinePageState extends State<LotoOnlinePage> {
  late final LotoVersusController _c;
  StreamSubscription<DatabaseEvent>? _sub;
  bool _ready = false;
  bool _resultShown = false;

  DatabaseReference get _gameRef => FirebaseDatabase.instance
      .ref('rooms')
      .child(widget.roomCode.trim().toUpperCase())
      .child('game');

  @override
  void initState() {
    super.initState();
    _c = LotoVersusController()..addListener(_onCtrl);
    _init();
  }

  Future<void> _init() async {
    try {
      await Repository.instance.initialize();
    } catch (_) {}

    if (widget.isHost) {
      _c.start(
        leagueFilter: widget.league,
        difficulty: widget.difficulty,
        vsBot: false,
        matchTimer: true,
        matchSeconds: 180,
      );
      await _gameRef.set({
        'mode': 'loto',
        'status': 'playing',
        'matchSeconds': 180,
        'board': _c.boardToWire(),
        'players': {
          widget.playerName: {
            'placements': {},
            'queueIndex': 0,
            'finished': false,
            'score': 0,
            'correct': 0,
          },
        },
      });
    } else {
      final boardReady =
          await _waitForBoard(timeout: const Duration(seconds: 12));
      if (!boardReady) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tahta yüklenemedi. Odaya yeniden katıl.'),
            ),
          );
          Navigator.pop(context);
        }
        return;
      }
    }

    _sub = _gameRef.onValue.listen((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) return;
      final data = Map<String, dynamic>.from(
        (event.snapshot.value as Map).map((k, v) => MapEntry('$k', v)),
      );
      final players = data['players'];
      if (players is! Map) return;
      for (final e in players.entries) {
        if ('${e.key}' == widget.playerName) continue;
        if (e.value is! Map) continue;
        final p = Map<String, dynamic>.from(
          (e.value as Map).map((k, v) => MapEntry('$k', v)),
        );
        final rawPl = p['placements'];
        final placements = <int, int>{};
        if (rawPl is Map) {
          rawPl.forEach((k, v) {
            final ci = int.tryParse('$k') ?? (k is int ? k : -1);
            final pid = v is int ? v : int.tryParse('$v') ?? -1;
            if (ci >= 0 && pid >= 0) placements[ci] = pid;
          });
        }
        _c.applyOpponentRemote(
          placements: placements,
          queueIndex: (p['queueIndex'] as num?)?.toInt() ?? 0,
          finished: p['finished'] as bool? ?? false,
        );
      }
    });

    // Misafir / host: kendi slotunu güvenceye al
    await _gameRef.child('players').child(widget.playerName).update({
      'placements': {},
      'queueIndex': 0,
      'finished': false,
      'score': 0,
      'correct': 0,
    });

    if (mounted) setState(() => _ready = true);
  }

  /// Misafir: host tahtayı yazana kadar bekle.
  Future<bool> _waitForBoard({required Duration timeout}) async {
    final completer = Completer<bool>();
    StreamSubscription<DatabaseEvent>? sub;
    Timer? timer;

    void tryParse(Object? value) {
      if (value is! Map) return;
      final data = Map<String, dynamic>.from(
        value.map((k, v) => MapEntry('$k', v)),
      );
      final boardRaw = data['board'];
      if (boardRaw is! Map) return;
      try {
        final boardMap = Map<String, dynamic>.from(
          boardRaw.map((k, v) => MapEntry('$k', v)),
        );
        final board = LotoVersusController.boardFromWire(boardMap);
        _c.start(
          vsBot: false,
          matchTimer: true,
          matchSeconds: (data['matchSeconds'] as num?)?.toInt() ?? 180,
          fixedBoard: board,
          difficulty: board.difficulty,
          leagueFilter: board.leagueFilter,
        );
        if (!completer.isCompleted) completer.complete(true);
      } catch (_) {}
    }

    final snap = await _gameRef.get();
    if (snap.exists) tryParse(snap.value);

    if (!completer.isCompleted) {
      sub = _gameRef.onValue.listen((e) {
        if (e.snapshot.exists) tryParse(e.snapshot.value);
      });
      timer = Timer(timeout, () {
        if (!completer.isCompleted) completer.complete(false);
      });
    }

    final ok = await completer.future;
    timer?.cancel();
    await sub?.cancel();
    return ok;
  }

  void _onCtrl() {
    if (!mounted) return;
    setState(() {});
    // kendi durumunu yaz
    final h = _c.state.human;
    _gameRef.child('players').child(widget.playerName).update({
      'placements': {
        for (final e in h.placements.entries) '${e.key}': e.value,
      },
      'queueIndex': h.queueIndex,
      'finished': h.finished,
      'score': h.score,
      'correct': h.correct,
    });
    if (_c.state.isFinished && !_resultShown) {
      _resultShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResult());
    }
  }

  Future<void> _showResult() async {
    final s = _c.state;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141A18),
        title: const Text('MAÇ BİTTİ',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color(0xFFFFD54F), fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sen: ${s.human.correct} doğru · ${s.human.score} puan',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Rakip: ${s.opponent.correct} doğru · ${s.opponent.score} puan',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Text(
              s.human.score > s.opponent.score
                  ? 'Kazandın!'
                  : s.human.score < s.opponent.score
                      ? 'Kaybettin'
                      : 'Berabere',
              style: const TextStyle(
                  color: Color(0xFF00E676), fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Çıkış'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _c.removeListener(_onCtrl);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _c.state.board == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A1210),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final s = _c.state;
    final board = s.board!;
    final player = s.currentHumanPlayer();
    final m = s.matchSecondsLeft;
    final mm = (m ~/ 60).toString().padLeft(1, '0');
    final ss = (m % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: const Color(0xFF0A1210),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white70,
        title: Text(
          '${widget.league ?? board.leagueFilter ?? 'Loto'} · ${board.difficulty.label}',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
      body: Column(
        children: [
          // maç süresi + skor
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141A18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text('MAÇ SÜRESİ',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 10)),
                      Text('$mm:$ss',
                          style: const TextStyle(
                              color: Color(0xFF00E676),
                              fontWeight: FontWeight.w900,
                              fontSize: 20)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${widget.playerName}  ${s.human.placements.length}/16',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      const Text('VS',
                          style: TextStyle(color: Colors.white38, fontSize: 11)),
                      Text(
                        'Rakip  ${s.opponent.placements.length}/16',
                        style: const TextStyle(
                            color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3F3D9E),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: s.playerSeconds /
                              board.difficulty.secondsPerPlayer,
                          color: const Color(0xFF00E676),
                          backgroundColor: Colors.white24,
                          strokeWidth: 4,
                        ),
                        Text('${s.playerSeconds}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      player?.name ?? '—',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                  ),
                  TextButton(
                    onPressed: s.human.finished ? null : _c.humanPass,
                    child: const Text('Pas Geç',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: 16,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 0.92,
              ),
              itemBuilder: (_, i) {
                final cell = board.cells[i];
                final placedId = s.human.placements[i];
                final filled = placedId != null;
                final name = filled
                    ? Repository.instance.playerById(placedId!)?.name
                    : null;
                return Material(
                  color: filled
                      ? const Color(0xFF1B5E20)
                      : const Color(0xFF2A3340),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: filled || s.human.finished
                        ? null
                        : () => _c.humanTapCell(i),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: filled
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Color(0xFF00E676), size: 14),
                                Text(
                                  name ?? '',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  cell.label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700),
                                ),
                                Text(cell.subtitle,
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 9)),
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
