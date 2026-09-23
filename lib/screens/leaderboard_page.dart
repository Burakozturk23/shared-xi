import 'package:flutter/material.dart';

import '../models/leaderboard_models.dart';
import '../services/social/social_gateways.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/social_ui.dart';
import '../widgets/user_avatar_badge.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({
    super.key,
    this.initialScope = LeaderboardScope.daily,
    this.dailyDate,
    this.gateway = const LeaderboardGateway(),
  });
  final LeaderboardScope initialScope;
  final DateTime? dailyDate;
  final LeaderboardGateway gateway;
  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabs;
  late Future<void> _ready;
  late DateTime _day;
  int _prepareEpoch = 0;
  final Map<LeaderboardScope, Stream<LeaderboardSnapshot>> _streams = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialScope.index,
    );
    _day = widget.dailyDate ?? DateTime.now();
    _ready = _prepare();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    final epoch = ++_prepareEpoch;
    await widget.gateway.prepare();
    if (!mounted || epoch != _prepareEpoch) return;
    for (final scope in LeaderboardScope.values) {
      _streams[scope] = widget.gateway.watch(scope, _day);
    }
  }

  void _retry() => setState(() => _ready = _prepare());
  void _refresh(LeaderboardScope scope) => setState(() {
    final now = DateTime.now();
    final changedDay =
        widget.dailyDate == null &&
        LeaderboardPeriodKeys.day(now) != LeaderboardPeriodKeys.day(_day);
    if (widget.dailyDate == null) _day = now;
    for (final target in changedDay ? LeaderboardScope.values : [scope]) {
      _streams[target] = widget.gateway.watch(target, _day);
    }
  });
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.dailyDate == null &&
        _streams.isNotEmpty) {
      final now = DateTime.now();
      if (LeaderboardPeriodKeys.day(now) != LeaderboardPeriodKeys.day(_day)) {
        _day = now;
        _retry();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Liderlik Tablosu'),
      bottom: TabBar(
        controller: _tabs,
        tabs: const [
          Tab(text: 'Günlük'),
          Tab(text: 'Haftalık'),
          Tab(text: 'Genel'),
        ],
      ),
    ),
    body: SafeArea(
      child: FutureBuilder<void>(
        future: _ready,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                SocialNotice(
                  title: 'Sıralamaya bağlanılamadı',
                  message: 'Bağlantını kontrol edip yeniden dene.',
                  icon: Icons.cloud_off_outlined,
                  onAction: _retry,
                ),
              ],
            );
          return TabBarView(
            controller: _tabs,
            children: [
              for (final scope in LeaderboardScope.values)
                _Board(
                  key: ValueKey(scope),
                  scope: scope,
                  stream: _streams[scope]!,
                  myUid: widget.gateway.uid,
                  onRetry: () => _refresh(scope),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _Board extends StatelessWidget {
  const _Board({
    super.key,
    required this.scope,
    required this.stream,
    required this.myUid,
    required this.onRetry,
  });
  final LeaderboardScope scope;
  final Stream<LeaderboardSnapshot> stream;
  final String? myUid;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => StreamBuilder<LeaderboardSnapshot>(
    stream: stream,
    builder: (context, snapshot) {
      if (!snapshot.hasData && !snapshot.hasError)
        return const Center(child: CircularProgressIndicator());
      final board = snapshot.data;
      if (snapshot.hasError)
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SocialNotice(
              title: 'Sıralama yenilenemedi',
              message:
                  'Bağlantın kesilmiş olabilir. Yeniden bağlanarak güncel sıralamayı görebilirsin.',
              icon: Icons.cloud_off_outlined,
              onAction: onRetry,
            ),
          ],
        );
      if (board == null || !board.isAvailable)
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SocialNotice(
              title: 'Bu sıralama henüz hazır değil',
              message: 'Skorlar hazır olduğunda burada görünecek.',
              icon: Icons.schedule_rounded,
              onAction: onRetry,
            ),
          ],
        );
      final entries = board.entries;
      LeaderboardEntry? mine;
      for (final entry in entries) {
        if (entry.uid == myUid) {
          mine = entry;
          break;
        }
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        children: [
          SocialHero(
            icon: Icons.emoji_events_outlined,
            eyebrow: _period(board),
            title: switch (scope) {
              LeaderboardScope.daily => 'Bugünün en iyileri.',
              LeaderboardScope.weekly => 'İstikrar kazandırır.',
              LeaderboardScope.global => 'Rekabetin zirvesi.',
            },
            message: switch (scope) {
              LeaderboardScope.daily => 'Günlük mücadeledeki en iyi skorlar.',
              LeaderboardScope.weekly =>
                'Her günün en iyi skorunun haftalık toplamı.',
              LeaderboardScope.global =>
                'Dereceli online maçlardaki Elo puanına göre sıralama.',
            },
            footer: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const SocialStatus('İlk 100'),
                if (board.serverValidated)
                  const SocialStatus('Doğrulanmış skorlar'),
                IconButton(
                  tooltip: 'Sıralamayı yenile',
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (entries.isEmpty)
            const SocialNotice(
              title: 'İlk skor henüz gelmedi',
              message:
                  'Bir maç tamamla; skorun doğrulandığında sıralamada yer alabilir.',
              icon: Icons.flag_outlined,
            )
          else ...[
            PitchPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Senin yerin',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  if (mine != null)
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          '#${mine.rank}',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        Text(
                          _score(mine, scope),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    )
                  else
                    Text(
                      'Gösterilen ilk 100 içinde görünmüyorsun. Bu, toplam sıralamanın olmadığı anlamına gelmez.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
            const PitchSectionTitle('Zirvedeki oyuncular'),
            LayoutBuilder(
              builder: (context, box) {
                final compact =
                    box.maxWidth < 340 ||
                    MediaQuery.textScalerOf(context).scale(14) > 19;
                final first = entries.take(3).toList();
                if (compact)
                  return Column(
                    children: [
                      for (final entry in first)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _RankRow(
                            entry: entry,
                            scope: scope,
                            isMe: entry.uid == myUid,
                          ),
                        ),
                    ],
                  );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < first.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _PodiumCard(
                          entry: first[i],
                          scope: scope,
                          isMe: first[i].uid == myUid,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            if (entries.length > 3) ...[
              const PitchSectionTitle('Sıralama'),
              for (final entry in entries.skip(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RankRow(
                    entry: entry,
                    scope: scope,
                    isMe: entry.uid == myUid,
                  ),
                ),
            ],
          ],
          const SizedBox(height: 20),
          Text(
            'Skorlar yenilendikçe liste otomatik güncellenir.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    },
  );
  String _period(LeaderboardSnapshot board) {
    if (scope == LeaderboardScope.global) return 'GENEL · ELO';
    if (scope == LeaderboardScope.weekly) {
      final parts = board.periodKey.split('-W');
      return parts.length == 2
          ? '${parts.first} · ${int.tryParse(parts.last) ?? parts.last}. HAFTA'
          : 'HAFTALIK';
    }
    final date = DateTime.tryParse(board.periodKey);
    return date == null
        ? 'GÜNLÜK'
        : '${date.day}.${date.month}.${date.year} · GÜNLÜK';
  }
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({
    required this.entry,
    required this.scope,
    required this.isMe,
  });
  final LeaderboardEntry entry;
  final LeaderboardScope scope;
  final bool isMe;
  @override
  Widget build(BuildContext context) => PitchPanel(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
    child: Column(
      children: [
        Icon(
          Icons.emoji_events_rounded,
          color: entry.rank == 1
              ? const Color(0xFFB8892D)
              : Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 8),
        Text('#${entry.rank}', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 10),
        UserAvatarBadge(avatarId: entry.avatarId ?? 'starter_ball', radius: 24),
        const SizedBox(height: 12),
        Text(
          entry.displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Text(
          _score(entry, scope),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        if (isMe) ...[const SizedBox(height: 8), const SocialStatus('Sen')],
      ],
    ),
  );
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.entry,
    required this.scope,
    required this.isMe,
  });
  final LeaderboardEntry entry;
  final LeaderboardScope scope;
  final bool isMe;
  @override
  Widget build(BuildContext context) => PitchPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            UserAvatarBadge(
              avatarId: entry.avatarId ?? 'starter_ball',
              radius: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SocialStatus('#${entry.rank}'),
            if (isMe) const SocialStatus('Sen'),
            Text(
              _score(entry, scope),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
        if (scope == LeaderboardScope.weekly && entry.daysPlayed != null) ...[
          const SizedBox(height: 8),
          Text(
            '${entry.daysPlayed} gün oynadı',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    ),
  );
}

String _score(LeaderboardEntry entry, LeaderboardScope scope) =>
    '${entry.value} ${scope == LeaderboardScope.global ? 'Elo' : 'puan'}';
