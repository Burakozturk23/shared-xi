import 'package:flutter/material.dart';

import '../data/build_xi_formations.dart';
import '../data/build_xi_themes.dart';
import 'build_xi_page.dart';

class BuildXiFormationSelectionPage extends StatelessWidget {
  final BuildXiTheme theme;

  const BuildXiFormationSelectionPage({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Taktik Seç')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: allFormations.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final formation = allFormations[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const Icon(Icons.sports_soccer, size: 32),
              title: Text(formation.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BuildXiPage(theme: theme, formation: formation),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}