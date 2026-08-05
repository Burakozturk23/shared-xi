import 'package:flutter/material.dart';

import '../data/football_docu_series.dart';
import 'story_journey_page.dart';

class FootballDocuSeriesPartSelectionPage extends StatelessWidget {
  const FootballDocuSeriesPartSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Football Docu-Series')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Hangi bölümle devam etmek istersin?',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const Icon(Icons.play_circle, size: 32),
                title: const Text('Bölüm 1',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: const Text('1-8: Leicester\'dan Nottingham Forest\'a'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>  StoryJourneyPage(
                      appBarTitle: 'Football Docu-Series - Bölüm 1',
                      chapters: footballDocuSeriesPart1Chapters,
                      completionText:
                          'Football Docu-Series\nBölüm 1 Tamamlandı! 🎉',
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
                title: const Text('Bölüm 2',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: const Text('9-16: Porto Rüyası\'ndan Sampdoria\'ya'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>  StoryJourneyPage(
                      appBarTitle: 'Football Docu-Series - Bölüm 2',
                      chapters: footballDocuSeriesPart2Chapters,
                      completionText:
                          'Football Docu-Series\nBölüm 2 Tamamlandı! 🎉',
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