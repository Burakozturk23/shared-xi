import 'package:flutter/material.dart';

import '../app/route_appearance.dart';
import '../services/auth_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/pitch_ui.dart';
import 'player_profile_page.dart';
import 'sign_in_page.dart';
import 'store_page.dart';
import 'community_center_page.dart';
import 'progression_center_page.dart';
import 'app_settings_page.dart';

class ProfileHubPage extends StatefulWidget {
  const ProfileHubPage({super.key});
  @override
  State<ProfileHubPage> createState() => _ProfileHubPageState();
}

class _ProfileHubPageState extends State<ProfileHubPage> {
  Future<void> _open(Widget page, {bool modern = false}) async {
    await Navigator.of(
      context,
    ).push(LinkballRoute(builder: (_) => page, modern: modern));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService.hasPersistentAccount) {
      return const PlayerProfilePage(embedded: true);
    }
    final p = PitchColors.of(context);
    return ListView(
      key: const PageStorageKey('profile'),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Text(
          'Futbol yolculuğun.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 24),
        PitchPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: p.tint,
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: p.accent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Konuk oyuncu',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Oyuna hemen katıl.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Google hesabını bağla; arkadaşlarınla oyna, profilini ve başarılarını yanında taşı.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              PitchAction(
                label: 'Google hesabını bağla',
                icon: Icons.login_rounded,
                onPressed: () =>
                    _open(const LinkballSignInPage(allowSkip: false)),
              ),
            ],
          ),
        ),
        const PitchSectionTitle('Oyuncu alanın'),
        PitchRow(
          title: 'Profilim ve istatistikler',
          subtitle: 'Başarıların, avatarların ve maç geçmişin',
          icon: Icons.bar_chart_rounded,
          onTap: () => _open(const PlayerProfilePage(), modern: true),
        ),
        const SizedBox(height: 16),
        PitchRow(
          title: 'Görevler ve ödüller',
          icon: Icons.task_alt_rounded,
          onTap: () => _open(const ProgressionCenterPage()),
        ),
        const SizedBox(height: 16),
        PitchRow(
          title: 'Mağaza',
          icon: Icons.storefront_outlined,
          onTap: () => _open(const StorePage()),
        ),
        const SizedBox(height: 16),
        PitchRow(
          title: 'Topluluk',
          icon: Icons.forum_outlined,
          onTap: () => _open(const CommunityCenterPage()),
        ),
        const SizedBox(height: 16),
        PitchRow(
          title: 'Ayarlar',
          icon: Icons.settings_outlined,
          onTap: () => _open(const AppSettingsPage(), modern: true),
        ),
      ],
    );
  }
}
