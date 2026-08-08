import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'vs_bot_cinko_page.dart';
import 'vs_bot_club_selection_page.dart';
import 'vs_bot_grid_mode_selection_page.dart';
import 'vs_bot_random_five_page.dart';

class VsBotModeSelectionPage extends StatelessWidget {
  const VsBotModeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Bot’a Karşı'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Nasıl oynamak istersin?',
            style: TextStyle(fontSize: 16, color: AppTheme.hintColor),
          ),
          const SizedBox(height: 20),
          _ModeCard(
            icon: Icons.smart_toy_rounded,
            accent: const Color(0xFFE91E63),
            title: 'Takım Yarışı',
            subtitle: 'Takımını seç, bot ile ortak oyuncu bul',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VsBotClubSelectionPage(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _ModeCard(
            icon: Icons.grid_view_rounded,
            accent: const Color(0xFF3F51B5),
            title: '3×3 Grid',
            subtitle: 'Klasik · Tersten · Rastgele Eşleşme',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VsBotGridModeSelectionPage(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _ModeCard(
            icon: Icons.grid_on_rounded,
            accent: const Color(0xFF00BCD4),
            title: 'Futbol Çinko',
            subtitle: 'Bot ile sırayla ızgarayı boya',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VsBotCinkoPage(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _ModeCard(
            icon: Icons.casino_rounded,
            accent: const Color(0xFFFF9800),
            title: 'Rastgele Beşler',
            subtitle: 'Aynı 5 kulüp · 5’er tur bot ile yarış',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VsBotRandomFivePage(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeCard({
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
