import 'package:flutter/material.dart';

import '../theme/ortak_saha_theme.dart';
import 'pitch_ui.dart';

class BotModeCard extends StatelessWidget {
  const BotModeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tags,
    required this.onTap,
  });

  final String title, subtitle;
  final IconData icon;
  final List<String> tags;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final type = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      child: PitchPanel(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: p.tint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: p.accent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: type.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: type.bodySmall),
                  const SizedBox(height: 8),
                  Text(tags.join(' · '), style: type.labelSmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Icon(
                Icons.chevron_right_rounded,
                color: p.muted,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
