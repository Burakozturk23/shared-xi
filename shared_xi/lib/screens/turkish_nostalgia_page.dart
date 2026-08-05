import 'package:flutter/material.dart';

import '../data/turkish_football_nostalgia.dart';
import 'story_journey_page.dart';

class TurkishNostalgiaPage extends StatelessWidget {
  const TurkishNostalgiaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StoryJourneyPage(
      appBarTitle: 'Türk Futbolu: Nostalji',
      chapters: turkishFootballNostalgiaChapters,
      completionText: 'Türk Futbolu: Nostalji\n%100 Tamamlandı! 🎉',
    );
  }
}