import 'package:flutter/material.dart';

import '../data/dynasties.dart';
import 'story_journey_page.dart';

/// Dynasties — 8'er dönemlik iki bölüm seçim ekranı
/// (Football Docu-Series ile aynı yapı)
class DynastiesPartSelectionPage extends StatelessWidget {
  const DynastiesPartSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dynasties')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Hangi bölümle devam etmek istersin?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const Icon(Icons.play_circle, size: 32),
                title: const Text(
                  'Bölüm 1',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: const Text(
                  "1-8: Barcelona'dan Bayern Münih'e",
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoryJourneyPage(
                      appBarTitle: 'Dynasties · Bölüm 1',
                      chapters: dynastiesPart1Chapters,
                      completionText: 'Dynasties\nBölüm 1 Tamamlandı! 🎉',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const Icon(Icons.play_circle, size: 32),
                title: const Text(
                  'Bölüm 2',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: const Text(
                  "9-16: Manchester United'dan Altın Takım'a",
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoryJourneyPage(
                      appBarTitle: 'Dynasties · Bölüm 2',
                      chapters: dynastiesPart2Chapters,
                      completionText: 'Dynasties\nBölüm 2 Tamamlandı! 🎉',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}