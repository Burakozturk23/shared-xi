import 'dart:math';
import 'package:flutter/material.dart';
import '../app/route_appearance.dart';
import '../screens/store_page.dart';
import '../services/store_gateway.dart';
import '../services/store_service.dart';

/// Solo assistance only: stock is consumed by the server before a hint appears.
class StoreBoostPanel extends StatefulWidget {
  const StoreBoostPanel({
    super.key,
    required this.modeId,
    required this.answer,
    this.blockedItems = const {},
    this.gateway = const StoreGateway(),
  });
  final String modeId, answer;
  final Set<String> blockedItems;
  final StoreGateway gateway;
  static Set<String> blockedLetters(String answer, Set<int> revealed) {
    final positions = <int>[];
    var offset = 0;
    for (final letter in answer.characters) {
      if (!RegExp(r"[\s.\-'’]").hasMatch(letter)) positions.add(offset);
      offset += letter.length;
    }
    return {
      if (positions.isNotEmpty && revealed.contains(positions.first))
        'boost_first_letter',
      if (positions.isNotEmpty && revealed.contains(positions.last))
        'boost_last_letter',
    };
  }

  @override
  State<StoreBoostPanel> createState() => _StoreBoostPanelState();
}

class _StoreBoostPanelState extends State<StoreBoostPanel> {
  late final String _roundId = StoreService.newRequestId();
  final Map<String, String> _revealed = {};
  Map<String, int> _stock = {};
  bool _loading = false, _loaded = false, _busy = false;
  String? _error;
  static const _labels = {
    'boost_first_letter': 'İlk harf',
    'boost_last_letter': 'Son harf',
    'boost_anagram': 'Anagram',
  };
  Future<void> _load() async {
    if (!widget.gateway.connected || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await widget.gateway.load();
      if (mounted)
        setState(() {
          _stock = catalog.inventory.map(
            (id, item) => MapEntry(id, item.quantity),
          );
          _loaded = true;
        });
    } catch (_) {
      if (mounted) setState(() => _error = 'Çantan yüklenemedi. Tekrar dene.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _hint(String id) {
    final letters = widget.answer.characters
        .where((c) => !RegExp(r"[\s.\-'’]").hasMatch(c))
        .toList();
    if (letters.isEmpty) return '—';
    if (id == 'boost_first_letter') return letters.first;
    if (id == 'boost_last_letter') return letters.last;
    final original = letters.join();
    letters.shuffle(Random(_roundId.codeUnits.fold<int>(0, (a, b) => a + b)));
    if (letters.join() == original && letters.length > 1)
      letters.add(letters.removeAt(0));
    return letters.join(' · ');
  }

  Future<void> _consume(String id) async {
    if (_busy || _revealed.containsKey(id) || widget.blockedItems.contains(id))
      return;
    setState(() {
      _busy = true;
      _error = null;
    });
    // Block leaving/changing the round while the server decides the debit.
    final navigator = Navigator.of(context, rootNavigator: true);
    final dialog = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text('Destek hazırlanıyor…')),
            ],
          ),
        ),
      ),
    );
    navigator.push(dialog);
    try {
      final remaining = await widget.gateway
          .consume(id, widget.modeId, _roundId)
          .timeout(const Duration(seconds: 20));
      if (mounted)
        setState(() {
          _stock[id] = remaining;
          _revealed[id] = _hint(id);
        });
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Destek doğrulanamadı. Tekrar denediğinde aynı tur için ikinci kez harcanmaz.',
        );
    } finally {
      if (dialog.isActive) navigator.removeRoute(dialog);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _store() async {
    await Navigator.of(context).push<void>(
      LinkballRoute(
        modern: true,
        builder: (_) => StorePage(gateway: widget.gateway),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text('Destek çantam'),
        subtitle: const Text('Mağazadan aldığın tek kullanımlık ipuçları'),
        leading: const Icon(Icons.backpack_outlined),
        onExpansionChanged: (open) {
          if (open && !_loaded) _load();
        },
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (!widget.gateway.connected)
            const Text('Çantanı kullanmak için Google hesabınla giriş yap.'),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(_error!),
            TextButton(
              onPressed: _loading || _busy ? null : _load,
              child: const Text('Çantayı yenile'),
            ),
          ],
          if (_loaded)
            ..._labels.entries.map((entry) {
              final hint = _revealed[entry.key];
              final blocked =
                  widget.blockedItems.contains(entry.key) ||
                  (_revealed.containsKey('boost_anagram') &&
                      entry.key != 'boost_anagram');
              final count = _stock[entry.key] ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hint != null)
                      Text(
                        '${entry.value}: $hint',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    else
                      OutlinedButton(
                        onPressed: _busy || blocked || count == 0
                            ? null
                            : () => _consume(entry.key),
                        child: Text(
                          blocked
                              ? '${entry.value} · zaten açık'
                              : '${entry.value} · 1 adet kullan ($count kalan)',
                        ),
                      ),
                  ],
                ),
              );
            }),
          TextButton.icon(
            onPressed: _busy ? null : _store,
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Mağazaya git'),
          ),
        ],
      ),
    );
  }
}
