import 'package:flutter/material.dart';

import '../controllers/loto_versus_controller.dart';
import '../models/loto_models.dart';
import '../repositories/repository.dart';
import '../services/loto_generator.dart';

/// Bota karşı Football Loto.
class LotoBotPage extends StatefulWidget {
  const LotoBotPage({super.key});

  @override
  State<LotoBotPage> createState() => _LotoBotPageState();
}

class _LotoBotPageState extends State<LotoBotPage> {
  late final LotoVersusController _c;
  bool _booting = true;
  bool _started = false;
  String? _league;
  LotoDifficulty _diff = LotoDifficulty.medium;
  bool _resultShown = false;

  @override
  void initState() {
    super.initState();
    _c = LotoVersusController()..addListener(_on);
    _boot();
  }

  Future<void> _boot() async {
    try {
      await Repository.instance.initialize();
    } catch (_) {}
    if (mounted) setState(() => _booting = false);
  }

  void _on() {
    if (!mounted) return;
    setState(() {});
    if (_c.state.isFinished && !_resultShown) {
      _resultShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResult());
    }
  }

  @override
  void dispose() {
    _c.removeListener(_on);
    _c.dispose();
    super.dispose();
  }

  Future<void> _showResult() async {
    final s = _c.state;
    final hs = s.human.score;
    final os = s.opponent.score;
    final win = hs > os;
    final draw = hs == os;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141A18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          draw ? 'BERABERE' : (win ? 'KAZANDIN!' : 'KAYBETTİN'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: draw
                ? Colors.amber
                : (win ? const Color(0xFF00E676) : Colors.redAccent),
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sen ${s.human.correct} doğru · ${hs} puan',
                style: const TextStyle(color: Colors.white70)),
            Text('Bot ${s.opponent.correct} doğru · ${os} puan',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _resultShown = false;
                _c.start(
                  leagueFilter: _league,
                  difficulty: _diff,
                  vsBot: true,
                );
              },
              child: const Text('Tekrar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _started = false;
                  _resultShown = false;
                });
              },
              child: const Text('Lig Seç'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1210),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white70,
        title: const Text('Loto · Bot', style: TextStyle(color: Colors.white)),
      ),
      body: _booting
          ? const Center(child: CircularProgressIndicator())
          : !_started
              ? _setup()
              : _game(),
    );
  }

  Widget _setup() {
    final leagues = LotoGenerator.availableLeagues();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Lig Seç',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final L in leagues)
              ChoiceChip(
                label: Text(L),
                selected: _league == L,
                selectedColor: const Color(0xFF00E676),
                labelStyle: TextStyle(
                  color: _league == L ? Colors.black : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: const Color(0xFF1A2420),
                onSelected: (_) => setState(() => _league = L),
              ),
          ],
        ),
        const SizedBox(height: 16),
        for (final d in LotoDifficulty.values)
          ListTile(
            onTap: () => setState(() => _diff = d),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: _diff == d
                ? const Color(0xFF00E676).withOpacity(0.15)
                : const Color(0xFF141A18),
            title: Text(d.label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            subtitle: Text('${d.secondsPerPlayer}s / oyuncu · ${d.description}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E676),
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 48),
          ),
          onPressed: _league == null
              ? null
              : () {
                  _resultShown = false;
                  setState(() => _started = true);
                  _c.start(
                    leagueFilter: _league,
                    difficulty: _diff,
                    vsBot: true,
                  );
                },
          child: const Text('Bota Karşı Başlat',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _game() {
    final s = _c.state;
    final board = s.board;
    final player = s.currentHumanPlayer();
    if (board == null) {
      return const Center(
          child: Text('Tahta yok', style: TextStyle(color: Colors.white)));
    }

    return Column(
      children: [
        // skor paneli
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: _scorePill('Sen', s.human.placements.length, s.human.score,
                    const Color(0xFF00E676)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('VS',
                    style: TextStyle(
                        color: Colors.white54, fontWeight: FontWeight.w800)),
              ),
              Expanded(
                child: _scorePill('Bot', s.opponent.placements.length,
                    s.opponent.score, Colors.orangeAccent),
              ),
            ],
          ),
        ),
        // aktif oyuncu
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
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
                    player?.name ?? (s.human.finished ? 'Bitti' : '—'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
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
                  child: Container(
                    decoration: filled
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFF00E676), width: 1.5),
                          )
                        : null,
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
                                  fontWeight: FontWeight.w700,
                                ),
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
                                  fontWeight: FontWeight.w700,
                                ),
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
    );
  }

  Widget _scorePill(String who, int filled, int score, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141A18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(who,
              style: TextStyle(
                  color: c, fontWeight: FontWeight.w800, fontSize: 12)),
          Text('$filled/16',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}
