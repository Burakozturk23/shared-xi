import 'package:flutter/material.dart';

import '../controllers/endless_controller.dart';
import '../theme/app_theme.dart';
import 'endless_page.dart';

/// 2. adım: Eşleşme türü seç (Kulüp-Kulüp / Kulüp-Ülke)
class EndlessMatchTypePage extends StatelessWidget {
  final EndlessGameStyle gameStyle;

  const EndlessMatchTypePage({super.key, required this.gameStyle});

  @override
  Widget build(BuildContext context) {
    final styleLabel =
        gameStyle == EndlessGameStyle.blitz ? 'Blitz' : 'Survival';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('$styleLabel · Eşleşme'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Eşleşme türünü seç',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.hintColor,
            ),
          ),
          const SizedBox(height: 16),
          _TypeCard(
            icon: Icons.shield_rounded,
            title: 'Kulüp – Kulüp',
            subtitle: 'Her turda iki rastgele kulüp',
            onTap: () => _start(context, EndlessMatchMode.clubClub),
          ),
          const SizedBox(height: 12),
          _TypeCard(
            icon: Icons.public_rounded,
            title: 'Kulüp – Ülke',
            subtitle: 'Her turda bir kulüp + bir ülke',
            onTap: () => _start(context, EndlessMatchMode.clubCountry),
          ),
        ],
      ),
    );
  }

  void _start(BuildContext context, EndlessMatchMode mode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EndlessPage(
          matchMode: mode,
          gameStyle: gameStyle,
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
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
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.hintColor),
            ],
          ),
        ),
      ),
    );
  }
}