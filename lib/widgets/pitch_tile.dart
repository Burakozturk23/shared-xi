import 'package:flutter/material.dart';

import '../theme/ortak_saha_theme.dart';
import 'pitch_ui.dart';

/// Compact destination card used by the games and online hubs.
class PitchTile extends StatelessWidget {
  const PitchTile({
    super.key,
    required this.title,
    required this.caption,
    required this.icon,
    required this.onTap,
    this.countLabel,
  });

  final String title, caption;
  final String? countLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 144),
      child: PitchPanel(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: PitchColors.of(context).accent),
                if (countLabel != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      countLabel!,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            const SizedBox(height: 16),
            Text(caption, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    ),
  );
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
