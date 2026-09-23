import 'package:flutter/material.dart';

import '../app/game_catalog.dart';
import '../app/game_launcher.dart';
import '../app/route_appearance.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/pitch_ui.dart';
import 'progression_center_page.dart';

class AppHomePage extends StatelessWidget {
  const AppHomePage({super.key, required this.onGames});
  final VoidCallback onGames;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return ListView(
      key: const PageStorageKey('home'),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Text(
          'Bağlantıyı bul.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'İki taraf. Ortak bir futbolcu.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: p.muted),
        ),
        const SizedBox(height: 24),
        PitchPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Günün Maçları',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              PitchField(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Side(color: p.accent),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.surface,
                        border: Border.all(color: p.border),
                      ),
                      child: const Center(
                        child: BrandMark(size: 32, semanticLabel: null),
                      ),
                    ),
                    _Side(color: p.limeInk),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Her gün yeni bir ortak oyuncu bulmacası.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              PitchAction(
                label: 'Maçları Gör',
                onPressed: () => GameLauncher.open(context, GameCatalog.daily),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PitchPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.link_rounded, color: p.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ortak Oyuncu Keşfi',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'İki kulüp veya kulüp ve ülke seç.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              PitchAction(
                label: 'Keşfet',
                secondary: true,
                onPressed: () =>
                    GameLauncher.open(context, GameCatalog.discovery),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PitchRow(
          title: 'Günlük ödül ve görevler',
          icon: Icons.card_giftcard_outlined,
          onTap: () => Navigator.of(context).push(
            LinkballRoute(
              builder: (_) => const ProgressionCenterPage(),
              modern: true,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: onGames,
          icon: const Icon(Icons.sports_esports_outlined),
          label: const Text('Tüm oyunları keşfet'),
        ),
      ],
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 48,
      height: 56,
      decoration: BoxDecoration(
        color: PitchColors.of(context).surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PitchColors.of(context).border),
      ),
      child: Icon(Icons.shield_outlined, color: color, size: 28),
    ),
  );
}
