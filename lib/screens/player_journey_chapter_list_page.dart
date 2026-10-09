import 'journey_passport_page.dart';
import 'package:flutter/material.dart';
import '../app/route_appearance.dart';
import '../data/player_journey_chapters.dart';
import '../widgets/pitch_ui.dart';
import 'player_journey_list_page.dart';

class PlayerJourneyChapterListPage extends StatelessWidget {
  const PlayerJourneyChapterListPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Player Journey')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [
      PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Kariyerin izinde', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8), const Text('Bir bölüm seç, futbolcuların yolculuklarını adım adım çöz.'),
      ])),
      const SizedBox(height: 16),
      PitchRow(title: 'Kariyer Pasaportu', subtitle: '32 damga · 5 rozet · Profil vitrinin', icon: Icons.auto_awesome, highlight: true,
        onTap: () => Navigator.of(context).push(LinkballRoute(builder: (_) => const JourneyPassportPage()))),
      const SizedBox(height: 20),
      for (final chapter in playerJourneyChapters) Padding(padding: const EdgeInsets.only(bottom: 12), child: PitchRow(
        key: ValueKey('journey-chapter-${chapter.number}'),
        title: 'Bölüm ${chapter.number} · ${chapter.title}',
        subtitle: chapter.available ? '${chapter.journeys.length} futbolcu · ${chapter.subtitle}' : 'Yakında',
        icon: chapter.available ? Icons.auto_stories_outlined : Icons.lock_outline,
        highlight: chapter.available,
        onTap: chapter.available ? () => Navigator.of(context).push(LinkballRoute(
          builder: (_) => PlayerJourneyListPage(chapter: chapter),
        )) : null,
      )),
    ])),
  );
}
