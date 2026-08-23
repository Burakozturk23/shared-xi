import 'package:flutter/material.dart';

import '../models/manager_formation.dart';
import '../models/manager_match.dart';
import '../models/manager_pool.dart';
import '../models/manager_rating.dart';
import '../models/manager_tactics.dart';
import '../services/manager_career_store.dart';
import '../services/manager_match_service.dart';
import 'club_manager_hub_page.dart';
import 'club_manager_season_page.dart';
import 'club_manager_squad_page.dart';

class ClubManagerMatchPage extends StatefulWidget {
  final List<ManagerPoolPlayer> xi;
  final ManagerDifficulty difficulty;
  final int budgetLink;
  final String formationId;
  final ManagerTactics tactics;
  final ManagerOpponent? opponent;
  final String? seasonOpponentId;

  const ClubManagerMatchPage({
    super.key,
    required this.xi,
    required this.difficulty,
    required this.budgetLink,
    required this.formationId,
    this.tactics = const ManagerTactics(),
    this.opponent,
    this.seasonOpponentId,
  });

  @override
  State<ClubManagerMatchPage> createState() => _ClubManagerMatchPageState();
}

class _ClubManagerMatchPageState extends State<ClubManagerMatchPage> {
  ManagerMatchResult? _result;
  bool _running = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final r = ManagerMatchService.instance.simulate(
      xi: widget.xi,
      difficulty: widget.difficulty,
      budgetLink: widget.budgetLink,
      tactics: widget.tactics,
      opponent: widget.opponent,
    );
    await ManagerCareerStore.instance.applyMatchResult(
      difficulty: widget.difficulty,
      remainingBudget: r.remainingAfter,
      isWin: r.isWin,
      isDraw: r.isDraw,
      squadPlayerIds: widget.xi.map((e) => e.playerId).toList(),
      formationId: widget.formationId,
      opponentId: widget.seasonOpponentId,
      userGoals: r.stats.goalsHome,
      oppGoals: r.stats.goalsAway,
    );
    if (!mounted) return;
    setState(() {
      _result = r;
      _running = false;
    });
  }

  void _backToSquad() {
    final formation = ManagerFormations.all.firstWhere(
      (f) => f.id == widget.formationId,
      orElse: () => ManagerFormations.all.first,
    );
    final r = _result!;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ClubManagerSquadPage(
          difficulty: widget.difficulty,
          careerBudget: r.remainingAfter,
          formation: formation,
          initialPlayerIds: widget.xi.map((e) => e.playerId).toList(),
          manageMode: true,
        ),
      ),
    );
  }

  void _toSeason() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => ClubManagerSeasonPage(difficulty: widget.difficulty),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white70,
        title: const Text('Maç', style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: !_running,
      ),
      body: _running || _result == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : _body(_result!),
    );
  }

  Widget _body(ManagerMatchResult r) {
    final outcomeColor = r.isWin
        ? const Color(0xFF00E676)
        : r.isDraw
            ? Colors.amber
            : Colors.redAccent;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          color: const Color(0xFF121820),
          child: Column(
            children: [
              Text(r.outcomeLabel,
                  style: TextStyle(
                      color: outcomeColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text(
                '${r.homeName}  ${r.stats.goalsHome} - ${r.stats.goalsAway}  ${r.awayName}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                r.winBonus > 0
                    ? '+${r.winBonus} LINK · Kasa ${r.remainingAfter}'
                    : 'Kasa ${r.remainingAfter} LINK',
                style: const TextStyle(color: Color(0xFF00E676), fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                      ),
                      onPressed: _toSeason,
                      child: const Text('PUAN DURUMU',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _backToSquad,
                      child: const Text('KADRO'),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ClubManagerHubPage()),
                    (r) => false,
                  );
                },
                child: const Text('Mod seç',
                    style: TextStyle(color: Colors.white38)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: r.events.length,
            itemBuilder: (_, i) {
              final e = r.events[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  "${e.minute}'  ${e.text}",
                  style: TextStyle(
                    color: e.isGoal ? Colors.white : Colors.white60,
                    fontWeight: e.isGoal ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
