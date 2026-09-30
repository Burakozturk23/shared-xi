import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LinkballSignInPage extends StatefulWidget {
  final bool allowSkip;

  const LinkballSignInPage({super.key, this.allowSkip = true});

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
    final connected = AuthService.isGoogleAccount;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Linkball hesabı')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _AccountHero(connected: connected),
                const SizedBox(height: 24),
                Text(
                  connected ? 'Hesabın hazır' : 'Oyunun burada devam eder',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  connected
                      ? 'Online oyunlara ve kalıcı profiline bu hesapla erişebilirsin.'
                      : 'Google hesabını bağla; rekabete katıl, arkadaşlarınla buluş ve profilini yanında taşı.',
                  style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
                ),
                const SizedBox(height: 20),
                const _Benefit(
                  icon: Icons.emoji_events_outlined,
                  title: 'Rekabette yerini al',
                  detail: 'Kupaların ve liderlik sıralaman tek profilde.',
                ),
                const _Benefit(
                  icon: Icons.groups_2_outlined,
                  title: 'Arkadaşlarınla sahaya çık',
                  detail: 'Arkadaş ekle, online oyunlara katıl.',
                ),
                const _Benefit(
                  icon: Icons.cloud_done_outlined,
                  title: 'Profilin seninle gelsin',
                  detail: 'Cihaz değiştirsen de hesabına yeniden eriş.',
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ),
                  ),
                if (!connected) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.onSurface,
                      foregroundColor: colors.surface,
                      minimumSize: const Size.fromHeight(56),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _busy ? null : _signIn,
                    icon: _busy
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onSurfaceVariant,
                            ),
                          )
                        : const Icon(Icons.login_rounded, size: 22),
                    label: Text(
                      _busy ? 'Bağlanıyor…' : 'Google ile devam et',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (widget.allowSkip)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.pop(context, false),
                        child: const Text('Şimdilik atla'),
                      ),
                    ),
                ] else
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Devam et'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Sahada takma adınla görünürsün. Google e-posta adresin ve profil fotoğrafın diğer oyuncularla paylaşılmaz.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountHero extends StatelessWidget {
  const _AccountHero({required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF123C36), Color(0xFF0B242A)],
        ),
        border: Border.all(color: const Color(0xFF28564F)),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: ExcludeSemantics(
              child: CustomPaint(painter: _PitchPainter()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.sports_soccer_rounded,
                      color: Color(0xFF53E8BE),
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        connected ? 'HESABIN BAĞLI' : 'SENİN LINKBALL PROFİLİN',
                        style: const TextStyle(
                          color: Color(0xFF91E6D0),
                          fontSize: 11,
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  connected
                      ? 'Tek hesap.\nHer zaman sahada.'
                      : 'Sahada iz bırak.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Senin profilin. Senin rekabetin.',
                  style: TextStyle(
                    color: Color(0xFFC1D8D2),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  const _PitchPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF83DBBF).withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Rect.fromLTWH(
      size.width * .65,
      -24,
      size.width * .55,
      size.height + 48,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, size.height / 2),
      Offset(rect.right, size.height / 2),
      paint,
    );
    canvas.drawCircle(Offset(rect.center.dx, size.height / 2), 42, paint);
  }

  @override
  bool shouldRepaint(covariant _PitchPainter oldDelegate) => false;
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  const _Benefit({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: colors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
