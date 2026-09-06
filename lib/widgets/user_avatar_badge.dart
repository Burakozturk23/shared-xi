import 'package:flutter/material.dart';

import '../models/linkball_profile_schema.dart';
import '../models/user_avatar_catalog.dart';

class UserAvatarBadge extends StatelessWidget {
  final String avatarId;
  final double radius;
  final bool showLocked;

  const UserAvatarBadge({
    super.key,
    required this.avatarId,
    this.radius = 26,
    this.showLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final definition = UserAvatarCatalog.byId(avatarId) ??
        UserAvatarCatalog.byId(LinkballProfileSchema.defaultAvatarId)!;

    final accent = _accentFor(definition.visualKey);
    final icon = _iconFor(definition.visualKey);

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.16),
        border: Border.all(
          color: accent.withValues(alpha: 0.55),
          width: 1.4,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, size: radius * 0.95, color: accent),
          if (showLocked && !definition.isStarter)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: radius * 0.72,
                height: radius * 0.72,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: radius * 0.42,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static IconData _iconFor(String visualKey) {
    return switch (visualKey) {
      'shield' => Icons.shield_outlined,
      'keeper' => Icons.sports_handball_outlined,
      'star' => Icons.auto_awesome_rounded,
      'bolt' => Icons.bolt_rounded,
      'tactics' => Icons.account_tree_outlined,
      'moon' => Icons.dark_mode_outlined,
      'trophy' => Icons.emoji_events_outlined,
      _ => Icons.sports_soccer_rounded,
    };
  }

  static Color _accentFor(String visualKey) {
    return switch (visualKey) {
      'shield' => const Color(0xFF2F80ED),
      'keeper' => const Color(0xFFF2994A),
      'star' => const Color(0xFF9B51E0),
      'bolt' => const Color(0xFFF2C94C),
      'tactics' => const Color(0xFF56CCF2),
      'moon' => const Color(0xFF6C63FF),
      'trophy' => const Color(0xFFFFB020),
      _ => const Color(0xFF27AE60),
    };
  }
}
