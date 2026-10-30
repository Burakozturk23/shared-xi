import '../widgets/paid_hint_button.dart';
import 'dart:async';
import '../services/game_error.dart';
import '../widgets/game_ui.dart';
import 'package:flutter/material.dart';
import '../models/rewarded_ad_models.dart';
import '../services/auth_service.dart';
import '../services/career_transfer_service.dart';
import '../widgets/fake_club_options.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/player_portrait.dart';

List<Map<String, dynamic>> _rows(dynamic value) => (value is List ? value : const []).map(rewardMap).toList();
List<int> _ids(dynamic value) => (value is List ? value : const []).whereType<num>().map((n) => n.toInt()).toList();
const _medals = ['Henüz yok', 'Bronz', 'Gümüş', 'Altın', 'Ustalık'];

class OddClubPage extends StatefulWidget {
  const OddClubPage({super.key, required this.timed, this.service});
  final bool timed;
  final CareerTransferService? service;
  @override
  State<OddClubPage> createState() => _OddClubPageState();
}

class _OddClubPageState extends State<OddClubPage> with WidgetsBindingObserver {
  late final _service = widget.service ?? CareerTransferService(fakeClub: true);
  Map<String, dynamic> _status = {}, _session = {};
  final _scroll = ScrollController();
  final _elapsed = Stopwatch();
  Timer? _ticker;
  StreamSubscription<dynamic>? _auth;
  String? _error, _observedUid;
  bool _busy = true, _accountChanged = false, _resumed = true, _records = false;
  String get _mode => widget.timed ? 'fake_speed' : 'fake_endless';
  String get _subtitle => widget.timed ? 'Hız Serisi' : 'Sonsuz Seri';
  bool get _finished => _session['finished'] == true;
  bool get _answered => _session['answered'] == true;
  bool get _active => _session.isNotEmpty && !_finished;
  int get _now => (_session['serverNow'] as num? ?? 0).toInt() + _elapsed.elapsedMilliseconds;
  int get _seconds => (((_session['deadline'] as num? ?? _now) - _now) / 1000).ceil().clamp(0, 10);
  Map<String, dynamic> get _availability => rewardMap(_status['availability']);

  @override
  void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this);
    _observedUid = AuthService.uid;
    _auth = AuthService.authStateChanges.listen((u) {
      if (_observedUid != null && u?.uid != _observedUid && mounted) {
        setState(() { _accountChanged = true; _status = {}; _session = {}; _error = 'Hesap değişti. Ekranı yeniden aç.'; });
      }
      _observedUid ??= u?.uid;
    });
    _load();
    if (widget.timed) _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || !_resumed || !_active || _answered || _accountChanged) return;
      setState(() {});
      if (_seconds == 0 && !_busy && _error == null) _load();
    });
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); _auth?.cancel(); _ticker?.cancel();
    _elapsed.stop(); _scroll.dispose(); super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed && !_busy && !_accountChanged) _load();
  }
  void _accept(Map<String, dynamic> status) {
    _status = status; _session = rewardMap(status['session']); _elapsed..reset()..start();
  }
  Future<void> _run(Future<void> Function() body) async {
    if (_accountChanged || !mounted) return;
    setState(() { _busy = true; _error = null; });
    try { await body(); } catch (e) {
      if (mounted) setState(() => _error = gameErrorMessage(e));
    } finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _load() => _run(() async {
    final r = await _service.load(_mode);
    if (mounted && !_accountChanged) setState(() => _accept(r));
  });
  Future<void> _start() => _run(() async {
    await _service.mutate('startFakeClub', {'mode': _mode, 'version': _status['version']});
    final r = await _service.load(_mode);
    if (mounted && !_accountChanged) { setState(() { _accept(r); _records = false; }); if (_scroll.hasClients) _scroll.jumpTo(0); }
  });
  Future<void> _act(String action, [Map<String, dynamic> extra = const {}]) => _run(() async {
    final r = await _service.mutate('actFakeClub', {'mode': _mode, 'version': _status['version'],
      'sessionId': _session['id'], 'revision': _session['revision'],
      'questionId': rewardMap(_session['question'])['questionId'], 'action': action, ...extra});
    if (!mounted || _accountChanged) return;
    setState(() { _session = rewardMap(r['session']); _elapsed..reset()..start(); });
    final status = await _service.load(_mode);
    if (mounted && !_accountChanged) setState(() => _accept(status));
    if (action == 'next' && _scroll.hasClients) _scroll.jumpTo(0);
  });
  Future<void> _watch({String? boostId}) => _run(() async {
    await _service.watchHint(_mode, '${_session['id']}', boostId: boostId);
    final r = await _service.load(_mode);
    if (mounted && !_accountChanged) setState(() => _accept(r));
  });
  Future<void> _finish() async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Oturumu bitir?'), content: const Text('Rekorların korunur. Yeni oturum enerji kuralına tabidir. Geri dönersen bu oyuna 24 saat içinde devam edebilirsin.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Devam et')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Bitir'))]));
    if (yes == true && mounted) await _act('finish');
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(toolbarHeight: MediaQuery.textScalerOf(context).scale(16) > 24 ? 96 : 64, title: const Text('Sahte Kulüp', maxLines: 2), actions: [
      IconButton(tooltip: 'Kulüp Dedektifi', onPressed: _busy || _accountChanged ? null : () => setState(() => _records = !_records), icon: const Icon(Icons.workspace_premium_outlined)),
      IconButton(tooltip: 'Yenile', onPressed: _busy || _accountChanged ? null : _load, icon: const Icon(Icons.refresh)),
    ]),
    body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640),
      child: ListView(controller: _scroll, padding: const EdgeInsets.all(16), children: [
        if (_busy) const LinearProgressIndicator(),
        if (_status.isEmpty) ...[const GameIntro(icon: Icons.policy_outlined, title: 'Dört kulüp. Biri sahte.',
          message: 'Futbolcunun kariyerini incele ve oynamadığı kulübü bul.'), const SizedBox(height: 16)],
        if (_error != null) GameErrorPanel(message: _error!, accountChanged: _accountChanged, onRetry: _busy ? null : _load),
        if (_status.isNotEmpty) ...[
          Wrap(spacing: 12, runSpacing: 8, children: [Chip(label: Text(_subtitle)), Chip(label: Text('${_status['coins']} Link Coin')),
            Chip(label: Text('${rewardMap(_status['energy'])['available'] ?? '—'} enerji'))]),
          const SizedBox(height: 12),
          if (_records) ..._recordPanel() else if (_session.isEmpty) ..._home() else ..._game(),
        ],
      ])))));
  List<Widget> _home() => [
    PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.policy_outlined, size: 40), const SizedBox(height: 12),
      Text('Dört kulüp. Biri sahte.', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 12),
      Text(widget.timed ? '10 soru, her soruya 10 saniye ve 3 can. İlk 3 saniyedeki doğru cevap Hız Bonusu kazandırır. Yardım yok.' :
        'Süresiz oyna. Üç canın var; yanlış cevap seriyi sıfırlar. Seri uzadıkça sorular zorlaşır.'),
      const SizedBox(height: 12),
      if (!widget.timed) const Text('Oturumda 1 ücretsiz 50/50 ve en fazla 2 Kariyer İzi. İzler doğrulanmış reklam veya mevcut destek stoğuyla açılır.'),
      const Text('Oyun puanı Coin değildir. Tek seferlik rozetler ve ortak günlük görev Link Coin / XP kazandırır.'),
      const SizedBox(height: 8), Text(_status['energyCost'] == 1 ? 'Yeni oturum: 1 enerji. Devam etmek ücretsiz.' : 'Enerji sistemi şu anda kapalı; yeni oturum ücretsiz.'),
      const Text('Oyun 24 saat saklanır. Hız Serisi saati arka planda durmaz.'),
      if (_availability['solo'] != true) const Text('Bu mod test aşamasında. Açıldığında buradan başlayabilirsin.'),
      if (_availability['rewards'] != true) const Text('Bu test aşamasında Coin / XP kazanımı kapalı.'),
      if (_status['linked'] != true) const Text('Rozet hakların saklanır. Cüzdana aktarılması için bu hesabı Google ile bağla.'),
    ])), const SizedBox(height: 16),
    FilledButton(onPressed: _busy || _availability['solo'] != true ? null : _start, child: Text('$_subtitle başlat')),
    const SizedBox(height: 12), ..._recordPanel(compact: true),
  ];
  List<Widget> _game() {
    final q = rewardMap(_session['question']), player = rewardMap(q['player']);
    final locked = _busy || _finished || _answered || widget.timed && _seconds == 0;
    return [
      Text(_finished ? 'Oturum tamamlandı' : 'Hangi kulüpte oynamadı?', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8), Wrap(spacing: 14, runSpacing: 8, children: [
        Text('Can ${_session['lives']} / 3'), Text('Seri ${_session['streak']}'), Text('${_session['score']} puan'),
        if (widget.timed) Text('Soru ${_session['questionNumber']} / 10 · $_seconds sn'),
        Text({'easy': 'Kolay', 'normal': 'Normal', 'hard': 'Zor', 'legend': 'Efsane'}[q['difficulty']] ?? ''),
      ]), const SizedBox(height: 16),
      PitchPanel(child: Row(children: [
        SizedBox(width: 64, height: 64, child: PlayerPortrait(playerId: (player['id'] as num? ?? 0).toInt(), size: 64, fallback: const Icon(Icons.person_outline, size: 48))),
        const SizedBox(width: 12), Expanded(child: Text('${player['name']}', style: Theme.of(context).textTheme.titleLarge)),
      ])), const SizedBox(height: 16),
      FakeClubOptions(options: _rows(q['options']), onSelected: locked ? null : (id) => _act('answer', {'clubId': id}),
        selectedId: (_session['selectedId'] as num?)?.toInt(), fakeClubId: (_session['fakeClubId'] as num?)?.toInt(),
        eliminated: _ids(_session['eliminated']), confirmed: _ids(_session['confirmed'])),
      if (_answered || _finished) PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_answered) Row(children: [Icon(_session['wasCorrect'] == true ? Icons.check_circle_outline : Icons.cancel_outlined), const SizedBox(width: 8),
          Expanded(child: Text(_session['wasCorrect'] == true ? '${_session['quick'] == true ? 'Hız Bonusu · ' : 'Doğru · '}+${_session['points']} puan' :
            _session['selectedId'] == null ? 'Süre doldu · bir can kaybı' : 'Bu kulüpte oynadı · bir can kaybı'))]),
        const SizedBox(height: 8), Text('${_session['explanation']}'),
        ExpansionTile(tilePadding: EdgeInsets.zero, title: const Text('Kaynak ve kapsam'), children: [
          const Text('Kiralık dönemler dahil A takım kariyeri. Altyapı ve teknik direktörlük hariç.'),
          for (final source in (rewardMap(_session['evidence'])['sources'] as List? ?? const [])) SelectableText('$source'),
        ]),
      ])),
      if (!_finished) ...[
        if (_answered) Padding(padding: const EdgeInsets.only(top: 16), child: FilledButton(onPressed: _busy ? null : () => _act('next'), child: const Text('Sonraki soru'))),
        if (!widget.timed && !_answered) ..._help(locked),
        TextButton(onPressed: _busy ? null : _finish, child: const Text('Oturumu bitir')),
      ] else ...[
        const SizedBox(height: 16), PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_session['reason']}'), Text('${_session['correct']} doğru · ${_session['answers']} cevap · en uzun seri ${_session['bestStreak']}'),
          Text('${_session['hintsUsed']} yardım · ${_session['earnedCoins']} Link Coin / ${_session['earnedXp']} XP rozet hakkı'),
          const Text('Günlük görev ve ömür boyu rozetler Kulüp Dedektifi bölümünde.'),
        ])), const SizedBox(height: 12),
        FilledButton(onPressed: _busy || _availability['solo'] != true ? null : _start, child: const Text('Yeni oturum başlat')),
        for (final item in _rows(_session['history'])) ExpansionTile(title: Text('${rewardMap(item['player'])['name']}'),
          subtitle: Text(item['correct'] == true ? 'Doğru · ${item['points']} puan' : 'Yanlış / süre doldu'),
          children: [Padding(padding: const EdgeInsets.all(12), child: Text('${item['explanation']}'))]),
      ],
    ];
  }
  List<Widget> _help(bool locked) => rewardMap(_session['support'])['version'] == 1 ? [
    const SizedBox(height: 12),
    if (_session['free5050'] == true)
      PaidHintButton(session: _session, sku: 'boost_eliminate', label: 'Tek seçenek ele', disabled: locked,
        onUse: (payment) => _act('fifty', payment), onWatch: () => _watch(boostId: 'boost_eliminate')),
    if ((_session['traceRemaining'] as num? ?? 0) > 0 && _session['traceAvailable'] == true)
      PaidHintButton(session: _session, sku: 'boost_connection', label: 'Kariyer İzi', disabled: locked,
        onUse: (payment) => _act('trace', payment), onWatch: () => _watch(boostId: 'boost_connection')),
  ] : [
    const SizedBox(height: 12),
    OutlinedButton.icon(onPressed: locked || _session['free5050'] != true ? null : () => _act('fifty'),
      icon: const Icon(Icons.filter_2), label: Text(_session['free5050'] == true ? '50/50 · oturumda 1 ücretsiz' : '50/50 kullanıldı')),
    if ((_session['traceRemaining'] as num? ?? 0) > 0 && _session['traceAvailable'] == true) ...[
      if ((_session['adCredits'] as num? ?? 0) > 0)
        OutlinedButton.icon(onPressed: locked ? null : () => _act('trace'), icon: const Icon(Icons.verified_outlined), label: const Text('Kariyer İzi aç'))
      else OutlinedButton.icon(onPressed: locked ? null : _watch, icon: const Icon(Icons.play_circle_outline), label: const Text('Reklam izle · Kariyer İzi')),
      for (final b in _rows(_status['inventory']).where((b) => (b['quantity'] as num? ?? 0) > 0))
        TextButton(onPressed: locked ? null : () => _act('trace', {'boost': b['id']}), child: Text('Mevcut desteği kullan · ${b['quantity']} adet')),
    ],
  ];
  List<Widget> _recordPanel({bool compact = false}) => [
    Text('Kulüp Dedektifi', style: Theme.of(context).textTheme.titleLarge),
    for (final entry in {'fake_endless': 'Sonsuz Seri', 'fake_speed': 'Hız Serisi'}.entries)
      PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${entry.value} · ${_medals[(rewardMap(_status['medals'])[entry.key] as num? ?? 0).toInt().clamp(0, 4)]}'),
        Text('Rekor ${rewardMap(rewardMap(_status['records'])[entry.key])['bestScore'] ?? 0} puan · ${rewardMap(rewardMap(_status['records'])[entry.key])['bestStreak'] ?? 0} seri'),
        if (!compact) Text('${rewardMap(rewardMap(_status['records'])[entry.key])['answers'] ?? 0} geçerli cevap · ${rewardMap(rewardMap(_status['records'])[entry.key])['hintsUsed'] ?? 0} yardım'),
      ])),
    const SizedBox(height: 8), const Text('Günlük görev: 5 ardışık doğru veya Hız Serisi’nde 7 doğru. Ortak günde 1 kez 2 Link Coin / 4 XP; genel günlük görev sınırına dahildir.'),
    Text(rewardMap(_status['daily'])['status'] == 'paid' ? 'Bugünün görevi ödendi.' : rewardMap(_status['daily'])['status'] == 'pending' ? 'Görev tamamlandı. Hesap bağlantısı ve ortak günlük sınır uygun olduğunda ödenir.' : 'Bugünün görevi henüz tamamlanmadı.'),
    const SizedBox(height: 8),
    const Text('Sonsuz: 5 / 10 / 20 / ipucusuz 30 seri → 2 / +3 / +3 / +4 Coin. Hız: tamamlanan 10 soruda 5 / 8 / 9 / 10 doğru → 1 / +2 / +2 / +3 Coin. XP iki katıdır. Rozet başına tek ödeme.'),
    if ((_status['pendingCoins'] as num? ?? 0) > 0) Text('Bekleyen rozet: ${_status['pendingCoins']} Link Coin'),
    if (!compact) TextButton(onPressed: () => setState(() => _records = false), child: const Text('Oyuna dön')),
  ];
}
