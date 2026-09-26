import 'package:flutter/material.dart';

import '../data/player_portrait_catalog.dart';
import '../models/player.dart';

/// Player-specific local portraits, with a neutral fallback for missing art.
/// Only catalogued IDs can display a face; legacy avatarKey values are not
/// evidence that a portrait exists or belongs to this player.
class PlayerAvatar extends StatelessWidget {
  final Player player;
  final double size;

  const PlayerAvatar({super.key, required this.player, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final asset = PlayerPortraitCatalog.assetFor(player.id);
    final decodeSize = (size * MediaQuery.devicePixelRatioOf(context))
        .ceil()
        .clamp(1, 384)
        .toInt();

    Widget fallback() => Semantics(
      image: true,
      label: '${player.name}: portre mevcut değil',
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.person_outline_rounded,
            size: size * .5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: asset == null
          ? fallback()
          : Image.asset(
              asset,
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: decodeSize,
              semanticLabel: '${player.name}: stilize portre',
              errorBuilder: (_, _, _) => fallback(),
            ),
    );
  }
}
