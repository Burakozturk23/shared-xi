import 'package:flutter/material.dart';

import '../theme/ortak_saha_theme.dart';
import 'hub_ui.dart';
import 'pitch_ui.dart';

/// Destination card used by the games and online hubs: icon and count pill,
/// title and description, then a hairline above an accent footer link.
class PitchTile extends StatelessWidget {
  const PitchTile({
    super.key,
    required this.title,
    required this.caption,
    required this.icon,
    required this.onTap,
    this.countLabel,
    this.description,
    this.footerColor,
    this.featured = false,
    this.preview,
  });

  final String title, caption;
  final String? countLabel, description;

  /// Short content hint above the footer, e.g. "Club Manager · +4".
  final String? preview;
  final IconData icon;
  final VoidCallback onTap;
  final Color? footerColor;

  /// Full-width hero variant (cyan atmosphere, larger title).
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    // Story is the featured tile; it carries the amber story accent.
    final amber = hubAmber(context);
    final footer = featured ? amber : footerColor ?? p.accent;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HubIconBox(
              icon,
              size: featured ? 48 : 44,
              color: featured ? amber : p.accent,
              background: featured ? amber.withValues(alpha: .12) : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.topRight,
                child: countLabel == null
                    ? null
                    : HubPill(
                        countLabel!,
                        color: featured ? amber : p.muted,
                        background: featured
                            ? amber.withValues(alpha: .12)
                            : p.raised,
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(title, style: featured ? text.titleLarge : text.titleSmall),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(description!, style: text.bodySmall?.copyWith(color: p.muted)),
        ],
        if (!featured) const Spacer(),
        if (preview != null) ...[
          const SizedBox(height: 10),
          Text(
            preview!,
            style: text.labelMedium?.copyWith(
              color: p.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Divider(height: 1, thickness: 1, color: p.border),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                caption,
                style: text.labelMedium?.copyWith(
                  color: footer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              featured
                  ? Icons.arrow_forward_rounded
                  : Icons.chevron_right_rounded,
              size: 20,
              color: featured ? footer : p.muted,
            ),
          ],
        ),
      ],
    );
    return Semantics(
      button: true,
      child: featured
          ? HubHeroCard(onTap: onTap, accent: amber, child: body)
          : ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 168),
              child: PitchPanel(onTap: onTap, child: body),
            ),
    );
  }
}

/// At most two columns. Intrinsic row heights allow wrapped and enlarged text;
/// there is no fixed aspect ratio or clipped description.
class PitchTileGrid extends StatelessWidget {
  const PitchTileGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final columns = constraints.maxWidth >= 280 * textScale ? 2 : 1;
      return Column(
        children: [
          for (var index = 0; index < children.length; index += columns)
            Padding(
              padding: EdgeInsets.only(
                bottom: index + columns < children.length ? 16 : 0,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: children[index]),
                    if (columns == 2) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: index + 1 < children.length
                            ? children[index + 1]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
