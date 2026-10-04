import 'package:flutter/material.dart';

import '../data/player_portrait_catalog.dart';
import '../data/season_portrait_catalog.dart';

/// Shared portrait selection for game cards and profile avatars.
class PlayerPortrait extends StatelessWidget {
  const PlayerPortrait({
    super.key,
    required this.playerId,
    required this.size,
    required this.fallback,
  });
  final int playerId;
  final double size;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final asset = PlayerPortraitCatalog.forPlayerId(playerId);
    if (asset != null) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    final season = SeasonPortraitCatalog.forPlayerId(playerId);
    if (season != null) {
      return _SeasonPortrait(spec: season, size: size, fallback: fallback);
    }
    return fallback;
  }
}

class _SeasonPortrait extends StatelessWidget {
  const _SeasonPortrait({
    required this.spec,
    required this.size,
    required this.fallback,
  });

  final SeasonPortraitSpec spec;
  final double size;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final scaleX = size / spec.width;
    final scaleY = size / spec.height;
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: -spec.left * scaleX,
            top: -spec.top * scaleY,
            width: spec.sheetWidth * scaleX,
            height: spec.sheetHeight * scaleY,
            child: Image.asset(
              spec.asset,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => Stack(
                children: [
                  Positioned(
                    left: spec.left * scaleX,
                    top: spec.top * scaleY,
                    width: size,
                    height: size,
                    child: fallback,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
