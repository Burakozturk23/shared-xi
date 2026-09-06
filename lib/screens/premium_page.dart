import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/premium_billing_models.dart';
import '../models/premium_models.dart';
import '../services/auth_service.dart';
import '../services/premium_billing_service.dart';
import '../services/premium_service.dart';
import '../services/profile_service.dart';
import 'sign_in_page.dart';

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});

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
  String? _purchaseStateMessage;

  @override
  void initState() {
    super.initState();

    if (AuthService.isGoogleAccount) {
      _startPersistentSession();
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  void _startPersistentSession() {
    _entitlementFuture = PremiumService.fetchStatus();
    _catalogFuture = PremiumBillingService.queryCatalog();

    _purchaseSubscription?.cancel();
    _purchaseSubscription = PremiumBillingService.purchaseUpdates.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _purchaseStateMessage =
              'Google Play satın alma akışı şu anda kullanılamıyor.';
        });
      },
    );
  }

  Future<void> _reload() async {
    if (!AuthService.isGoogleAccount) return;

    final entitlement = PremiumService.fetchStatus();
    final catalog = PremiumBillingService.queryCatalog();

    setState(() {
      _entitlementFuture = entitlement;
      _catalogFuture = catalog;
    });

    await entitlement;
    await catalog;
  }

  Future<void> _connectGoogle() async {
    final signedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const LinkballSignInPage(allowSkip: false),
      ),
    );

    if (!mounted || signedIn != true || !AuthService.isGoogleAccount) {
      return;
    }

    await ProfileService.ensureCanonicalProfile();

    if (!mounted) return;

    setState(() {
      _purchaseStateMessage = null;
    });

    _startPersistentSession();
    setState(() {});
  }

  Future<void> _buy(PremiumBillingProduct product) async {
    if (_launchingPlan != null) return;

    setState(() {
      _launchingPlan = product.plan;
      _purchaseStateMessage = null;
    });

    try {
      final launched = await PremiumBillingService.purchasePlan(product.plan);

      if (!mounted) return;

      setState(() {
        _purchaseStateMessage = launched
            ? 'Google Play satın alma ekranı açıldı. Onay bekleniyor.'
            : 'Google Play satın alma ekranı açılamadı.';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
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
    if (_restoring) return;

    setState(() {
      _restoring = true;
      _purchaseStateMessage =
          'Google Play satın alma geçmişi kontrol ediliyor...';
    });

    try {
      await PremiumBillingService.restorePurchases();

      if (!mounted) return;

      setState(() {
        _purchaseStateMessage =
            'Geri yükleme isteği gönderildi. Doğrulama sonuçları bekleniyor.';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
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
      if (!mounted) return;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          setState(() {
            _purchaseStateMessage =
                'Google Play satın alma onayı bekleniyor...';
          });
          break;

        case PurchaseStatus.error:
          setState(() {
            _purchaseStateMessage =
                purchase.error?.message ??
                'Google Play satın alma işlemi tamamlanamadı.';
          });
          break;

        case PurchaseStatus.canceled:
          setState(() {
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

    if (mounted) {
      setState(() {
        _purchaseStateMessage =
            'Satın alma Linkball sunucusunda doğrulanıyor...';
      });
    }

    try {
      final entitlement = await PremiumBillingService.verifyAndComplete(
        purchase,
      );

      if (!mounted) return;

      setState(() {
        _entitlementFuture = Future<PremiumEntitlement>.value(entitlement);
        _purchaseStateMessage = 'Premium doğrulandı ve hesabına tanımlandı.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Linkball Premium etkinleştirildi.')),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _purchaseStateMessage = _friendlyVerificationError(error);
      });
    } finally {
      _verifyingPurchaseKeys.remove(key);
    }
  }

  String _friendlyBillingError(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('bulunamadı') ||
        raw.contains('not found') ||
        raw.contains('product')) {
      return 'Premium ürünleri Google Play üzerinde henüz etkin değil.';
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
      return 'Satın alma doğrulaması Play Console/API kurulumu '
          'tamamlandıktan sonra etkinleşecek.';
    }

    return 'Satın alma doğrulanamadı. Premium hakkı verilmedi.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Linkball Premium')),
      body: AuthService.isGoogleAccount
          ? _buildPersistentBody()
          : _buildAccountRequired(),
    );
  }

  Widget _buildAccountRequired() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.workspace_premium_outlined, size: 54),
                  const SizedBox(height: 16),
                  const Text(
                    'Premium için kalıcı profil gerekli',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Premium üyeliğin ve satın alma geçmişin Google hesabına '
                    'bağlı Linkball profilinde korunur.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _connectGoogle,
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Google ile Bağla'),
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

  Widget _buildPersistentBody() {
    final entitlementFuture = _entitlementFuture ??=
        PremiumService.fetchStatus();

    return FutureBuilder<PremiumEntitlement>(
      future: entitlementFuture,
      builder: (context, entitlementSnapshot) {
        final entitlement =
            entitlementSnapshot.data ?? const PremiumEntitlement.inactive();

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 36),
            children: [
              _PremiumHero(entitlement: entitlement),
              const SizedBox(height: 14),
              if (entitlementSnapshot.hasError)
                _InlineNotice(
                  icon: Icons.sync_problem_rounded,
                  title: 'Premium durumu yenilenemedi',
                  message:
                      'Mevcut üyelik bilgisi şu anda alınamadı. Yenilemek '
                      'için aşağı çekebilirsin.',
                ),
              if (entitlementSnapshot.connectionState ==
                  ConnectionState.waiting)
                const LinearProgressIndicator(),
              if (_purchaseStateMessage != null) ...[
                const SizedBox(height: 14),
                _InlineNotice(
                  icon: Icons.info_outline_rounded,
                  title: 'Satın alma durumu',
                  message: _purchaseStateMessage!,
                ),
              ],
              const SizedBox(height: 22),
              const _SectionTitle(
                title: 'Premium avantajları',
                subtitle:
                    'Rekabetçi oyun gücü vermez; üyelik ve koleksiyon '
                    'avantajlarına odaklanır.',
              ),
              const SizedBox(height: 10),
              const _BenefitCard(
                icon: Icons.auto_awesome_rounded,
                title: 'Premium kozmetikler',
                subtitle: 'Premium koleksiyonları ve özel görsel içerikler.',
                status: 'HAZIR',
              ),
              const SizedBox(height: 10),
              const _BenefitCard(
                icon: Icons.block_rounded,
                title: 'Reklamsız deneyim',
                subtitle:
                    'Reklam katmanı devreye girdiğinde Premium hesaplara '
                    'otomatik uygulanacak.',
                status: 'YAKINDA',
              ),
              const SizedBox(height: 10),
              const _BenefitCard(
                icon: Icons.card_giftcard_rounded,
                title: 'Günlük ödül bonusu',
                subtitle:
                    'Günlük ödül sistemi açıldığında Premium bonusu '
                    'üyeliğe bağlanacak.',
                status: 'YAKINDA',
              ),
              const SizedBox(height: 10),
              const _BenefitCard(
                icon: Icons.local_fire_department_outlined,
                title: 'Seri koruması',
                subtitle:
                    'Streak sistemi açıldığında Premium seri koruması '
                    'kullanılabilecek.',
                status: 'YAKINDA',
              ),
              const SizedBox(height: 24),
              const _SectionTitle(
                title: 'Premium planları',
                subtitle:
                    'Fiyatlar Linkball tarafından yazılmaz; Google Play '
                    'üzerinden yerel para biriminle gelir.',
              ),
              const SizedBox(height: 10),
              _buildBillingSection(entitlement),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _restoring ? null : _restore,
                icon: _restoring
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restore_rounded),
                label: Text(
                  _restoring
                      ? 'Kontrol ediliyor...'
                      : 'Satın almaları geri yükle',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Premium yalnızca Google Play satın alması Linkball '
                'sunucusunda doğrulandıktan sonra etkinleşir.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBillingSection(PremiumEntitlement entitlement) {
    final future = _catalogFuture ??= PremiumBillingService.queryCatalog();

    return FutureBuilder<PremiumBillingCatalog>(
      future: future,
      builder: (context, catalogSnapshot) {
        if (catalogSnapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(22),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (catalogSnapshot.hasError) {
          return const _BillingUnavailableCard(
            message:
                'Google Play ürün bilgileri şu anda alınamıyor. '
                'Play Console kurulumu tamamlandığında fiyatlar burada '
                'otomatik görünecek.',
          );
        }

        final catalog = catalogSnapshot.data;

        if (catalog == null || !catalog.storeAvailable) {
          return _BillingUnavailableCard(
            message: catalog?.errorMessage.trim().isNotEmpty == true
                ? catalog!.errorMessage
                : 'Google Play satın alma servisi bu cihazda kullanılamıyor.',
          );
        }

        if (catalog.products.isEmpty) {
          return const _BillingUnavailableCard(
            message:
                'Premium ürünleri Play Console üzerinde henüz etkin değil. '
                'Ürünler etkinleştirildiğinde yerel fiyatlar burada '
                'otomatik görünecek.',
          );
        }

        return Column(
          children: [
            for (final plan in const <PremiumPlan>[
              PremiumPlan.monthly,
              PremiumPlan.yearly,
              PremiumPlan.lifetime,
            ]) ...[
              _PremiumPlanCard(
                plan: plan,
                product: catalog.productFor(plan),
                activeEntitlement: entitlement,
                launching: _launchingPlan == plan,
                onBuy: (product) => _buy(product),
              ),
              if (plan != PremiumPlan.lifetime) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _PremiumHero extends StatelessWidget {
  final PremiumEntitlement entitlement;

  const _PremiumHero({required this.entitlement});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final active = entitlement.active;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primary.withValues(alpha: 0.32),
              primary.withValues(alpha: 0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    active
                        ? Icons.workspace_premium_rounded
                        : Icons.workspace_premium_outlined,
                    color: primary,
                    size: 31,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        active ? 'Premium aktif' : 'Premiuma Geç',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        active
                            ? _entitlementSubtitle(entitlement)
                            : 'Kozmetik ve konfor avantajlarını hesabına bağla.',
                        style: const TextStyle(height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (active) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusPill(
                    icon: Icons.verified_rounded,
                    label: _planLabel(entitlement.plan),
                  ),
                  if (entitlement.autoRenewing)
                    const _StatusPill(
                      icon: Icons.autorenew_rounded,
                      label: 'Otomatik yenilenir',
                    ),
                  if (entitlement.isLifetime)
                    const _StatusPill(
                      icon: Icons.all_inclusive_rounded,
                      label: 'Süresiz',
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _entitlementSubtitle(PremiumEntitlement entitlement) {
    if (entitlement.isLifetime) {
      return 'Ömür boyu Premium üyeliğin hesabında aktif.';
    }

    if (entitlement.expiresAt > 0) {
      final date = DateTime.fromMillisecondsSinceEpoch(
        entitlement.expiresAt,
      ).toLocal();

      return 'Üyelik bitişi: ${_two(date.day)}.${_two(date.month)}.${date.year}';
    }

    return 'Premium üyeliğin hesabında aktif.';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

class _PremiumPlanCard extends StatelessWidget {
  final PremiumPlan plan;
  final PremiumBillingProduct? product;
  final PremiumEntitlement activeEntitlement;
  final bool launching;
  final ValueChanged<PremiumBillingProduct> onBuy;

  const _PremiumPlanCard({
    required this.plan,
    required this.product,
    required this.activeEntitlement,
    required this.launching,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final currentPlan =
        activeEntitlement.active && activeEntitlement.plan == plan;
    final anyPremiumActive = activeEntitlement.active;
    final available = product != null && !anyPremiumActive;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _planIcon(plan),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _planLabel(plan),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (currentPlan) ...[
                        const SizedBox(width: 8),
                        const _MiniBadge(text: 'AKTİF'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product?.description.trim().isNotEmpty == true
                        ? product!.description
                        : _planDescription(plan),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 118,
              child: FilledButton(
                onPressed: available && !launching
                    ? () => onBuy(product!)
                    : null,
                child: launching
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        currentPlan ? 'Aktif' : (product?.price ?? 'Yakında'),
                        textAlign: TextAlign.center,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;

  const _BenefitCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        trailing: _MiniBadge(text: status),
      ),
    );
  }
}

class _BillingUnavailableCard extends StatelessWidget {
  final String message;

  const _BillingUnavailableCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.store_mall_directory_outlined, size: 38),
            const SizedBox(height: 12),
            const Text(
              'Google Play kurulumu bekleniyor',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).hintColor, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InlineNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(message),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: Theme.of(context).hintColor, height: 1.35),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatusPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;

  const _MiniBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: primary,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

String _planLabel(PremiumPlan plan) {
  switch (plan) {
    case PremiumPlan.monthly:
      return 'Aylık';
    case PremiumPlan.yearly:
      return 'Yıllık';
    case PremiumPlan.lifetime:
      return 'Ömür Boyu';
    case PremiumPlan.none:
      return 'Premium';
  }
}

String _planDescription(PremiumPlan plan) {
  switch (plan) {
    case PremiumPlan.monthly:
      return 'Her ay yenilenen Premium üyelik.';
    case PremiumPlan.yearly:
      return 'Yıllık Premium üyelik.';
    case PremiumPlan.lifetime:
      return 'Tek seferlik kalıcı Premium yükseltmesi.';
    case PremiumPlan.none:
      return 'Premium üyelik.';
  }
}

IconData _planIcon(PremiumPlan plan) {
  switch (plan) {
    case PremiumPlan.monthly:
      return Icons.calendar_month_rounded;
    case PremiumPlan.yearly:
      return Icons.event_repeat_rounded;
    case PremiumPlan.lifetime:
      return Icons.all_inclusive_rounded;
    case PremiumPlan.none:
      return Icons.workspace_premium_outlined;
  }
}
