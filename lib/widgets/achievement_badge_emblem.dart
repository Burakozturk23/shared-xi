import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/achievement_models.dart';

class AchievementBadgeEmblem extends StatelessWidget {
  final AchievementDefinition definition;
  final bool unlocked;
  final double size;

  const AchievementBadgeEmblem({
    super.key,
    required this.definition,
    required this.unlocked,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    final tier = tierColor(definition.tier);
    final accent = categoryColor(definition.category);
    final muted = Theme.of(context).hintColor;
    final iconColor = unlocked
        ? Color.lerp(tier, Colors.white, 0.16)!
        : muted.withValues(alpha: 0.72);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _AchievementMedalPainter(
              tier: tier,
              accent: accent,
              unlocked: unlocked,
              category: definition.category,
              surface: Theme.of(context).colorScheme.surfaceContainerHighest,
              outline: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          Icon(
            _iconFor(definition.iconKey, definition.category),
            size: size * 0.39,
            color: iconColor,
          ),
          Positioned(
            left: size * 0.08,
            top: size * 0.08,
            child: Container(
              width: size * 0.23,
              height: size * 0.23,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: unlocked
                      ? accent.withValues(alpha: 0.8)
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Icon(
                _categoryIcon(definition.category),
                size: size * 0.125,
                color: unlocked ? accent : muted,
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: size * 0.31,
              height: size * 0.31,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: unlocked
                      ? tier.withValues(alpha: 0.9)
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Icon(
                unlocked ? Icons.check_rounded : Icons.lock_rounded,
                size: size * 0.18,
                color: unlocked ? tier : muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color tierColor(AchievementTier tier) {
    return switch (tier) {
      AchievementTier.bronze => const Color(0xFFCD7F32),
      AchievementTier.silver => const Color(0xFFB0BEC5),
      AchievementTier.gold => const Color(0xFFFFC107),
      AchievementTier.platinum => const Color(0xFF26C6DA),
    };
  }

  static Color categoryColor(AchievementCategory category) {
    return switch (category) {
      AchievementCategory.ranked => const Color(0xFF7C4DFF),
      AchievementCategory.mastery => const Color(0xFF00C853),
      AchievementCategory.daily => const Color(0xFFFF9100),
      AchievementCategory.social => const Color(0xFF00B8D4),
    };
  }

  static IconData _categoryIcon(AchievementCategory category) {
    return switch (category) {
      AchievementCategory.ranked => Icons.emoji_events_rounded,
      AchievementCategory.mastery => Icons.sports_esports_rounded,
      AchievementCategory.daily => Icons.calendar_today_rounded,
      AchievementCategory.social => Icons.people_alt_rounded,
    };
  }

  static IconData _iconFor(
    String key,
    AchievementCategory category,
  ) {
    return switch (key) {
      'first_whistle' => Icons.sports_rounded,
      'first_victory' => Icons.emoji_events_rounded,
      'challenger' => Icons.sports_mma_rounded,
      'loyal_rival' => Icons.handshake_rounded,
      'centurion' => Icons.military_tech_rounded,
      'form_days' => Icons.local_fire_department_rounded,
      'brave_heart' => Icons.favorite_rounded,
      'victory_machine' => Icons.workspace_premium_rounded,
      'hot_streak' => Icons.whatshot_rounded,
      'streak_killer' => Icons.bolt_rounded,
      'unchanged_champion' => Icons.emoji_events_rounded,
      'rising_star' => Icons.star_rounded,
      'tough_opponent' => Icons.shield_rounded,
      'ranking_beast' => Icons.leaderboard_rounded,
      'legend' => Icons.auto_awesome_rounded,
      'shared_xi_master' => Icons.groups_rounded,
      'grid_master' => Icons.grid_view_rounded,
      'cinko_master' => Icons.casino_rounded,
      'five_master' => Icons.looks_5_rounded,
      'calendar_rookie' => Icons.calendar_today_rounded,
      'calendar_regular' => Icons.event_repeat_rounded,
      'month_tactician' => Icons.calendar_month_rounded,
      'loyal_tactician' => Icons.date_range_rounded,
      'perfectionist' => Icons.diamond_rounded,
      'week_warrior' => Icons.view_week_rounded,
      'team_spirit' => Icons.people_alt_rounded,
      'group_leader' => Icons.groups_2_rounded,
      'social_captain' => Icons.campaign_rounded,
      _ => _categoryIcon(category),
    };
  }
}

class _AchievementMedalPainter extends CustomPainter {
  final Color tier;
  final Color accent;
  final bool unlocked;
  final AchievementCategory category;
  final Color surface;
  final Color outline;

  const _AchievementMedalPainter({
    required this.tier,
    required this.accent,
    required this.unlocked,
    required this.category,
    required this.surface,
    required this.outline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.46;
    final outer = _polygon(center, radius, 8, math.pi / 8);

    final baseColor = unlocked
        ? Color.alphaBlend(
            accent.withValues(alpha: 0.16),
            surface,
          )
        : surface.withValues(alpha: 0.58);

    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.fill
        ..color = baseColor,
    );

    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unlocked ? 2.4 : 1.2
        ..color = unlocked
            ? tier.withValues(alpha: 0.92)
            : outline.withValues(alpha: 0.8),
    );

    canvas.drawCircle(
      center,
      radius * 0.76,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.035
        ..color = unlocked
            ? accent.withValues(alpha: 0.72)
            : outline.withValues(alpha: 0.45),
    );

    if (unlocked) {
      _drawCategoryPattern(canvas, center, radius);
    } else {
      canvas.drawCircle(
        center,
        radius * 0.66,
        Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.black.withValues(alpha: 0.08),
      );
    }

    canvas.drawCircle(
      center,
      radius * 0.57,
      Paint()
        ..style = PaintingStyle.fill
        ..color = unlocked
            ? tier.withValues(alpha: 0.11)
            : Colors.transparent,
    );
  }

  void _drawCategoryPattern(
    Canvas canvas,
    Offset center,
    double radius,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * 0.055
      ..color = accent.withValues(alpha: 0.34);

    switch (category) {
      case AchievementCategory.ranked:
        for (var i = 0; i < 8; i += 1) {
          final angle = (math.pi * 2 / 8) * i;
          canvas.drawLine(
            center +
                Offset(
                  math.cos(angle) * radius * 0.62,
                  math.sin(angle) * radius * 0.62,
                ),
            center +
                Offset(
                  math.cos(angle) * radius * 0.82,
                  math.sin(angle) * radius * 0.82,
                ),
            paint,
          );
        }

      case AchievementCategory.mastery:
        canvas.drawArc(
          Rect.fromCircle(
            center: center,
            radius: radius * 0.68,
          ),
          -math.pi * 0.15,
          math.pi * 0.62,
          false,
          paint,
        );
        canvas.drawArc(
          Rect.fromCircle(
            center: center,
            radius: radius * 0.68,
          ),
          math.pi * 0.85,
          math.pi * 0.62,
          false,
          paint,
        );

      case AchievementCategory.daily:
        for (var i = 0; i < 4; i += 1) {
          final angle = math.pi / 4 + i * math.pi / 2;
          canvas.drawLine(
            center +
                Offset(
                  math.cos(angle) * radius * 0.58,
                  math.sin(angle) * radius * 0.58,
                ),
            center +
                Offset(
                  math.cos(angle) * radius * 0.79,
                  math.sin(angle) * radius * 0.79,
                ),
            paint,
          );
        }

      case AchievementCategory.social:
        final left = center.translate(-radius * 0.33, radius * 0.24);
        final right = center.translate(radius * 0.33, radius * 0.24);
        canvas.drawArc(
          Rect.fromCircle(center: left, radius: radius * 0.25),
          math.pi * 1.15,
          math.pi * 0.7,
          false,
          paint,
        );
        canvas.drawArc(
          Rect.fromCircle(center: right, radius: radius * 0.25),
          math.pi * 1.15,
          math.pi * 0.7,
          false,
          paint,
        );
    }
  }

  Path _polygon(
    Offset center,
    double radius,
    int sides,
    double rotation,
  ) {
    final path = Path();

    for (var i = 0; i < sides; i += 1) {
      final angle = rotation + (math.pi * 2 * i / sides);
      final point = center +
          Offset(
            math.cos(angle) * radius,
            math.sin(angle) * radius,
          );

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _AchievementMedalPainter oldDelegate) {
    return oldDelegate.tier != tier ||
        oldDelegate.accent != accent ||
        oldDelegate.unlocked != unlocked ||
        oldDelegate.category != category ||
        oldDelegate.surface != surface ||
        oldDelegate.outline != outline;
  }
}
