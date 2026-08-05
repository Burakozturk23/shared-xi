import 'package:flutter/material.dart';
import 'player_journey_list_page.dart';
import 'derby_day_country_page.dart';
import 'ucl_moments_page.dart';
import 'turkish_nostalgia_page.dart';
import 'international_glory_page.dart';
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
    title: 'Derby Day',
    subtitle: 'Tarihi rekabetlerin içine gir',
    icon: Icons.sports_kabaddi,
  ),
  StorySubMode(
    title: 'UCL Moments',
    subtitle: 'Şampiyonlar Ligi\'nin unutulmaz anları',
    icon: Icons.stars,
  ),
  StorySubMode(
    title: 'Türk Futbolu: Nostalji',
    subtitle: 'Türk futbolunun altın yılları',
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
    title: 'WHAT IF',
    subtitle: 'Futbol tarihinin en büyük "Ya şöyle olsaydı?" kırılma anları',
    icon: Icons.swap_horizontal_circle_sharp,
  ),
];

class StoryModeSelectionPage extends StatelessWidget {
  const StoryModeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Story Mode')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: storySubModes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final mode = storySubModes[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Icon(mode.icon, size: 32),
              title: Row(
                children: [
                  Text(
                    'MOD ${index + 1}: ${mode.title}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(width: 6),
                  // index == 0 değilse kilit göster, 0 ise gösterme
if (index != 0 && index != 2 && index != 3 && index != 4 && index != 7) ...[
  const SizedBox(width: 6),
  const Icon(Icons.lock, size: 14, color: Colors.grey),
],
                ],
              ),
              subtitle: Text(mode.subtitle),
              trailing: const Icon(Icons.chevron_right),
        onTap: () {
  if (index == 0) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlayerJourneyListPage()),
    );
    return;
  }
  if (index == 2) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UclMomentsPage()),
    );
    return;
  }
  if (index == 7) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DerbyDayCountryPage()),
    );
    return;
  }
  if (index == 3) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const TurkishNostalgiaPage()),
  );
  return;
}
if (index == 4) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const InternationalGloryPage()),
  );
  return;
}
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('${mode.title} çok yakında!')),
  );
},
            ),
          );
        },
      ),
    );
  }
}