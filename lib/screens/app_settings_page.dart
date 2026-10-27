import 'package:flutter/material.dart';
import '../app/app_copy.dart';
import '../app/app_preferences.dart';
import '../app/app_feedback.dart';
import '../app/route_appearance.dart';
import '../services/ads_consent_service.dart';
import '../theme/ortak_saha_theme.dart';
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(c('Tercihin kaydedilemedi. Tekrar dene.',
            'Could not save preference. Please retry.')),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _open(Widget page) =>
      Navigator.of(context).push(LinkballRoute(builder: (_) => page));

  String _themeName(ThemeMode mode) => switch (mode) {
    ThemeMode.system => c('Sistemle aynı', 'Use device theme'),
    ThemeMode.dark => c('Koyu', 'Dark'),
    ThemeMode.light => c('Açık', 'Light'),
  };
  String _strengthName(HapticStrength value) => switch (value) {
    HapticStrength.gentle => c('Hafif', 'Gentle'),
    HapticStrength.standard => c('Standart', 'Standard'),
    HapticStrength.strong => c('Güçlü', 'Strong'),
  };

  Future<void> _choose<T>({
    required String title,
    required String description,
    required T selected,
    required List<(T, String, String, IconData)> options,
    required Future<void> Function(T) save,
  }) async {
    final value = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * .8),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(sheet).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(description, style: Theme.of(sheet).textTheme.bodySmall),
                const SizedBox(height: 20),
                for (final option in options) ...[
                  Semantics(
                    selected: selected == option.$1,
                    child: _SettingRow(
                      icon: option.$4,
                      title: option.$2,
                      detail: option.$3,
                      trailing: Icon(selected == option.$1
                        ? Icons.check_circle_rounded : Icons.circle_outlined,
                        color: selected == option.$1 ? PitchColors.of(sheet).accent : PitchColors.of(sheet).muted),
                      onTap: () => Navigator.pop(sheet, option.$1),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (value != null && mounted && value != selected) await _save(() => save(value));
  }

  @override
  Widget build(BuildContext context) {
    final p = PreferencesScope.of(context);
    final colors = PitchColors.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(c('Ayarlar', 'Settings'))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                PitchPanel(child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_compactTextLayout(context)) ...[
                      _SettingsIcon(Icons.tune_rounded),
                      const SizedBox(width: 14),
                    ],
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c('Oyunu kendine göre ayarla', 'Make the game yours'),
                          style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(c('Tercihlerin bu cihazda otomatik kaydedilir.',
                          'Your preferences are saved automatically on this device.'),
                          style: Theme.of(context).textTheme.bodySmall),
                      ],
                    )),
                  ],
                )),
                PitchSectionTitle(c('Genel', 'General')),
                PitchPanel(padding: EdgeInsets.zero, child: Column(children: [
                  _SettingRow(
                    icon: Icons.contrast_rounded,
                    title: c('Tema', 'Theme'),
                    detail: _themeName(p.themeMode),
                    onTap: _saving ? null : () => _choose<ThemeMode>(
                      title: c('Görünümünü seç', 'Choose your appearance'),
                      description: c('Açık, koyu veya cihazının görünümü.', 'Light, dark or your device setting.'),
                      selected: p.themeMode,
                      options: [
                        (ThemeMode.system, _themeName(ThemeMode.system), c('Cihazınla birlikte değişir', 'Changes with your device'), Icons.brightness_auto_rounded),
                        (ThemeMode.dark, _themeName(ThemeMode.dark), c('Koyu zemin, canlı detaylar', 'Dark surfaces, vivid details'), Icons.dark_mode_outlined),
                        (ThemeMode.light, _themeName(ThemeMode.light), c('Aydınlık ve net', 'Bright and clear'), Icons.light_mode_outlined),
                      ],
                      save: p.setTheme,
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _SettingRow(
                    icon: Icons.language_rounded,
                    title: c('Menü dili', 'Menu language'),
                    detail: p.languageCode == 'tr' ? 'Türkçe' : 'English',
                    onTap: _saving ? null : () => _choose<String>(
                      title: c('Menü dilini seç', 'Choose your menu language'),
                      description: c('Ayarlar ve desteklenen menüler anında değişir. Bazı oyun ve görev metinleri Türkçe kalır.',
                        'Settings and supported menus change immediately. Some game and mission text remains in Turkish.'),
                      selected: p.languageCode,
                      options: const [
                        ('tr', 'Türkçe', 'Türkçe menüler', Icons.language_rounded),
                        ('en', 'English', 'English menus', Icons.language_rounded),
                      ],
                      save: p.setLanguage,
                    ),
                  ),
                ])),
                PitchSectionTitle(c('Ses ve titreşim', 'Sound & vibration')),
                PitchPanel(padding: EdgeInsets.zero, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SettingRow(
                      icon: p.sound ? Icons.volume_up_outlined : Icons.volume_off_outlined,
                      title: c('Oyun sesleri', 'Game sounds'),
                      detail: c('Cevap, ipucu, maç ve ödül efektleri', 'Answer, hint, match and reward effects'),
                      trailing: Semantics(
                        label: c('Oyun sesleri', 'Game sounds'),
                        child: Switch(
                        value: p.sound,
                        onChanged: _saving ? null : (v) => _save(() => p.setSound(v)),
                      )),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: OutlinedButton.icon(
                        style: const ButtonStyle(enableFeedback: false),
                        key: const ValueKey('preview-sound'),
                        onPressed: !_saving && p.sound ? () => AppFeedback.previewSound(p) : null,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(c('Sesi dene', 'Test sound'), textAlign: TextAlign.center),
                      ),
                    ),
                    _VolumeRow(key: const ValueKey('sfx-volume'), label: c('Efekt seviyesi', 'Effects volume'),
                      value: p.sfxVolume, enabled: !_saving && p.sound, onChanged: (v) => _save(() => p.setSfxVolume(v))),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _SettingRow(
                      icon: p.music ? Icons.music_note_outlined : Icons.music_off_outlined,
                      title: c('Müzik', 'Music'),
                      detail: c('Menü, hikâye ve oyun türüne göre arka plan müziği', 'Background music for menus, stories and game types'),
                      trailing: Semantics(
                        label: c('Müzik', 'Music'),
                        child: Switch(
                        key: const ValueKey('music-switch'),
                        value: p.music,
                        onChanged: _saving ? null : (v) => _save(() => p.setMusic(v)),
                      )),
                    ),
                    _VolumeRow(key: const ValueKey('music-volume'), label: c('Müzik seviyesi', 'Music volume'),
                      value: p.musicVolume, enabled: !_saving && p.music, onChanged: (v) => _save(() => p.setMusicVolume(v))),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _SettingRow(
                      icon: Icons.vibration_rounded,
                      title: c('Titreşim', 'Vibration'),
                      detail: c('Seçimlerde ve cevaplarda geri bildirim', 'Feedback for selections and answers'),
                      trailing: Semantics(
                        label: c('Titreşim', 'Vibration'),
                        child: Switch(
                        value: p.haptics,
                        onChanged: _saving ? null : (v) => _save(() => p.setHaptics(v)),
                      )),
                    ),
                    _SettingRow(
                      icon: Icons.tune_rounded,
                      title: c('Titreşim gücü', 'Vibration strength'),
                      detail: p.haptics ? _strengthName(p.hapticStrength) : c('Titreşimi açarak seçebilirsin', 'Enable vibration to choose'),
                      onTap: _saving || !p.haptics ? null : () => _choose<HapticStrength>(
                        title: c('Titreşim gücünü seç', 'Choose vibration strength'),
                        description: c('Hissettiğin güç cihazına göre değişebilir.', 'The intensity you feel depends on your device.'),
                        selected: p.hapticStrength,
                        options: [
                          (HapticStrength.gentle, _strengthName(HapticStrength.gentle), c('Kısa ve hafif dokunuş', 'A subtle tap'), Icons.touch_app_outlined),
                          (HapticStrength.standard, _strengthName(HapticStrength.standard), c('Seçime ve cevaba göre', 'Varies with selections and answers'), Icons.vibration_rounded),
                          (HapticStrength.strong, _strengthName(HapticStrength.strong), c('Daha belirgin geri bildirim', 'More pronounced feedback'), Icons.bolt_rounded),
                        ],
                        save: p.setHapticStrength,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: OutlinedButton.icon(
                        style: const ButtonStyle(enableFeedback: false),
                        key: const ValueKey('preview-haptics'),
                        onPressed: !_saving && p.haptics ? () => AppFeedback.previewHaptics(p) : null,
                        icon: const Icon(Icons.touch_app_outlined),
                        label: Text(c('Titreşimi dene', 'Test vibration'), textAlign: TextAlign.center),
                      ),
                    ),
                  ],
                )),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                  child: Text(c('Müzik ve efekt seviyeleri cihaz ses düzeyine göre çalar; iPhone sessiz modda oyun sesi çıkarmaz. Reklam sırasında ve uygulama arka plandayken müzik durur.',
                    'Music and effect levels follow your device volume; iPhone silent mode mutes game audio. Music pauses during ads and in the background.'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.muted)),
                ),
                PitchSectionTitle(c('Hesap ve destek', 'Account & support')),
                PitchPanel(padding: EdgeInsets.zero, child: Column(children: [
                  _SettingRow(icon: Icons.privacy_tip_outlined,
                    title: c('Gizlilik ve hesap', 'Privacy & account'),
                    onTap: () => _open(const PrivacyAccountPage())),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _SettingRow(icon: Icons.shield_outlined,
                    title: c('Oyuncu güvenliği', 'Player safety'),
                    onTap: () => _open(const SocialSafetyCenterPage())),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _SettingRow(icon: Icons.notifications_outlined,
                    title: c('Bildirim tercihleri', 'Notification preferences'),
                    onTap: () => _open(const NotificationPreferencesPage())),
                  ValueListenableBuilder<bool>(
                    valueListenable: AdsConsentService.privacyOptionsRequired,
                    builder: (_, required, _) => required
                      ? _SettingRow(icon: Icons.ad_units_outlined,
                        title: c('Reklam gizlilik tercihleri', 'Ad privacy options'),
                        onTap: _saving ? null : () => _save(AdsConsentService.showPrivacyOptions))
                      : const SizedBox.shrink(),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _SettingRow(icon: Icons.sports_esports_outlined,
                    title: c('Oyunları tanı', 'Discover the games'),
                    onTap: () => Navigator.of(context).push(LinkballRoute(
                      builder: (route) => OnboardingPage(onComplete: () => Navigator.pop(route)),
                    ))),
                ])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Give enlarged text room instead of splitting words beside decorative icons.
bool _compactTextLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 360 && MediaQuery.textScalerOf(context).scale(16) > 22;

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon(this.icon);
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final colors = PitchColors.of(context);
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: colors.tint, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, size: 22, color: colors.accent),
    );
  }
}

class _VolumeRow extends StatefulWidget {
  const _VolumeRow({super.key, required this.label, required this.value, required this.enabled, required this.onChanged});
  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;
  @override
  State<_VolumeRow> createState() => _VolumeRowState();
}

// Dragging stays local; only the released value is persisted.
class _VolumeRowState extends State<_VolumeRow> {
  double? _drag;
  @override
  Widget build(BuildContext context) {
    final value = _drag ?? widget.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${widget.label} · %${(value * 100).round()}', style: Theme.of(context).textTheme.bodyMedium),
        Slider(value: value, divisions: 20, label: '%${(value * 100).round()}', semanticFormatterCallback: (v) =>
            '${widget.label} %${(v * 100).round()}',
          onChanged: widget.enabled ? (v) => setState(() => _drag = v) : null,
          onChangeEnd: widget.enabled ? (v) { setState(() => _drag = null); widget.onChanged(v); } : null),
      ]),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.title, this.detail, this.trailing, this.onTap});
  final IconData icon;
  final String title;
  final String? detail;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    enableFeedback: false,
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (!_compactTextLayout(context)) ...[
            _SettingsIcon(icon),
            const SizedBox(width: 12),
          ],
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              if (detail != null) ...[
                const SizedBox(height: 4),
                Text(detail!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          )),
          const SizedBox(width: 8),
          trailing ?? Icon(Icons.chevron_right_rounded, color: PitchColors.of(context).muted),
        ],
      ),
    ),
  );
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
