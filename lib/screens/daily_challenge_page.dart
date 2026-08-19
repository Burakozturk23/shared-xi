import 'package:flutter/material.dart';

import '../services/daily_challenge_service.dart';
import 'daily_challenge_game_page.dart';
import 'daily_leaderboard_page.dart';

class DailyChallengePage extends StatefulWidget {
  const DailyChallengePage({super.key});

  @override
  State<DailyChallengePage> createState() => _DailyChallengePageState();
}

class _DailyChallengePageState extends State<DailyChallengePage> {
  bool _loading = true;
  bool _completedToday = false;
  int _streak = 0;
  int _lastScore = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final completed = await DailyChallengeService.isCompletedToday();
    final streak = await DailyChallengeService.getStreak();
    final lastScore = await DailyChallengeService.getLastScore();

    if (!mounted) return;

    setState(() {
      _completedToday = completed;
      _streak = streak;
      _lastScore = lastScore;
      _loading = false;
    });
  }

  Future<void> _start() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DailyChallengeGamePage()),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Günün Mücadelesi')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const CircularProgressIndicator()
              : Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 36, horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.calendar_today,
                              size: 48, color: Colors.amber),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '$_streak günlük seri 🔥',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        if (_completedToday) ...[
                          const Text(
                            'Bugünkü mücadeleyi tamamladın!',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(fontSize: 15, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Skorun: $_lastScore',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Yarın yeni bir mücadele seni bekliyor.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DailyLeaderboardPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.leaderboard_outlined),
                            label: const Text('Günün sıralaması'),
                          ),
                        ] else ...[
                          const Text(
                            '90 saniyen var. Bugünün eşleşmesinde\nortak oyuncuları bul!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 15),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _start,
                              child: const Text(
                                'BAŞLA',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}