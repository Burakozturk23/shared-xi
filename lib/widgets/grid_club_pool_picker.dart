import 'package:flutter/material.dart';
import '../models/grid_club_pool.dart';

class GridClubPoolPicker extends StatefulWidget {
  const GridClubPoolPicker({super.key});
  @override
  State<GridClubPoolPicker> createState() => _GridClubPoolPickerState();
}
class _GridClubPoolPickerState extends State<GridClubPoolPicker> {
  GridClubPool? _pool;
  @override
  void initState() {
    super.initState();
    GridClubPoolStore.load().then((value) { if (mounted) setState(() => _pool = value); });
  }
  Future<void> _edit() async {
    final selected = await showModalBottomSheet<GridClubPool>(
      context: context, isScrollControlled: true, useSafeArea: true,
      builder: (_) => _PoolSheet(initial: _pool!),
    );
    if (selected != null && mounted) setState(() => _pool = selected);
  }
  @override
  Widget build(BuildContext context) => Card(child: ListTile(
    leading: const Icon(Icons.tune_rounded),
    title: const Text('Kulüp havuzu'),
    subtitle: Text(_pool == null ? 'Yükleniyor…' : '${_pool!.label}\nÜç Grid modunda, yeni oyunlarda geçerli.'),
    trailing: const Icon(Icons.expand_more), onTap: _pool == null ? null : _edit,
  ));
}
class _PoolSheet extends StatefulWidget {
  const _PoolSheet({required this.initial});
  final GridClubPool initial;
  @override
  State<_PoolSheet> createState() => _PoolSheetState();
}
class _PoolSheetState extends State<_PoolSheet> {
  late GridPoolKind _kind = widget.initial.kind;
  late final Set<String> _leagues = {...widget.initial.leagues};
  bool _saving = false;
  String? _error;
  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    final pool = GridClubPool(kind: _kind, leagues: Set.unmodifiable(_leagues));
    try {
      await GridClubPoolStore.save(pool);
      if (mounted) Navigator.pop(context, pool);
    } catch (_) {
      if (mounted) setState(() { _saving = false; _error = 'Kaydedilemedi. Tekrar dene.'; });
    }
  }
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: FractionallySizedBox(heightFactor: .85, child: SafeArea(child: ListView(
      padding: const EdgeInsets.all(24), children: [
        Text('Kulüp havuzunu seç', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('Seçimin sorulardaki kulüpleri belirler. Kriterleri sağlayan tüm futbolcu cevapları geçerlidir.'),
        for (final entry in const {
          GridPoolKind.popular: 'Popüler kulüpler',
          GridPoolKind.leagues: 'Lig seç', GridPoolKind.broad: 'Geniş havuz',
        }.entries)
          ListTile(contentPadding: EdgeInsets.zero,
            leading: Icon(_kind == entry.key ? Icons.radio_button_checked : Icons.radio_button_unchecked),
            title: Text(entry.value), subtitle: entry.key == GridPoolKind.broad ? const Text('Daha az bilinen kulüpler de çıkabilir.') : null,
            onTap: _saving ? null : () => setState(() => _kind = entry.key)),
        if (_kind == GridPoolKind.leagues) ...[
          const Text('Bir veya daha fazla lig seç.'),
          Wrap(spacing: 8, runSpacing: 4, children: [for (final entry in GridClubPool.labels.entries)
            FilterChip(label: Text(entry.value), selected: _leagues.contains(entry.key),
              onSelected: _saving ? null : (value) => setState(() { value ? _leagues.add(entry.key) : _leagues.remove(entry.key); }))]),
        ],
        if (_error != null) Text(_error!),
        const SizedBox(height: 20),
        FilledButton(onPressed: _saving || (_kind == GridPoolKind.leagues && _leagues.isEmpty) ? null : _save,
          child: Text(_saving ? 'Kaydediliyor…' : 'Uygula')),
      ],
    ))),
  );
}
