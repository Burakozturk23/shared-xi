import 'package:flutter/material.dart';
import '../app/game_catalog.dart';
import '../app/game_launcher.dart';
import '../widgets/pitch_ui.dart';
import 'player_journey_chapter_list_page.dart';
import 'derby_day_country_page.dart';
import 'ucl_moments_page.dart';
import 'turkish_nostalgia_page.dart';
import 'international_glory_page.dart';
import 'dynasties_page.dart';
import 'football_docu_series_part_selection_page.dart';
import 'what_if_selection_page.dart';
class StorySubMode {
  final String title;
  final String subtitle;
  final IconData icon;

  const StorySubMode({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

const List<StorySubMode> storySubModes = [
  StorySubMode(
    title: 'Player Journey',
    subtitle: 'Bir oyuncunun kariyer yolculuğunu yaşa',
    icon: Icons.route,
  ),
  StorySubMode(
    title: 'WHAT IF',
    subtitle: 'Futbol tarihinin en büyük "Ya şöyle olsaydı?" kırılma anları',
    icon: Icons.swap_horizontal_circle_sharp,
  ),
  StorySubMode(
    title: 'UCL Moments',
    subtitle: 'Şampiyonlar Ligi\'nin unutulmaz anları',
    icon: Icons.stars,
  ),
  StorySubMode(
    title: 'Türk Futbolu: Nostalji',
    subtitle: '12 dönem · 24 görev · Nostalji Albümü',
    icon: Icons.history_edu,
  ),
  StorySubMode(
    title: 'International Glory',
    subtitle: 'Milli takım zaferleri',
    icon: Icons.public,
  ),
  StorySubMode(
    title: 'Dynasties',
    subtitle: 'Bir dönemi domine eden kulüpler',
    icon: Icons.castle,
  ),
  StorySubMode(
    title: 'Football Docu-Series',
    subtitle: 'Belgesel tadında futbol hikayeleri',
    icon: Icons.movie_creation,
  ),
  StorySubMode(
    title: 'Derby Day',
    subtitle: 'Tarihi rekabetlerin içine gir',
    icon: Icons.sports_kabaddi,
  ),
];

class StoryModeSelectionPage extends StatelessWidget {
  const StoryModeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    const pages = <Widget>[
      PlayerJourneyChapterListPage(), LegendsPathPartSelectionPage(),
      UclMomentsPage(), TurkishNostalgiaPage(), InternationalGloryPage(),
      DynastiesPage(), FootballDocuSeriesPartSelectionPage(), DerbyDayCountryPage(),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Hikâye')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [
        Text('Futbolun hikâyelerine katıl.', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8), const Text('Bir yolculuk seç. Sahadaki izleri takip et.'),
        const SizedBox(height: 22),
        for (var i=0;i<storySubModes.length;i++) Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PitchRow(key: ValueKey('story-mode-$i'), title: storySubModes[i].title,
            subtitle: storySubModes[i].subtitle, icon: storySubModes[i].icon, highlight: true,
            onTap: () => GameLauncher.open(context, GameEntry(
              title: storySubModes[i].title, subtitle: storySubModes[i].subtitle,
              icon: storySubModes[i].icon, page: pages[i],
              requiresRepository: i > 2, modern: i <= 2,
            )),
          ),
        ),
      ])),
    );
  }
}
