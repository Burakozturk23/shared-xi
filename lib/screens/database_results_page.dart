import 'package:flutter/material.dart';

import '../models/player.dart';

class DatabaseResultsPage extends StatelessWidget {
  final String title;
  final List<Player> players;

  const DatabaseResultsPage({
    super.key,
    required this.title,
    required this.players,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<Player>.from(players)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: sorted.isEmpty
          ? const Center(child: Text('Ortak oyuncu bulunamadı.'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    '${sorted.length} oyuncu',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = sorted[i];
                      final sub = [
                        if (p.position.trim().isNotEmpty) p.position,
                        if (p.countryLabel.trim().isNotEmpty) p.countryLabel,
                      ].join(' · ');
                      return ListTile(
                        title: Text(p.name),
                        subtitle: sub.isEmpty ? null : Text(sub),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
