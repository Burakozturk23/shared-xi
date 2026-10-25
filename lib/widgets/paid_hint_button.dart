import 'package:flutter/material.dart';
import '../models/rewarded_ad_models.dart';
import '../services/auth_service.dart';
import '../services/store_gateway.dart';

/// The game sends a typed product and price. The server generates the hint and
/// commits payment with the run; this widget never receives a hidden answer.
class PaidHintButton extends StatefulWidget {
  const PaidHintButton({super.key, required this.session, required this.sku,
    required this.label, required this.onUse, this.onWatch, this.disabled = false,
    this.loadBalance, this.currentUser});
  final Map<String, dynamic> session;
  final String sku, label;
  final bool disabled;
  final Future<void> Function(Map<String, dynamic>) onUse;
  final Future<void> Function()? onWatch;
  final Future<Map<String, int>> Function()? loadBalance;
  final String? Function()? currentUser;

  @override
  State<PaidHintButton> createState() => _PaidHintButtonState();
}

class _PaidHintButtonState extends State<PaidHintButton> {
  bool _open = false;
  String? _uid() => widget.currentUser != null ? widget.currentUser!() : AuthService.uid;
  Map<String, dynamic> get product {
    final products = rewardMap(widget.session['support'])['products'];
    for (final p in products is List ? products : const []) {
      final row = rewardMap(p);
      if (row['id'] == widget.sku) return row;
    }
    return {};
  }
  Future<Map<String, int>> _balance() async {
    if (widget.loadBalance != null) return widget.loadBalance!();
    final value = await const StoreGateway().load();
    return {'stock': value.inventory[widget.sku]?.quantity ?? 0};
  }
  Future<void> _choose() async {
    if (_open || widget.disabled || product.isEmpty) return;
    final owner = _uid();
    final sessionId = widget.session['id'];
    final revision = widget.session['revision'];
    final quote = product;
    setState(() => _open = true);
    try {
      final source = await showModalBottomSheet<String>(context: context,
        isScrollControlled: true, useSafeArea: true,
        builder: (_) => _SupportSheet(label: widget.label, product: quote,
          credits: (rewardMap(rewardMap(widget.session['support'])['adCreditsByProduct'])[widget.sku]
            as num? ?? widget.session['adCredits'] as num? ?? 0).toInt(),
          recoveryPending: rewardMap(widget.session['support'])['recoveryPending'] == true,
          canWatch: widget.onWatch != null &&
            (widget.session['adGranted'] as num? ?? 0) <
              (rewardMap(widget.session['support'])['adLimit'] as num? ?? 2) &&
            (rewardMap(widget.session['support'])['adRemaining'] as num? ?? 2) > 0,
          load: _balance));
      if (!mounted || source == null || owner != _uid() ||
          sessionId != widget.session['id'] || revision != widget.session['revision']) return;
      if (source == 'watch') {
        await widget.onWatch?.call();
      } else {
        await widget.onUse({'boostId': widget.sku, 'paymentSource': source,
          if (source == 'coins') 'expectedPriceCoins': quote['priceCoins']});
      }
    } finally {
      if (mounted) setState(() => _open = false);
    }
  }
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: widget.disabled || _open || product.isEmpty ? null : _choose,
    icon: const Icon(Icons.backpack_outlined),
    label: Text('${widget.label} · ${product['priceCoins'] ?? '—'} Coin'),
  );
}

class _SupportSheet extends StatefulWidget {
  const _SupportSheet({required this.label, required this.product,
    required this.credits, required this.canWatch, required this.recoveryPending, required this.load});
  final String label;
  final Map<String, dynamic> product;
  final int credits;
  final bool canWatch, recoveryPending;
  final Future<Map<String, int>> Function() load;
  @override
  State<_SupportSheet> createState() => _SupportSheetState();
}
class _SupportSheetState extends State<_SupportSheet> {
  late Future<Map<String, int>> _balance = widget.load();
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min,
      children: [
        Text('Destek çantası', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8), Text(widget.label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Kullanırsan sonuç Yardımlı olarak kaydedilir; yardımsız ustalık ve rekoruna eklenmez.'),
        if (widget.recoveryPending) const Text('Kullanılmayan reklam hakkın korunuyor. Çantanda yer açınca oyunu yenile.'),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, int>>(future: _balance, builder: (context, snapshot) {
          if (snapshot.hasError) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Çanta yüklenemedi. Stok harcanmadı.'),
            TextButton(onPressed: () => setState(() => _balance = widget.load()), child: const Text('Çantayı yenile')),
          ]);
          if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
          final stock = snapshot.data!['stock'] ?? 0;
          return OutlinedButton(onPressed: stock > 0 ? () => Navigator.pop(context, 'stock') : null,
            child: Text(stock > 0 ? 'Çantamdan kullan · $stock adet' : 'Çantanda bu destek yok'));
        }),
        FilledButton(onPressed: () => Navigator.pop(context, 'coins'),
          child: Text('Coin ile al ve kullan · ${widget.product['priceCoins']} Coin')),
        if (widget.product['ads'] == true) ...[
          if (widget.credits > 0)
            OutlinedButton(onPressed: () => Navigator.pop(context, 'ad'),
              child: Text('Doğrulanmış reklam hakkını kullan · ${widget.credits}')),
          OutlinedButton.icon(onPressed: widget.canWatch ? () => Navigator.pop(context, 'watch') : null,
            icon: const Icon(Icons.play_circle_outline), label: const Text('Reklam izle · 1 destek hakkı')),
          Text(widget.canWatch ? 'Günde ortak 4 hak. Reklam doğrulanınca hakkın açılır; süreli oyun saati devam eder.' :
            'Bu oyun için yeni reklam hakkı kullanılamıyor.'),
        ] else const Text('Güçlü destek reklamla alınamaz.'),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Desteksiz devam et')),
      ]),
  );
}
