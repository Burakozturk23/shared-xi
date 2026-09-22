import 'package:flutter/material.dart';

import '../app/game_catalog.dart';
import '../app/game_launcher.dart';
import '../online/online_friends_mode_page.dart';
import '../online/online_ranked_mode_page.dart';
import '../services/auth_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/pitch_tile.dart';
import '../widgets/pitch_ui.dart';
import 'friends_page.dart';
import 'leaderboard_page.dart';

class OnlineHubPage extends StatefulWidget {
  const OnlineHubPage({super.key});
  @override
  State<OnlineHubPage> createState() => _OnlineHubPageState();
}

class _OnlineHubPageState extends State<OnlineHubPage> {
  Future<void> _open(GameEntry game) async {
    await GameLauncher.open(context, game);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return ListView(
      key: const PageStorageKey('online'),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        Text(
          'Futbol bilgin sahaya çıksın.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: p.muted),
        ),
        const SizedBox(height: 24),
        PitchPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                child: Row(
                  children: [
                    const _OpponentMarker(label: 'SEN', description: 'Sen'),
                    Expanded(
                      child: Text(
                        'VS',
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(color: p.accent),
                      ),
                    ),
                    const _OpponentMarker(label: '?', description: 'Rakibin'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Rastgele eşleş',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Modunu seç, rakibini bul.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: p.muted),
              ),
              const SizedBox(height: 24),
              PitchAction(
                label: 'Mod seç',
                onPressed: () => _open(
                  const GameEntry(
                    title: 'Rastgele eşleş',
                    subtitle: '',
                    icon: Icons.public_rounded,
                    page: OnlineRankedModePage(),
                    requiresPersistentAccount: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PitchPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Arkadaşınla oyna',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Oda kur veya arkadaşına katıl.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: p.muted),
              ),
              const SizedBox(height: 24),
              PitchAction(
                label: 'Birlikte oyna',
                secondary: true,
                neutral: true,
                onPressed: () => _open(
                  const GameEntry(
                    title: 'Arkadaşlarınla oyna',
                    subtitle: '',
                    icon: Icons.groups_outlined,
                    page: OnlineFriendsModePage(),
                    requiresPersistentAccount: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PitchTileGrid(
          children: [
            PitchTile(
              title: 'Arkadaşlar',
              caption: 'Görüntüle',
              icon: Icons.people_outline_rounded,
              onTap: () => _open(
                const GameEntry(
                  title: 'Arkadaşlar',
                  subtitle: '',
                  icon: Icons.person_add_alt_1_outlined,
                  page: FriendsPage(),
                  requiresRepository: false,
                  requiresPersistentAccount: true,
                ),
              ),
            ),
            PitchTile(
              title: 'Liderlik Tablosu',
              caption: 'Görüntüle',
              icon: Icons.emoji_events_outlined,
              onTap: () => _open(
                const GameEntry(
                  title: 'Liderlik Tablosu',
                  subtitle: '',
                  icon: Icons.emoji_events_outlined,
                  page: LeaderboardPage(),
                  requiresRepository: false,
                  requiresAuth: true,
                ),
              ),
            ),
          ],
        ),
        if (!AuthService.hasPersistentAccount) ...[
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded, size: 18, color: p.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Online oyunlar için Google hesabını bağla.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _OpponentMarker extends StatelessWidget {
  const _OpponentMarker({required this.label, required this.description});
  final String label, description;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Semantics(
      label: description,
      child: ExcludeSemantics(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: p.raised,
            border: Border.all(color: p.border),
          ),
          alignment: Alignment.center,
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
      ),
    );
  }
}
