import 'package:flutter/material.dart';

import '../app/app_feedback.dart';
import '../app/bot_game_catalog.dart';
import '../app/route_appearance.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/bot_mode_card.dart';
import '../widgets/hub_ui.dart';
import '../widgets/pitch_tile.dart';
import 'bot_game_detail_page.dart';
import 'vs_bot_grid_mode_selection_page.dart';

class VsBotModeSelectionPage extends StatelessWidget {
  const VsBotModeSelectionPage({super.key});

  void _open(BuildContext context, Widget page) {
    AppFeedback.selection();
    Navigator.of(context).push(LinkballRoute(builder: (_) => page));
  }

  Widget _card(
    BuildContext context,
    BotGameDefinition game, {
    String? badge,
    bool featured = false,
    bool accentFooter = true,
  }) => BotModeCard(
    title: game.entry.title,
    subtitle: game.entry.subtitle,
    icon: game.entry.icon,
    tags: game.tags,
    badge: badge,
    featured: featured,
    fillHeight: !featured,
    accentFooter: accentFooter,
    onTap: () => _open(context, BotGameDetailPage(game: game)),
  );

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Botla oyna'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: p.border),
        ),
      ),
      body: SafeArea(
        child: ListView(
          key: const PageStorageKey('bot-games'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Text('Rakibin hazır.', style: text.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Bir oyun seç, kurallara göz at ve sahaya çık.',
              style: text.bodyMedium?.copyWith(color: p.muted),
            ),
            const SizedBox(height: 20),
            HubHeroCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      HubIconBox(
                        Icons.smart_toy_outlined,
                        size: 52,
                        background: p.background.withValues(alpha: .4),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TAKTİK BOT',
                              style: hubCaps(context, color: p.accent),
                            ),
                            const SizedBox(height: 2),
                            Text('Seviyeni sen seç', style: text.titleLarge),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Zorluk seçilen oyunlarda botun hızı ve isabeti seçtiğin seviyeye göre değişir.',
                    style: text.bodySmall?.copyWith(color: p.muted),
                  ),
                  const SizedBox(height: 14),
                  Divider(height: 1, color: p.border),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      HubPill(
                        'Kolay · Orta · Zor',
                        icon: Icons.tune_rounded,
                        color: p.text,
                        background: p.background.withValues(alpha: .4),
                      ),
                      HubPill(
                        'Hesap gerekmez',
                        icon: Icons.sports_soccer_outlined,
                        color: p.text,
                        background: p.background.withValues(alpha: .4),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _card(
              context,
              BotGameCatalog.loto,
              featured: true,
              badge: 'SÜRELİ',
            ),
            const SizedBox(height: 16),
            PitchTileGrid(
              children: [
                _card(context, BotGameCatalog.teamRace, badge: 'DÜELLO'),
                BotModeCard(
                  title: 'Grid',
                  subtitle: 'Klasik, Tersten veya Rastgele Grid ile yarış.',
                  icon: Icons.grid_view_rounded,
                  tags: const ['3 oyun türü', 'Sıra tabanlı'],
                  badge: 'KLASİK',
                  fillHeight: true,
                  accentFooter: false,
                  onTap: () =>
                      _open(context, const VsBotGridModeSelectionPage()),
                ),
                _card(context, BotGameCatalog.cinko, badge: 'STRATEJİ'),
                _card(
                  context,
                  BotGameCatalog.five,
                  badge: 'KULÜP',
                  accentFooter: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
