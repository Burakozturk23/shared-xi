import 'package:flutter/material.dart';

import '../models/football_calendar_theme.dart';
import '../services/daily_challenge_service.dart';
import '../services/daily_playable_matches.dart';
import 'daily_challenge_game_page.dart';

class FootballCalendarPage extends StatefulWidget {
  const FootballCalendarPage({super.key});

  @override
  State<FootballCalendarPage> createState() => _FootballCalendarPageState();
}

class _FootballCalendarPageState extends State<FootballCalendarPage> {
  late FootballCalendarTheme _theme;
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

  @override
  void initState() {
    super.initState();
    _theme = DailyChallengeService.themeFor();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
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
      if (playable.isNotEmpty) {
        _theme = playable.first.theme;
      } else {
        _theme = DailyChallengeService.themeFor();
      }
    });
  }

  Color get _accent {
    switch (_theme.kind) {
      case CalendarThemeKind.europeNight:
        return Colors.amber;
      case CalendarThemeKind.derbyDay:
      case CalendarThemeKind.derbyCountdown:
        return Colors.redAccent;
      case CalendarThemeKind.weekSummary:
        return Colors.lightBlueAccent;
    }
  }

  Future<void> _onDayTap(DateTime day) async {
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
            builder: (_) => DailyChallengeGamePage(playDate: d, match: list.first),
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
                  title: Text('Maç seç',
                      style: TextStyle(fontWeight: FontWeight.bold)),
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
                          builder: (_) => DailyChallengeGamePage(
                            playDate: d,
                            match: m,
                          ),
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
              child: const Text('İptal')),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    if (result.ok) {
      await _onDayTap(d);
    } else {
      _loadMeta();
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Futbol Takvimi'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildThemeBanner(),
            const SizedBox(height: 16),
            _buildStatsRow(),
            const SizedBox(height: 16),
            _buildMatchList(),
            const SizedBox(height: 16),
            _buildWeekStrip(now),
            const SizedBox(height: 16),
            if (_badges.isNotEmpty) _buildBadges(),
            const SizedBox(height: 12),
            Text(
              'Geçmiş günlere dokun → ${DailyChallengeService.unlockCost} puanla telafi.\n'
              'Bugünün eşleşmeleri gerçek fikstürden seçilir. İstediğin kadar oyna.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeBanner() {
    return Card(
      color: _accent.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _theme.badgeLabel,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _accent),
              ),
            ),
            const SizedBox(height: 10),
            Text(_theme.title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              _playable.isNotEmpty
                  ? '${_playable.length} oynanabilir maç'
                  : _theme.subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _statTile('🔥 Seri', '$_streak gün')),
        const SizedBox(width: 8),
        Expanded(child: _statTile('💡 İpucu', '$_hints')),
        const SizedBox(width: 8),
        Expanded(child: _statTile('⭐ Puan', '$_points')),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            'Son',
            _playedToday ? '%${(_lastRate * 100).round()}' : '—',
          ),
        ),
      ],
    );
  }

  Widget _statTile(String title, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(
          children: [
            Text(title,
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchList() {
    if (_loadingMatches) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_playable.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Bugün oynanabilir maç bulunamadı.'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Bugünün Maçları',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          'İstediğin maçı seç, istediğin kadar oyna.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 12),
        ..._playable.map(
          (m) => Card(
            child: ListTile(
              title: Text(
                m.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                [
                  if (m.leagueName.isNotEmpty) m.leagueName,
                  if (m.isDerby) 'Derbi',
                  '${m.theme.roundSeconds}s',
                  '${m.theme.maxLives} can',
                  '${m.sharedCount} ortak',
                ].join(' · '),
              ),
              trailing: const Icon(Icons.play_arrow),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DailyChallengeGamePage(match: m),
                  ),
                );
                _loadMeta();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekStrip(DateTime now) {
    const names = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final monday = now.subtract(Duration(days: now.weekday - 1));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bu Hafta — güne dokun',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: List.generate(7, (i) {
                final day = monday.add(Duration(days: i));
                final theme = FootballCalendarTheme.forDate(day);
                final isToday = day.day == now.day &&
                    day.month == now.month &&
                    day.year == now.year;
                final key = DailyChallengeService.dateKeyFor(day);
                final unlocked = _unlockedCache[key] ?? isToday;
                final completed = _completedCache[key] ?? false;
                final isFuture = day.isAfter(
                    DateTime(now.year, now.month, now.day));

                final icon = switch (theme.kind) {
                  CalendarThemeKind.europeNight => '⭐',
                  CalendarThemeKind.derbyDay ||
                  CalendarThemeKind.derbyCountdown =>
                    '🔥',
                  CalendarThemeKind.weekSummary => '📋',
                };

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onDayTap(day),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isToday
                            ? _accent.withValues(alpha: 0.22)
                            : completed
                                ? Colors.green.withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: isToday
                            ? Border.all(color: _accent, width: 1.4)
                            : null,
                      ),
                      child: Column(
                        children: [
                          Text(names[i],
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            isFuture
                                ? '🔒'
                                : completed
                                    ? '✅'
                                    : unlocked
                                        ? icon
                                        : '🔐',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text('${day.day}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadges() {
    final labels = {
      'sadik_taktisyen': '🎖️ Sadık Taktisyen',
      'derbi_uzmani': '🏆 Derbi Uzmanı',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rozetler',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _badges
                  .map((b) => Chip(label: Text(labels[b] ?? b)))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}