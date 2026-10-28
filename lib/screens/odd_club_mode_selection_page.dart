import 'package:flutter/material.dart';
import '../app/game_audio.dart';
import '../app/route_appearance.dart';
import '../widgets/game_ui.dart';
import '../widgets/hub_ui.dart';
import 'odd_club_page.dart';

class OddClubModeSelectionPage extends StatelessWidget {
  const OddClubModeSelectionPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sahte Kulüp')),
    body: GameContent(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const GameIntro(
            icon: Icons.search_off_rounded,
            title: 'Kariyerdeki yabancıyı bul',
            message:
                'Futbolcunun oynamadığı kulübü seç. Kendi hızında ilerle veya zamana karşı yarış.',
          ),
          const SizedBox(height: 24),
          Text(
            'Oyun tarzını seç',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ModeStyleCard(
            title: 'Sonsuz Seri',
            icon: Icons.all_inclusive,
            specs: 'Süresiz · 3 can · 1 ücretsiz 50/50 · kalıcı rekor',
            onTap: () => Navigator.push(
              context,
              LinkballRoute(
                modern: true,
                builder: (_) => const OddClubPage(timed: false),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ModeStyleCard(
            title: 'Hız Serisi',
            icon: Icons.timer_outlined,
            specs: '10 soru · soru başına 10 saniye · 3 can · yardımsız',
            onTap: () => Navigator.push(
              context,
              LinkballRoute(
                modern: true,
                builder: (_) => const MusicScene(
                  track: MusicTrack.rush,
                  child: OddClubPage(timed: true),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
