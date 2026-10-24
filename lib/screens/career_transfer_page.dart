import '../widgets/paid_hint_button.dart';
import 'dart:async';
import '../services/game_error.dart';
import '../widgets/game_ui.dart';
import 'package:flutter/material.dart';
import '../models/rewarded_ad_models.dart';
import '../models/club.dart';
import '../widgets/club_badge.dart';
import '../services/auth_service.dart';
import '../services/career_transfer_service.dart';
import '../widgets/pitch_ui.dart';

List<Map<String, dynamic>> _maps(dynamic v) => (v is List ? v : const []).map(rewardMap).toList();
const _medals = ['Henüz madalya yok', 'Bronz', 'Gümüş', 'Altın', 'Ustalık'];
const _levels = {'beginner': 'Başlangıç · 3–4 dönem', 'normal': 'Normal · 5–7 dönem', 'legend': 'Efsane · 8–12 dönem'};

class CareerTransferPage extends StatefulWidget {
  const CareerTransferPage({super.key, required this.mode, this.difficulty = 'normal', this.service});
  final String mode, difficulty;
  final CareerTransferService? service;
  @override
  State<CareerTransferPage> createState() => _CareerTransferPageState();
}
class _CareerTransferPageState extends State<CareerTransferPage> with WidgetsBindingObserver {
  late final _service = widget.service ?? CareerTransferService();
  late String _difficulty = widget.difficulty;
  Map<String, dynamic> _status = {}, _session = {};
  List<Map<String, dynamic>> _results = [];
  final _query = TextEditingController();
  Timer? _debounce;
  StreamSubscription<dynamic>? _auth;
  bool _busy = true, _archive = false, _searching = false, _accountChanged = false;
  String? _error;
  int _generation = 0;
  String? _observedUid;
  bool get _career => widget.mode == 'career';
  bool get _finished => _session['finished'] == true;
  bool get _active => _session.isNotEmpty && !_finished;
  String get _version => '${_status['version']}';
  String get _title => _career ? 'Kariyer Bulmacası' : 'Transfer Dedektifi';
  @override
  void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this);
    _observedUid = AuthService.uid;
    _auth = AuthService.authStateChanges.listen((u) {
      if (_observedUid != null && u?.uid != _observedUid && mounted) {
        _generation++;
        setState(() { _accountChanged = true; _status = {}; _session = {}; _results = [];
          _error = 'Hesap değişti. Ekranı kapatıp yeniden aç.'; });
      }
      _observedUid ??= u?.uid;
    });
    _load();
  }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); _auth?.cancel(); _debounce?.cancel(); _query.dispose(); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy && !_accountChanged) _load();
  }
  Future<void> _run(Future<void> Function() body) async {
    if (_accountChanged) return;
    setState(() { _busy = true; _error = null; });
    try { await body(); }
    catch (e) { if (mounted) setState(() => _error = gameErrorMessage(e)); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _load() => _run(() async {
    final s = await _service.load(widget.mode);
    if (mounted && !_accountChanged) setState(() { _status = s; _session = rewardMap(s['session']); _clear(); });
  });
  void _clear() { _generation++; _debounce?.cancel(); _query.clear(); _results = []; _searching = false; }
  Future<void> _start({String? target}) => _run(() async {
    final r = await _service.mutate('startCareerTransfer', {'mode': widget.mode, 'version': _version,
      'difficulty': _difficulty, if (target != null) 'target': target});
    if (mounted && !_accountChanged) setState(() { _session = rewardMap(r['session']); _archive = false; _clear(); });
  });
  Future<void> _act(String action, [Map<String, dynamic> extra = const {}]) => _run(() async {
    final r = await _service.mutate('actCareerTransfer', {'mode': widget.mode, 'version': _version,
      'sessionId': _session['id'], 'revision': _session['revision'], 'action': action, ...extra});
    if (mounted && !_accountChanged) setState(() { _session = rewardMap(r['session']); _status['coins'] = r['coins'] ?? _status['coins'];
      _status['inventory'] = r['inventory'] ?? _status['inventory']; _clear(); });
  });
  Future<void> _skip() async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Bu oyunu bitir?'), content: Text(_career
        ? 'Cevap ve seçili kariyer açılır. Yeni bulmaca enerji sistemi açıkken 1 enerji kullanır.'
        : 'Dosya başarısız kapanır ve seri sıfırlanır. Yeni dosya enerji sistemi açıkken 1 enerji kullanır.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Bitir'))]));
    if (ok == true && mounted) await _act('skip');
  }
  void _search(String value) {
    _debounce?.cancel(); final generation = ++_generation;
    setState(() { _results = []; _searching = value.trim().length >= 2; });
    if (!_searching) return;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final r = await _service.search({'mode': widget.mode, 'version': _version, 'query': value});
        if (mounted && generation == _generation && !_accountChanged) setState(() { _results = _maps(r['results']); _searching = false; });
      } catch (_) {
        if (mounted && generation == _generation) setState(() { _searching = false; _error = 'Arama tamamlanmadı. Hakkın azalmadı.'; });
      }
    });
  }
  Future<void> _watch() => _run(() async {
    await _service.watchHint(widget.mode, '${_session['id']}');
    final r = await _service.load(widget.mode);
    if (mounted && !_accountChanged) setState(() { _status = r; _session = rewardMap(r['session']); });
  });
  Future<void> _hint(String kind, {String? boost}) => _act('hint', {'hint': kind, if (boost != null) 'boost': boost});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(toolbarHeight: MediaQuery.textScalerOf(context).scale(16) > 24 ? 112 : 64, title: Text(_title, maxLines: 3), actions: [
      IconButton(tooltip: 'Arşiv', onPressed: _busy ? null : () async { await _load(); if (mounted) setState(() => _archive = !_archive); }, icon: const Icon(Icons.collections_bookmark_outlined)),
      IconButton(tooltip: 'Yenile', onPressed: _busy || _accountChanged ? null : _load, icon: const Icon(Icons.refresh))]),
    body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (_busy) const LinearProgressIndicator(),
        if (_status.isEmpty) ...[
          GameIntro(icon: _career ? Icons.route_outlined : Icons.travel_explore, title: _title,
            message: _career ? 'Kulüp izlerini takip et, futbolcuyu bul.' : 'İki kulüp ve bir yıl. Transferin gizli ismini bul.'),
          const SizedBox(height: 16),
        ],
        if (_error != null) GameErrorPanel(message: _error!, accountChanged: _accountChanged, onRetry: _busy ? null : _load),
        if (_status.isNotEmpty) ...[
          GameStats(items: [(Icons.toll_outlined, '${_status['coins']} Link Coin'),
            (Icons.bolt_outlined, '${rewardMap(_status['energy'])['available'] ?? '—'} enerji')]),
          if (_archive) ..._collection() else if (_session.isNotEmpty) ..._game() else ..._home(),
        ],
      ])))),
  );
  List<Widget> _home() => [
    GameIntro(icon: _career ? Icons.route_outlined : Icons.travel_explore,
      title: _career ? 'Bir futbolcu. Bir kariyer.' : 'İki kulüp. Bir transfer.',
      message: _career ? 'Futbolcuyu bul, kariyerinden seçilen kulüpleri sırala. Üç tahmin, iki sıralama kontrolü.'
        : 'Kulüp yönü ve yıldan futbolcuyu bul. Her dosyada üç tahmin hakkın var.'),
    const SizedBox(height: 12),
    PitchPanel(child: ExpansionTile(tilePadding: EdgeInsets.zero, title: const Text('Kurallar ve kazanımlar'),
      expandedCrossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_career ? 'Futbolcu başına en fazla 12 Link Coin / 24 XP. Başlangıç seviyesinde ustalık yok.' : 'Transfer başına ilk resmî denemede en fazla 6 Link Coin / 12 XP.'),
      const Text('İki modun ortak ödül sınırı: günde 36 Link Coin / 72 XP. Fazlası bekleyen ödül olarak saklanır.'),
      const Text('1 ücretsiz + 2 reklamlı ipucu; mevcut destek stoğun da aynı üç slotu kullanır.'),
      Text(rewardMap(_status['energy'])['enabled'] == true ? 'Yeni oyun: 1 enerji. 24 saat içinde devam ücretsiz.' : 'Enerji sistemi şu anda kapalı. Yeni oyun ücretsiz.'),
      if (_status['linked'] != true) const Text('Ödüllerin saklanır; cüzdana aktarılması için Google hesabını bağla.'),
    ])), const SizedBox(height: 16),
    if (_career) DropdownButtonFormField<String>(initialValue: _difficulty, isExpanded: true,
      decoration: const InputDecoration(labelText: 'Zorluk'), items: _levels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
      onChanged: _busy ? null : (v) => setState(() => _difficulty = v!)),
    const SizedBox(height: 12), FilledButton(onPressed: _busy ? null : () => _start(), child: Text(_career ? 'Yeni bulmaca' : 'Yeni transfer dosyası')),
  ];
  List<Widget> _game() {
    final stops = _maps(_session['stops']); final transfer = rewardMap(_session['transfer']);
    final ordering = _session['phase'] == 'order';
    final result = rewardMap(_session['result']);
    return [
      GameIntro(icon: _finished ? Icons.task_alt_rounded : _career ? Icons.route_outlined : Icons.travel_explore,
        title: _finished ? 'Dosya tamamlandı' : ordering ? '2 / 2 · Kariyeri sırala' : 'Futbolcuyu bul',
        message: _career ? ordering ? 'Kulüpleri en eski dönemden en yeniye yerleştir.' :
          'Bu kulüplerde forma giyen futbolcuyu keşfet.' : 'Kulüpleri ve transfer yılını incele. Bu yolculuk kime ait?'),
      GameStats(items: [(Icons.favorite_border, 'Tahmin: ${3 - (_session['wrong'] as num? ?? 0)} / 3'),
        if (_career) (Icons.checklist_rounded, 'Kontrol: ${_session['checks']} / 2'),
        (Icons.stars_outlined, 'Puan: ${_session['score']}'),
        if (!_career) (Icons.local_fire_department_outlined, 'Seri: ${_session['streak']}')]),
      if (_career) ...[
        const Text('Kariyerinden seçilen kulüpleri sırala.'),
        if (ordering) const Text('En eskiden en yeniye sürükle. Ok düğmelerini de kullanabilirsin.'),
        ReorderableListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false, itemCount: stops.length,
          onReorder: (old, next) { if (!_busy && ordering) _reorder(stops, old, next > old ? next - 1 : next); },
          itemBuilder: (context, i) {
            final stop = stops[i]; final correctness = _session['correctness'] is List ? _session['correctness'] as List : [];
            return Padding(key: ValueKey<String>('${stop['id']}'), padding: const EdgeInsets.only(bottom: 8),
              child: PitchPanel(padding: const EdgeInsets.all(12), child: Column(children: [
                Row(children: [
                  if (ordering && !_busy) ReorderableDragStartListener(index: i, child: const Padding(
                    padding: EdgeInsets.only(right: 8), child: Icon(Icons.drag_handle))),
                  ClubBadge(club: Club.fromJson(rewardMap(stop['club'])), size: 36),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${rewardMap(stop['club'])['name']}', style: Theme.of(context).textTheme.titleMedium),
                    if (stop['visit'] != null) Text('${stop['visit']}. dönem', style: Theme.of(context).textTheme.bodySmall),
                    if (correctness.length == stops.length) Text(correctness[i] == true ? 'Doğru pozisyon' : 'Yerini değiştir'),
                  ])),
                ]),
                if (ordering) Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  IconButton(tooltip: 'Yukarı taşı', onPressed: _busy || i == 0 ? null : () => _reorder(stops, i, i - 1), icon: const Icon(Icons.arrow_upward)),
                  IconButton(tooltip: 'Aşağı taşı', onPressed: _busy || i == stops.length - 1 ? null : () => _reorder(stops, i, i + 1), icon: const Icon(Icons.arrow_downward)),
                ]),
              ])));
          }),
      ] else PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('TRANSFER DOSYASI · ${transfer['year']}', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 20),
        _transferClub(rewardMap(transfer['from']), 'AYRILDIĞI KULÜP'),
        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Align(
          alignment: Alignment.centerLeft, child: Icon(Icons.south_rounded))),
        _transferClub(rewardMap(transfer['to']), 'KATILDIĞI KULÜP'),
      ])),
      if (!_career && !_finished) Padding(padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('${_session['maskedName'] ?? 'Gizemli futbolcu'}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge)),
      if (_session['player'] != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('${rewardMap(_session['player'])['name']}', style: Theme.of(context).textTheme.headlineSmall)),
      if ('${_session['feedback'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('${_session['feedback']}')),
      if (!_finished && !ordering) ...[
        TextField(controller: _query, enabled: !_busy, onChanged: _search, decoration: const InputDecoration(labelText: 'Futbolcu ara', hintText: 'Ad, soyad veya takma ad'),
          onSubmitted: _busy ? null : (v) => _act('guess', {'answer': v})),
        if (_searching) const LinearProgressIndicator(),
        for (final p in _results) ListTile(title: Text('${p['name']}'), subtitle: Text('${p['country']} · ${p['position']}'),
          onTap: _busy ? null : () => _act('guess', {'playerId': p['id']})),
        const Text('Tanınmayan veya belirsiz isimler tahmin hakkını azaltmaz.'),
      ],
      if (ordering) ...[
        if (_session['found'] != true) const Text('Ödülsüz alıştırma: futbolcu bulunamadı.'),
        FilledButton(onPressed: _busy ? null : () => _act('order', {'order': stops.map((x) => x['id']).toList()}),
          child: Text(_session['checks'] == 0 ? 'İlk kontrol' : 'Son kontrol')),
      ],
      for (final h in _maps(_session['hints'])) ListTile(leading: const Icon(Icons.lightbulb_outline), title: Text('${h['text']}')),
      if (!_finished) ..._help(ordering),
      if (_finished) ...[
        PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_medals[(result['medal'] as num? ?? 0).toInt().clamp(0, 4)]),
          Text('Bu denemede kazanılan: ${result['coins']} Link Coin / ${result['xp']} XP'),
          const Text('Günlük sınırı aşan hakların bekleyen ödüllere aktarılır.'),
          if (!_career) Text('${transfer['date']} · ${transfer['source']}'),
          for (final s in _maps(_session['solution'])) Text('${rewardMap(s['club'])['name']} · ${s['start']} – ${s['end'] ?? 'açık dönem'}'),
        ])),
        const SizedBox(height: 12), FilledButton(onPressed: _busy ? null : () async { await _load(); if (mounted) setState(() => _session = {}); }, child: const Text('Yeni oyun seç')),
      ] else TextButton(onPressed: _busy ? null : _skip, child: Text(_career ? 'Oyunu bitir' : 'Pas geç / dosyayı kapat')),
    ];
  }
  Widget _transferClub(Map<String, dynamic> club, String label) => Row(children: [
    ClubBadge(club: Club.fromJson(club), size: 48), const SizedBox(width: 16),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall), const SizedBox(height: 4),
      Text('${club['name']}', style: Theme.of(context).textTheme.titleLarge),
    ])),
  ]);
  void _reorder(List<Map<String, dynamic>> stops, int old, int next) {
    final order = stops.map((x) => x['id']).toList(); order.insert(next, order.removeAt(old));
    _act('reorder', {'order': order});
  }
  List<Widget> _help(bool ordering) {
    final hints = _maps(_session['hints']);
    if (hints.length >= 3) return [const Text('Bu bulmacanın üç ipucu kullanıldı.')];
    final options = !_career ? {'next': 'Sıradaki ipucu'} : ordering
      ? {'connection': 'Ardışık bağlantı', 'years': 'Yıl aralığı', 'short': 'Kısa dönem'}
      : {'country': 'Milliyet', 'position': 'Mevki'};
    final available = options.entries.where((e) => !hints.any((h) => h['kind'] == e.key)).toList();
    if (rewardMap(_session['support'])['version'] == 1) return [
      const SizedBox(height: 12), Text('Destek çantası · ${hints.length} / 3'),
      for (final e in available) PaidHintButton(session: _session,
        sku: !_career && hints.length == 2 ? 'boost_first_letter' : ordering ? 'boost_connection' : 'boost_basic',
        label: !_career ? ['Ülke bilgisi', 'Mevki bilgisi', 'İlk harf'][hints.length] : e.value,
        disabled: _busy, onUse: (payment) => _act('hint', {'hint': e.key, ...payment}), onWatch: _watch),
    ];
    final credit = _session['freeHint'] == true || (_session['adCredits'] as num? ?? 0) > 0;
    return [const SizedBox(height: 12), Text('İpucu · ${hints.length} / 3'),
      Wrap(spacing: 8, children: [for (final e in available) OutlinedButton(onPressed: _busy || !credit ? null : () => _hint(e.key), child: Text(e.value))]),
      if (!credit && (_session['adRemaining'] as num? ?? 0) > 0) OutlinedButton.icon(onPressed: _busy ? null : _watch,
        icon: const Icon(Icons.play_circle_outline), label: const Text('Reklam izle · 1 ipucu hakkı')),
      for (final b in _maps(_status['inventory']).where((x) => (x['quantity'] as num? ?? 0) > 0))
        TextButton(onPressed: _busy || available.isEmpty ? null : () => _hint(available.first.key, boost: '${b['id']}'),
          child: Text('Destek stoğunu kullan · ${b['quantity']} adet')),
    ];
  }
  List<Widget> _collection() => [
    Text(_career ? 'Kariyer Arşivi' : 'Transfer Dosyaları', style: Theme.of(context).textTheme.headlineSmall),
    Text('Bekleyen ödül: ${_status['pendingCoins']} Link Coin'),
    if (!_career) Text('En uzun seri: ${_status['longestStreak']}'),
    Wrap(spacing: 8, children: [for (final b in _maps(_status['badges'])) Chip(
      avatar: Icon(b['earned'] == true ? Icons.emoji_events : Icons.lock_outline, size: 18),
      label: Text('${b['title']} · ${b['progress']} / ${b['target']}'))]),
    TextButton(onPressed: () => setState(() => _archive = false), child: Text(_active ? 'Oyuna dön · ücretsiz' : 'Oyuna dön')),
    if (_maps(_status['collection']).isEmpty) const Text('Tamamladığın dosyalar burada saklanır.'),
    for (final r in _maps(_status['collection'])) Card(child: ExpansionTile(
      title: Text('${rewardMap(r['player'])['name']}'),
      subtitle: Text('${_medals[(r['medal'] as num? ?? 0).toInt().clamp(0, 4)]} · En iyi puan: ${r['bestScore']}'),
      childrenPadding: const EdgeInsets.all(16), expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_career) for (final s in _maps(r['route'])) Text('${rewardMap(s['club'])['name']} · ${s['start']} – ${s['end'] ?? 'açık dönem'}'),
        if (!_career) Text('${rewardMap(rewardMap(r['transfer'])['from'])['name']} → ${rewardMap(rewardMap(r['transfer'])['to'])['name']} · ${rewardMap(r['transfer'])['date']}'),
        Text('Kaynak: ${r['source']}'),
        Text('İlk deneme: ${rewardMap(r['firstResult'])['wrong'] ?? '—'} yanlış · ${rewardMap(r['firstResult'])['hints'] ?? '—'} ipucu'),
        TextButton(onPressed: _busy || _active ? null : () { _difficulty = '${r['difficulty']}'; _start(target: '${r['id']}'); }, child: const Text('Yeniden oyna · yeni oturum')),
      ])),
  ];
}
