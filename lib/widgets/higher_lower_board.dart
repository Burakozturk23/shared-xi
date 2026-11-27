import 'package:flutter/material.dart';

import '../theme/ortak_saha_theme.dart';
import '../utils/country_names.dart';
import 'bot_arena.dart';

String _position(dynamic raw) =>
    const {
      'Goalkeeper': 'Kaleci',
      'Defender': 'Defans',
      'Midfield': 'Orta saha',
      'Attack': 'Forvet',
    }['$raw'] ??
    '';

/// "Portekiz · Forvet" for a catalog player; empty when the catalog has neither.
String playerMeta(Map<dynamic, dynamic> player) {
  final raw = '${player['country'] ?? ''}'.trim();
  final country = raw.isEmpty ? '' : CountryNames.canonical(raw);
  return [
    country,
    _position(player['position']),
  ].where((s) => s.isNotEmpty).join(' · ');
}

/// One player of a Higher or Lower pair: portrait or initials, name and value.
class VersusCard extends StatelessWidget {
  const VersusCard({
    super.key,
    required this.player,
    required this.color,
    this.value,
    this.caption,
    this.footer,
  });
  final Map<dynamic, dynamic> player;
  final Color color;

  /// Null while the value is still hidden.
  final String? value;
  final String? caption;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final name = '${player['name'] ?? 'Oyuncu'}';
    final meta = playerMeta(player);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .55), width: 1.4),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .16), p.surface],
        ),
      ),
      child: Column(
        children: [
          ArenaPlayerAvatar(
            id: player['playerId'],
            name: name,
            size: 84,
            ring: color,
          ),
          const SizedBox(height: 10),
          Text(
            name,
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              meta,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: p.muted),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            value ?? '?',
            textAlign: TextAlign.center,
            style: text.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          if (caption != null)
            Text(
              caption!,
              textAlign: TextAlign.center,
              style: text.labelMedium?.copyWith(color: p.muted),
            ),
          if (footer != null) ...[const SizedBox(height: 14), footer!],
        ],
      ),
    );
  }
}

/// The round "VEYA" badge between the two players.
class VersusBadge extends StatelessWidget {
  const VersusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Divider(color: p.border),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: p.background,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Arena.lime.withValues(alpha: .7)),
            ),
            child: Text(
              'VEYA',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: Arena.lime,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A selectable statistic in the setup list.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final ink = selected ? Arena.lime : p.muted;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? p.limeTint : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? Arena.lime : p.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: ink),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: selected ? p.text : null,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: Arena.lime,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
