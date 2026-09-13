import 'package:flutter/material.dart';

import '../app/game_catalog.dart';
import '../app/game_launcher.dart';
import '../online/online_friends_mode_page.dart';
import '../online/online_ranked_mode_page.dart';
import '../services/auth_service.dart';
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
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('online'),
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
    children: [
      Text(
        'Bilgini sahaya taşı.',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 8),
      Text(
        'Bir rakiple eşleş veya arkadaşlarınla oyna.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 24),
      PitchRow(
        title: 'Rastgele eşleş',
        subtitle: 'Modunu seç, rakibini bul.',
        icon: Icons.public_rounded,
        highlight: true,
        onTap: () => _open(
          const GameEntry(
            title: 'Rastgele eşleş',
            subtitle: '',
            icon: Icons.public_rounded,
            page: OnlineRankedModePage(),
            requiresPersistentAccount: true,
          ),
        ),
      ),
      const SizedBox(height: 16),
      PitchRow(
        title: 'Arkadaşlarınla oyna',
        subtitle: 'Oda kur veya bir odaya katıl.',
        icon: Icons.groups_outlined,
        highlight: true,
        onTap: () => _open(
          const GameEntry(
            title: 'Arkadaşlarınla oyna',
            subtitle: '',
            icon: Icons.groups_outlined,
            page: OnlineFriendsModePage(),
            requiresPersistentAccount: true,
          ),
        ),
      ),
      const SizedBox(height: 24),
      PitchRow(
        title: 'Liderlik Tablosu',
        subtitle: 'Bugün · Bu hafta · Global Elo',
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
      const SizedBox(height: 16),
      PitchRow(
        title: 'Arkadaşlar',
        subtitle: 'Arkadaşlarını bul ve davet et.',
        icon: Icons.person_add_alt_1_outlined,
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
      if (!AuthService.hasPersistentAccount) ...[
        const SizedBox(height: 24),
        PitchPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline_rounded),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Online oynamak için Google hesabını bağlaman gerekir. İlerlemen hesabında korunur.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}
