import 'package:flutter/material.dart';

import '../models/player.dart';

/// Fictional illustrated characters, not photographs or player likenesses.
/// Selection uses only a stable catalog ID, never nationality or other traits.
class PlayerAvatar extends StatelessWidget {
  final Player player;
  final double size;

  const PlayerAvatar({super.key, required this.player, this.size = 48});

  static const representativeAssets = [
    'assets/avatars/representative_v1_01.webp',
    'assets/avatars/representative_v1_02.webp',
    'assets/avatars/representative_v1_03.webp',
    'assets/avatars/representative_v1_04.webp',
  ];

  static String representativeAssetFor(int playerId) {
    final id = playerId.abs();
    return representativeAssets[(id ^ (id >> 4) ^ (id >> 8)) % representativeAssets.length];
  }

  @override
  Widget build(BuildContext context) {
    final custom = player.avatarKey;
    final decodeSize = (size * MediaQuery.devicePixelRatioOf(context))
        .ceil().clamp(1, 384).toInt();
    Widget illustration() => Image.asset(
      representativeAssetFor(player.id),
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: decodeSize,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(child: Icon(Icons.person_outline_rounded, size: size * .5)),
      ),
    );
    return Semantics(
      image: true,
      label: '${player.name}: temsili oyuncu illüstrasyonu',
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * .22),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: custom != null && custom.isNotEmpty
            ? Image.asset(
                'assets/avatars/$custom.webp',
                fit: BoxFit.cover,
                cacheWidth: decodeSize,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => illustration(),
              )
            : illustration(),
      ),
    );
  }
}
