import 'package:flutter/material.dart';
import '../app/game_catalog.dart';
import '../app/game_launcher.dart';
import '../app/route_appearance.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/pitch_ui.dart';
import 'progression_center_page.dart';

class AppHomePage extends StatelessWidget {
  const AppHomePage({super.key, this.onOpen});
  final ValueChanged<GameEntry>? onOpen;

  void _open(BuildContext context, GameEntry game) {
    if (onOpen != null) { onOpen!(game); return; }
    GameLauncher.open(context, game);
  }

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return ListView(
      key: const PageStorageKey('home'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text('Bugün sahada.', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text('Yeni bir gün, yeni futbol bulmacaları.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: p.muted)),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(colors: [p.tint, p.surface]),
            border: Border.all(color: p.accent.withValues(alpha: .4))),
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: p.background, borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.person_search_outlined, color: p.accent, size: 30)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('GÜNLÜK BULMACA', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: p.accent)),
                const SizedBox(height: 4),
                Text('Günün Futbolcusu', style: Theme.of(context).textTheme.titleLarge),
              ])),
            ]),
            const SizedBox(height: 12),
            const Text('6 tahmin. 6 özellik. Gizli isme giden izleri takip et.'),
            const SizedBox(height: 16),
            PitchAction(label: 'Futbolcuyu bul', icon: Icons.arrow_forward_rounded,
              onPressed: () => _open(context, GameCatalog.dailyFootballer)),
          ]),
        ),
        const SizedBox(height: 12),
        PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.calendar_today_outlined, color: p.limeInk, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text('Günün Maçları', style: Theme.of(context).textTheme.titleLarge)),
          ]),
          const SizedBox(height: 8),
          const Text('Bugünün eşleşmelerindeki ortak futbolcuları çöz.'),
          const SizedBox(height: 12),
          PitchAction(label: 'Maçları gör', secondary: true,
            onPressed: () => _open(context, GameCatalog.daily)),
        ])),
        const SizedBox(height: 12),
        PitchRow(title: 'Ortak Oyuncu Keşfi', subtitle: 'İki kulüp seç, bağlantıyı bul.',
          icon: Icons.link_rounded, highlight: true,
          onTap: () => _open(context, GameCatalog.discovery)),
        const SizedBox(height: 12),
        PitchRow(title: 'Günlük ödül ve görevler', subtitle: 'İlerlemeni sürdür, ödüllerini topla.',
          icon: Icons.card_giftcard_outlined,
          onTap: () => Navigator.of(context).push(LinkballRoute(
            builder: (_) => const ProgressionCenterPage(), modern: true))),
      ],
    );
  }
}
