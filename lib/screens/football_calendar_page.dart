import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/football_calendar_theme.dart';
import '../services/daily_challenge_service.dart';
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

    if (!mounted) return;
    setState(() {
      _streak = streak;
      _hints = hints;
      _points = points;
      _playedToday = played;
      _lastRate = rate;
      _badges = badges;
      _theme = DailyChallengeService.themeFor();
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
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DailyChallengeGamePage()),
      );
      _loadMeta();
      return;
    }

    // Geçmiş gün
    final unlocked = await DailyChallengeService.isUnlocked(d);
    if (unlocked) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DailyChallengeGamePage(playDate: d),
        ),
      );
      _loadMeta();
      return;
    }

    // Telafi dialog
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
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DailyChallengeGamePage(playDate: d),
        ),
      );
      _loadMeta();
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
            _buildTodayCard(),
            const SizedBox(height: 16),
            _buildWeekStrip(now),
            const SizedBox(height: 16),
            if (_badges.isNotEmpty) _buildBadges(),
            const SizedBox(height: 12),
            Text(
              'Geçmiş günlere dokun → ${DailyChallengeService.unlockCost} puanla telafi.\n'
              'Fikstür API, push ve canlı skor sonraki fazda.',
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
            Text(_theme.subtitle,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
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

  Widget _buildTodayCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _playedToday
                  ? 'Bugünkü mücadele tamamlandı'
                  : 'Bugünün Mücadelesi',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '${_theme.roundSeconds}s · ${_theme.maxLives} can · hedef ${_theme.targetFinds} oyuncu',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent.withValues(alpha: 0.85),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DailyChallengeGamePage(),
                    ),
                  );
                  _loadMeta();
                },
                child: Text(
                  _playedToday ? 'SONUCU GÖR' : 'MÜCADELEYE BAŞLA',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
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
                final isFuture = day.isAfter(DateTime(now.year, now.month, now.day));

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