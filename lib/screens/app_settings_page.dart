import 'package:flutter/material.dart';

import '../app/app_preferences.dart';
import '../app/route_appearance.dart';
import '../widgets/pitch_ui.dart';
import 'onboarding_page.dart';
import 'privacy_account_page.dart';
import 'social_safety_center_page.dart';

class AppSettingsPage extends StatelessWidget {
  const AppSettingsPage({super.key});
  Future<void> _save(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tercihin kaydedilemedi. Tekrar dene.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = PreferencesScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Text(
            'Tam sana göre.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Görünümünü ve tercihlerini ayarla.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const PitchSectionTitle('Görünüm'),
          PitchPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  title: const Text('Tema'),
                  subtitle: Text(switch (prefs.themeMode) {
                    ThemeMode.system => 'Sistem',
                    ThemeMode.light => 'Açık',
                    ThemeMode.dark => 'Koyu',
                  }),
                  leading: const Icon(Icons.contrast_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (sheetContext) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (mode, label) in const [
                            (ThemeMode.system, 'Sistem'),
                            (ThemeMode.dark, 'Koyu'),
                            (ThemeMode.light, 'Açık'),
                          ])
                            ListTile(
                              title: Text(label),
                              selected: prefs.themeMode == mode,
                              trailing: prefs.themeMode == mode
                                  ? const Icon(Icons.check_rounded)
                                  : null,
                              onTap: () async {
                                Navigator.pop(sheetContext);
                                await _save(
                                  context,
                                  () => prefs.setTheme(mode),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                const ListTile(
                  leading: Icon(Icons.language_rounded),
                  title: Text('Dil'),
                  subtitle: Text('Türkçe'),
                ),
              ],
            ),
          ),
          const PitchSectionTitle('Oyun ve bildirimler'),
          PitchPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Oyun sesleri'),
                  value: prefs.sound,
                  onChanged: (v) => _save(context, () => prefs.setSound(v)),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  title: const Text('Titreşim'),
                  value: prefs.haptics,
                  onChanged: (v) => _save(context, () => prefs.setHaptics(v)),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: const Text('Bildirim tercihleri'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    LinkballRoute(
                      builder: (_) => const NotificationPreferencesPage(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const PitchSectionTitle('Hesap ve destek'),
          PitchPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  title: const Text('Gizlilik ve hesap'),
                  leading: const Icon(Icons.privacy_tip_outlined),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    LinkballRoute(
                      builder: (_) => const PrivacyAccountPage(),
                      modern: false,
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: const Text('Oyuncu güvenliği'),
                  leading: const Icon(Icons.shield_outlined),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    LinkballRoute(
                      builder: (_) => const SocialSafetyCenterPage(),
                      modern: false,
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: const Text('Oyunları tanı'),
                  leading: const Icon(Icons.sports_esports_outlined),
                  subtitle: const Text('Tanıtımı yeniden göster'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    LinkballRoute(
                      builder: (routeContext) => OnboardingPage(
                        onComplete: () => Navigator.pop(routeContext),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'LINKBALL\nFutbolun ortak noktası.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class NotificationPreferencesPage extends StatelessWidget {
  const NotificationPreferencesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final prefs = PreferencesScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirim tercihleri')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Sana uygun hatırlatmalar.',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            'Bildirim gönderimi henüz etkin değil. İstediğin kategorileri şimdiden seçebilirsin; bu seçimler cihaz izni vermez.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          PitchPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (key, title, subtitle) in const [
                  ('daily', 'Günün Maçları', 'Yeni günlük bulmacalar'),
                  (
                    'social',
                    'Arkadaşlar ve davetler',
                    'Arkadaş istekleri ve oyun davetleri',
                  ),
                  (
                    'rewards',
                    'Görevler ve ödüller',
                    'Yeni görev ve ödül haberleri',
                  ),
                ])
                  SwitchListTile(
                    title: Text(title),
                    subtitle: Text(subtitle),
                    value: prefs.notification(key),
                    onChanged: (value) async {
                      try {
                        await prefs.setNotification(key, value);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Tercihin kaydedilemedi. Tekrar dene.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
