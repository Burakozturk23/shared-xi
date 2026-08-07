import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'vs_bot_grid_page.dart';
import 'vs_bot_random_grid_page.dart';
import 'vs_bot_reverse_grid_page.dart';

class VsBotGridModeSelectionPage extends StatelessWidget {
  const VsBotGridModeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Bot’a Karşı · Grid'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Hangi grid türüyle bota karşı oynamak istersin?',
            style: TextStyle(fontSize: 16, color: AppTheme.hintColor),
          ),
          const SizedBox(height: 20),
          _Tile(
            icon: Icons.grid_view,
            accent: const Color(0xFF3F51B5),
            title: 'Klasik',
            subtitle: 'Kriterlere uyan oyuncuyu bul · sıra sıra bot',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VsBotGridPage()),
            ),
          ),
          const SizedBox(height: 14),
          _Tile(
            icon: Icons.swap_horiz,
            accent: const Color(0xFF9C27B0),
            title: 'Tersten',
            subtitle: 'Oyuncuları gör, ortak noktayı bot ile kapış',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VsBotReverseGridPage()),
            ),
          ),
          const SizedBox(height: 14),
          _Tile(
            icon: Icons.shuffle,
            accent: const Color(0xFF00897B),
            title: 'Rastgele Eşleşme',
            subtitle: 'Çift üret, yerleştir · bot ile yarış',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VsBotRandomGridPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.hintColor,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.hintColor),
            ],
          ),
        ),
      ),
    );
  }
}