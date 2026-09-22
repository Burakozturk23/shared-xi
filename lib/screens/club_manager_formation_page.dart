import 'package:flutter/material.dart';

import '../models/manager_formation.dart';
import '../models/manager_rating.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/manager_ui.dart';
import '../widgets/pitch_ui.dart';

class ClubManagerFormationPage extends StatelessWidget {
  const ClubManagerFormationPage({
    super.key,
    required this.difficulty,
    required this.careerBudget,
    this.selectedId,
  });
  final ManagerDifficulty difficulty;
  final int careerBudget;
  final String? selectedId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dizilişini seç')),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            'Oyunun sahada başlar.',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text('${difficulty.label} · Kasa $careerBudget LINK'),
          const SizedBox(height: 10),
          const Text(
            'Sistemi seç, oyuncuları uygun mevkilerine yerleştir. '
            'Diziliş değişince dışarıda kalan oyuncular yedeklerinde kalır.',
          ),
          for (final category in ManagerFormations.categories) ...[
            PitchSectionTitle(category),
            for (final f in ManagerFormations.all.where(
              (f) => f.category == category,
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PitchPanel(
                  onTap: () => Navigator.of(context).pop(f),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              f.label,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          if (selectedId == f.id)
                            const Icon(Icons.check_circle_outline),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(f.blurb),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final group in ['GK', 'DEF', 'MID', 'ATT'])
                            ManagerTag('$group ${f.countGroup(group)}'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Semantics(
                        label: '${f.label} saha dizilişi',
                        child: ExcludeSemantics(
                          child: Column(
                            children: [
                              for (final row in f.rows)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      for (final _ in row)
                                        Icon(
                                          Icons.circle,
                                          size: 10,
                                          color: PitchColors.of(context).accent,
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    ),
  );
}
