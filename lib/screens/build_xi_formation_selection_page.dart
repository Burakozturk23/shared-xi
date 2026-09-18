import 'package:flutter/material.dart';

import '../models/squad_challenge.dart';
import '../widgets/pitch_ui.dart';

class BuildXiFormationSelectionPage extends StatelessWidget {
  const BuildXiFormationSelectionPage({
    super.key,
    required this.theme,
    required this.catalog,
  });
  final SquadTheme theme;
  final SquadCatalog catalog;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dizilişini seç')),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(theme.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Antrenman · 160 kadro kredisi · Süre ve deneme sınırı yok.',
          ),
          const SizedBox(height: 20),
          for (final f in catalog.formations.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PitchRow(
                title: f.name,
                subtitle: '11 oyuncu · Bağ kur, bütçeyi yönet',
                icon: Icons.schema_outlined,
                onTap: () => Navigator.of(context).pop(f),
              ),
            ),
        ],
      ),
    ),
  );
}
