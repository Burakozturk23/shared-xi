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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Hangi grid türüyle oynamak istersin?',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            _ModeTile(
              icon: Icons.grid_view,
              title: 'Klasik',
              subtitle: 'Kriterlere uyan doğru oyuncuyu bul',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GridPage()),
              ),
            ),
            const SizedBox(height: 14),
            _ModeTile(
              icon: Icons.swap_horiz,
              title: 'Tersten',
              subtitle: 'İki oyuncunun ortak kulübünü bul',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReverseGridPage()),
              ),
            ),
            const SizedBox(height: 14),
            _ModeTile(
  icon: Icons.shuffle,
  title: 'Rastgele Eşleşme',
  subtitle: '3 rastgele kulüp çifti, sen yerleştir',
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const RandomGridPage()),
  ),
),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool locked;
  final VoidCallback onTap;

  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.locked = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, size: 32),
        title: Row(
          children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (locked) ...[
              const SizedBox(width: 6),
              const Icon(Icons.lock, size: 14, color: Colors.grey),
            ],
          ],
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}