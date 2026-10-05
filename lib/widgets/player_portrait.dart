import 'package:flutter/material.dart';

import '../data/player_portrait_catalog.dart';
import '../data/season_portrait_catalog.dart';
import '../data/uploaded_portrait_catalog.dart';

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
    final uploaded = UploadedPortraitCatalog.forPlayerId(playerId);
    if (uploaded != null) {
      return PortraitCrop(spec: uploaded, size: size, fallback: fallback);
    }
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
      return PortraitCrop(spec: season, size: size, fallback: fallback);
    }
    return fallback;
  }
}

class PortraitCrop extends StatelessWidget {
  const PortraitCrop({
    super.key,
    required this.spec,
    required this.size,
    required this.fallback,
  });

  final SeasonPortraitSpec spec;
  final double size;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final scale = size / (spec.width > spec.height ? spec.width : spec.height);
    final scaleX = scale;
    final scaleY = scale;
    return Center(
      child: SizedBox(
        width: spec.width * scale,
        height: spec.height * scale,
        child: ClipRect(
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
              cacheWidth: spec.sheetWidth > 1024 ? 1024 : spec.sheetWidth.toInt(),
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
        ),
      ),
    );
  }
}
