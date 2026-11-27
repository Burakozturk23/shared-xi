import 'package:flutter/material.dart';

import '../theme/ortak_saha_theme.dart';
import 'hub_ui.dart';
import 'pitch_ui.dart';

/// Bot game entry. The compact variant is a list or grid tile; [featured]
/// renders the full-width hero with an explicit play action.
class BotModeCard extends StatelessWidget {
  const BotModeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tags,
    required this.onTap,
    this.badge,
    this.featured = false,
    this.fillHeight = false,
    this.accentFooter = true,
  });

  final String title, subtitle;
  final IconData icon;
  final List<String> tags;
  final VoidCallback onTap;

  /// Small caps label in the top-right corner ("DÜELLO").
  final String? badge;
  final bool featured;

  /// Pushes the footer to the bottom when the tile sits in an equal-height row.
  final bool fillHeight;

  /// Cyan footer when true, lime otherwise.
  final bool accentFooter;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final type = Theme.of(context).textTheme;
    if (featured) {
      return Semantics(
        button: true,
        child: HubHeroCard(
          onTap: onTap,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Flexible(
                    child: HubPill(
                      'ÖNE ÇIKAN',
                      color: p.limeInk,
                      background: p.limeTint,
                      dot: true,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: HubPill(
                          badge!,
                          color: p.accent,
                          background: p.background.withValues(alpha: .4),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  HubIconBox(icon, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: type.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: type.bodySmall?.copyWith(color: p.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: p.border),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tags.join(' · '),
                      style: type.labelMedium?.copyWith(color: p.text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ExcludeSemantics(
                    child: HubCompactAction(
                      label: 'Hemen Oyna',
                      icon: Icons.play_arrow_rounded,
                      onPressed: onTap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    final footer = accentFooter ? p.accent : p.limeInk;
    return Semantics(
      button: true,
      child: PitchPanel(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HubIconBox(icon, size: 44),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: badge == null
                        ? null
                        : HubPill(badge!, color: p.accent, background: p.tint),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: type.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: type.bodySmall?.copyWith(color: p.muted)),
            if (fillHeight) const Spacer(),
            const SizedBox(height: 12),
            Divider(height: 1, color: p.border),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tags.isEmpty ? 'Kuralları gör' : tags.first,
                    style: type.labelMedium?.copyWith(
                      color: footer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: p.muted, size: 20),
              ],
            ),
            if (tags.length > 1) ...[
              const SizedBox(height: 4),
              Text(tags.skip(1).join(' · '), style: type.labelSmall),
            ],
          ],
        ),
      ),
    );
  }
}
