import 'package:flutter/material.dart';

import '../app/app_feedback.dart';
import '../app/bot_game_catalog.dart';
import '../app/route_appearance.dart';
import '../widgets/bot_mode_card.dart';
import 'bot_game_detail_page.dart';
import 'vs_bot_grid_mode_selection_page.dart';

class VsBotModeSelectionPage extends StatelessWidget {
  const VsBotModeSelectionPage({super.key});

  void _open(BuildContext context, Widget page) {
    AppFeedback.selection();
    Navigator.of(context).push(LinkballRoute(builder: (_) => page));
  }

  Widget _card(BuildContext context, BotGameDefinition game) => BotModeCard(
    title: game.entry.title,
    subtitle: game.entry.subtitle,
    icon: game.entry.icon,
    tags: game.tags,
    onTap: () => _open(context, BotGameDetailPage(game: game)),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Botla oyna')),
    body: SafeArea(
      child: ListView(
        key: const PageStorageKey('bot-games'),
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Rakibin hazır.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Bir oyun seç, kurallara göz at ve sahaya çık.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          _card(context, BotGameCatalog.loto),
          const SizedBox(height: 16),
          _card(context, BotGameCatalog.teamRace),
          const SizedBox(height: 16),
          BotModeCard(
            title: 'Grid',
            subtitle: 'Klasik, Tersten veya Rastgele Grid ile yarış.',
            icon: Icons.grid_view_rounded,
            tags: const ['3 oyun türü', 'Sıra tabanlı'],
            onTap: () => _open(
              context,
              const VsBotGridModeSelectionPage(),
            ),
          ),
          const SizedBox(height: 16),
          _card(context, BotGameCatalog.cinko),
          const SizedBox(height: 16),
          _card(context, BotGameCatalog.five),
        ],
      ),
    ),
  );
}
