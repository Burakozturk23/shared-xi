import 'package:flutter/material.dart';

import '../models/club.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';
import 'club_badge.dart';
import 'linkball_card.dart';

class ClubCard extends StatelessWidget {
  final Club club;
  final bool isSelected;
  final VoidCallback onTap;

  const ClubCard({
    super.key,
    required this.club,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LinkballCard(
      selected: isSelected,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClubBadge(club: club, size: AppSizes.clubBadge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            club.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textColor,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          if (club.country.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              club.country,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.hintColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
