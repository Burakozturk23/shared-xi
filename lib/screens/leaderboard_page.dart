import 'package:flutter/material.dart';

import '../models/leaderboard_models.dart';
import '../services/auth_service.dart';
import '../services/leaderboard_service.dart';
import '../widgets/user_avatar_badge.dart';

class LeaderboardPage extends StatefulWidget {
  final LeaderboardScope initialScope;
  final DateTime? dailyDate;

  const LeaderboardPage({
    super.key,
    this.initialScope = LeaderboardScope.daily,
    this.dailyDate,
  });

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final Future<void> _authFuture;
  late final DateTime _dailyDate;

  @override
  void initState() {
    super.initState();
    _dailyDate = widget.dailyDate ?? DateTime.now();
    _authFuture = AuthService.ensureSignedIn().then((_) {});
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _tabIndex(widget.initialScope),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _tabIndex(LeaderboardScope scope) {
    return switch (scope) {
      LeaderboardScope.daily => 0,
      LeaderboardScope.weekly => 1,
      LeaderboardScope.global => 2,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liderlik Tablosu'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.today_rounded),
              text: 'Bugün',
            ),
            Tab(
              icon: Icon(Icons.date_range_rounded),
              text: 'Bu Hafta',
            ),
            Tab(
              icon: Icon(Icons.public_rounded),
              text: 'Global',
            ),
          ],
        ),
      ),
      body: FutureBuilder<void>(
        future: _authFuture,
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (authSnapshot.hasError) {
            return _LeaderboardErrorState(
              message: 'Sıralama için oturum açılamadı.',
              details: '${authSnapshot.error}',
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _LeaderboardBoard(
                scope: LeaderboardScope.daily,
                dailyDate: _dailyDate,
              ),
              const _LeaderboardBoard(
                scope: LeaderboardScope.weekly,
              ),
              const _LeaderboardBoard(
                scope: LeaderboardScope.global,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LeaderboardBoard extends StatelessWidget {
  final LeaderboardScope scope;
  final DateTime? dailyDate;

  const _LeaderboardBoard({
    required this.scope,
    this.dailyDate,
  });

  Stream<LeaderboardSnapshot> _stream() {
    return switch (scope) {
      LeaderboardScope.daily => LeaderboardService.watchDaily(
          date: dailyDate,
          limit: 100,
        ),
      LeaderboardScope.weekly => LeaderboardService.watchWeekly(
          limit: 100,
        ),
      LeaderboardScope.global => LeaderboardService.watchGlobal(
          limit: 100,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LeaderboardSnapshot>(
      stream: _stream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _LeaderboardErrorState(
            message: 'Sıralama yüklenemedi.',
            details: '${snapshot.error}',
          );
        }

        final board = snapshot.data;
        if (board == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!board.isAvailable) {
          return _PendingBoardState(
            reason: board.unavailableReason,
          );
        }

        final entries = board.entries;
        final myUid = AuthService.uid;
        LeaderboardEntry? myEntry;

        if (myUid != null) {
          for (final entry in entries) {
            if (entry.uid == myUid) {
              myEntry = entry;
              break;
            }
          }
        }

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _BoardHeader(
              scope: scope,
              periodKey: board.periodKey,
              serverValidated: board.serverValidated,
            ),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              _EmptyBoardState(scope: scope)
            else ...[
              _Podium(
                entries: entries.take(3).toList(growable: false),
                myUid: myUid,
                scope: scope,
              ),
              const SizedBox(height: 14),
              _MyRankCard(
                entry: myEntry,
                scope: scope,
                hasEntries: entries.isNotEmpty,
              ),
              if (entries.length > 3) ...[
                const SizedBox(height: 18),
                Text(
                  'Sıralamanın devamı',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                ...entries.skip(3).map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _LeaderboardRow(
                          entry: entry,
                          scope: scope,
                          isMe: entry.uid == myUid,
                        ),
                      ),
                    ),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _BoardHeader extends StatelessWidget {
  final LeaderboardScope scope;
  final String periodKey;
  final bool serverValidated;

  const _BoardHeader({
    required this.scope,
    required this.periodKey,
    required this.serverValidated,
  });

  @override
  Widget build(BuildContext context) {
    final title = switch (scope) {
      LeaderboardScope.daily => 'Günün Liderleri',
      LeaderboardScope.weekly => 'Haftanın Liderleri',
      LeaderboardScope.global => 'Global Elo',
    };

    final subtitle = switch (scope) {
      LeaderboardScope.daily =>
        'Bugünün sunucu tarafından doğrulanan en iyi skorları',
      LeaderboardScope.weekly =>
        'Her günün en iyi doğrulanmış skorunun haftalık toplamı',
      LeaderboardScope.global =>
        'Dereceli online maçlardan gelen güvenilir Elo sıralaması',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        periodKey,
                        style: TextStyle(
                          color: Theme.of(context).hintColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (serverValidated)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          color: Colors.greenAccent,
                          size: 16,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Doğrulandı',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).hintColor,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final String? myUid;
  final LeaderboardScope scope;

  const _Podium({
    required this.entries,
    required this.myUid,
    required this.scope,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    if (entries.length < 3) {
      return Row(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: _PodiumCard(
                entry: entries[i],
                scope: scope,
                isMe: entries[i].uid == myUid,
              ),
            ),
          ],
        ],
      );
    }

    final ordered = <LeaderboardEntry>[
      entries[1],
      entries[0],
      entries[2],
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < ordered.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: ordered[i].rank == 1 ? 0 : 10,
              ),
              child: _PodiumCard(
                entry: ordered[i],
                scope: scope,
                isMe: ordered[i].uid == myUid,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final LeaderboardScope scope;
  final bool isMe;

  const _PodiumCard({
    required this.entry,
    required this.scope,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final medalColor = switch (entry.rank) {
      1 => Colors.amber,
      2 => Colors.blueGrey,
      3 => Colors.deepOrangeAccent,
      _ => Theme.of(context).colorScheme.primary,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
      decoration: BoxDecoration(
        color: isMe
            ? Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.12)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMe
              ? Theme.of(context).colorScheme.primary
              : medalColor.withValues(alpha: 0.45),
          width: isMe ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: medalColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                color: medalColor,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 10),
          UserAvatarBadge(
            avatarId: entry.avatarId ?? 'starter_ball',
            radius: entry.rank == 1 ? 31 : 27,
          ),
          const SizedBox(height: 9),
          Text(
            entry.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          if (entry.normalizedName?.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text(
              '@${entry.normalizedName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 10,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _primaryValue(entry, scope),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          if (isMe) ...[
            const SizedBox(height: 5),
            Text(
              'SEN',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MyRankCard extends StatelessWidget {
  final LeaderboardEntry? entry;
  final LeaderboardScope scope;
  final bool hasEntries;

  const _MyRankCard({
    required this.entry,
    required this.scope,
    required this.hasEntries,
  });

  @override
  Widget build(BuildContext context) {
    final row = entry;

    if (row == null) {
      if (!hasEntries) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_search_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bu tabloda henüz sıralaman yok.',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primary
            .withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          UserAvatarBadge(
            avatarId: row.avatarId ?? 'starter_ball',
            radius: 22,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Senin sıran',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '#${row.rank} · ${row.displayName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _primaryValue(row, scope),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final LeaderboardScope scope;
  final bool isMe;

  const _LeaderboardRow({
    required this.entry,
    required this.scope,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: isMe
            ? Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.10)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe
              ? Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.55)
              : Theme.of(context).dividerColor.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '${entry.rank}.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isMe
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          UserAvatarBadge(
            avatarId: entry.avatarId ?? 'starter_ball',
            radius: 22,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight:
                              isMe ? FontWeight.w900 : FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Text(
                        'SEN',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _secondaryLine(entry, scope),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _primaryValue(entry, scope),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBoardState extends StatelessWidget {
  final LeaderboardScope scope;

  const _EmptyBoardState({required this.scope});

  @override
  Widget build(BuildContext context) {
    final text = switch (scope) {
      LeaderboardScope.daily =>
        'Bugün henüz doğrulanmış skor yok.\nİlk sırayı sen al!',
      LeaderboardScope.weekly =>
        'Bu hafta henüz doğrulanmış skor yok.',
      LeaderboardScope.global =>
        'Henüz güvenilir dereceli Elo kaydı yok.\n'
        'İlk dereceli online maçtan sonra sıralama oluşur.',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 24),
      child: Column(
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 54,
            color: Theme.of(context).hintColor,
          ),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).hintColor,
              height: 1.45,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingBoardState extends StatelessWidget {
  final String? reason;

  const _PendingBoardState({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Bu sıralama hazırlanıyor',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (reason?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(
                reason!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LeaderboardErrorState extends StatelessWidget {
  final String message;
  final String? details;

  const _LeaderboardErrorState({
    required this.message,
    this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (details?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                details!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _primaryValue(
  LeaderboardEntry entry,
  LeaderboardScope scope,
) {
  return switch (scope) {
    LeaderboardScope.daily => '${entry.value} puan',
    LeaderboardScope.weekly => '${entry.value} puan',
    LeaderboardScope.global => '${entry.value} Elo',
  };
}

String _secondaryLine(
  LeaderboardEntry entry,
  LeaderboardScope scope,
) {
  final parts = <String>[];

  if (entry.normalizedName?.isNotEmpty == true) {
    parts.add('@${entry.normalizedName}');
  }

  switch (scope) {
    case LeaderboardScope.daily:
      if (entry.successRate != null) {
        parts.add('%${(entry.successRate! * 100).round()} başarı');
      }
      if (entry.secondsLeft != null) {
        parts.add('${entry.secondsLeft} sn kaldı');
      }
      if ((entry.streak ?? 0) > 0) {
        parts.add('🔥${entry.streak}');
      }
    case LeaderboardScope.weekly:
      parts.add('${entry.daysPlayed ?? 0} gün');
      if ((entry.bestDailyScore ?? 0) > 0) {
        parts.add('en iyi ${entry.bestDailyScore}');
      }
    case LeaderboardScope.global:
      parts.add('dereceli Elo');
  }

  return parts.join(' · ');
}
