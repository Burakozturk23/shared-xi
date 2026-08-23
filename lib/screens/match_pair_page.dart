import 'package:flutter/material.dart';

import '../controllers/match_pair_controller.dart';
import '../models/match_pair_models.dart';
import '../repositories/repository.dart';

class MatchPairPage extends StatefulWidget {
  const MatchPairPage({super.key});

  @override
  State<MatchPairPage> createState() => _MatchPairPageState();
}

class _MatchPairPageState extends State<MatchPairPage> {
  late final MatchPairController _c;
  bool _booting = true;
  bool _started = false;
  MatchDifficulty _diff = MatchDifficulty.medium;

  @override
  void initState() {
    super.initState();
    _c = MatchPairController()..addListener(_refresh);
    _boot();
  }

  Future<void> _boot() async {
    try {
      // Repo zaten yüklüyse hızlı çıkar
      if (!Repository.instance.isInitialized) {
        await Repository.instance.initialize();
      }
    } catch (_) {}
    if (mounted) setState(() => _booting = false);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_refresh);
    _c.disposeController();
    super.dispose();
  }

  String _fmtTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white70,
        title: const Text('Eşleştirme', style: TextStyle(color: Colors.white)),
        actions: [
          if (_started)
            TextButton(
              onPressed: () {
                setState(() => _started = false);
              },
              child: const Text('Seviye',
                  style: TextStyle(color: Color(0xFF00E676))),
            ),
        ],
      ),
      body: _booting
          ? const Center(child: CircularProgressIndicator())
          : !_started
              ? _setup()
              : _game(),
    );
  }

  Widget _setup() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'ZORLUK SEÇ',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Oyuncu havuzu piyasa değerine göre belirlenir.\n'
          '12 çift · 24 kart (6×4)',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 20),
        for (final d in MatchDifficulty.values) _diffCard(d),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () async {
              setState(() => _started = true);
              await _c.startNew(_diff);
            },
            child: const Text('Oyunu Başlat',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _diffCard(MatchDifficulty d) {
    final selected = _diff == d;
    final color = d == MatchDifficulty.easy
        ? const Color(0xFF00E676)
        : d == MatchDifficulty.medium
            ? Colors.orangeAccent
            : Colors.redAccent;
    final (minV, maxV) = d.valueRange;
    final rangeText = d == MatchDifficulty.easy
        ? '50M€+ peak değer'
        : d == MatchDifficulty.medium
            ? '20M€ – 50M€ peak değer'
            : '0 – 20M€ peak değer';

    return GestureDetector(
      onTap: () => setState(() => _diff = d),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.12)
              : const Color(0xFF141A22),
          borderRadius: BorderRadius.circular(14),
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
                Text(
                  d.label.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(d.description,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Text(rangeText,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _game() {
    final s = _c.state;
    final board = s.board;

    if (s.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF00E676)),
            SizedBox(height: 12),
            Text('Tahta hazırlanıyor…',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    if (s.error != null) {
      return Center(
        child: Text(s.error!, style: const TextStyle(color: Colors.redAccent)),
      );
    }
    if (board == null) {
      return const Center(
        child: Text('Tahta yok', style: TextStyle(color: Colors.white)),
      );
    }

    // 6 sütun x 4 satır = 24
    final cross = board.cards.length >= 24 ? 6 : 4;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Text(
                'Hamle ${s.moves}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 16),
              Text(
                _fmtTime(s.seconds),
                style: const TextStyle(color: Colors.white70),
              ),
              const Spacer(),
              Text(
                '${s.matchedPairIds.length}/${board.pairCount}',
                style: const TextStyle(
                    color: Color(0xFF00E676), fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        if (s.isComplete)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Tamamlandı!',
              style: TextStyle(
                color: Color(0xFF00E676),
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.78,
            ),
            itemCount: board.cards.length,
            // Performans: sabit extent yok ama cacheExtent düşük
            cacheExtent: 200,
            itemBuilder: (_, i) {
              final card = board.cards[i];
              final up = s.isFaceUp(i);
              return _CardTile(
                key: ValueKey(card.id),
                label: card.label,
                isClub: card.kind == MatchCardKind.club,
                faceUp: up,
                onTap: up ? null : () => _c.tapCard(i),
              );
            },
          ),
        ),
        if (s.isComplete)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
              ),
              onPressed: _c.restart,
              child: const Text('Tekrar oyna',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    );
  }
}

class _CardTile extends StatelessWidget {
  final String label;
  final bool isClub;
  final bool faceUp;
  final VoidCallback? onTap;

  const _CardTile({
    super.key,
    required this.label,
    required this.isClub,
    required this.faceUp,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: faceUp ? const Color(0xFF1A2332) : const Color(0xFF121820),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: faceUp
                  ? (isClub ? Colors.amber.shade700 : const Color(0xFF00E676))
                  : Colors.white12,
              width: faceUp ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: faceUp
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isClub ? Icons.shield : Icons.person,
                      size: 16,
                      color: isClub ? Colors.amber : const Color(0xFF00E676),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : const Center(
                  child: Icon(Icons.sports_soccer,
                      color: Colors.white24, size: 22),
                ),
        ),
      ),
    );
  }
}
