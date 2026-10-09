import 'package:flutter/material.dart';

import '../data/international_glory.dart';
import 'story_journey_page.dart';
import 'history_archive_page.dart';
import '../models/history_record.dart';

class InternationalGloryPage extends StatelessWidget {
  const InternationalGloryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StoryJourneyPage(
      appBarTitle: 'International Glory',
      archiveAction: const HistoryArchiveButton(scope: HistoryScope.international),
      chapters: internationalGloryChapters,
      completionText: 'International Glory\n%100 Tamamlandı! 🎉',
    );
  }
}