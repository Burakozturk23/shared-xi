import 'dart:async';

import 'package:flutter/material.dart';

import '../models/achievement_catalog.dart';
import '../models/achievement_models.dart';
import '../models/economy_models.dart';
import '../services/achievement_presentation_store.dart';
import '../services/achievement_service.dart';
import '../services/economy_service.dart';
import '../widgets/achievement_badge_emblem.dart';
import '../widgets/wallet_balance_chip.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  final Set<String> _claiming = <String>{};

  AchievementCategory? _category;
  bool _syncing = true;
  bool _presenting = false;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  Future<void> _sync() async {
    setState(() {
      _syncing = true;
      _syncError = null;
    });

    try {
      await Future.wait([
        AchievementService.syncMyAchievements(),
        EconomyService.syncMyWallet(),
      ]);
    } catch (_) {
      _syncError = 'Rozet veya coin ilerlemesi şu anda eşitlenemedi.';
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  Future<void> _claim(AchievementDefinition definition) async {
    if (_claiming.contains(definition.id)) return;

    setState(() {
      _claiming.add(definition.id);
    });

    try {
      final result = await EconomyService.claimAchievementReward(
        definition.id,
      );

      if (!mounted) return;

      final message = result.granted
          ? '+${result.amount} coin hesabına eklendi.'
          : 'Bu başarım ödülü daha önce alınmış.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Başarım ödülü alınamadı. Kilidin açık olduğundan emin ol.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _claiming.remove(definition.id);
        });
      }
    }
  }

  Future<void> _presentNew(
    Map<String, AchievementProgress> progress,
  ) async {
    if (_presenting) return;

    final unlocked = AchievementCatalog.all
        .where((item) => progress[item.id]?.unlocked == true)
        .map((item) => item.id)
        .toList();

    if (unlocked.isEmpty) return;

    final seen = await AchievementPresentationStore.loadSeenIds();
    final unseen = unlocked.where((id) => !seen.contains(id)).toList();

    if (unseen.isEmpty || !mounted) return;

    _presenting = true;
    try {
      for (final id in unseen) {
        final item = AchievementCatalog.byId[id];
        if (item == null || !mounted) continue;

        await showDialog<void>(
          context: context,
          builder: (_) => _UnlockedDialog(definition: item),
        );

        await AchievementPresentationStore.markSeen(id);
      }
    } finally {
      _presenting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rozetler'),
        actions: [
          const WalletBalanceChip(compact: true),
          IconButton(
            tooltip: 'İlerlemeyi eşitle',
            onPressed: _syncing ? null : _sync,
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: StreamBuilder<Map<String, AchievementProgress>>(
        stream: AchievementService.watchProgress(),
        builder: (context, snapshot) {
          final progress =
              snapshot.data ?? const <String, AchievementProgress>{};

          if (snapshot.hasData) {
            scheduleMicrotask(() => _presentNew(progress));
          }

          return StreamBuilder<Map<String, EconomyRewardClaim>>(
            stream: EconomyService.watchRewardClaims(),
            builder: (context, claimSnapshot) {
              final claims =
                  claimSnapshot.data ?? const <String, EconomyRewardClaim>{};
              final definitions = _category == null
                  ? AchievementCatalog.all
                  : AchievementCatalog.forCategory(_category!);

              final unlockedCount = AchievementCatalog.all
                  .where((item) => progress[item.id]?.unlocked == true)
                  .length;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _SummaryCard(
                      unlockedCount: unlockedCount,
                      totalCount: AchievementCatalog.all.length,
                      error: _syncError,
                      onRetry: _sync,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _CategoryFilters(
                      selected: _category,
                      onChanged: (value) {
                        setState(() => _category = value);
                      },
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.crossAxisExtent;
                        final columns = width >= 900
                            ? 5
                            : width >= 650
                                ? 4
                                : width >= 430
                                    ? 3
                                    : 2;

                        return SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.68,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = definitions[index];
                              final claimId =
                                  EconomyService.achievementClaimId(item.id);

                              return _BadgeTile(
                                definition: item,
                                progress: progress[item.id],
                                claimed: claims.containsKey(claimId),
                                claiming: _claiming.contains(item.id),
                                onClaim: () => _claim(item),
                              );
                            },
                            childCount: definitions.length,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int unlockedCount;
  final int totalCount;
  final String? error;
  final VoidCallback onRetry;

  const _SummaryCard({
    required this.unlockedCount,
    required this.totalCount,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = totalCount == 0 ? 0.0 : unlockedCount / totalCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.military_tech_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rozet Koleksiyonu',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '$unlockedCount / $totalCount rozet açıldı',
                          style: TextStyle(
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(ratio * 100).round()}%',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onRetry,
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryFilters extends StatelessWidget {
  final AchievementCategory? selected;
  final ValueChanged<AchievementCategory?> onChanged;

  const _CategoryFilters({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = <(String, AchievementCategory?, IconData)>[
      ('Tümü', null, Icons.apps_rounded),
      ('Dereceli', AchievementCategory.ranked, Icons.emoji_events_outlined),
      ('Ustalık', AchievementCategory.mastery, Icons.sports_esports_rounded),
      ('Günlük', AchievementCategory.daily, Icons.calendar_today_rounded),
      ('Sosyal', AchievementCategory.social, Icons.people_outline_rounded),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selected == item.$2,
              onSelected: (_) => onChanged(item.$2),
              avatar: Icon(item.$3, size: 17),
              label: Text(item.$1),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final AchievementDefinition definition;
  final AchievementProgress? progress;
  final bool claimed;
  final bool claiming;
  final Future<void> Function() onClaim;

  const _BadgeTile({
    required this.definition,
    required this.progress,
    required this.claimed,
    required this.claiming,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final unlocked = progress?.unlocked == true;
    final value = progress?.value ?? 0;
    final target = (progress?.target ?? 0) > 0
        ? progress!.target
        : definition.target;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (_) => _DetailsSheet(
            definition: definition,
            progress: progress,
            claimed: claimed,
            claiming: claiming,
            onClaim: onClaim,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          child: Column(
            children: [
              AchievementBadgeEmblem(
                definition: definition,
                unlocked: unlocked,
                size: 68,
              ),
              const SizedBox(height: 10),
              Text(
                definition.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: unlocked ? null : Theme.of(context).hintColor,
                ),
              ),
              const SizedBox(height: 6),
              _CoinRewardPill(amount: definition.coinReward),
              const Spacer(),
              if (unlocked)
                claimed
                    ? const _RewardClaimedPill()
                    : FilledButton.tonalIcon(
                        onPressed: claiming ? null : onClaim,
                        icon: claiming
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.monetization_on_rounded,
                                size: 17,
                              ),
                        label: Text(
                          claiming
                              ? 'Alınıyor'
                              : 'Topla +${definition.coinReward}',
                        ),
                      )
              else ...[
                Text(
                  '$value / $target',
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: target <= 0
                        ? 0
                        : (value / target).clamp(0, 1).toDouble(),
                    minHeight: 5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CoinRewardPill extends StatelessWidget {
  final int amount;

  const _CoinRewardPill({
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB300).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.monetization_on_rounded,
            color: Color(0xFFFFB300),
            size: 15,
          ),
          const SizedBox(width: 4),
          Text(
            '+$amount',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardClaimedPill extends StatelessWidget {
  const _RewardClaimedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primary
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'ÖDÜL ALINDI',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DetailsSheet extends StatelessWidget {
  final AchievementDefinition definition;
  final AchievementProgress? progress;
  final bool claimed;
  final bool claiming;
  final Future<void> Function() onClaim;

  const _DetailsSheet({
    required this.definition,
    required this.progress,
    required this.claimed,
    required this.claiming,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final unlocked = progress?.unlocked == true;
    final value = progress?.value ?? 0;
    final target = (progress?.target ?? 0) > 0
        ? progress!.target
        : definition.target;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AchievementBadgeEmblem(
              definition: definition,
              unlocked: unlocked,
              size: 92,
            ),
            const SizedBox(height: 14),
            Text(
              definition.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              definition.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).hintColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            _CoinRewardPill(amount: definition.coinReward),
            const SizedBox(height: 18),
            if (unlocked)
              if (claimed)
                const _RewardClaimedPill()
              else
                FilledButton.icon(
                  onPressed: claiming
                      ? null
                      : () async {
                          await onClaim();
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                  icon: claiming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.monetization_on_rounded),
                  label: Text(
                    claiming
                        ? 'Ödül alınıyor'
                        : '+${definition.coinReward} coin topla',
                  ),
                )
            else ...[
              Row(
                children: [
                  const Text(
                    'İlerleme',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text(
                    '$value / $target',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: target <= 0
                      ? 0
                      : (value / target).clamp(0, 1).toDouble(),
                  minHeight: 9,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UnlockedDialog extends StatelessWidget {
  final AchievementDefinition definition;

  const _UnlockedDialog({required this.definition});

  @override
  Widget build(BuildContext context) {
    final color = AchievementBadgeEmblem.tierColor(definition.tier);

    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'YENİ ROZET',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 18),
          AchievementBadgeEmblem(
            definition: definition,
            unlocked: true,
            size: 104,
          ),
          const SizedBox(height: 18),
          Text(
            definition.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            definition.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).hintColor,
            ),
          ),
          const SizedBox(height: 12),
          _CoinRewardPill(amount: definition.coinReward),
          const SizedBox(height: 8),
          Text(
            'Coin ödülünü Rozetler ekranından toplayabilirsin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).hintColor,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Harika'),
          ),
        ],
      ),
    );
  }
}
