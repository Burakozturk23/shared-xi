import 'package:flutter/material.dart';

import '../models/economy_models.dart';
import '../models/store_models.dart';
import '../models/user_avatar_catalog.dart';
import '../services/auth_service.dart';
import '../services/economy_service.dart';
import '../services/profile_service.dart';
import '../services/store_service.dart';
import '../widgets/user_avatar_badge.dart';
import '../widgets/wallet_balance_chip.dart';
import 'sign_in_page.dart';
import 'premium_page.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  Future<StoreCatalogSnapshot>? _catalogFuture;
  final Set<String> _purchasingOfferIds = <String>{};

  @override
  void initState() {
    super.initState();
    if (AuthService.isGoogleAccount) {
      _catalogFuture = StoreService.fetchCatalog();
    }
  }

  void _reloadCatalog() {
    setState(() {
      _catalogFuture = StoreService.fetchCatalog();
    });
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
    _reloadCatalog();
  }

  Future<void> _purchase(StoreOffer offer) async {
    if (_purchasingOfferIds.contains(offer.offerId)) return;

    setState(() => _purchasingOfferIds.add(offer.offerId));

    try {
      final result = await StoreService.purchase(offer);

      if (!mounted) return;

      final message = result.alreadyOwned
          ? '${offer.title} zaten koleksiyonunda.'
          : '${offer.title} açıldı. ${result.coins} coin kaldı.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      _reloadCatalog();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_purchaseErrorMessage(error))));
    } finally {
      if (mounted) {
        setState(() => _purchasingOfferIds.remove(offer.offerId));
      }
    }
  }

  String _purchaseErrorMessage(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('insufficient') ||
        raw.contains('yetersiz') ||
        raw.contains('balance')) {
      return 'Bu teklif için yeterli coinin yok.';
    }

    if (raw.contains('already') || raw.contains('owned')) {
      return 'Bu ürün zaten koleksiyonunda.';
    }

    return 'Satın alma tamamlanamadı. Tekrar dene.';
  }

  @override
  Widget build(BuildContext context) {
    final persistent = AuthService.isGoogleAccount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mağaza'),
        actions: [
          if (persistent) const WalletBalanceChip(compact: true),
          const SizedBox(width: 6),
        ],
      ),
      body: persistent ? _buildStore() : _buildAccountRequired(),
    );
  }

  Widget _buildAccountRequired() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storefront_outlined, size: 52),
                  const SizedBox(height: 16),
                  const Text(
                    'Mağaza için kalıcı profil gerekli',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Coin bakiyen, satın aldığın avatarlar ve ilerideki '
                    'premium hakların Google hesabına bağlı Linkball '
                    'profilinde korunur.',
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

  Widget _buildStore() {
    final future = _catalogFuture ??= StoreService.fetchCatalog();

    return FutureBuilder<StoreCatalogSnapshot>(
      future: future,
      builder: (context, catalogSnapshot) {
        if (catalogSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (catalogSnapshot.hasError || !catalogSnapshot.hasData) {
          return _StoreErrorState(onRetry: _reloadCatalog);
        }

        final catalog = catalogSnapshot.data!;

        return StreamBuilder<EconomyWallet>(
          stream: EconomyService.watchWallet(),
          initialData: catalog.wallet,
          builder: (context, walletSnapshot) {
            final wallet = walletSnapshot.data ?? catalog.wallet;

            return StreamBuilder<UserProfile?>(
              stream: ProfileService.watchMyProfile(),
              builder: (context, profileSnapshot) {
                final profile = profileSnapshot.data;
                final owned = profile?.ownedAvatarIds ?? const <String>{};

                return RefreshIndicator(
                  onRefresh: () async {
                    final next = await StoreService.fetchCatalog();
                    if (!mounted) return;
                    setState(() {
                      _catalogFuture = Future<StoreCatalogSnapshot>.value(next);
                    });
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 760
                          ? 3
                          : 2;

                      return CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                              child: _StoreHeaderCard(
                                coins: wallet.coins,
                                offerCount: catalog.offers.length,
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                              child: _PremiumStoreBanner(
                                onTap: () {
                                  Navigator.push<void>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const PremiumPage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          if (catalog.offers.isEmpty)
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Text(
                                  'Şu anda aktif mağaza teklifi yok.',
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
                              sliver: SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      childAspectRatio:
                                          constraints.maxWidth >= 760
                                          ? 0.92
                                          : 0.76,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                    ),
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final offer = catalog.offers[index];
                                  final isOwned = owned.contains(offer.itemId);
                                  final purchasing = _purchasingOfferIds
                                      .contains(offer.offerId);
                                  final canAfford =
                                      wallet.coins >= offer.priceCoins;

                                  return _StoreOfferCard(
                                    offer: offer,
                                    owned: isOwned,
                                    purchasing: purchasing,
                                    canAfford: canAfford,
                                    onBuy: () => _purchase(offer),
                                  );
                                }, childCount: catalog.offers.length),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _StoreHeaderCard extends StatelessWidget {
  final int coins;
  final int offerCount;

  const _StoreHeaderCard({required this.coins, required this.offerCount});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Color(0xFFFFB300),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Coin Mağazası',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$offerCount aktif teklif · $coins coin kullanılabilir',
                    style: TextStyle(color: Theme.of(context).hintColor),
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

class _PremiumStoreBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _PremiumStoreBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primary.withValues(alpha: 0.24),
                primary.withValues(alpha: 0.08),
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: primary,
                  size: 29,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Linkball Premium',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Üyelik durumunu, avantajları ve Google Play '
                      'planlarını görüntüle.',
                      style: TextStyle(height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(onPressed: onTap, child: const Text('İncele')),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreOfferCard extends StatelessWidget {
  final StoreOffer offer;
  final bool owned;
  final bool purchasing;
  final bool canAfford;
  final VoidCallback onBuy;

  const _StoreOfferCard({
    required this.offer,
    required this.owned,
    required this.purchasing,
    required this.canAfford,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final isKnownAvatar =
        offer.isAvatar && UserAvatarCatalog.contains(offer.itemId);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: _OfferBadge(
                text: owned
                    ? 'SAHİPSİN'
                    : (offer.badge.isEmpty ? 'MAĞAZA' : offer.badge),
                owned: owned,
              ),
            ),
            const SizedBox(height: 6),
            if (isKnownAvatar)
              UserAvatarBadge(avatarId: offer.itemId, radius: 38)
            else
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded, size: 36),
              ),
            const SizedBox(height: 12),
            Text(
              offer.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Expanded(
              child: Text(
                offer.subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: owned
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Koleksiyonunda'),
                    )
                  : FilledButton.icon(
                      onPressed: purchasing || !canAfford ? null : onBuy,
                      icon: purchasing
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.monetization_on_rounded),
                      label: Text(
                        purchasing
                            ? 'Alınıyor...'
                            : (canAfford
                                  ? '${offer.priceCoins} coin'
                                  : 'Yetersiz coin'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferBadge extends StatelessWidget {
  final String text;
  final bool owned;

  const _OfferBadge({required this.text, required this.owned});

  @override
  Widget build(BuildContext context) {
    final background = owned
        ? Colors.green.withValues(alpha: 0.15)
        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.14);

    final foreground = owned
        ? Colors.greenAccent
        : Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _StoreErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _StoreErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Mağaza yüklenemedi',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Bağlantını kontrol edip tekrar deneyebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}
