import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/coin_billing_service.dart';
import '../services/monetization_analytics.dart';
import '../widgets/wallet_balance_chip.dart';

class CoinPacksPage extends StatefulWidget {
  const CoinPacksPage({super.key, this.service});
  final CoinBillingService? service;
  @override
  State<CoinPacksPage> createState() => _CoinPacksPageState();
}

class _CoinPacksPageState extends State<CoinPacksPage> {
  late final service = widget.service ?? CoinBillingService.instance;
  bool get supported =>
      widget.service != null ||
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
  @override
  void initState() {
    super.initState();
    unawaited(
      MonetizationAnalytics.instance.surfaceViewed('coin_packs'),
    );
    if (supported) service.refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Link Coin paketleri'),
      actions: [
        if (widget.service == null && AuthService.isGoogleAccount)
          const WalletBalanceChip(compact: true),
      ],
    ),
    body: !supported
        ? const Center(
            child: Text('Coin paketleri Google Play’de kullanılabilir.'),
          )
        : ListenableBuilder(
            listenable: service,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Koleksiyonunu genişlet',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Avatar ve kozmetikler için Link Coin. Coinler oynayarak da kazanılır; '
                  'satın almak maç puanını veya kazanma ihtimalini artırmaz.',
                ),
                const SizedBox(height: 20),
                if (service.loading)
                  const Center(child: CircularProgressIndicator()),
                for (final product in service.products)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${coinProductAmounts[product.id]} Link Coin',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: service.enabled && !service.purchasing
                                ? () => service.buy(product)
                                : null,
                            child: Text('${product.price} · Satın al'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (service.message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(service.message),
                    ),
                  ),
                TextButton.icon(
                  onPressed: service.loading ? null : service.refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Paketleri yenile'),
                ),
                OutlinedButton(
                  onPressed: service.restore,
                  child: const Text('Satın almaları kontrol et'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tamamlanmamış işlemler kontrol edilir. Daha önce teslim edilmiş coinler '
                  'yeniden verilmez; bakiyen Linkball hesabında saklanır.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'İade edilen satın almanın coinleri bakiyeden düşülür. Harcanmışsa bakiye '
                  'eksiye düşebilir; sonraki kazanımlar bu farkı kapatır. Temel oyun modları açık kalır.',
                ),
              ],
            ),
          ),
  );
}
