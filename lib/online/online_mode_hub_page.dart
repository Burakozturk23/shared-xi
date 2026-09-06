import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../screens/sign_in_page.dart';
import '../screens/player_profile_page.dart';
import '../screens/friends_page.dart';
import '../screens/leaderboard_page.dart';
import '../models/leaderboard_models.dart';
import '../widgets/user_avatar_badge.dart';
import 'online_friends_mode_page.dart';
import 'online_ranked_mode_page.dart';

/// Online ana menü: persistent Linkball hesabı + 2 yol + profil.
class OnlineModeHubPage extends StatefulWidget {
  const OnlineModeHubPage({super.key});

  @override
  State<OnlineModeHubPage> createState() => _OnlineModeHubPageState();
}

class _OnlineModeHubPageState extends State<OnlineModeHubPage> {
  Future<void> _connectGoogle() async {
    final signedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const LinkballSignInPage(allowSkip: false),
      ),
    );

    if (!mounted || signedIn != true) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.hasPersistentAccount) {
      return Scaffold(
        appBar: AppBar(title: const Text('Online')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_person_outlined, size: 50),
                      const SizedBox(height: 16),
                      const Text(
                        'Online için kalıcı hesap gerekli',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Online maçlar, kupa ve ilerideki arkadaş sistemi '
                        'Google hesabına bağlı Linkball profilinde tutulur.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).hintColor,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _connectGoogle,
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('Google ile Giriş Yap'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Online')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _ProfileCard(),
          const SizedBox(height: 14),
          _card(
            context,
            icon: Icons.people_alt_rounded,
            color: const Color(0xFF26C6DA),
            title: 'Arkadaşlar',
            subtitle: 'Ara · istekler · arkadaş listesi',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FriendsPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          _card(
            context,
            icon: Icons.emoji_events_rounded,
            color: const Color(0xFFFFB300),
            title: 'Liderlik Tablosu',
            subtitle: 'Bugün · Bu Hafta · Global Elo',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LeaderboardPage(
                    initialScope: LeaderboardScope.global,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          _card(
            context,
            icon: Icons.public,
            color: const Color(0xFFFFB300),
            title: 'Rastgele eşleş',
            subtitle: 'Mod seç · otomatik rakip · Elo sayılır',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OnlineRankedModePage()),
              );
            },
          ),
          const SizedBox(height: 14),
          _card(
            context,
            icon: Icons.group_outlined,
            color: const Color(0xFF26C6DA),
            title: 'Arkadaşlarınla oyna',
            subtitle: 'Mod seç · oda kodu · Elo sayılmaz',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OnlineFriendsModePage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Theme.of(context).hintColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: ProfileService.watchMyProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PlayerProfilePage(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  UserAvatarBadge(
                    avatarId: profile?.avatarId ?? 'starter_ball',
                    radius: 27,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.displayName ?? 'Profil yükleniyor…',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Elo ${profile?.elo ?? 1000} · '
                          '${profile?.played ?? 0} maç',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).hintColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (profile?.nicknameNeedsSetup == true) ...[
                          const SizedBox(height: 5),
                          const Text(
                            'Takma adını tamamla',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
