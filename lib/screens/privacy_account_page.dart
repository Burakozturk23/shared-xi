import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/privacy_config.dart';
import '../services/account_deletion_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'sign_in_page.dart';

class PrivacyAccountPage extends StatefulWidget {
  const PrivacyAccountPage({super.key});

  @override
  State<PrivacyAccountPage> createState() => _PrivacyAccountPageState();
}

class _PrivacyAccountPageState extends State<PrivacyAccountPage> {
  final TextEditingController _deleteController = TextEditingController();

  User? _currentUser;
  bool _confirmingDeletion = false;
  bool _deleting = false;
  bool _deleted = false;
  String? _deleteError;

  @override
  void initState() {
    super.initState();
    _currentUser = AuthService.currentUser;
  }

  @override
  void dispose() {
    _deleteController.dispose();
    super.dispose();
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label kopyalandı.')));
  }

  void _startDeleteConfirmation() {
    if (_deleting || _currentUser == null) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _confirmingDeletion = true;
      _deleteError = null;
      _deleteController.clear();
    });
  }

  void _cancelDeleteConfirmation() {
    if (_deleting) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _confirmingDeletion = false;
      _deleteError = null;
      _deleteController.clear();
    });
  }

  bool get _deletePhraseMatches {
    var normalized = _deleteController.text.trim();
    normalized = normalized.replaceAll('İ', 'I').replaceAll('ı', 'i');
    return normalized.toLowerCase() == 'sil';
  }

  Future<void> _deleteAccountConfirmed() async {
    if (_deleting || _currentUser == null || !_deletePhraseMatches) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _deleting = true;
      _deleteError = null;
    });

    try {
      final result = await AccountDeletionService.deleteCurrentAccount();

      if (!mounted) return;

      setState(() {
        _deleting = false;
        _confirmingDeletion = false;
        _deleted = true;
        _currentUser = null;
        _deleteController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hesap silindi. '
            '${result.leaderboardEntriesRemoved} günlük skor kaldırıldı; '
            '${result.sharedRecordsScrubbed} paylaşılan kayıt '
            'kimliksizleştirildi.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _deleting = false;
        _deleteError = error.toString();
      });
    }
  }

  Widget _section(String title, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _copyRow({required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SelectableText(value, style: const TextStyle(fontSize: 13)),
        ),
        IconButton(
          tooltip: '$label kopyala',
          onPressed: () => _copy(label, value),
          icon: const Icon(Icons.copy_rounded, size: 20),
        ),
      ],
    );
  }

  Future<void> _openGoogleSignIn() async {
    final signedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const LinkballSignInPage(allowSkip: true),
      ),
    );

    if (!mounted || signedIn != true) return;
    setState(() {
      _currentUser = AuthService.currentUser;
      _deleteError = null;
    });
  }

  Widget _accountBody() {
    if (_deleted) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline_rounded),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hesap silme işlemi tamamlandı.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Çevrim içi bir özelliği yeniden kullandığında Linkball '
            'gerekiyorsa yeni anonim hesap oluşturur.',
          ),
        ],
      );
    }

    final user = _currentUser;
    if (user == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Şu anda aktif bir Linkball hesabı yok. Offline modları hesap '
            'olmadan kullanabilirsin. Kalıcı profil ve rekabetçi özellikler '
            'için Google hesabını bağlayabilirsin.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _openGoogleSignIn,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Google ile Giriş Yap'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user.displayName ?? 'Oyuncu',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          AuthService.isGoogleAccount
              ? 'Google hesabı bağlı · kalıcı profil'
              : 'Misafir hesap · cihazla sınırlı',
          style: TextStyle(
            fontSize: 12,
            color: AuthService.isGoogleAccount
                ? AppTheme.primaryColor
                : AppTheme.hintColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (!AuthService.isGoogleAccount) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _deleting ? null : _openGoogleSignIn,
            icon: const Icon(Icons.link_rounded),
            label: const Text('Google hesabına bağla'),
          ),
        ],
        const SizedBox(height: 8),
        const Text('Hesap kimliği', style: TextStyle(fontSize: 12)),
        _copyRow(label: 'Hesap kimliği', value: user.uid),
        const SizedBox(height: 12),
        if (!_confirmingDeletion)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _deleting ? null : _startDeleteConfirmation,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.dangerColor,
              ),
              icon: const Icon(Icons.delete_forever_rounded),
              label: const Text('Hesabımı ve verilerimi sil'),
            ),
          )
        else
          _inlineDeleteConfirmation(),
      ],
    );
  }

  Widget _inlineDeleteConfirmation() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.dangerColor.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bu işlem kalıcıdır.',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Profilin, istatistiklerin, günlük skorların ve hesabın '
            'silinir. Paylaşılan maç kayıtlarında hesabına bağlı '
            'kimlik alanları anonimleştirilir.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Devam etmek için SİL yaz:',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _deleteController,
            enabled: !_deleting,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) {
              if (mounted) {
                setState(() {});
              }
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'SİL',
            ),
          ),
          if (_deleteError != null) ...[
            const SizedBox(height: 10),
            Text(
              'Hesap silinemedi: $_deleteError',
              style: const TextStyle(color: AppTheme.dangerColor, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _deleting ? null : _cancelDeleteConfirmation,
                  child: const Text('Vazgeç'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _deleting || !_deletePhraseMatches
                      ? null
                      : _deleteAccountConfirmed,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.dangerColor,
                  ),
                  child: _deleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Kalıcı olarak sil'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gizlilik & Hesap')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _section('Linkball hesabı', _accountBody()),
          _section(
            'Topladığımız veriler',
            const Text(
              'Linkball çevrim içi özellikler için anonim Firebase kullanıcı '
              'kimliği, görünen ad, oyun sonuçları, Elo/istatistikler, günlük '
              'skorlar ve çevrim içi maç/oda verileri işler. Firebase '
              'Authentication ve Realtime Database; güvenlik ve hizmet '
              'işletimi için IP adresi, user-agent ve Firebase uygulama '
              'tanımlayıcıları gibi teknik bilgileri işleyebilir. Analytics; '
              'uygulama etkileşimleri, app-instance/device tanımlayıcıları ve '
              'yaklaşık konum gibi ölçüm bilgilerini işleyebilir. '
              'Crashlytics/Sessions ise crash, ANR, uygulama/cihaz durumu ve '
              'tanılama bilgilerini işleyebilir. App Check / Play Integrity '
              'bütünlük ve kötüye kullanımı önleme sinyalleri kullanır. '
              'Ayrıntılar yayımlanan gizlilik politikasındadır.',
            ),
          ),
          _section(
            'Verileri nasıl kullanıyoruz?',
            const Text(
              'Veriler; oyunu çalıştırmak, eşleştirme ve skor tablolarını '
              'sunmak, hata/performans sorunlarını teşhis etmek, hizmet '
              'kalitesini ölçmek ve kötüye kullanımı azaltmak amacıyla '
              'kullanılır. Linkball kişisel verileri satmaz. Çevrim içi '
              'oyunlarda görünen adın ve oyun skorların diğer oyunculara '
              'veya skor tablolarına gösterilebilir.',
            ),
          ),
          _section(
            'Saklama ve silme',
            const Text(
              'Hesap silme isteği tamamlandığında Firebase Authentication '
              'hesabı, Linkball profil/istatistikleri, günlük skor ve oturum '
              'verileri ile eşleştirme kuyruk verileri silinir. Diğer '
              'oyuncularla paylaşılan maç kayıtlarındaki kullanıcı kimliği '
              've görünen ad gibi tanımlayıcı alanlar anonimleştirilir. '
              'Kimliği kaldırılmış toplu ölçümler ile Firebase tanılama '
              'verileri, ilgili hizmetlerin saklama süreleri kapsamında '
              'bir süre daha tutulabilir.',
            ),
          ),
          _section(
            'Gizlilik politikası',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Play Store için yayımlanan güncel politika:'),
                const SizedBox(height: 6),
                _copyRow(
                  label: 'Gizlilik politikası bağlantısı',
                  value: PrivacyConfig.privacyPolicyUrl,
                ),
              ],
            ),
          ),
          _section(
            'Uygulama dışından hesap silme talebi',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Uygulamaya erişemiyorsan aşağıdaki web kaynağından '
                  'hesap/veri silme talebi başlatabilirsin:',
                ),
                const SizedBox(height: 6),
                _copyRow(
                  label: 'Hesap silme bağlantısı',
                  value: PrivacyConfig.accountDeletionUrl,
                ),
              ],
            ),
          ),
          _section(
            'İletişim',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gizlilik ve veri talepleri:'),
                const SizedBox(height: 6),
                _copyRow(
                  label: 'İletişim e-postası',
                  value: PrivacyConfig.contactEmail,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
