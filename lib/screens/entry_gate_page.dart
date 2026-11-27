import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_copy.dart';
import '../app/app_preferences.dart';
import '../config/privacy_config.dart';
import '../services/auth_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/brand_mark.dart';

/// First-run entry after the onboarding slides: Google or guest. Guests are
/// never pushed; the online features ask for an account when they need one.
class EntryGatePage extends StatefulWidget {
  const EntryGatePage({
    super.key,
    required this.onDone,
    this.signIn = AuthService.signInWithGoogle,
  });
  final VoidCallback onDone;
  final Future<LinkballGoogleSignInResult?> Function() signIn;
  @override
  State<EntryGatePage> createState() => _EntryGatePageState();
}

class _EntryGatePageState extends State<EntryGatePage> {
  bool _busy = false;
  String? _error;
  String c(String tr, String en) => appCopy(context, tr, en);

  Future<void> _finish() async {
    try {
      await PreferencesScope.maybeOf(context)?.finishEntryGate();
    } catch (_) {
      // The gate is a first-run convenience; a storage error must not trap the player.
    }
    if (mounted) widget.onDone();
  }

  Future<void> _google() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.signIn();
      if (!mounted) return;
      if (result == null) {
        setState(() => _busy = false);
        return;
      }
      if (result.switchedToExistingGoogleAccount) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              c(
                'Mevcut Linkball hesabın açıldı. Bu cihazda misafir olarak oynadıkların ona eklenmedi.',
                'Your existing Linkball account is open. Guest play on this device was not added to it.',
              ),
            ),
          ),
        );
      }
      await _finish();
      if (mounted) setState(() => _busy = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = c(
          'Google ile giriş tamamlanamadı. Bağlantını kontrol edip tekrar dene ya da misafir olarak devam et.',
          'Google sign-in did not finish. Check your connection and retry, or continue as a guest.',
        );
      });
    }
  }

  Future<void> _privacy() => showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(c('Gizlilik Politikası', 'Privacy Policy')),
      content: SelectableText(PrivacyConfig.privacyPolicyUrl),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(
              const ClipboardData(text: PrivacyConfig.privacyPolicyUrl),
            );
            if (dialog.mounted) Navigator.pop(dialog);
          },
          child: Text(c('Bağlantıyı kopyala', 'Copy link')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: Text(c('Kapat', 'Close')),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.tint, p.background],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                children: [
                  const Center(child: BrandMark(size: 88)),
                  const SizedBox(height: 20),
                  Text(
                    c('Sahada iz bırak.', 'Leave your mark.'),
                    textAlign: TextAlign.center,
                    style: text.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c(
                      'Futbol bilgini onlarca modda sına. İstersen hemen başla, istersen profilini şimdi kur.',
                      'Test your football knowledge across dozens of modes. Start now, or set up your profile first.',
                    ),
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: p.muted),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Perk(
                        Icons.sports_esports_rounded,
                        c('Online düellolar', 'Online duels'),
                      ),
                      _Perk(
                        Icons.military_tech_rounded,
                        c('Rozet ve görevler', 'Badges and missions'),
                      ),
                      _Perk(
                        Icons.cloud_done_rounded,
                        c('Profilin her cihazda', 'Your profile anywhere'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  if (_error != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: p.error.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(_error!, style: TextStyle(color: p.error)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  FilledButton.icon(
                    key: const ValueKey('entry-google'),
                    style: FilledButton.styleFrom(
                      backgroundColor: p.text,
                      foregroundColor: p.background,
                      minimumSize: const Size.fromHeight(56),
                    ),
                    onPressed: _busy ? null : _google,
                    icon: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login_rounded),
                    label: Text(
                      _busy
                          ? c('Bağlanıyor…', 'Connecting…')
                          : c('Google ile devam et', 'Continue with Google'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('entry-guest'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    onPressed: _busy ? null : _finish,
                    icon: const Icon(Icons.person_outline_rounded),
                    label: Text(c('Misafir olarak oyna', 'Play as a guest')),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    c(
                      'Misafir ilerlemen bu cihazda kalır. Online düellolar, arkadaşlar ve ödüllü görevler için hesabını istediğin zaman bağlarsın.',
                      'Guest progress stays on this device. Link your account any time for online duels, friends and rewarded missions.',
                    ),
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(color: p.muted),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, size: 18, color: p.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          c(
                            'Oyuncular seni takma adınla görür; Google e-posta adresin ve fotoğrafın paylaşılmaz.',
                            'Players see your nickname; your Google email and photo are not shared.',
                          ),
                          style: text.bodySmall?.copyWith(color: p.muted),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    child: TextButton(
                      onPressed: _privacy,
                      child: Text(c('Gizlilik Politikası', 'Privacy Policy')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: p.accent),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
