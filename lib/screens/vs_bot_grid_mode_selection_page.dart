import 'package:flutter/material.dart';

import '../app/app_feedback.dart';
import '../app/bot_game_catalog.dart';
import '../app/route_appearance.dart';
import '../widgets/bot_mode_card.dart';
import 'bot_game_detail_page.dart';

class VsBotGridModeSelectionPage extends StatelessWidget {
  const VsBotGridModeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Grid')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Tahtayı sen çöz.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Oyuncuyu bul, kriteri çöz veya bağlantıyı kendin kur.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          for (final game in BotGameCatalog.gridVariants)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: BotModeCard(
                title: game.entry.title,
                subtitle: game.entry.subtitle,
                icon: game.entry.icon,
                tags: game.tags,
                onTap: () {
                  AppFeedback.selection();
                  Navigator.of(context).push(
                    LinkballRoute(
                      builder: (_) => BotGameDetailPage(game: game),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}
