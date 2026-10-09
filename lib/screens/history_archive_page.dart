import 'dart:async';

import 'package:flutter/material.dart';

import '../models/history_record.dart';
import '../services/history/history_repository.dart';

class HistoryArchiveButton extends StatelessWidget {
  const HistoryArchiveButton({super.key, this.scope = HistoryScope.all});
  final HistoryScope scope;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Maç ve kadro arşivi',
    icon: const Icon(Icons.history),
    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => HistoryArchivePage(initialScope: scope),
    )),
  );
}

class HistoryArchivePage extends StatefulWidget {
  const HistoryArchivePage({super.key, this.initialScope = HistoryScope.all, this.repository});
  final HistoryScope initialScope;
  final HistoryRepository? repository;
  @override
  State<HistoryArchivePage> createState() => _HistoryArchivePageState();
}

class _HistoryArchivePageState extends State<HistoryArchivePage> {
  late final HistoryRepository _repository = widget.repository ?? SqliteHistoryRepository.instance;
  late HistoryScope _scope = widget.initialScope;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final List<HistoryRecord> _records = [];
  Timer? _debounce;
  bool _squads = false, _loading = true, _more = true, _error = false;
  int _generation = 0;

  @override
  void initState() { super.initState(); _load(reset: true); }

  Future<void> _load({required bool reset}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true; _error = false;
      if (reset) { _records.clear(); _more = true; }
    });
    if (reset && _scroll.hasClients) _scroll.jumpTo(0);
    try {
      final records = await _repository.browse(squads: _squads, scope: _scope, query: _search.text, offset: _records.length);
      if (!mounted || generation != _generation) return;
      setState(() {
        _records.addAll(records); _more = records.length == SqliteHistoryRepository.pageSize; _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() { _loading = false; _error = true; });
    }
  }

  void _changed() {
    _debounce?.cancel();
    ++_generation; // A pending request must not publish results for old input.
    setState(() { _records.clear(); _loading = true; _error = false; });
    _debounce = Timer(const Duration(milliseconds: 300), () => _load(reset: true));
  }

  @override
  void dispose() { _debounce?.cancel(); _search.dispose(); _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Futbol arşivi'), actions: [IconButton(tooltip: 'Seçili 37 maç', icon: const Icon(Icons.bookmarks_outlined), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => HistorySelectionPage(repository: _repository))))]),
    body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: TextField(
        controller: _search, onChanged: (_) => _changed(),
        decoration: InputDecoration(labelText: 'Takım, turnuva veya sezon ara', prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(tooltip: 'Aramayı temizle', icon: const Icon(Icons.clear), onPressed: () { _search.clear(); _changed(); })),
      )),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: DropdownButtonFormField<HistoryScope>(
        initialValue: _scope, isExpanded: true,
        decoration: const InputDecoration(labelText: 'Kapsam'),
        items: [
          const DropdownMenuItem(value: HistoryScope.all, child: Text('Tüm arşiv')),
          DropdownMenuItem(value: HistoryScope.championsLeague, child: Text(_squads ? 'Kulüp kadroları' : 'Şampiyonlar Ligi')),
          const DropdownMenuItem(value: HistoryScope.international, child: Text('Millî takımlar')),
        ],
        onChanged: (scope) { if (scope == null) return; _debounce?.cancel(); _scope = scope; _load(reset: true); },
      )),
      Wrap(spacing: 12, children: [
        ChoiceChip(label: const Text('Maçlar'), selected: !_squads, onSelected: (_) { _debounce?.cancel(); _squads = false; _load(reset: true); }),
        ChoiceChip(label: const Text('Sezon kadroları'), selected: _squads, onSelected: (_) { _debounce?.cancel(); _squads = true; _load(reset: true); }),
      ]),
      Expanded(child: ListView.builder(
        controller: _scroll, padding: const EdgeInsets.all(16), itemCount: _records.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) return Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(
            _squads ? 'Sezon ve turnuva kadrolarıdır. Maçın ilk 11’ini göstermez.' : 'Tarihsel sonuçlar ve mevcut gol kayıtları. Bazı maçlarda ayrıntılar eksiktir.',
            style: Theme.of(context).textTheme.bodySmall,
          ));
          if (index == _records.length + 1) {
            if (_loading) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
            if (_error) return Column(children: [
              const Text('Arşiv açılamadı. Mobil uygulamada yeniden deneyebilirsin.'),
              TextButton(onPressed: () => _load(reset: _records.isEmpty), child: const Text('Yeniden dene')),
            ]);
            if (_records.isEmpty) return const Padding(padding: EdgeInsets.all(24), child: Text('Bu aramada kayıt bulunamadı.'));
            if (_more) return TextButton(onPressed: () => _load(reset: false), child: const Text('Daha fazla göster'));
            return const SizedBox(height: 24);
          }
          final record = _records[index - 1];
          return Card(child: ListTile(
            title: Text(record.title),
            subtitle: Text(_squads ? record.text('context') : '${record.text('date')} · ${record.text('competition')}\n${record.score}${record.conflicted ? ' · Kaynaklar çelişiyor' : ''}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => HistoryDetailPage(id: record.id, squads: _squads, repository: _repository))),
          ));
        },
      )),
    ])),
  );
}

class HistoryDetailPage extends StatefulWidget {
  const HistoryDetailPage({super.key, required this.id, required this.squads, required this.repository});
  final String id;
  final bool squads;
  final HistoryRepository repository;
  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> {
  late Future<HistoryDetail> _future = widget.repository.detail(widget.id, squads: widget.squads);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.squads ? 'Sezon kadrosu' : 'Maç kaydı')),
    body: FutureBuilder<HistoryDetail>(future: _future, builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: TextButton(onPressed: () => setState(() { _future = widget.repository.detail(widget.id, squads: widget.squads); }), child: const Text('Kayıt açılamadı. Yeniden dene')));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final detail = snapshot.data!;
      final record = detail.record;
      return ListView(padding: const EdgeInsets.all(20), children: [
        Text(record.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        if (widget.squads) ...[
          Text(record.text('context')),
          const SizedBox(height: 12),
          const Text('Bu liste sezon veya turnuva kadrosudur; ilk 11, forma giyme ya da güncel transfer bilgisi olarak kullanılamaz.'),
          for (final status in ['listed', 'past']) ...[
            const SizedBox(height: 20),
            Text(status == 'listed' ? 'Kadrodaki oyuncular' : 'Kaynakta eski oyuncular', style: Theme.of(context).textTheme.titleMedium),
            for (final player in detail.players.where((p) => p.text('status') == status)) ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${player.text('shirt')}  ${player.text('name')}'.trim()),
              subtitle: Text([
                [player.text('nationality'), player.text('position'), player.text('birth_date_text')].where((x) => x.isNotEmpty).join(' · '),
                if (player.text('related_club').isNotEmpty) '${_relation(player.text('relation'))}: ${player.text('related_club')}',
              ].where((x) => x.isNotEmpty).join('\n')),
            ),
          ],
        ] else ...[
          Text('${record.text('date')} · ${record.text('competition')}'),
          const SizedBox(height: 12),
          Text(record.score, style: Theme.of(context).textTheme.headlineLarge),
          Text(record.text('score_basis') == 'including_extra_time' ? 'Sonuç uzatma dâhil, penaltı serisi hariçtir.' : record.text('score_basis') == '90_minutes' ? 'Normal süre sonucu' : 'Kaynağın maç sonucu; normal süre / uzatma ayrımı belirtilmemiş olabilir.'),
          if (record.has('ht_home')) Text('İlk yarı: ${record.number('ht_home')}–${record.number('ht_away')}'),
          if (record.has('et_home')) Text('Uzatma sonu: ${record.number('et_home')}–${record.number('et_away')}'),
          if (record.has('pen_home')) Text('Penaltı serisi: ${record.number('pen_home')}–${record.number('pen_away')}'),
          if (record.has('shootout_winner')) Text('Penaltı galibi: ${record.text('shootout_winner')}'),
          if (record.conflicted) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Kaynakların sonuçları çelişiyor. Bu maç otomatik soru üretimi için uygun değildir.')),
          const SizedBox(height: 20),
          Text('Gol kayıtları', style: Theme.of(context).textTheme.titleMedium),
          if (detail.goals.isEmpty) const Text('Bu maç için gol ayrıntısı sağlanmamış.')
          else if (record.number('goals_complete') != 1) const Text('Gol listesi eksik olabilir; sonuçla tam olarak doğrulanamadı.'),
          for (final goal in detail.goals) ListTile(contentPadding: EdgeInsets.zero,
            title: Text(goal.text('scorer')),
            subtitle: Text('${goal.text('team')} · ${goal.has('minute') ? "${goal.text('minute')}′" : 'Dakika bilinmiyor'}${goal.number('own_goal') == 1 ? ' · Kendi kalesine' : ''}${goal.number('penalty') == 1 ? ' · Penaltı' : ''}'),
          ),
          const SizedBox(height: 12),
          const Text('Bu arşivde StatsBomb olay verisi ve maça özel ilk 11 bulunmuyor.'),
        ],
        const Divider(height: 32),
        Text('Kaynaklar', style: Theme.of(context).textTheme.titleMedium),
        for (final source in detail.sources) Padding(padding: const EdgeInsets.only(top: 8), child: SelectableText('${source.text('name')} · ${source.text('license')}\n${source.text('url')}')),
      ]);
    }),
  );

  String _relation(String relation) => switch (relation) {
    'Previous Club' => 'Önceki kulüp', 'New Club' => 'Sonraki kulüp', 'Current Club' => 'Kaydın kulübü', _ => 'Kulüp',
  };
}

class HistorySelectionPage extends StatefulWidget {
  const HistorySelectionPage({super.key, required this.repository});
  final HistoryRepository repository;
  @override
  State<HistorySelectionPage> createState() => _HistorySelectionPageState();
}

class _HistorySelectionPageState extends State<HistorySelectionPage> {
  late Future<List<HistoryRecord>> _future = widget.repository.selections();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Seçili 37 maç')),
    body: FutureBuilder<List<HistoryRecord>>(future: _future, builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: TextButton(onPressed: () => setState(() { _future = widget.repository.selections(); }), child: const Text('Yeniden dene')));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      return ListView(padding: const EdgeInsets.all(16), children: [
        const Padding(padding: EdgeInsets.only(bottom: 16), child: Text('StatsBomb paketindeki maç seçkisi. Olay ve ilk 11 dosyaları paket içinde bulunmuyor. Bağlı sonuçlar diğer tarihsel kaynaklardan gelir.')),
        for (final record in snapshot.data!) Card(child: ListTile(
          title: Text(record.text('title')),
          subtitle: Text('${record.text('date')} · ${record.has('match_id') ? 'Arşiv sonucu mevcut' : 'Yalnızca katalog kaydı'}'),
          trailing: record.has('match_id') ? const Icon(Icons.chevron_right) : null,
          onTap: record.has('match_id') ? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => HistoryDetailPage(id: record.text('match_id'), squads: false, repository: widget.repository))) : null,
        )),
      ]);
    }),
  );
}
