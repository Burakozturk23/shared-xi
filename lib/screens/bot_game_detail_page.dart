import 'package:flutter/material.dart';

import '../app/bot_game_catalog.dart';
import '../app/game_launcher.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/pitch_ui.dart';

/// A controller, board and timer are created only after the play action.
class BotGameDetailPage extends StatefulWidget {
  const BotGameDetailPage({super.key, required this.game});
  final BotGameDefinition game;

  @override
  State<BotGameDetailPage> createState() => _BotGameDetailPageState();
}

class _BotGameDetailPageState extends State<BotGameDetailPage> {
  bool _launching = false;

  Future<void> _start() async {
    if (_launching) return;
    setState(() => _launching = true);
    try {
      await GameLauncher.open(context, widget.game.entry);
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final p = PitchColors.of(context);
    final type = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(game.entry.title)),
      body: SafeArea(
        bottom: false,
        child: ListView(
          key: PageStorageKey('bot-rules-' + game.entry.title),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: p.tint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(game.entry.icon, color: p.accent, size: 32),
              ),
            ),
            const SizedBox(height: 16),
            Text(game.goal, style: type.headlineSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in game.tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: p.raised,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(tag, style: type.labelSmall),
                  ),
              ],
            ),
            const PitchSectionTitle('Nasıl oynanır?'),
            for (var i = 0; i < game.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (i + 1).toString().padLeft(2, '0'),
                      style: type.titleSmall?.copyWith(color: p.accent),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(game.steps[i].$1, style: type.titleSmall),
                          const SizedBox(height: 4),
                          Text(
                            game.steps[i].$2,
                            style: type.bodyMedium?.copyWith(color: p.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            PitchPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Skor ve kazanma', style: type.titleSmall),
                  const SizedBox(height: 8),
                  Text(game.scoring, style: type.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: PitchAction(
          label: _launching ? 'Oyun hazırlanıyor…' : game.action,
          busy: _launching,
          onPressed: _launching ? null : _start,
        ),
      ),
    );
  }
}
