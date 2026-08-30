import 'package:flutter/material.dart';

import '../models/player.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';
import 'linkball_card.dart';
import 'player_avatar.dart';

/// Reusable Linkball player card for grids, results and selection screens.
class PlayerCard extends StatelessWidget {
  final Player player;
  final VoidCallback? onTap;
  final bool selected;
  final bool disabled;
  final bool compact;
  final int? multiplier;
  final bool showMeta;

  const PlayerCard({
    super.key,
    required this.player,
    this.onTap,
    this.selected = false,
    this.disabled = false,
    this.compact = false,
    this.multiplier,
    this.showMeta = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatarSize = compact ? AppSizes.compactAvatar : AppSizes.cardAvatar;

    return LinkballCard(
      selected: selected,
      disabled: disabled,
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.xs : AppSpacing.sm,
        vertical: compact ? AppSpacing.xs : AppSpacing.sm,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PlayerAvatar(player: player, size: avatarSize),
              SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
              Text(
                player.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textColor,
                  fontSize: compact ? 12 : 13,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (showMeta && _meta.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  _meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.hintColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          if (multiplier != null && multiplier! > 1)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.elevatedCardColor,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: AppTheme.strongBorderColor),
                  boxShadow: AppShadows.soft,
                ),
                child: Text(
                  '${multiplier!}×',
                  style: const TextStyle(
                    color: AppTheme.textColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String get _meta {
    final values = <String>[];
    if (player.position.trim().isNotEmpty) values.add(player.position.trim());
    if (player.countries.isNotEmpty) values.add(player.countries.first);
    return values.join(' · ');
  }
}
