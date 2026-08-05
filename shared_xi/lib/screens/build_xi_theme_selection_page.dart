import 'package:flutter/material.dart';

import '../data/build_xi_themes.dart';
import 'build_xi_formation_selection_page.dart';

class BuildXiThemeSelectionPage extends StatelessWidget {
  const BuildXiThemeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Build XI - Tema Seç')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: buildXiThemes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final theme = buildXiThemes[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(theme.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(theme.description),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BuildXiFormationSelectionPage(theme: theme),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}