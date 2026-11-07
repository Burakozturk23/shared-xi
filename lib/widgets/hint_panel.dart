import 'package:flutter/material.dart';

import '../app/app_feedback.dart';
import '../models/hint_menu.dart';
export '../models/hint_menu.dart';
import '../services/store_gateway.dart';

/// İpucu v2: one "İpucu al" button and panel for every game (spec §3).
/// Bag stock is used with one tap; with an empty bag the panel offers Joker
/// (Pro), a verified ad, then Coin. The server reveals and charges; this widget
/// only sends the item and the payment source.
class HintButton extends StatefulWidget {
  const HintButton({
    super.key,
    required this.menu,
    required this.onUse,
    this.onWatch,
    this.loadBag,
    this.target,
    this.disabled = false,
  });
  final HintMenu menu;
  final Future<void> Function(String itemId, String source) onUse;
  final Future<void> Function(String itemId)? onWatch;
  final Future<Map<String, int>> Function()? loadBag;

  /// Selected cell/axis in modes whose items depend on it (Grid, Çinko).
  final Object? target;
  final bool disabled;

  @override
  State<HintButton> createState() => _HintButtonState();
}

class _HintButtonState extends State<HintButton> {
  bool _open = false;

  Future<Map<String, int>> _bag() async {
    if (widget.loadBag != null) return widget.loadBag!();
    final value = await const StoreGateway().load();
    return {for (final e in value.inventory.entries) if (e.key.startsWith('hint_')) e.key: e.value.quantity};
  }

  Future<void> _choose() async {
    if (_open || widget.disabled) return;
    setState(() => _open = true);
    try {
      final picked = await showModalBottomSheet<(String, String)>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _HintSheet(menu: widget.menu, items: widget.menu.forTarget(widget.target), load: _bag),
      );
      if (!mounted || picked == null) return;
      final (id, source) = picked;
      if (source == 'watch') {
        await widget.onWatch?.call(id);
      } else {
        await widget.onUse(id, source);
        AppFeedback.hint();
      }
    } finally {
      if (mounted) setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.menu.items.where((i) => !i.used).length;
    return FilledButton.tonalIcon(
      key: const ValueKey('hint-button'),
      onPressed: widget.disabled || _open || left == 0 ? null : _choose,
      icon: const Icon(Icons.lightbulb_outline),
      label: Text(left == 0 ? 'İpuçları açıldı' : 'İpucu al'),
    );
  }
}

class _HintSheet extends StatefulWidget {
  const _HintSheet({required this.menu, required this.items, required this.load});
  final HintMenu menu;
  final List<HintItem> items;
  final Future<Map<String, int>> Function() load;
  @override
  State<_HintSheet> createState() => _HintSheetState();
}

class _HintSheetState extends State<_HintSheet> {
  late Future<Map<String, int>> _bag = widget.load();
  String? _selected;

  void _tap(HintItem item, Map<String, int> bag) {
    if (item.used) return;
    if ((bag[item.bagKey] ?? 0) > 0) {
      Navigator.pop(context, (item.id, 'stock'));
    } else {
      setState(() => _selected = item.id);
    }
  }

  String _cost(HintItem item, Map<String, int> bag) {
    final stock = bag[item.bagKey] ?? 0;
    return stock > 0 ? 'Çantada ×$stock' : '${item.price} Coin';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final menu = widget.menu;
    final open = widget.items.where((i) => !i.used).map((i) => i.id).toSet();
    final suggested = [menu.suggested.$1, menu.suggested.$2]
        .where((id) => id != null && open.contains(id))
        .map((id) => menu.item(id)!)
        .toList();
    return SingleChildScrollView(
      key: const ValueKey('hint-panel'),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: FutureBuilder<Map<String, int>>(
        future: _bag,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              const Text('Çanta yüklenemedi. Hiçbir şey harcanmadı.'),
              TextButton(onPressed: () => setState(() => _bag = widget.load()), child: const Text('Çantayı yenile')),
            ]);
          }
          if (!snapshot.hasData) {
            return const Padding(padding: EdgeInsets.all(24), child: LinearProgressIndicator());
          }
          final bag = snapshot.data!;
          final joker = bag['hint_joker'] ?? 0;
          final types = {for (final i in widget.items) i.bagKey};
          final inBag = types.fold<int>(0, (n, k) => n + (bag[k] ?? 0));
          final selected = menu.item(_selected);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: Text('İpucu al', style: theme.textTheme.headlineSmall)),
              Chip(avatar: const Icon(Icons.backpack_outlined, size: 18), label: Text('Çanta: $inBag')),
              if (joker > 0) ...[
                const SizedBox(width: 6),
                Chip(avatar: const Icon(Icons.auto_awesome, size: 18), label: Text('Joker ×$joker')),
              ],
            ]),
            const SizedBox(height: 4),
            Text('Kullanırsan sonuç Yardımlı kaydedilir. Bir tahtada her ipucu bir kez açılır.',
                style: theme.textTheme.bodySmall),
            if (suggested.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Önerilen', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              for (final item in suggested)
                Card(
                  key: ValueKey('hint-suggest-${item.id}'),
                  margin: const EdgeInsets.only(bottom: 8),
                  color: item.strong ? theme.colorScheme.tertiaryContainer : theme.colorScheme.secondaryContainer,
                  child: ListTile(
                    onTap: () => _tap(item, bag),
                    leading: Icon(hintTypeIcon(item.type)),
                    title: Text(item.strong ? '${item.label} · Güçlü' : item.label),
                    subtitle: item.why == null ? null : Text(item.why!),
                    trailing: Text(_cost(item, bag), style: theme.textTheme.labelLarge),
                  ),
                ),
            ],
            const SizedBox(height: 10),
            Text('Tüm ipuçları', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final item in widget.items)
                Opacity(
                  opacity: item.used ? .45 : 1,
                  child: ActionChip(
                    key: ValueKey('hint-chip-${item.id}'),
                    avatar: Icon(item.used ? Icons.check : hintTypeIcon(item.type), size: 18),
                    label: Text(item.used
                        ? '${item.label}: ${item.result ?? 'açıldı'}'
                        : '${item.label} · ${_cost(item, bag)}'),
                    onPressed: item.used ? null : () => _tap(item, bag),
                  ),
                ),
            ]),
            if (selected != null) ...[
              const SizedBox(height: 16),
              _Payment(key: const ValueKey('hint-pay-block'), item: selected, menu: menu, joker: joker),
            ],
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İpucusuz devam et')),
          ]);
        },
      ),
    );
  }
}

/// Payment for an item the bag does not have: Joker (Pro), ad credit or a new ad, then Coin.
class _Payment extends StatelessWidget {
  const _Payment({super.key, required this.item, required this.menu, required this.joker});
  final HintItem item;
  final HintMenu menu;
  final int joker;

  @override
  Widget build(BuildContext context) {
    final need = item.strong ? 2 : 1;
    final credit = (menu.credits[item.id] ?? 0) >= need;
    final watch = menu.adsAllowed && menu.adsRemaining > 0 && !credit;
    VoidCallback pop(String source) => () => Navigator.pop(context, (item.id, source));
    final coins = 'Coin ile al · ${item.price} Coin';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${item.label} çantanda yok.', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      if (joker > 0)
        FilledButton.icon(key: const ValueKey('hint-pay-joker'), onPressed: pop('joker'),
            icon: const Icon(Icons.auto_awesome), label: Text('Joker kullan · ×$joker')),
      if (menu.adsAllowed && credit)
        FilledButton(key: const ValueKey('hint-pay-ad'), onPressed: pop('ad'),
            child: const Text('Reklam hakkını kullan')),
      if (watch)
        FilledButton.tonalIcon(onPressed: pop('watch'), icon: const Icon(Icons.play_circle_outline),
            label: Text(item.strong ? 'Reklam izle · +1 (2 reklam gerekir)' : 'Reklam izle · +1')),
      if (watch || credit || joker > 0)
        TextButton(key: const ValueKey('hint-pay-coins-link'), onPressed: pop('coins'), child: Text('ya da $coins'))
      else
        FilledButton(key: const ValueKey('hint-pay-coins'), onPressed: pop('coins'), child: Text(coins)),
      if (!menu.adsAllowed)
        Text('Süreli oyunda ipucu reklamla alınmaz; oyun saati durmaz.', style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

/// İpucu v2 entry for a game screen: the "İpucu al" button and the hints this
/// board has opened. Null while the session is on the old supports, so a screen
/// writes `if (hintEntry(...) case final w?) w else <old support UI>`.
Widget? hintEntry(
  Map? session, {
  required Future<void> Function(Map<String, dynamic> payment) send,
  Future<void> Function(String itemId)? watch,
  Object? target,
  bool disabled = false,
  Future<Map<String, int>> Function()? loadBag,
}) {
  final menu = HintMenu.fromSession(session);
  if (menu == null) return null;
  final opened = [for (final i in menu.items) if (i.used && i.result != null) i];
  return Column(
    key: const ValueKey('hint-entry'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final i in opened)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Icon(hintTypeIcon(i.type), size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('${i.label}: ${i.result}')),
          ]),
        ),
      HintButton(
        menu: menu,
        target: target,
        disabled: disabled,
        loadBag: loadBag,
        onWatch: watch,
        onUse: (id, source) => send({
          'itemId': id,
          'paymentSource': source,
          if (source == 'coins') 'expectedPriceCoins': menu.item(id)?.price,
        }),
      ),
    ],
  );
}
