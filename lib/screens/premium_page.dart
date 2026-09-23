import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/premium_billing_models.dart';
import '../models/premium_models.dart';
import '../services/premium_billing_service.dart';
import 'sign_in_page.dart';
import '../services/experience/pro_gateway.dart';
import '../app/route_appearance.dart';
import '../widgets/social_ui.dart';
import '../widgets/pitch_ui.dart';

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key, this.gateway = const ProGateway()});
  final ProGateway gateway;

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  Future<PremiumEntitlement>? _entitlementFuture;
  Future<PremiumBillingCatalog>? _catalogFuture;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  final Set<String> _verifyingPurchaseKeys = <String>{};

  PremiumPlan? _launchingPlan;
  bool _restoring = false;
  bool _pending = false;
  bool _reloading = false;
  bool _cancellationLogged = false;
  String? _purchaseStateMessage;

  @override
  void initState() {
    super.initState();
    widget.gateway.record('view');

    if (widget.gateway.connected) {
      _startPersistentSession();
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  Future<PremiumEntitlement> _loadEntitlement() async {
    final entitlement = await widget.gateway.status();
    if (entitlement.cancellationPending && !_cancellationLogged) {
      _cancellationLogged = true;
      widget.gateway.record('cancel', productId: entitlement.productId);
    }
    return entitlement;
  }

  void _startPersistentSession() {
    _entitlementFuture = _loadEntitlement();
    _catalogFuture = widget.gateway.catalog().catchError(
      (Object _) => const PremiumBillingCatalog.unavailable(),
    );

    _purchaseSubscription?.cancel();
    _purchaseSubscription = widget.gateway.purchases.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _pending = false;
          _purchaseStateMessage =
              'Google Play satın alma akışı şu anda kullanılamıyor.';
        });
      },
    );
  }

  Future<void> _reload() async {
    if (!widget.gateway.connected || _reloading) return;
    setState(() {
      _reloading = true;
    });
    final entitlement = _loadEntitlement();
    final catalog = widget.gateway.catalog().catchError(
      (Object _) => const PremiumBillingCatalog.unavailable(),
    );
    setState(() {
      _entitlementFuture = entitlement;
      _catalogFuture = catalog;
    });
    try {
      await Future.wait<Object>([entitlement, catalog]);
    } catch (_) {
      /* FutureBuilders display recoverable errors. */
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
  }

  Future<void> _connectGoogle() async {
    final signedIn = await Navigator.push<bool>(
      context,
      LinkballRoute(
        modern: false,
        builder: (_) => const LinkballSignInPage(allowSkip: false),
      ),
    );

    if (!mounted || signedIn != true || !widget.gateway.connected) {
      return;
    }

    try {
      await widget.gateway.prepareProfile();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil hazırlanamadı. Yeniden dene.')),
        );
      return;
    }

    if (!mounted) return;

    setState(() {
      _purchaseStateMessage = null;
    });

    _startPersistentSession();
    setState(() {});
  }

  Future<void> _buy(PremiumBillingProduct product) async {
    if (_launchingPlan != null || _pending || _restoring || _reloading) return;

    setState(() {
      _launchingPlan = product.plan;
      _pending = true;
      _purchaseStateMessage = null;
    });

    try {
      widget.gateway.record('start', productId: product.productId);
      final launched = await widget.gateway.buy(product.plan);

      if (!mounted) return;

      setState(() {
        if (!launched) _pending = false;
        _purchaseStateMessage = launched
            ? 'Google Play satın alma ekranı açıldı. Onay bekleniyor.'
            : 'Google Play satın alma ekranı açılamadı.';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _pending = false;
        _purchaseStateMessage = _friendlyBillingError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _launchingPlan = null;
        });
      }
    }
  }

  Future<void> _restore() async {
    if (_restoring || _launchingPlan != null) return;

    setState(() {
      _restoring = true;
      _purchaseStateMessage =
          'Google Play satın alma geçmişi kontrol ediliyor...';
    });

    try {
      await widget.gateway.restore();

      if (!mounted) return;

      setState(() {
        _purchaseStateMessage =
            'Geri yükleme isteği gönderildi. Doğrulama sonuçları bekleniyor.';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _pending = false;
        _purchaseStateMessage = _friendlyBillingError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _restoring = false);
      }
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!PremiumBillingProductIds.all.contains(purchase.productID)) continue;
      if (!mounted) return;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          setState(() {
            _pending = true;
            _purchaseStateMessage =
                'Google Play satın alma onayı bekleniyor...';
          });
          break;

        case PurchaseStatus.error:
          setState(() {
            _pending = false;
            _purchaseStateMessage =
                'Satın alma tamamlanamadı. Tekrar deneyebilir veya satın almalarını geri yükleyebilirsin.';
          });
          break;

        case PurchaseStatus.canceled:
          setState(() {
            _pending = false;
            _purchaseStateMessage = 'Satın alma iptal edildi.';
          });
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyPurchase(purchase);
          break;
      }
    }
  }

  Future<void> _verifyPurchase(PurchaseDetails purchase) async {
    final key =
        '${purchase.productID}:${purchase.purchaseID ?? ''}:'
        '${purchase.transactionDate ?? ''}';

    if (_verifyingPurchaseKeys.contains(key)) return;
    _verifyingPurchaseKeys.add(key);
    _pending = true;

    if (mounted) {
      setState(() {
        _purchaseStateMessage =
            'Satın alma Linkball sunucusunda doğrulanıyor...';
      });
    }

    try {
      final entitlement = await widget.gateway.verify(purchase);
      widget.gateway.record(
        'complete',
        productId: purchase.productID,
        restored: purchase.status == PurchaseStatus.restored,
      );

      if (!mounted) return;

      setState(() {
        _entitlementFuture = Future<PremiumEntitlement>.value(entitlement);
        _purchaseStateMessage =
            'Linkball Pro doğrulandı ve hesabına tanımlandı.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Linkball Pro etkinleştirildi.')),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _purchaseStateMessage = _friendlyVerificationError(error);
      });
    } finally {
      _verifyingPurchaseKeys.remove(key);
      if (mounted) setState(() => _pending = _verifyingPurchaseKeys.isNotEmpty);
    }
  }

  String _friendlyBillingError(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('bulunamadı') ||
        raw.contains('not found') ||
        raw.contains('product')) {
      return 'Bu plan şu anda kullanılamıyor. Daha sonra yeniden dene.';
    }

    if (raw.contains('kullanılamıyor') ||
        raw.contains('unavailable') ||
        raw.contains('billing')) {
      return 'Google Play satın alma servisi bu cihazda kullanılamıyor.';
    }

    return 'Satın alma işlemi başlatılamadı. Tekrar deneyebilirsin.';
  }

  String _friendlyVerificationError(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('failed-precondition') ||
        raw.contains('play developer api') ||
        raw.contains('api access')) {
      return 'Satın alma henüz doğrulanamadı. Yeniden ödeme yapmadan satın almalarını geri yüklemeyi dene.';
    }

    return 'Satın alma doğrulanamadı. Üyeliğin etkinleşmedi; satın almalarını geri yükleyerek tekrar deneyebilirsin.';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Linkball Pro'),
      actions: [
        if (widget.gateway.connected)
          IconButton(
            tooltip: 'Yenile',
            onPressed: _reloading ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
      ],
    ),
    body: SafeArea(
      child: widget.gateway.connected
          ? _body()
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SocialHero(
                  icon: Icons.workspace_premium_rounded,
                  eyebrow: 'LINKBALL PRO',
                  title: 'Oyunun, bir adım daha kişisel.',
                  message:
                      'Reklamsız bonuslar, profil kozmetiği ve kişisel istatistikler. Üyeliğin Google hesabına bağlı profilinde korunur.',
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _connectGoogle,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Google hesabını bağla'),
                ),
              ],
            ),
    ),
  );
  Widget _body() => FutureBuilder<PremiumEntitlement>(
    future: _entitlementFuture,
    builder: (context, snapshot) {
      final entitlement = snapshot.data;
      final known =
          snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError &&
          entitlement != null;
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            SocialHero(
              icon: Icons.workspace_premium_rounded,
              eyebrow: 'LINKBALL PRO',
              title: !known
                  ? 'Üyeliğin kontrol ediliyor'
                  : entitlement.active
                  ? 'Pro ayrıcalıkları senin.'
                  : 'Oyunun, bir adım daha kişisel.',
              message: !known
                  ? 'Güncel üyelik bilgini doğruladıktan sonra planlarını göstereceğiz.'
                  : entitlement.active
                  ? _status(entitlement)
                  : 'Temel oyun herkese açık. Pro ile deneyimini kişiselleştir.',
              footer: known && entitlement.active
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SocialStatus(_planName(entitlement.plan)),
                        if (entitlement.autoRenewing)
                          const SocialStatus('Otomatik yenilenir'),
                        if (entitlement.cancellationPending)
                          const SocialStatus('Yenileme iptal edildi'),
                        if (entitlement.inGracePeriod)
                          const SocialStatus('Ödeme kontrolü gerekli'),
                      ],
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState != ConnectionState.done)
              const LinearProgressIndicator(),
            if (snapshot.hasError)
              SocialNotice(
                title: 'Üyelik bilgisi alınamadı',
                message:
                    'Bağlantını kontrol edip yeniden dene. Üyelik durumu bilinmeden yeni satın alma başlatılmaz.',
                onAction: _reload,
              ),
            if (_purchaseStateMessage != null) ...[
              SocialNotice(
                title: 'Satın alma durumu',
                message: _purchaseStateMessage!,
              ),
              const SizedBox(height: 16),
            ],
            const PitchSectionTitle('Pro ile neler değişir?'),
            for (final item in const [
              (
                Icons.card_giftcard_outlined,
                'Reklamsız bonus',
                'Günlük coin bonusunu mevcut hakkın ve limitin içinde reklam izlemeden al.',
              ),
              (
                Icons.auto_awesome_outlined,
                'Sana ait bir profil',
                'Pro profil çerçevesi ve üyelik rozetiyle kendini göster.',
              ),
              (
                Icons.insights_outlined,
                'Oyununun gelişimini gör',
                'Maç formunu, Elo hareketini ve skor eğilimlerini kendi profilinde takip et.',
              ),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PitchPanel(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.$1, color: socialAccent(context)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$2,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(item.$3),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const PitchSectionTitle('Planını seç'),
            const Text(
              'Güncel fiyatlar ve ödeme koşulları Google Play’den gelir. Son onaydan önce mağazada gösterilen tutarı kontrol et.',
            ),
            const SizedBox(height: 12),
            if (known) _plans(entitlement),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _restoring || _launchingPlan != null ? null : _restore,
              icon: const Icon(Icons.restore_rounded),
              label: Text(
                _restoring ? 'Kontrol ediliyor…' : 'Satın almaları geri yükle',
              ),
            ),
            const SizedBox(height: 12),
            const PitchPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Üyeliğini yönet',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Aboneliğini ve yenilemeyi Google Play → Ödemeler ve abonelikler → Abonelikler bölümünden yönetebilirsin. Hesabını silmek veya uygulamayı kaldırmak abonelik yönetiminin yerini almaz.',
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
  Widget _plans(
    PremiumEntitlement entitlement,
  ) => FutureBuilder<PremiumBillingCatalog>(
    future: _catalogFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const LinearProgressIndicator();
      final catalog = snapshot.data;
      if (snapshot.hasError ||
          catalog == null ||
          !catalog.storeAvailable ||
          catalog.products.isEmpty)
        return SocialNotice(
          title: 'Planlar şu anda alınamıyor',
          message:
              'Google Play bağlantını ve mağaza hesabını kontrol et. Mevcut üyeliğin varsa satın almalarını geri yükleyebilirsin.',
          onAction: _reload,
        );
      return Column(
        children: [
          for (final plan in const [PremiumPlan.monthly, PremiumPlan.yearly])
            if (catalog.productFor(plan) != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ProPlanCard(
                  product: catalog.productFor(plan)!,
                  active: entitlement.active,
                  current: entitlement.active && entitlement.plan == plan,
                  busy:
                      _pending ||
                      _launchingPlan != null ||
                      _restoring ||
                      _reloading,
                  onBuy: () => _buy(catalog.productFor(plan)!),
                ),
              ),
        ],
      );
    },
  );
  String _status(PremiumEntitlement e) {
    if (e.isLifetime) return 'Süresiz Pro üyeliğin aktif.';
    if (e.inGracePeriod)
      return 'Ödeme yöntemini Google Play’den kontrol et. Pro erişimin ek süre boyunca devam ediyor.';
    final d = DateTime.fromMillisecondsSinceEpoch(e.expiresAt).toLocal();
    if (e.expiresAt <= 0) return 'Üyeliğin hesabında aktif.';
    return e.autoRenewing
        ? 'Sonraki yenileme: ${d.day}.${d.month}.${d.year}'
        : 'Pro erişimin ${d.day}.${d.month}.${d.year} tarihine kadar aktif.';
  }
}

class ProPlanCard extends StatelessWidget {
  const ProPlanCard({
    super.key,
    required this.product,
    required this.active,
    required this.current,
    required this.busy,
    required this.onBuy,
  });
  final PremiumBillingProduct product;
  final bool active, current, busy;
  final VoidCallback onBuy;
  @override
  Widget build(BuildContext context) => PitchPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              _planName(product.plan),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (current) const SocialStatus('Aktif'),
          ],
        ),
        const SizedBox(height: 8),
        Text(product.price, style: Theme.of(context).textTheme.headlineMedium),
        Text(
          product.plan == PremiumPlan.yearly
              ? 'Yıllık faturalandırılır'
              : 'Aylık faturalandırılır',
        ),
        if (product.description.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(product.description),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: active || busy ? null : onBuy,
          child: Text(
            current
                ? 'Mevcut planın'
                : active
                ? 'Pro üyeliğin aktif'
                : busy
                ? 'İşlem bekleniyor…'
                : 'Google Play ile devam et',
          ),
        ),
      ],
    ),
  );
}

String _planName(PremiumPlan plan) => switch (plan) {
  PremiumPlan.monthly => 'Aylık',
  PremiumPlan.yearly => 'Yıllık',
  PremiumPlan.lifetime => 'Süresiz',
  PremiumPlan.none => 'Pro',
};
