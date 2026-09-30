import 'package:flutter/material.dart';
import '../app/app_copy.dart';
import '../app/app_preferences.dart';
import '../app/app_feedback.dart';
import '../app/route_appearance.dart';
import '../services/ads_consent_service.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/social_ui.dart';
import 'privacy_account_page.dart';
import 'social_safety_center_page.dart';
import 'onboarding_page.dart';

class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});
  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  bool _saving = false;
  String c(String tr, String en) => appCopy(context, tr, en);
  Future<void> _save(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              c(
                'Tercihin kaydedilemedi. Tekrar dene.',
                'Could not save preference. Please retry.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _open(Widget page) =>
      Navigator.of(context).push(LinkballRoute(builder: (_) => page));
  @override
  Widget build(BuildContext context) {
    final p = PreferencesScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(c('Ayarlar', 'Settings'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            SocialHero(
              icon: Icons.tune_rounded,
              eyebrow: c('SENİN OYUNUN', 'YOUR GAME'),
              title: c('Tam sana göre.', 'Make it yours.'),
              message: c(
                'Görünüm, dil ve oyun geri bildirimleri bu cihazda saklanır.',
                'Appearance, language and game feedback are saved on this device.',
              ),
            ),
            const SizedBox(height: 20),
            PitchSectionTitle(c('Görünüm ve dil', 'Appearance & language')),
            PitchPanel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.contrast_rounded),
                    title: Text(c('Tema', 'Theme')),
                    subtitle: Text(switch (p.themeMode) {
                      ThemeMode.system => c('Sistem', 'System'),
                      ThemeMode.dark => c('Koyu', 'Dark'),
                      ThemeMode.light => c('Açık', 'Light'),
                    }),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _saving
                        ? null
                        : () => showModalBottomSheet<void>(
                            context: context,
                            showDragHandle: true,
                            builder: (sheet) => SafeArea(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final mode in ThemeMode.values)
                                      ListTile(
                                        title: Text(switch (mode) {
                                          ThemeMode.system => c(
                                            'Sistem',
                                            'System',
                                          ),
                                          ThemeMode.dark => c('Koyu', 'Dark'),
                                          ThemeMode.light => c('Açık', 'Light'),
                                        }),
                                        trailing: p.themeMode == mode
                                            ? const Icon(Icons.check)
                                            : null,
                                        onTap: () {
                                          Navigator.pop(sheet);
                                          _save(() => p.setTheme(mode));
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.language_rounded),
                    title: Text(c('Menü dili', 'Menu language')),
                    subtitle: Text(
                      p.languageCode == 'tr' ? 'Türkçe' : 'English',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _saving
                        ? null
                        : () => showModalBottomSheet<void>(
                            context: context,
                            showDragHandle: true,
                            builder: (sheet) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final entry in const [
                                    ('tr', 'Türkçe'),
                                    ('en', 'English'),
                                  ])
                                    ListTile(
                                      title: Text(entry.$2),
                                      trailing: p.languageCode == entry.$1
                                          ? const Icon(Icons.check)
                                          : null,
                                      onTap: () {
                                        Navigator.pop(sheet);
                                        _save(() => p.setLanguage(entry.$1));
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      c(
                        'Bu paket: ayarlar, görev/rozet menüleri ve ana gezinme. Diğer ekranlar ve oyun/görev içerikleri özgün dilinde kalır.',
                        'This release: settings, mission/badge menus and main navigation. Other screens and game/mission content retain their original language.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            PitchSectionTitle(c('Oyun hissi', 'Game feedback')),
            PitchPanel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.volume_up_outlined),
                    title: Text(c('Oyun sesleri', 'Game sounds')),
                    subtitle: Text(
                      c(
                        'Doğru cevap ve ödüllerde kısa sistem sesi',
                        'Short system sound for correct answers and rewards',
                      ),
                    ),
                    value: p.sound,
                    onChanged: _saving
                        ? null
                        : (v) => _save(() => p.setSound(v)),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.vibration_rounded),
                    title: Text(c('Titreşim', 'Vibration')),
                    subtitle: Text(
                      c(
                        'Seçimlerde ve cevaplarda dokunsal geri bildirim',
                        'Haptic feedback for selections and answers',
                      ),
                    ),
                    value: p.haptics,
                    onChanged: _saving
                        ? null
                        : (v) => _save(() => p.setHaptics(v)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: p.sound || p.haptics
                              ? () => AppFeedback.answer(correct: true)
                              : null,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(c('Geri bildirimi dene', 'Try feedback')),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          c(
                            'Ses ve titreşim cihaz desteğine, sessiz moda ve sistem ayarlarına bağlıdır.',
                            'Sound and vibration depend on device support, silent mode and system settings.',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            PitchSectionTitle(c('Hesap ve destek', 'Account & support')),
            PitchPanel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: Text(c('Gizlilik ve hesap', 'Privacy & account')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(const PrivacyAccountPage()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(c('Oyuncu güvenliği', 'Player safety')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(const SocialSafetyCenterPage()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: Text(
                      c('Bildirim tercihleri', 'Notification preferences'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(const NotificationPreferencesPage()),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: AdsConsentService.privacyOptionsRequired,
                    builder: (_, required, _) => required
                        ? ListTile(
                            leading: const Icon(Icons.ad_units_outlined),
                            title: Text(
                              c(
                                'Reklam gizlilik tercihleri',
                                'Ad privacy options',
                              ),
                            ),
                            onTap: _saving
                                ? null
                                : () => _save(
                                    AdsConsentService.showPrivacyOptions,
                                  ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  ListTile(
                    leading: const Icon(Icons.sports_esports_outlined),
                    title: Text(c('Oyunları tanı', 'Discover the games')),
                    onTap: () => Navigator.of(context).push(
                      LinkballRoute(
                        builder: (route) => OnboardingPage(
                          onComplete: () => Navigator.pop(route),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationPreferencesPage extends StatelessWidget {
  const NotificationPreferencesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final p = PreferencesScope.of(context);
    String c(String tr, String en) => appCopy(context, tr, en);
    return Scaffold(
      appBar: AppBar(
        title: Text(c('Bildirim tercihleri', 'Notification preferences')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SocialNotice(
              title: c('Kontrol sende', 'You are in control'),
              message: c(
                'Bildirim gönderimi henüz etkin değil. Bu seçimler yalnızca bu cihazda saklanır ve bildirim izni vermez.',
                'Notifications are not enabled yet. These choices are saved on this device and do not grant notification permission.',
              ),
            ),
            const SizedBox(height: 16),
            for (final row in [
              ('daily', c('Günün maçları', 'Daily games')),
              ('social', c('Arkadaşlar ve davetler', 'Friends & invitations')),
              ('rewards', c('Görevler ve ödüller', 'Missions & rewards')),
            ])
              SwitchListTile(
                title: Text(row.$2),
                value: p.notification(row.$1),
                onChanged: (v) async {
                  try {
                    await p.setNotification(row.$1, v);
                  } catch (_) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            c(
                              'Tercih kaydedilemedi.',
                              'Could not save preference.',
                            ),
                          ),
                        ),
                      );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
