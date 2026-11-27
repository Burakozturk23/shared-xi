import 'package:flutter/material.dart';

import '../models/coach.dart';
import 'coach_avatar.dart';

/// A Grid row/column criterion from the server (`{id, type, label, avatarKey?}`).
/// A teknik direktör criterion shows a small "TD" tag (and the coach portrait
/// when the catalog has one) so it is not mistaken for a player or a club.
class GridCriterionLabel extends StatelessWidget {
  const GridCriterionLabel({
    super.key,
    required this.criterion,
    this.style,
    this.maxLines = 3,
  });

  final Map<dynamic, dynamic>? criterion;
  final TextStyle? style;
  final int maxLines;

  static bool isCoach(Map<dynamic, dynamic>? c) => c?['type'] == 'coach';

  /// Plain text for dialogs and notes: "Fatih Terim (TD)".
  static String text(Map<dynamic, dynamic>? c) {
    final label = c?['label']?.toString() ?? '—';
    return isCoach(c) ? '$label (TD)' : label;
  }

  @override
  Widget build(BuildContext context) {
    final label = criterion?['label']?.toString() ?? '—';
    final name = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    if (!isCoach(criterion)) return name;
    final scheme = Theme.of(context).colorScheme;
    final avatarKey = criterion?['avatarKey']?.toString();
    return Semantics(
      container: true,
      label: 'Teknik direktör: $label',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (avatarKey != null && avatarKey.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: CoachAvatar(
                size: 26,
                coach: Coach(
                  id: criterion?['value']?.toString() ?? '',
                  name: label,
                  countries: const [],
                  clubIds: const [],
                  avatarKey: avatarKey,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'TD',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          name,
        ],
      ),
    );
  }
}
