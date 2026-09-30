import 'package:flutter/material.dart';
import '../models/player.dart';
import 'player_avatar.dart';

/// One compact identity shared by reverse/random boards; adapts to short cells.
class GridPlayerIdentity extends StatelessWidget {
  const GridPlayerIdentity({super.key, required this.player});
  final Player player;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (bounds.maxHeight >= 80) ...[
          PlayerAvatar(player: player, size: 28),
          const SizedBox(height: 4),
        ],
        Flexible(child: Text(player.name,
          textAlign: TextAlign.center, maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 11, fontWeight: FontWeight.w700))),
      ],
    ),
  );
}
