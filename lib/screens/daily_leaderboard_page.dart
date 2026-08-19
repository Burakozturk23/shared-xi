import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/daily_challenge_service.dart';
import '../services/daily_leaderboard_service.dart';

class DailyLeaderboardPage extends StatelessWidget {
  final DateTime? date;

  const DailyLeaderboardPage({super.key, this.date});

  @override
  Widget build(BuildContext context) {
    final day = date ?? DateTime.now();
    final key = DailyChallengeService.dateKeyFor(day);
    final myUid = AuthService.uid;

    return Scaffold(
      appBar: AppBar(title: Text('Günün Sıralaması · $key')),
      body: StreamBuilder<List<DailyLeaderboardEntry>>(
        stream: DailyLeaderboardService.watch(date: day),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Henüz kimse oynamadı.\nİlk sırayı sen al!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final e = list[i];
              final isMe = e.uid == myUid;
              final rank = i + 1;
              final medal = rank == 1
                  ? '🥇'
                  : (rank == 2 ? '🥈' : (rank == 3 ? '🥉' : '$rank.'));
              final pct = (e.successRate * 100).round();

              return ListTile(
                tileColor: isMe
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                    : null,
                leading: SizedBox(
                  width: 40,
                  child: Text(
                    medal,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  e.displayName + (isMe ? ' (sen)' : ''),
                  style: TextStyle(
                    fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '%$pct başarı'
                  '${e.secondsLeft != null ? ' · ${e.secondsLeft}s kaldı' : ''}'
                  '${e.streak != null && e.streak! > 0 ? ' · 🔥${e.streak}' : ''}',
                ),
                trailing: Text(
                  '${e.score}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
