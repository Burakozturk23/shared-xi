import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../models/rewarded_ad_models.dart';
import '../services/auth_service.dart';
import '../services/career_transfer_service.dart';
import '../widgets/friend_match_invite_button.dart';
import '../widgets/pitch_ui.dart';
import 'online_mode_catalog.dart';

List<Map<String, dynamic>> _rows(dynamic v) => (v is List ? v : const []).map(rewardMap).toList();
class CareerTransferOnlinePage extends StatefulWidget {
  const CareerTransferOnlinePage({super.key, required this.mode, this.ranked = false, this.joinCode, this.service});
  final String mode;
  final bool ranked;
  final String? joinCode;
  final CareerTransferService? service;
  @override
  State<CareerTransferOnlinePage> createState() => _CareerTransferOnlinePageState();
}
class _CareerTransferOnlinePageState extends State<CareerTransferOnlinePage> with WidgetsBindingObserver {
  late final _service = widget.service ?? CareerTransferService(mysteryChain: widget.mode == 'mystery_duel');
  Map<String, dynamic> _room = {};
  String _version = '';
  String? _error;
  bool _busy = true, _polling = false, _resumed = true, _canPop = false, _accountChanged = false;
  final _code = TextEditingController(), _query = TextEditingController();
  Timer? _timer, _debounce;
  StreamSubscription<dynamic>? _auth;
  int _searchGeneration = 0, _mutationEpoch = 0;
  String? _observedUid;
  List<Map<String, dynamic>> _results = [], _order = [];
  dynamic _selected;
  DateTime _received = DateTime.now();
  bool get _playing => _room['status'] == 'playing';
  bool get _waiting => _room['status'] == 'waiting';
  bool get _finished => ['finished', 'forfeit', 'cancelled'].contains(_room['status']);
  bool get _mystery => widget.mode == 'mystery_duel';
  bool get _career => widget.mode == 'career_race';
  int get _now => (_room['serverNow'] as num? ?? 0).toInt() + DateTime.now().difference(_received).inMilliseconds;
  @override
  void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this);
    _observedUid = AuthService.uid;
    _auth = AuthService.authStateChanges.listen((u) {
      if (_observedUid != null && _observedUid != u?.uid && mounted) setState(() {
        _accountChanged = true; _room = {}; _error = 'Hesap değişti. Ekranı yeniden aç.';
      });
      _observedUid ??= u?.uid;
    });
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _resumed) { setState(() {}); if (!_busy && !_polling && (_playing || _waiting)) _poll(); }
    });
  }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); _auth?.cancel(); _timer?.cancel(); _debounce?.cancel(); _code.dispose(); _query.dispose(); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { _resumed = state == AppLifecycleState.resumed; }
  void _accept(Map<String, dynamic> room) {
    final changed = room['id'] != _room['id'] || room['round'] != _room['round'] ||
      rewardMap(room['question'])['kind'] != rewardMap(_room['question'])['kind'];
    _room = room; _received = DateTime.now();
    if (changed) { _order = _rows(rewardMap(room['question'])['options']); _selected = null; _results = []; _query.clear(); _searchGeneration++; }
  }
  Future<void> _run(Future<void> Function() body) async {
    if (_accountChanged) return;
    _mutationEpoch++;
    setState(() { _busy = true; _error = null; });
    try { await body(); } catch (e) {
      if (mounted) setState(() => _error = e is FirebaseFunctionsException ? e.message : e.toString().replaceFirst('Bad state: ', ''));
    } finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _load() => _run(() async {
    final status = await _service.onlineLoad(widget.mode);
    if (!mounted || _accountChanged) return;
    setState(() { _version = '${status['version']}'; _accept(rewardMap(status['room'])); });
    if (_room.isEmpty && widget.joinCode != null) await _enterImpl('join', code: widget.joinCode);
  });
  Future<void> _enterImpl(String action, {String? code}) async {
    final r = await _service.mutate('enterCareerTransferOnline', {'mode': widget.mode, 'version': _version,
      'action': action, if (code != null) 'code': code.trim().toUpperCase()});
    if (mounted && !_accountChanged) setState(() => _accept(rewardMap(r['room'])));
  }
  Future<void> _enter(String action, {String? code}) => _run(() => _enterImpl(action, code: code));
  Future<void> _poll() async {
    if (_accountChanged) return;
    _polling = true;
    final epoch = _mutationEpoch;
    try {
      final r = await _service.poll({'mode': widget.mode, 'version': _version, 'roomId': _room['id'], 'action': 'poll'});
      if (mounted && !_accountChanged && epoch == _mutationEpoch) setState(() => _accept(rewardMap(r['room'])));
    } catch (_) {
      if (mounted) setState(() => _error = 'Bağlantı kesildi. Süre sunucuda ilerliyor; yeniden bağlanılıyor.');
    } finally { _polling = false; }
  }
  Future<void> _answer() => _run(() async {
    final q = rewardMap(_room['question']);
    final r = await _service.mutate('actCareerTransferOnline', {'mode': widget.mode, 'version': _version,
      'roomId': _room['id'], 'action': 'answer', 'round': _room['round'], 'roundToken': _room['roundToken'],
      'answer': q['kind'] == 'order' ? _order.map((x) => x['id']).toList() : _selected});
    if (mounted && !_accountChanged) setState(() => _accept(rewardMap(r['room'])));
  });
  Future<void> _leave() async {
    if (_busy) return;
    if (_playing || _waiting) {
      final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Maçtan ayrıl?'),
        content: Text(_playing ? 'Maç hükmen biter; bu maçtan Coin veya XP verilmez.' : 'Oda veya eşleşme araman iptal edilir.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Kal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ayrıl'))]));
      if (ok != true || !mounted) return;
      await _run(() async {
        final r = await _service.mutate('actCareerTransferOnline', {'mode': widget.mode, 'version': _version,
          'roomId': _room['id'], 'action': 'leave'});
        if (mounted) setState(() => _accept(rewardMap(r['room'])));
      });
      if (_playing || _waiting) return;
    }
    if (mounted) { setState(() => _canPop = true); WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) Navigator.pop(context); }); }
  }
  void _search(String text) {
    _debounce?.cancel(); final generation = ++_searchGeneration;
    setState(() { _results = []; _selected = null; });
    if (text.trim().length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final r = await _service.search({'mode': 'transfer', 'version': _version, 'query': text});
        if (mounted && generation == _searchGeneration && !_accountChanged) setState(() => _results = _rows(r['results']));
      } catch (_) { if (mounted) setState(() => _error = 'Arama tamamlanmadı. Tekrar dene.'); }
    });
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: _canPop, onPopInvokedWithResult: (didPop, _) { if (!didPop) _leave(); },
    child: Scaffold(appBar: AppBar(title: Text(_mystery ? 'Gizem Düellosu' : _career ? 'Kariyer Yarışı' : 'Transfer Düellosu'), actions: [
      if (_waiting && _room['host'] == true && _room['ranked'] != true)
        FriendMatchInviteButton(mode: _mystery ? OnlinePlayMode.mysteryDuel : _career ? OnlinePlayMode.careerRace : OnlinePlayMode.transferDuel, roomCode: '${_room['code']}'),
      IconButton(tooltip: 'Yeniden bağlan', onPressed: _busy || _accountChanged ? null : _load, icon: const Icon(Icons.refresh))]),
      body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          if (_room.isEmpty || _finished) ..._lobby(),
          if (_waiting) PitchPanel(child: Column(children: [
            const CircularProgressIndicator(), const SizedBox(height: 16),
            Text(_room['ranked'] == true ? 'Rakip aranıyor…' : 'Oda kodun: ${_room['code']}', style: Theme.of(context).textTheme.headlineSmall),
            const Text('Oda 5 dakika açık kalır. Eşleşince iki oyuncu aynı anda başlar.'),
            TextButton(onPressed: _busy ? null : _leave, child: const Text('Aramayı iptal et')),
          ])),
          if (_playing) ..._game(),
        ]))))));
  List<Widget> _lobby() => [
    if (_finished) PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_room['status'] == 'forfeit' ? 'Hükmen sonuç' : _room['status'] == 'cancelled' ? 'Oda kapandı' :
        {'win': 'Kazandın', 'draw': 'Berabere', 'loss': 'Rakibin kazandı'}[_room['result']] ?? 'Maç bitti', style: Theme.of(context).textTheme.headlineSmall),
      Text('${rewardMap(_room['mine'])['score'] ?? 0} – ${rewardMap(_room['theirs'])['score'] ?? 0}'),
      Text(_room['rewardEligible'] == true ? 'Günün ilk 5 geçerli dereceli maçı ortak ödül sınırına tabidir.' : 'Bu maçtan Coin / XP / ELO ödülü yok.'),
      if (_room['rewardEligible'] == true) const Text('Galibiyet 3C / 8XP · beraberlik 2C / 6XP · mağlubiyet 1C / 4XP'),
      for (final r in _rows(_room['rounds'])) Padding(padding: const EdgeInsets.only(top: 8),
        child: Text('Tur: ${r['kind']} · ${rewardMap(r['mine'])['correct'] == true ? 'Doğru' : 'Yanlış / süre doldu'} · ${rewardMap(r['mine'])['score'] ?? 0} puan')),
    ])),
    const SizedBox(height: 12),
    Text(_mystery ? '5 gizemli futbolcu · her tur 30 saniye' : _career ? '6 tur · eksik kulüp, kronoloji, gizemli kariyer' : '5 transfer · her tur 30 saniye', style: Theme.of(context).textTheme.titleLarge),
    const Text('Enerji, reklam ve destek yok. Her tur tek kesin cevap. Doğruluk ve hız puan getirir.'),
    if (widget.ranked) FilledButton(onPressed: _busy || _version.isEmpty ? null : () => _enter('ranked'), child: const Text('Dereceli rakip bul')) else ...[
      FilledButton(onPressed: _busy || _version.isEmpty ? null : () => _enter('create'), child: const Text('Arkadaş odası oluştur')),
      TextField(controller: _code, textCapitalization: TextCapitalization.characters, maxLength: 8, decoration: const InputDecoration(labelText: 'Oda kodu')),
      OutlinedButton(onPressed: _busy || _version.isEmpty ? null : () => _enter('join', code: _code.text), child: const Text('Odaya katıl')),
    ],
  ];
  List<Widget> _game() {
    final q = rewardMap(_room['question']); final before = _now < (_room['startsAt'] as num? ?? 0);
    final seconds = (((_room['deadline'] as num? ?? _now) - _now) / 1000).ceil().clamp(0, 30);
    final locked = _busy || _room['submitted'] == true || seconds == 0 || before;
    return [
      Text('Tur ${(_room['round'] as num? ?? 0) + 1} / ${_room['totalRounds']} · $seconds sn', style: Theme.of(context).textTheme.headlineSmall),
      Text('Sen ${rewardMap(_room['mine'])['score'] ?? 0} · Rakip ${rewardMap(_room['theirs'])['score'] ?? 0}'),
      const SizedBox(height: 16),
      if (before || q.isEmpty) const Text('Tur başlıyor…') else ...[
        if (q['kind'] == 'mystery_duel') ...[
          PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${q['country']} · ${q['position']}', style: Theme.of(context).textTheme.titleLarge),
            const Text('10. ve 20. saniyede iki rakibe aynı yeni bilgi açılır.'),
            for (final hint in (q['hints'] as List? ?? const [])) Padding(padding: const EdgeInsets.only(top: 8), child: Text('$hint')),
          ])),
        ],
        if (q['player'] != null) Text('${rewardMap(q['player'])['name']}', style: Theme.of(context).textTheme.titleLarge),
        if (q['route'] is List) Text((q['route'] as List).join(' → ')),
        if (q['kind'] == 'transfer') ...[
          PitchPanel(child: Text('${rewardMap(q['from'])['name']} → ${rewardMap(q['to'])['name']}\n${q['year']}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge)),
          TextField(controller: _query, enabled: !locked, onChanged: _search, decoration: const InputDecoration(labelText: 'Futbolcu ara')),
          for (final p in _results) ListTile(title: Text('${p['name']}'), subtitle: Text('${p['country']}'), selected: _selected == p['id'],
            onTap: locked ? null : () => setState(() => _selected = p['id'])),
        ] else if (q['kind'] == 'order') ...[
          const Text('En eskiden en yeniye sırala'),
          for (var i = 0; i < _order.length; i++) ListTile(title: Text('${i + 1}. ${_order[i]['name']}'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(tooltip: 'Yukarı taşı', onPressed: locked || i == 0 ? null : () => setState(() { final p = _order.removeAt(i); _order.insert(i - 1, p); }), icon: const Icon(Icons.arrow_upward)),
            IconButton(tooltip: 'Aşağı taşı', onPressed: locked || i == _order.length - 1 ? null : () => setState(() { final p = _order.removeAt(i); _order.insert(i + 1, p); }), icon: const Icon(Icons.arrow_downward)),
          ])),
        ] else for (final p in _rows(q['options'])) Card(child: ListTile(title: Text('${p['name']}'), selected: _selected == p['id'],
          leading: Icon(_selected == p['id'] ? Icons.radio_button_checked : Icons.radio_button_off), onTap: locked ? null : () => setState(() => _selected = p['id']))),
        FilledButton(onPressed: locked || q['kind'] != 'order' && _selected == null ? null : _answer, child: const Text('Kesin cevabımı gönder')),
        if (_room['submitted'] == true) const Text('Cevabın kaydedildi. Tur bitince sonuç açıklanacak.'),
        if (_room.containsKey('correct')) Text(_room['correct'] == true ? 'Doğru!' : 'Yanlış / süre doldu'),
      ],
    ];
  }
}
