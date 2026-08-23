import 'package:flutter/material.dart';

import '../controllers/loto_controller.dart';
import '../models/loto_models.dart';
import '../repositories/repository.dart';
import '../services/loto_generator.dart';

class LotoPage extends StatefulWidget {
  const LotoPage({super.key});

  @override
  State<LotoPage> createState() => _LotoPageState();
}

class _LotoPageState extends State<LotoPage> {
  late final LotoController _c;
  bool _booting = true;
  String? _league;
  LotoDifficulty _diff = LotoDifficulty.medium;
  bool _started = false;
  bool _resultShown = false;

  @override
  void initState() {
    super.initState();
    _c = LotoController()..addListener(_onCtrl);
    _boot();
  }

  Future<void> _boot() async {
    try {
      await Repository.instance.initialize();
    } catch (_) {}
    if (mounted) setState(() => _booting = false);
  }

  void _onCtrl() {
    if (!mounted) return;
    setState(() {});
    if (_c.state.isFinished && !_resultShown) {
      _resultShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResult());
    }
  }

  @override
  void dispose() {
    _c.removeListener(_onCtrl);
    _c.disposeController();
    super.dispose();
  }

  Future<void> _showResult() async {
    final s = _c.state;
    final correct = s.finalCorrect ?? 0;
    final wrong = s.finalWrong ?? 0;
    final score = s.finalScore ?? 0;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141A18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Column(
            children: [
              Icon(Icons.sports_soccer, color: Color(0xFF00E676), size: 40),
              SizedBox(height: 8),
              Text('TAMAMLADIN!',
                  style: TextStyle(
                      color: Color(0xFFFFD54F), fontWeight: FontWeight.w900)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$correct doğru, $wrong yanlış — Toplam $score puan',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _scoreBox('$correct', '✓ DOĞRU',
                        const Color(0xFF1B3D2F), const Color(0xFF00E676)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _scoreBox('$wrong', '✗ YANLIŞ',
                        const Color(0xFF3D1B1B), Colors.redAccent),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _dlgBtn('Aynı Ayarlarla Yeni Oyun', () {
                Navigator.pop(ctx);
                _resultShown = false;
                _c.restartSame();
              }),
              const SizedBox(height: 8),
              _dlgBtn('Lig Seç', () {
                Navigator.pop(ctx);
                setState(() {
                  _started = false;
                  _resultShown = false;
                });
              }),
              const SizedBox(height: 8),
              _dlgBtn('Çıkış', () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _scoreBox(String n, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(n,
              style: TextStyle(
                  color: fg, fontSize: 28, fontWeight: FontWeight.w900)),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _dlgBtn(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00E676),
          foregroundColor: Colors.black,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
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
        title:
            const Text('Football Loto', style: TextStyle(color: Colors.white)),
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
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final L in leagues) _leagueChip(L)],
        ),
        const SizedBox(height: 20),
        const Text(
          'Oyuncu bilinirliği, kriter çeşitliliği ve cevap süresi seçtiğin seviyeye göre değişir.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 12),
        for (final d in LotoDifficulty.values) _diffCard(d),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.white12,
            ),
            onPressed: _league == null
                ? null
                : () {
                    _resultShown = false;
                    setState(() => _started = true);
                    _c.start(leagueFilter: _league, difficulty: _diff);
                  },
            child: const Text('Oyunu Başlat',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  Widget _diffCard(LotoDifficulty d) {
    final selected = _diff == d;
    final color = d == LotoDifficulty.easy
        ? const Color(0xFF00E676)
        : d == LotoDifficulty.medium
            ? Colors.orangeAccent
            : Colors.redAccent;
    return GestureDetector(
      onTap: () => setState(() => _diff = d),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141A18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.white12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: color),
                const SizedBox(width: 8),
                Text(d.label.toUpperCase(),
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            Text(d.description,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            Text('Oyuncu başına ${d.secondsPerPlayer} saniye',
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _leagueChip(String label) {
    final selected = _league == label;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFF00E676),
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.white70,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      backgroundColor: const Color(0xFF1A2420),
      onSelected: (_) => setState(() => _league = label),
    );
  }

  Widget _game() {
    final s = _c.state;
    final board = s.board;
    final player = s.currentPlayer;
    if (board == null) {
      return const Center(
          child: Text('Tahta yok', style: TextStyle(color: Colors.white)));
    }

    return Column(
      children: [
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
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: s.remainingSeconds /
                            board.difficulty.secondsPerPlayer,
                        color: const Color(0xFF00E676),
                        backgroundColor: Colors.white24,
                        strokeWidth: 4,
                      ),
                      Text('${s.remainingSeconds}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player?.name ?? (s.isFinished ? 'Bitti' : '—'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${s.placements.length}/16 yerleştirildi  ·  '
                        '${s.queueIndex + (s.isFinished ? 0 : 1)}/${s.totalPlayers}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: s.isFinished ? null : _c.pass,
                  child: const Text('Pas Geç',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: GridView.builder(
              itemCount: 16,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 0.92,
              ),
              itemBuilder: (_, i) {
                final cell = board.cells[i];
                final placedId = s.placements[i];
                final filled = placedId != null;
                final placedName = filled
                    ? Repository.instance.playerById(placedId!)?.name
                    : null;

                return Material(
                  color: filled
                      ? const Color(0xFF1B5E20)
                      : const Color(0xFF2A3340),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap:
                        filled || s.isFinished ? null : () => _c.tapCell(i),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: filled
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFF00E676), width: 1.5),
                            )
                          : null,
                      padding: const EdgeInsets.all(6),
                      child: filled
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Align(
                                  alignment: Alignment.topRight,
                                  child: Icon(Icons.check_circle,
                                      color: Color(0xFF00E676), size: 14),
                                ),
                                Text(
                                  placedName ?? '',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_icon(cell.type),
                                    size: 18, color: Colors.white54),
                                const SizedBox(height: 4),
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
                                Text(
                                  cell.subtitle,
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 9),
                                ),
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: OutlinedButton(
            onPressed: () => setState(() {
              _started = false;
              _resultShown = false;
            }),
            child: const Text('Çıkış'),
          ),
        ),
      ],
    );
  }

  IconData _icon(LotoCriterionType t) {
    switch (t) {
      case LotoCriterionType.club:
        return Icons.shield;
      case LotoCriterionType.country:
        return Icons.flag;
      case LotoCriterionType.league:
        return Icons.emoji_events;
      case LotoCriterionType.position:
        return Icons.sports_soccer;
      case LotoCriterionType.decade:
        return Icons.calendar_today;
    }
  }
}
