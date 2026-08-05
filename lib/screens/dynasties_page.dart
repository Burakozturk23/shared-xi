import 'package:flutter/material.dart';

import '../data/dynasties.dart';
import 'story_journey_page.dart';

class DynastiesPage extends StatelessWidget {
  const DynastiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StoryJourneyPage(
      appBarTitle: 'Dynasties',
      chapters: dynastiesChapters,
      completionText: 'Dynasties\n%100 Tamamlandı! 🎉',
    );
  }
}