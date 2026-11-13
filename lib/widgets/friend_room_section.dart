import 'package:flutter/material.dart';

import '../app/route_appearance.dart';
import '../online/online_mode_catalog.dart';
import '../online/online_mode_route.dart';
import '../theme/ortak_saha_theme.dart';
import 'hub_ui.dart';
import 'pitch_ui.dart';

/// A mode's own menu links straight to a friend room, so a friend match does
/// not need the Online menu first. Each entry: online mode, title, short specs.
class FriendRoomSection extends StatelessWidget {
  const FriendRoomSection({super.key, required this.modes});
  final List<(OnlinePlayMode, String, String)> modes;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.groups_rounded, color: p.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Arkadaşınla oyna',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Oda kur, kodu paylaş veya arkadaşının koduyla katıl. Dostluk maçları '
          'Elo ve ödül vermez; Google hesabı gerekir.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: p.muted),
        ),
        const SizedBox(height: 10),
        for (final (mode, title, specs) in modes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PitchPanel(
              key: ValueKey('friend-room-${mode.wireName}'),
              padding: const EdgeInsets.all(14),
              onTap: () => Navigator.of(context).push(
                LinkballRoute(
                  modern: true,
                  builder: (_) => onlineModePage(mode, playKind: 'friend'),
                ),
              ),
              child: Row(
                children: [
                  HubIconBox(mode.icon, color: mode.color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          specs,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: p.muted),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
