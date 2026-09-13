import 'package:flutter/material.dart';

import '../services/daily_challenge_service.dart';
import '../services/daily_playable_matches.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/entity_header_tile.dart';
import '../widgets/pitch_ui.dart';
import 'daily_challenge_game_page.dart';

class FootballCalendarPage extends StatefulWidget {
  const FootballCalendarPage({super.key});

  @override
  State<FootballCalendarPage> createState() => _FootballCalendarPageState();
}

class _FootballCalendarPageState extends State<FootballCalendarPage> {
  int _streak = 0;
  int _hints = 0;
  int _points = 0;
  bool _playedToday = false;
  double _lastRate = 0;
  Set<String> _badges = {};
  final Map<String, bool> _unlockedCache = {};
  final Map<String, bool> _completedCache = {};
  List<PlayableDailyMatch> _playable = [];
  bool _loadingMatches = true;
  bool _failed = false, _openingDay = false;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    if (!mounted) return;
    setState(() {
      _loadingMatches = true;
      _failed = false;
    });
    try {
      final streak = await DailyChallengeService.getStreak();
      final hints = await DailyChallengeService.getHints();
      final points = await DailyChallengeService.getPoints();
      final played = await DailyChallengeService.isCompletedToday();
      final rate = await DailyChallengeService.getLastSuccessRate();
      final badges = await DailyChallengeService.getBadges();

      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      for (var i = 0; i < 7; i++) {
        final day = monday.add(Duration(days: i));
        final key = DailyChallengeService.dateKeyFor(day);
        _unlockedCache[key] = await DailyChallengeService.isUnlocked(day);
        _completedCache[key] = await DailyChallengeService.isCompletedOn(day);
      }

      final playable = await DailyPlayableMatches.forDate(DateTime.now());

      if (!mounted) return;
      setState(() {
        _streak = streak;
        _hints = hints;
        _points = points;
        _playedToday = played;
        _lastRate = rate;
        _badges = badges;
        _playable = playable;
        _loadingMatches = false;
      });
    } catch (error, stack) {
      debugPrint('Daily calendar: $error\n$stack');
      if (mounted) {
        setState(() {
          _loadingMatches = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _onDayTap(DateTime day) async {
    if (_openingDay) return;
    _openingDay = true;
    try {
      await _openDay(day);
    } catch (error, stack) {
      debugPrint('Open daily date: $error\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu gün açılamadı. Tekrar deneyebilirsin.'),
          ),
        );
      }
    } finally {
      _openingDay = false;
    }
  }

  Future<void> _openDay(DateTime day) async {
    final now = DateTime.now();
    final d = DateTime(day.year, day.month, day.day);
    final t = DateTime(now.year, now.month, now.day);

    if (d.isAfter(t)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gelecek günler henüz kilitli.')),
      );
      return;
    }

    if (d == t) {
      // Bugün: liste zaten ekranda; ekstra bir şey yapma
      return;
    }

    final unlocked = await DailyChallengeService.isUnlocked(d);
    if (unlocked) {
      final list = await DailyPlayableMatches.forDate(d);
      if (!mounted) return;
      if (list.isEmpty) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DailyChallengeGamePage(playDate: d),
          ),
        );
      } else if (list.length == 1) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DailyChallengeGamePage(playDate: d, match: list.first),
          ),
        );
      } else {
        await showModalBottomSheet<void>(
          context: context,
          builder: (ctx) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(
                  title: Text(
                    'Maç seç',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ...list.map(
                  (m) => ListTile(
                    title: Text(m.label),
                    subtitle: Text(m.leagueName),
                    trailing: const Icon(Icons.play_arrow),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              DailyChallengeGamePage(playDate: d, match: m),
                        ),
                      ).then((_) => _loadMeta());
                    },
                  ),
                ),
              ],
            ),
          ),
        );
        _loadMeta();
        return;
      }
      _loadMeta();
      return;
    }

    final points = await DailyChallengeService.getPoints();
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Telafi hakkı'),
        content: Text(
          '${day.day}.${day.month}.${day.year} mücadelesini açmak için '
          '${DailyChallengeService.unlockCost} puan gerekir.\n\n'
          'Mevcut puanın: $points',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aç'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await DailyChallengeService.unlockDate(d);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.ok) {
      await _openDay(d);
    } else {
      _loadMeta();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Günün maçları')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadMeta,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Bugün sahada ne var?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Bir eşleşme seç, ortak futbolcuları bul.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: p.muted),
              ),
              const SizedBox(height: 24),
              _buildStats(),
              const PitchSectionTitle('Bugünün eşleşmeleri'),
              if (_loadingMatches)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_failed)
                EmptyState(
                  title: 'Maçlar yüklenemedi',
                  icon: Icons.cloud_off_outlined,
                  message: 'Bir kez daha deneyebilirsin.',
                  actionLabel: 'Tekrar dene',
                  onAction: _loadMeta,
                )
              else if (_playable.isEmpty)
                EmptyState(
                  title: 'Eşleşmeler hazırlanıyor',
                  message: 'Yeni eşleşmeleri biraz sonra kontrol edebilirsin.',
                  actionLabel: 'Yenile',
                  onAction: _loadMeta,
                )
              else ...[
                for (final match in _playable) ...[
                  PitchPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          match.id.startsWith('fallback-')
                              ? 'GÜNLÜK BAĞLANTI'
                              : [
                                  match.leagueName,
                                  if (match.isDerby) 'Derbi',
                                ].where((s) => s.isNotEmpty).join(' · '),
                          style: Theme.of(
                            context,
                          ).textTheme.labelMedium?.copyWith(color: p.accent),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: EntityHeaderTile(entity: match.entity1),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Icon(
                                Icons.join_inner_rounded,
                                color: p.muted,
                              ),
                            ),
                            Expanded(
                              child: EntityHeaderTile(entity: match.entity2),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${match.theme.roundSeconds} sn · ${match.theme.maxLives} can · ${match.sharedCount} ortak oyuncu',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        PitchAction(
                          label: 'Oyna',
                          icon: Icons.play_arrow_rounded,
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    DailyChallengeGamePage(match: match),
                              ),
                            );
                            if (mounted) _loadMeta();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
              const PitchSectionTitle('Bu hafta'),
              _buildWeekStrip(DateTime.now()),
              const SizedBox(height: 16),
              Text(
                'Geçmiş bir günü ${DailyChallengeService.unlockCost} puanla açabilirsin.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_badges.isNotEmpty) ...[
                const PitchSectionTitle('Kazandığın rozetler'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final badge in _badges)
                      Chip(
                        avatar: const Icon(
                          Icons.emoji_events_outlined,
                          size: 20,
                        ),
                        label: Text(switch (badge) {
                          'sadik_taktisyen' => 'Sadık Taktisyen',
                          'derbi_uzmani' => 'Derbi Uzmanı',
                          _ => badge,
                        }),
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

  Widget _buildStats() {
    final stats = [
      ('Seri', '$_streak gün'),
      ('İpucu', '$_hints'),
      ('Puan', '$_points'),
      ('Son başarı', _playedToday ? '%${(_lastRate * 100).round()}' : '—'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            MediaQuery.textScalerOf(context).scale(16) > 24 ||
                constraints.maxWidth < 340
            ? 2
            : 4;
        final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final stat in stats)
              SizedBox(
                width: width,
                child: PitchPanel(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        stat.$2,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stat.$1,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildWeekStrip(DateTime now) {
    const names = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final p = PitchColors.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Builder(
              builder: (context) {
                final day = monday.add(Duration(days: i));
                final key = DailyChallengeService.dateKeyFor(day);
                final current = day == today;
                final completed = _completedCache[key] ?? false;
                final unlocked = _unlockedCache[key] ?? current;
                final future = day.isAfter(today);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Semantics(
                    button: true,
                    selected: current,
                    label:
                        '${day.day} ${day.month}, ${completed
                            ? 'tamamlandı'
                            : future
                            ? 'henüz açılmadı'
                            : unlocked
                            ? 'açık'
                            : 'telafi hakkı'}',
                    child: Material(
                      color: current ? p.tint : p.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: current ? p.accent : p.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _onDayTap(day),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 56),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Text(
                                  names[i],
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${day.day}',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                Icon(
                                  completed
                                      ? Icons.check_circle_outline_rounded
                                      : future || !unlocked
                                      ? Icons.lock_outline_rounded
                                      : Icons.sports_soccer_rounded,
                                  color: completed
                                      ? p.success
                                      : current
                                      ? p.accent
                                      : p.muted,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
