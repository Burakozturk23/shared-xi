import 'package:flutter/material.dart';

import '../data/player_journey_chapters.dart';
import 'player_journey_list_page.dart';

/// Player Journey giriş: bölüm seçimi.
class PlayerJourneyChapterListPage extends StatelessWidget {
  const PlayerJourneyChapterListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Player Journey'),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: playerJourneyChapters.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final chapter = playerJourneyChapters[index];
          final locked = !chapter.available;

          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Icon(
                locked ? Icons.lock : Icons.menu_book,
                size: 30,
                color: locked ? Colors.white38 : Colors.amber,
              ),
              title: Text(
                'BÖLÜM ${chapter.number}: ${chapter.title}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: locked ? Colors.white38 : null,
                ),
              ),
              subtitle: Text(
                locked
                    ? 'Yakında'
                    : '${chapter.journeys.length} futbolcu • ${chapter.subtitle}',
                style: TextStyle(
                  color: locked ? Colors.white24 : null,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                if (locked) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Bölüm ${chapter.number} çok yakında!',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerJourneyListPage(chapter: chapter),
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