import 'package:flutter/material.dart';

import '../models/manager_formation.dart';
import '../models/manager_rating.dart';
import 'club_manager_squad_page.dart';

class ClubManagerFormationPage extends StatelessWidget {
  final ManagerDifficulty difficulty;
  final int careerBudget;

  const ClubManagerFormationPage({
    super.key,
    required this.difficulty,
    required this.careerBudget,
  });

  void _select(BuildContext context, ManagerFormation f) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClubManagerSquadPage(
          difficulty: difficulty,
          careerBudget: careerBudget,
          formation: f,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cats = ManagerFormations.categories;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white70,
        title: Text('Formasyon · ${difficulty.label}',
            style: const TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Text('Bütçe: $careerBudget LINK',
              style: const TextStyle(
                  color: Color(0xFF00E676), fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            'Dizilişi seç. Sonra oyuncuyu seçip sahadaki mevkiye sen yerleştir.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          for (final cat in cats) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 8),
              child: Text(cat.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final f
                    in ManagerFormations.all.where((e) => e.category == cat))
                  _FormationTile(formation: f, onTap: () => _select(context, f)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FormationTile extends StatelessWidget {
  final ManagerFormation formation;
  final VoidCallback onTap;

  const _FormationTile({required this.formation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final f = formation;
    return Material(
      color: const Color(0xFF141A22),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: const Color(0xFF00E676).withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2818),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    for (final row in f.rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (final _ in row)
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00E676),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(f.label,
                  style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontWeight: FontWeight.w900,
                      fontSize: 16)),
              Text(f.blurb,
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
