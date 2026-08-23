import 'package:flutter/material.dart';

import '../models/manager_formation.dart';
import '../models/manager_rating.dart';
import '../models/manager_season.dart';
import '../services/manager_career_store.dart';
import '../services/manager_season_service.dart';
import 'club_manager_formation_page.dart';
import 'club_manager_squad_page.dart';
import 'club_manager_transfer_page.dart';

class ClubManagerSeasonPage extends StatefulWidget {
  final ManagerDifficulty difficulty;

  const ClubManagerSeasonPage({super.key, required this.difficulty});

  @override
  State<ClubManagerSeasonPage> createState() => _ClubManagerSeasonPageState();
}

class _ClubManagerSeasonPageState extends State<ClubManagerSeasonPage>
    with SingleTickerProviderStateMixin {
  ManagerCareerState? _career;
  bool _loading = true;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    var c = await ManagerCareerStore.instance.startIfNeeded(widget.difficulty);
    if (c.season == null) {
      final season = ManagerSeasonService.instance.createSeason();
      c = c.copyWith(season: season, started: true);
      await ManagerCareerStore.instance.save(c);
    }
    if (!mounted) return;
    setState(() {
      _career = c;
      _loading = false;
    });
  }

  Future<void> _openTransfer() async {
    final c = _career!;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClubManagerTransferPage(
          difficulty: widget.difficulty,
          cash: c.budgetLink,
          squadIds: c.squadPlayerIds,
          benchIds: c.benchPlayerIds,
        ),
      ),
    );
    await _load();
  }

  Future<void> _continue() async {
    final c = _career!;
    if (c.hasSquad) {
      final formation = ManagerFormations.all.firstWhere(
        (f) => f.id == c.formationId,
        orElse: () => ManagerFormations.all.first,
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClubManagerSquadPage(
            difficulty: widget.difficulty,
            careerBudget: c.budgetLink,
            formation: formation,
            initialPlayerIds: c.squadPlayerIds,
            manageMode: true,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClubManagerFormationPage(
            difficulty: widget.difficulty,
            careerBudget: c.budgetLink,
          ),
        ),
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _career?.season == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E14),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final season = _career!.season!;
    final next = season.nextFixture;
    final rank = season.userRank();
    final user = season.user;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white70,
        title: Text('Sezon · ${widget.difficulty.label}',
            style: const TextStyle(color: Colors.white)),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Fikstür'),
            Tab(text: 'Puan durumu'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            color: const Color(0xFF121820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  season.isComplete
                      ? 'Sezon bitti · Sıra $rank/19'
                      : 'Hafta ${next!.week}/19 · Sıra $rank',
                  style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontWeight: FontWeight.w800,
                      fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Puan ${user.points} · ${user.won}G ${user.drawn}B ${user.lost}M · ${user.gf}:${user.ga}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                if (next != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Sıradaki: ${season.clubs.firstWhere((c) => c.id == next.opponentId).name}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _fixtures(season),
                _table(season),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: season.isComplete ? null : _openTransfer,
                      child: const Text('TRANSFER'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: season.isComplete ? null : _continue,
                      child: Text(
                        season.isComplete
                            ? 'BİTTİ'
                            : (_career!.hasSquad ? 'HAFTAYA DEVAM' : 'KADRO KUR'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fixtures(ManagerSeason season) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: season.fixtures.length,
      itemBuilder: (_, i) {
        final f = season.fixtures[i];
        final opp = season.clubs.firstWhere((c) => c.id == f.opponentId);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: f.played
                ? const Color(0xFF141A22)
                : const Color(0xFF1B3D2F).withOpacity(0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: !f.played
                  ? const Color(0xFF00E676).withOpacity(0.4)
                  : Colors.white10,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text('H${f.week}',
                    style: const TextStyle(
                        color: Colors.white38, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: Text(opp.name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              if (f.played)
                Text(
                  '${f.userGoals} - ${f.oppGoals}',
                  style: TextStyle(
                    color: (f.userGoals ?? 0) > (f.oppGoals ?? 0)
                        ? const Color(0xFF00E676)
                        : (f.userGoals == f.oppGoals)
                            ? Colors.amber
                            : Colors.redAccent,
                    fontWeight: FontWeight.w900,
                  ),
                )
              else
                Text('${opp.strength.toStringAsFixed(0)} G',
                    style: const TextStyle(color: Colors.white30, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  Widget _table(ManagerSeason season) {
    final table = season.table();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: table.length,
      itemBuilder: (_, i) {
        final c = table[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: c.isUser
                ? const Color(0xFF1B3D2F)
                : const Color(0xFF141A22),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text('${i + 1}',
                    style: const TextStyle(
                        color: Colors.white38, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: Text(
                  c.name,
                  style: TextStyle(
                    color: c.isUser ? const Color(0xFF00E676) : Colors.white,
                    fontWeight: c.isUser ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text('${c.played}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ),
              SizedBox(
                width: 36,
                child: Text('${c.gd >= 0 ? '+' : ''}${c.gd}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ),
              SizedBox(
                width: 28,
                child: Text('${c.points}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13)),
              ),
            ],
          ),
        );
      },
    );
  }
}
