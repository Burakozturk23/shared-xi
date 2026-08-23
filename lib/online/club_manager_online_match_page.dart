import 'package:flutter/material.dart';

class ClubManagerOnlineMatchPage extends StatelessWidget {
  final String roomCode;
  final String playerName;
  final Map<String, dynamic> result;

  const ClubManagerOnlineMatchPage({
    super.key,
    required this.roomCode,
    required this.playerName,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final home = result['home'] as String? ?? 'A';
    final away = result['away'] as String? ?? 'B';
    final hg = (result['homeGoals'] as num?)?.toInt() ?? 0;
    final ag = (result['awayGoals'] as num?)?.toInt() ?? 0;
    final hp = (result['homePower'] as num?)?.toDouble() ?? 0;
    final ap = (result['awayPower'] as num?)?.toDouble() ?? 0;
    final events = (result['events'] as List?) ?? [];

    final iAmHome = playerName == home;
    final myGoals = iAmHome ? hg : ag;
    final oppGoals = iAmHome ? ag : hg;
    final win = myGoals > oppGoals;
    final draw = myGoals == oppGoals;

    final outcome = win
        ? 'GALİBİYET'
        : draw
            ? 'BERABERE'
            : 'MAĞLUBİYET';
    final color = win
        ? const Color(0xFF00E676)
        : draw
            ? Colors.amber
            : Colors.redAccent;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white70,
        title: Text('Sonuç · ${roomCode}',
            style: const TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF121820),
            child: Column(
              children: [
                Text(outcome,
                    style: TextStyle(
                        color: color,
                        fontSize: 28,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Text(
                  '$home  $hg - $ag  $away',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Güç ${hp.toStringAsFixed(0)} · ${ap.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: events.length,
              itemBuilder: (_, i) {
                final e = Map<String, dynamic>.from(events[i] as Map);
                final goal = e['isGoal'] == true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    "${e['minute']}'  ${e['text']}",
                    style: TextStyle(
                      color: goal ? Colors.white : Colors.white60,
                      fontWeight: goal ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () =>
                    Navigator.popUntil(context, (r) => r.isFirst),
                child: const Text('ANA MENÜ',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
