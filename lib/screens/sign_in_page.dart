import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../app/app_copy.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/social_ui.dart';

class LinkballSignInPage extends StatefulWidget {
  final bool allowSkip;

  const LinkballSignInPage({super.key, this.allowSkip = true});

  @override
  State<LinkballSignInPage> createState() => _LinkballSignInPageState();
}

class _LinkballSignInPageState extends State<LinkballSignInPage> {
  bool _busy = false;
  String? _error;
  String c(String tr, String en) => appCopy(context, tr, en);

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = await AuthService.signInWithGoogle();
      if (!mounted) return;
      if (result == null) {
        setState(() => _busy = false);
        return;
      }

      if (result.switchedToExistingGoogleAccount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              c('Mevcut Google hesabın açıldı. Bu cihazdaki geçici misafir hesabı otomatik olarak birleştirilmedi.',
                'Your existing Google account is now active. The guest account on this device was not automatically merged.'),
            ),
          ),
        );
      } else if (result.linkedAnonymousAccount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              c('Misafir hesabın Google hesabına bağlandı. Mevcut Linkball kimliğin korundu.',
                'Your guest account is now linked to Google. Your Linkball identity was preserved.'),
            ),
          ),
        );
      }

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = AuthService.isGoogleAccount;
    final colors = PitchColors.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(c('Linkball hesabı', 'Linkball account'))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                SocialHero(
                  icon: Icons.sports_soccer_rounded,
                  eyebrow: connected ? c('HESABIN BAĞLI', 'ACCOUNT CONNECTED') : c('LINKBALL PROFİLİN', 'YOUR LINKBALL PROFILE'),
                  title: connected ? c('Her zaman sahada.', 'Always in the game.') : c('Sahada iz bırak.', 'Leave your mark.'),
                  message: c('Senin profilin. Senin rekabetin.', 'Your profile. Your competition.'),
                ),
                const SizedBox(height: 24),
                Text(connected ? c('Hesabın hazır', 'Your account is ready') : c('Oyunun burada devam eder', 'Your game continues here'),
                  style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(connected
                  ? c('Online oyunlara ve kalıcı profiline bu hesapla erişebilirsin.', 'Access online games and your persistent profile with this account.')
                  : c('Google hesabını bağla; arkadaşlarınla oyna, profilini yanında taşı.', 'Connect Google to play with friends and take your profile with you.'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.muted)),
                const SizedBox(height: 20),
                PitchPanel(child: Column(children: [
                  _Benefit(icon: Icons.emoji_events_outlined,
                    title: c('Rekabette yerini al', 'Join the competition'),
                    detail: c('Kupaların ve sıralaman tek profilde.', 'Your trophies and ranking in one profile.')),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
                  _Benefit(icon: Icons.groups_2_outlined,
                    title: c('Arkadaşlarınla sahaya çık', 'Play with friends'),
                    detail: c('Arkadaş ekle, online oyunlara katıl.', 'Add friends and join online games.')),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
                  _Benefit(icon: Icons.cloud_done_outlined,
                    title: c('Profilin seninle gelsin', 'Take your profile with you'),
                    detail: c('Yeni cihazında hesabına yeniden eriş.', 'Access your account on your next device.')),
                ])),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Semantics(liveRegion: true, child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(16)),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                  )),
                  const SizedBox(height: 16),
                ],
                if (!connected) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.text,
                      foregroundColor: colors.background,
                      minimumSize: const Size.fromHeight(56),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    onPressed: _busy ? null : _signIn,
                    icon: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.login_rounded),
                    label: Text(_busy ? c('Bağlanıyor…', 'Connecting…') : c('Google ile devam et', 'Continue with Google'),
                      textAlign: TextAlign.center),
                  ),
                  if (widget.allowSkip) ...[
                    const SizedBox(height: 8),
                    TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false),
                      child: Text(c('Şimdilik atla', 'Skip for now'))),
                  ],
                ] else
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: Text(c('Devam et', 'Continue')),
                  ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, size: 20, color: colors.muted),
                    const SizedBox(width: 10),
                    Expanded(child: Text(c('Oyuncular seni takma adınla görür. Google e-posta adresin ve fotoğrafın paylaşılmaz.',
                      'Players see your nickname. Your Google email and photo are not shared with them.'),
                      style: Theme.of(context).textTheme.bodySmall)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.title, required this.detail});
  final IconData icon;
  final String title, detail;
  @override
  Widget build(BuildContext context) {
    final colors = PitchColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!(MediaQuery.sizeOf(context).width < 360 && MediaQuery.textScalerOf(context).scale(16) > 22)) ...[
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: colors.tint, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: colors.accent, size: 22),
        ),
        const SizedBox(width: 12),
        ],
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(detail, style: Theme.of(context).textTheme.bodySmall),
          ],
        )),
      ],
    );
  }
}
