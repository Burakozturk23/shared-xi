import 'package:flutter/material.dart';

import '../models/club.dart';
import 'club_badge.dart';

/// Canonical club visual when a full Club object is not available.
///
/// Reuses ClubBadge, so the same local badge-key handling and deterministic
/// Linkball shield fallback are used everywhere.
class ClubIdentityBadge extends StatelessWidget {
  final int clubId;
  final String clubName;
  final String? badgeKey;
  final int? color;
  final double size;

  const ClubIdentityBadge({
    super.key,
    required this.clubId,
    required this.clubName,
    this.badgeKey,
    this.color,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return ClubBadge(
      club: Club(
        id: clubId,
        name: clubName,
        league: '',
        country: '',
        badgeKey: badgeKey,
        color: color,
      ),
      size: size,
    );
  }
}
