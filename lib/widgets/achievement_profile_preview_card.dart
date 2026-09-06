import 'package:flutter/material.dart';

import '../models/achievement_catalog.dart';
import '../models/achievement_models.dart';
import '../screens/achievements_page.dart';
import '../services/achievement_service.dart';
import '../services/achievement_presentation_store.dart';
import 'achievement_badge_emblem.dart';

class AchievementProfilePreviewCard extends StatefulWidget {
  const AchievementProfilePreviewCard({super.key});

  @override
  State<AchievementProfilePreviewCard> createState() =>
      _AchievementProfilePreviewCardState();
}

class _AchievementProfilePreviewCardState
    extends State<AchievementProfilePreviewCard> {
  late Future<Set<String>> _seenFuture;

  @override
  void initState() {
    super.initState();
    _seenFuture = AchievementPresentationStore.loadSeenIds();
    AchievementService.syncMyAchievements().catchError((_) => 0);
  }

  void _refreshSeen() {
    if (!mounted) return;
    setState(() {
      _seenFuture = AchievementPresentationStore.loadSeenIds();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, AchievementProgress>>(
      stream: AchievementService.watchProgress(),
      builder: (context, snapshot) {
        final progress =
            snapshot.data ?? const <String, AchievementProgress>{};

        final unlocked = AchievementCatalog.all
            .where((item) => progress[item.id]?.unlocked == true)
            .toList();

        final previewItems = unlocked.isNotEmpty
            ? unlocked.reversed.take(3).toList()
            : _closestLocked(progress);

        return FutureBuilder<Set<String>>(
          future: _seenFuture,
          builder: (context, seenSnapshot) {
            final seen = seenSnapshot.data ?? const <String>{};
            final unseenCount = unlocked
                .where((item) => !seen.contains(item.id))
                .length;

            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AchievementsPage(),
                    ),
                  );
                  _refreshSeen();
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.military_tech_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Rozetler',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if (unseenCount > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'YENİ $unseenCount',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              unlocked.isEmpty
                                  ? 'İlk rozetine doğru ilerliyorsun'
                                  : '${unlocked.length} / '
                                      '${AchievementCatalog.all.length} açıldı',
                              style: TextStyle(
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: previewItems.map((item) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: AchievementBadgeEmblem(
                                    definition: item,
                                    unlocked:
                                        progress[item.id]?.unlocked == true,
                                    size: 44,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<AchievementDefinition> _closestLocked(
    Map<String, AchievementProgress> progress,
  ) {
    final items = AchievementCatalog.all
        .where((item) => progress[item.id]?.unlocked != true)
        .toList();

    items.sort((a, b) {
      final aRatio = _ratio(a, progress[a.id]);
      final bRatio = _ratio(b, progress[b.id]);
      final compare = bRatio.compareTo(aRatio);
      return compare != 0 ? compare : a.target.compareTo(b.target);
    });

    return items.take(3).toList();
  }

  double _ratio(
    AchievementDefinition definition,
    AchievementProgress? progress,
  ) {
    final target = (progress?.target ?? 0) > 0
        ? progress!.target
        : definition.target;
    final value = progress?.value ?? 0;

    if (target <= 0) return 0;
    return (value / target).clamp(0, 1).toDouble();
  }
}
