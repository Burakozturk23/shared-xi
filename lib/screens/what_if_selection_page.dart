import 'package:flutter/material.dart';

import '../data/what_if.dart';
import 'story_journey_page.dart';

class LegendsPathPartSelectionPage extends StatelessWidget {
  const LegendsPathPartSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('What if?')),
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
                subtitle: const Text('1-8: Messi\'den Zlatan\'a'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>  StoryJourneyPage(
                      appBarTitle: 'What if? - Bölüm 1',
                      chapters: legendsPathPart1Chapters,
                      completionText: 'What if?\nBölüm 1 Tamamlandı! 🎉',
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
                subtitle: const Text('9-16: Rooney\'den Shearer\'a'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoryJourneyPage(
                      appBarTitle: 'What if? - Bölüm 2',
                      chapters: legendsPathPart2Chapters,
                      completionText: 'What if?\nBölüm 2 Tamamlandı! 🎉',
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
                title: const Text('Bölüm 3',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: const Text('17-24: Van Basten\'den Ronaldinho\'ya'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>  StoryJourneyPage(
                      appBarTitle: 'What if? - Bölüm 3',
                      chapters: legendsPathPart3Chapters,
                      completionText: 'What if?\nBölüm 3 Tamamlandı! 🎉',
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