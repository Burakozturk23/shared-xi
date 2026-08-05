import 'package:flutter/material.dart';

import '../data/player_journeys.dart';
import 'player_journey_page.dart';

class PlayerJourneyListPage extends StatelessWidget {
  const PlayerJourneyListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Player Journey')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: playerJourneys.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final journey = playerJourneys[index];

          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Icon(
                journey.available ? Icons.person : Icons.lock,
                size: 30,
                color: journey.available ? Colors.amber : Colors.white38,
              ),
              title: Text(
                journey.subjectName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: journey.available ? null : Colors.white38,
                ),
              ),
              subtitle: Text(
                journey.available ? '${journey.stages.length} aşama' : 'Yakında',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                if (!journey.available) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${journey.subjectName} hikayesi çok yakında!')),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerJourneyPage(journey: journey),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}