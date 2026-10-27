import 'package:flutter/material.dart';
import '../app/game_audio.dart';
import '../app/route_appearance.dart';
import '../models/chain_state.dart';
import '../widgets/game_ui.dart';
import '../widgets/pitch_ui.dart';
import 'chain_page.dart';

class ChainModeSelectionPage extends StatelessWidget {
  const ChainModeSelectionPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kariyer Zinciri')),
    body: GameContent(child: ListView(padding: const EdgeInsets.all(20), children: [
      const GameIntro(icon: Icons.hub_outlined, title: 'Kulüpler arasında bir bağ kur.',
        message: 'Ortak futbolcuları bul. Kendi hızında en kısa yolu çöz veya zamana karşı yarış.'),
      const SizedBox(height: 24),
      Text('Oyun tarzını seç', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      PitchRow(title: 'Zincir Ustalığı', subtitle: 'Süre yok · En az hamle · PAR hedefi',
        icon: Icons.psychology_outlined, highlight: true,
        onTap: () => Navigator.push(context, LinkballRoute(builder: (_) => const ChainPage(mode: ChainGameMode.mastermind)))),
      const SizedBox(height: 12),
      PitchRow(title: 'Zincir Sprinti', subtitle: '60 sn başlangıç · Zincir başına +5 sn · En fazla 180 sn',
        icon: Icons.timer_outlined, highlight: true,
        onTap: () => Navigator.push(context, LinkballRoute(builder: (_) =>
          const MusicScene(track: MusicTrack.rush, child: ChainPage(mode: ChainGameMode.blitz))))),
    ])),
  );
}
