import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class LinkballSignInPage extends StatefulWidget {
  final bool allowSkip;

  const LinkballSignInPage({
    super.key,
    this.allowSkip = true,
  });

  @override
  State<LinkballSignInPage> createState() => _LinkballSignInPageState();
}

class _LinkballSignInPageState extends State<LinkballSignInPage> {
  bool _busy = false;
  String? _error;

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
          const SnackBar(
            content: Text(
              'Mevcut Google hesabın açıldı. Bu cihazdaki geçici misafir '
              'hesabı otomatik olarak birleştirilmedi.',
            ),
          ),
        );
      } else if (result.linkedAnonymousAccount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Misafir hesabın Google hesabına bağlandı. Mevcut Linkball '
              'kimliğin korundu.',
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
    final alreadyGoogle = AuthService.isGoogleAccount;

    return Scaffold(
      appBar: AppBar(title: const Text('Linkball hesabı')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sports_soccer_rounded,
                size: 46,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              alreadyGoogle
                  ? 'Google hesabın bağlı'
                  : 'İlerlemeni koru, rekabete katıl',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              alreadyGoogle
                  ? 'Online ve kalıcı profil özellikleri bu hesapla kullanılabilir.'
                  : 'Google ile giriş yaptığında online sıralaman, kupaların, '
                      'arkadaşların ve ileride açacağın rozetler tek Linkball '
                      'profilinde korunur.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.hintColor,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 32),
            if (!alreadyGoogle) ...[
              const _Benefit(
                icon: Icons.emoji_events_outlined,
                text: 'Kupa topla ve liderlik tablolarına katıl',
              ),
              const _Benefit(
                icon: Icons.groups_2_outlined,
                text: 'Online oyna ve arkadaş sistemini kullan',
              ),
              const _Benefit(
                icon: Icons.cloud_done_outlined,
                text: 'Profilini cihaz değiştirince de koru',
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _signIn,
                  icon: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login_rounded),
                  label: Text(_busy ? 'Bağlanıyor…' : 'Google ile Giriş Yap'),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Diğer oyuncular Google e-posta adresini veya Google profil '
                'fotoğrafını görmez. Linkball içinde yalnız seçtiğin takma ad '
                'kullanılır.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.4, color: AppTheme.hintColor),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.dangerColor, fontSize: 13),
                ),
              ],
              if (widget.allowSkip) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context, false),
                  child: const Text('Şimdilik atla'),
                ),
              ],
            ] else ...[
              const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor, size: 52),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Devam et'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Benefit({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
