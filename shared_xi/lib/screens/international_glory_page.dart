import 'package:flutter/material.dart';

import '../data/international_glory.dart';
import 'story_journey_page.dart';

class InternationalGloryPage extends StatelessWidget {
  const InternationalGloryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StoryJourneyPage(
      appBarTitle: 'International Glory',
      chapters: internationalGloryChapters,
      completionText: 'International Glory\n%100 Tamamlandı! 🎉',
    );
  }
}