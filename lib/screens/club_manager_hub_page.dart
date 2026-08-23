import 'package:flutter/material.dart';

import '../models/manager_rating.dart';
import '../repositories/repository.dart';
import '../services/manager_career_store.dart';
import 'club_manager_season_page.dart';

class ClubManagerHubPage extends StatefulWidget {
  const ClubManagerHubPage({super.key});

  @override
  State<ClubManagerHubPage> createState() => _ClubManagerHubPageState();
}

class _ClubManagerHubPageState extends State<ClubManagerHubPage> {
  bool _booting = true;
  final Map<ManagerDifficulty, ManagerCareerState> _careers = {};

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      await Repository.instance.initialize();
    } catch (_) {}
    for (final d in ManagerDifficulty.values) {
      _careers[d] = await ManagerCareerStore.instance.load(d);
    }
    if (mounted) setState(() => _booting = false);
  }

  Future<void> _open(ManagerDifficulty d) async {
    await ManagerCareerStore.instance.startIfNeeded(d);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClubManagerSeasonPage(difficulty: d),
      ),
    );
    final updated = await ManagerCareerStore.instance.load(d);
    if (mounted) setState(() => _careers[d] = updated);
  }

  Future<void> _reset(ManagerDifficulty d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141A18),
        title: const Text('Sıfırla?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Sezon, kadro ve bütçe silinecek.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sıfırla')),
        ],
      ),
    );
    if (ok != true) return;
    await ManagerCareerStore.instance.reset(d);
    final fresh = await ManagerCareerStore.instance.load(d);
    if (mounted) setState(() => _careers[d] = fresh);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white70,
        title: const Text('Club Manager', style: TextStyle(color: Colors.white)),
      ),
      body: _booting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                const Text(
                  '19 HAFTALIK SEZON',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '18 rakip · 19 maç · puan durumu ve fikstür.\n'
                  'Her hafta kadronla çık, taktik seç, sıralamayı kap.',
                  style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.35),
                ),
                const SizedBox(height: 20),
                for (final d in ManagerDifficulty.values) ...[
                  _DiffCard(
                    difficulty: d,
                    career: _careers[d] ?? ManagerCareerState.fresh(d),
                    accent: d == ManagerDifficulty.easy
                        ? const Color(0xFF00E676)
                        : d == ManagerDifficulty.medium
                            ? Colors.orangeAccent
                            : Colors.redAccent,
                    onPlay: () => _open(d),
                    onReset: () => _reset(d),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _DiffCard extends StatelessWidget {
  final ManagerDifficulty difficulty;
  final ManagerCareerState career;
  final Color accent;
  final VoidCallback onPlay;
  final VoidCallback onReset;

  const _DiffCard({
    required this.difficulty,
    required this.career,
    required this.accent,
    required this.onPlay,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final season = career.season;
    final week = season?.nextFixture?.week;
    return Material(
      color: const Color(0xFF141A22),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(difficulty.label.toUpperCase(),
                    style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1)),
                const Spacer(),
                if (career.started)
                  TextButton(
                    onPressed: onReset,
                    child: const Text('Sıfırla',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ),
              ],
            ),
            Text('${career.budgetLink} LINK',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              season == null
                  ? '19 haftalık yeni sezon'
                  : season.isComplete
                      ? 'Sezon bitti · Sıra ${season.userRank()}'
                      : 'Hafta $week/19 · Sıra ${season.userRank()} · ${season.user.points} puan',
              style: TextStyle(
                  color: accent, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                ),
                onPressed: onPlay,
                child: Text(
                  season == null ? 'SEZONU BAŞLAT' : 'SEZONA GİR',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
