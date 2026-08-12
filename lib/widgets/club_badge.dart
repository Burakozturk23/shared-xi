import 'package:flutter/material.dart';

import '../models/club.dart';
import '../theme/app_theme.dart';

/// Kulüp logosu + isim (Beşler, listeler vb.).
class ClubBadge extends StatelessWidget {
  final Club club;
  final double logoSize;
  final bool compact;

  const ClubBadge({
    super.key,
    required this.club,
    this.logoSize = 28,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final logo = club.logo.trim().isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              club.logo,
              width: logoSize,
              height: logoSize,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _shield(),
            ),
          )
        : _shield();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.hintColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          logo,
          SizedBox(width: compact ? 6 : 8),
          Flexible(
            child: Text(
              club.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shield() {
    return Container(
      width: logoSize,
      height: logoSize,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        Icons.shield,
        size: logoSize * 0.55,
        color: AppTheme.primaryColor,
      ),
    );
  }
}