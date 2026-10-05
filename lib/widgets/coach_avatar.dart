import 'package:flutter/material.dart';

import '../data/uploaded_portrait_catalog.dart';
import '../models/coach.dart';
import 'player_portrait.dart';

/// Uses the coach-specific portrait, or the same person's player portrait.
class CoachAvatar extends StatelessWidget {
  const CoachAvatar({super.key, required this.coach, this.size = 52});

  final Coach coach;
  final double size;

  @override
  Widget build(BuildContext context) {
    final uploaded = UploadedPortraitCatalog.forCoachId(coach.id);
    final playerId = UploadedPortraitCatalog.coachPlayerIds[coach.id];
    final fallback = Center(
      child: Text(
        coach.name.isEmpty ? '?' : coach.name.characters.first.toUpperCase(),
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * .38),
      ),
    );
    return Semantics(
      image: true,
      label: coach.name,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .2),
        ),
        child: uploaded != null
            ? PortraitCrop(spec: uploaded, size: size, fallback: fallback)
            : playerId != null
                ? PlayerPortrait(playerId: playerId, size: size, fallback: fallback)
                : fallback,
      ),
    );
  }
}
