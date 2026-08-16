import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'this_or_that_bracket_selection_page.dart';
import 'this_or_that_club_bracket_selection_page.dart';

/// O mu Bu mu? — ana hub
class ThisOrThatModeSelectionPage extends StatelessWidget {
  const ThisOrThatModeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('O mu Bu mu?'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'İki seçenek. Bir karar. Hangisi?',
            style: TextStyle(
              color: AppTheme.hintColor,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 24),
          _ModeCard(
            icon: Icons.person_outline_rounded,
            accent: const Color(0xFFFFB300),
            title: 'Futbolcu vs Futbolcu',
            subtitle: 'Zirve sezonları, efsane formlar — bracket savaşları',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ThisOrThatBracketSelectionPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          _ModeCard(
            icon: Icons.shield_outlined,
            accent: const Color(0xFF26C6DA),
            title: 'Kulüp vs Kulüp',
            subtitle: 'Hanedanlıklar, treble sezonları, efsane kadrolar',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ThisOrThatClubBracketSelectionPage(),
                ),
              );
            },
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
  final bool enabled;

  const _ModeCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accent, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppTheme.textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTheme.hintColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  enabled ? Icons.chevron_right : Icons.lock_outline,
                  color: AppTheme.hintColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}