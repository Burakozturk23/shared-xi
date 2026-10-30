import 'supported_grid_page.dart';
import '../widgets/grid_club_pool_picker.dart';
import '../widgets/hub_ui.dart';
import 'package:flutter/material.dart';

import 'grid_page.dart';
import 'reverse_grid_page.dart';
import 'random_grid_page.dart';

class GridModeSelectionPage extends StatelessWidget {
  const GridModeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grid Modu')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Text(
              'Hangi grid türüyle oynamak istersin?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            const GridClubPoolPicker(),
            const SizedBox(height: 16),
            ModeStyleCard(
              icon: Icons.grid_view,
              title: 'Klasik',
              specs: 'Kriterlere uyan doğru oyuncuyu bul',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SupportedGridPage(
                    mode: 'solo_grid_classic',
                    legacy: GridPage(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ModeStyleCard(
              icon: Icons.swap_horiz,
              title: 'Tersten',
              specs: 'Üç oyuncunun ortak kriterini bul',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SupportedGridPage(
                    mode: 'solo_grid_reverse',
                    legacy: ReverseGridPage(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ModeStyleCard(
              icon: Icons.shuffle,
              title: 'Rastgele Eşleşme',
              specs: '3 rastgele kulüp çifti, sen yerleştir',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SupportedGridPage(
                    mode: 'solo_grid_random',
                    legacy: RandomGridPage(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
