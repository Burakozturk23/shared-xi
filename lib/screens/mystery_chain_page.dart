import '../widgets/paid_hint_button.dart';
import '../app/app_feedback.dart';
import 'dart:async';
import '../services/game_error.dart';
import '../widgets/game_ui.dart';
import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/rewarded_ad_models.dart';
import '../services/auth_service.dart';
import '../services/career_transfer_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/club_badge.dart';
import '../widgets/hub_ui.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/share_result.dart';

List<Map<String, dynamic>> _rows(dynamic value) =>
    (value is List ? value : const []).map(rewardMap).toList();
const _medals = ['Kilitli', 'Bronz', 'Gümüş', 'Altın', 'Ustalık'];
// Mystery levels follow how well known the player is; '' is the mix.
const _levels = {
  '': 'Karışık',
  'easy': 'Kolay',
  'medium': 'Orta',
  'hard': 'Zor',
};
const _streakNames = {'streak_5': '5 seri', 'streak_10': '10 seri'};

class MysteryChainPage extends StatefulWidget {
  const MysteryChainPage({super.key, required this.mode, this.service});
  final String mode;
  final CareerTransferService? service;
  @override
  State<MysteryChainPage> createState() => _MysteryChainPageState();
}

class _MysteryChainPageState extends State<MysteryChainPage>
    with WidgetsBindingObserver {
  late final _service =
      widget.service ?? CareerTransferService(mysteryChain: true);
  Map<String, dynamic> _status = {}, _session = {};
  List<Map<String, dynamic>> _results = [], _clubs = [];
  Map<String, dynamic>? _selected;
  String _level = '';
  final _query = TextEditingController(), _clubQuery = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce, _ticker;
  StreamSubscription<dynamic>? _auth;
  DateTime _received = DateTime.now();
  bool _busy = true,
      _archive = false,
      _searching = false,
      _accountChanged = false,
      _resumed = true;
  int _generation = 0;
  String? _error, _observedUid;
  bool get _mystery => widget.mode == 'mystery';
  bool get _sprint => widget.mode == 'blitz';
  bool get _finished => _session['finished'] == true;
  bool get _active => _session.isNotEmpty && !_finished;
  String get _title => _mystery
      ? 'Gizemli Futbolcu'
      : _sprint
      ? 'Zincir Sprinti'
      : 'Zincir Ustalığı';
  String get _version => '${_status['version']}';
  int get _serverNow =>
      (_session['serverNow'] as num? ?? 0).toInt() +
      DateTime.now().difference(_received).inMilliseconds;
  int get _seconds =>
      (((_session['endAt'] as num? ?? _serverNow) - _serverNow) / 1000)
          .ceil()
          .clamp(0, 75);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _observedUid = AuthService.uid;
    _auth = AuthService.authStateChanges.listen((u) {
      if (_observedUid != null && u?.uid != _observedUid && mounted) {
        setState(() {
          _accountChanged = true;
          _status = {};
          _session = {};
          _clear();
          _error = 'Hesap değişti. Ekranı yeniden aç.';
        });
      }
      _observedUid ??= u?.uid;
    });
    _load();
    if (_sprint)
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_resumed || !_active || _accountChanged) return;
        setState(() {});
        if (_seconds == 0 && !_busy && _error == null) _load();
      });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth?.cancel();
    _debounce?.cancel();
    _ticker?.cancel();
    _query.dispose();
    _clubQuery.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed && !_busy && !_accountChanged) _load();
  }

  void _clear() {
    _generation++;
    _debounce?.cancel();
    _query.clear();
    _clubQuery.clear();
    _results = [];
    _clubs = [];
    _selected = null;
    _searching = false;
  }

  void _accept(Map<String, dynamic> session) {
    _session = session;
    _received = DateTime.now();
    _clear();
  }

  Future<void> _run(Future<void> Function() body) async {
    if (_accountChanged) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await body();
    } catch (e) {
      if (mounted) setState(() => _error = gameErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() => _run(() async {
    final r = await _service.load(widget.mode);
    if (mounted && !_accountChanged)
      setState(() {
        _status = r;
        _accept(rewardMap(r['session']));
      });
  });
  Future<void> _start({String? target, bool daily = false}) => _run(() async {
    await _service.mutate('startMysteryChain', {
      'mode': widget.mode,
      'version': _version,
      if (target != null) 'target': target,
      if (daily) 'daily': true,
      if (_mystery && !daily && target == null && _level.isNotEmpty)
        'difficulty': _level,
    });
    final r = await _service.load(widget.mode);
    if (mounted && !_accountChanged)
      setState(() {
        _status = r;
        _accept(rewardMap(r['session']));
        _archive = false;
      });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  });
  Future<void> _act(String action, [Map<String, dynamic> extra = const {}]) =>
      _run(() async {
        final r = await _service.mutate('actMysteryChain', {
          'mode': widget.mode,
          'version': _version,
          'sessionId': _session['id'],
          'revision': _session['revision'],
          'action': action,
          ...extra,
        });
        if (!mounted || _accountChanged) return;
        final before = _session;
        setState(() {
          _accept(rewardMap(r['session']));
          AppFeedback.answerFrom(before, _session);
          _status['coins'] = r['coins'] ?? _status['coins'];
          _status['inventory'] = r['inventory'] ?? _status['inventory'];
        });
        if (_finished) {
          final status = await _service.load(widget.mode);
          if (mounted && !_accountChanged)
            setState(() {
              _status = status;
              _accept(rewardMap(status['session']));
            });
        }
      });
  Future<void> _close() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _sprint
              ? 'Sprinti bitir?'
              : _mystery
              ? 'Dosyayı kapat?'
              : 'Teslim ol?',
        ),
        content: Text(
          _sprint
              ? 'Şu ana kadar tamamladığın zincirlerle sonuç kaydedilir.'
              : _mystery
              ? 'İlk resmî sonuç kalıcıdır. Sonraki denemeler alıştırma olur.'
              : 'Bu çiftin ilk resmî ödül hakkı yanar ve en kısa rota gösterilir.'
                    '${_session['deadEnd'] == true || _rows(_session['path']).isNotEmpty ? ' Teslim olmak yerine son hamleyi geri alıp başka köprü deneyebilirsin.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Devam et'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_mystery || _sprint ? 'Bitir' : 'Çözümü gör'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await _act(_sprint ? 'finish' : 'skip');
  }

  void _search(String value) {
    _debounce?.cancel();
    final generation = ++_generation;
    setState(() {
      _results = [];
      _searching = value.trim().length >= 2;
    });
    if (!_searching) return;
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final r = await _service.search({
          'mode': widget.mode,
          'version': _version,
          'sessionId': _session['id'],
          'query': value,
        });
        if (mounted && generation == _generation && !_accountChanged)
          setState(() {
            _results = _rows(r['results']);
            _searching = false;
          });
      } catch (_) {
        if (mounted && generation == _generation)
          setState(() {
            _searching = false;
            _error = 'Arama tamamlanmadı. Tekrar dene.';
          });
      }
    });
  }

  Future<void> _choose(Map<String, dynamic> player) async {
    if (_mystery) {
      await _act('guess', {'playerId': player['id']});
      return;
    }
    await _run(() async {
      final r = await _service.search({
        'mode': widget.mode,
        'version': _version,
        'sessionId': _session['id'],
        'playerId': player['id'],
      });
      if (mounted && !_accountChanged)
        setState(() {
          _selected = player;
          _clubs = _rows(r['clubs']);
          _results = [];
          _generation++;
        });
    });
  }

  Future<void> _watch({String? boostId}) => _run(() async {
    await _service.watchHint(
      widget.mode,
      '${_session['id']}',
      boostId: boostId,
    );
    final r = await _service.load(widget.mode);
    if (mounted && !_accountChanged)
      setState(() {
        _status = r;
        _accept(rewardMap(r['session']));
      });
  });
  Widget _club(Map<String, dynamic> club, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        ClubBadge(club: Club.fromJson(club), size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              Text(
                '${club['name']}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: MediaQuery.textScalerOf(context).scale(16) > 24 ? 112 : 64,
      title: Text(_title, maxLines: 3),
      actions: [
        IconButton(
          tooltip: _mystery ? 'Oyuncu Dosyaları' : 'Zincir Arşivi',
          onPressed: _busy || _accountChanged
              ? null
              : () async {
                  await _load();
                  if (mounted && !_accountChanged)
                    setState(() => _archive = !_archive);
                },
          icon: const Icon(Icons.collections_bookmark_outlined),
        ),
        IconButton(
          tooltip: 'Yenile',
          onPressed: _busy || _accountChanged ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_status.isEmpty) ...[
                GameIntro(
                  icon: _mystery
                      ? Icons.person_search_outlined
                      : Icons.hub_outlined,
                  title: _title,
                  message: _mystery
                      ? 'İpuçlarını birleştir, gizli futbolcuyu keşfet.'
                      : 'Futbolcuların kariyerleriyle kulüpler arasında bağ kur.',
                ),
                const SizedBox(height: 16),
              ],
              if (_error != null)
                GameErrorPanel(
                  message: _error!,
                  accountChanged: _accountChanged,
                  onRetry: _busy ? null : _load,
                ),
              if (_status.isNotEmpty) ...[
                GameStats(
                  items: [
                    (Icons.toll_outlined, '${_status['coins']} Link Coin'),
                    (
                      Icons.bolt_outlined,
                      '${rewardMap(_status['energy'])['available'] ?? '—'} enerji',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_archive)
                  ..._collection()
                else if (_session.isEmpty)
                  ..._home()
                else
                  ..._game(),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  List<Widget> _home() => [
    HubHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: HubIconBox(
              _mystery
                  ? Icons.person_search_outlined
                  : _sprint
                  ? Icons.timer_outlined
                  : Icons.hub_outlined,
              size: 52,
              background: PitchColors.of(
                context,
              ).background.withValues(alpha: .4),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _mystery
                ? 'İpuçlarını birleştir.'
                : _sprint
                ? 'Zamana karşı bağ kur.'
                : 'İki kulüp. Senin rotan.',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _mystery
                ? 'Milliyet, mevki ve bir kulüple başla. Üç geçerli tahminde futbolcuyu bul. Her yanlışta yeni bir bilgi açılır.'
                : _sprint
                ? '60 saniyede başla. Tamamladığın her zincir +5 saniye verir. Sayaç en fazla 75; oturum en fazla 180 saniye sürer.'
                : 'İki kulüpte de oynamış futbolcularla köprüler kur. Futbolcu ve kulüp tekrarı yok. PAR, en kısa geçerli yolun hamle sayısıdır.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: PitchColors.of(context).muted,
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    PitchPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Kurallar ve kazanımlar',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final rule in [
            _sprint
                ? 'Bir pas hakkı: −10 saniye. Saat arka planda da işler. Oyun sırasında ipucu ve reklam yok.'
                : '1 ücretsiz + en fazla 2 reklamlı ipucu. Mevcut destek stoğu aynı üç hakkı paylaşır.',
            _mystery
                ? 'İlk resmî dosyada en fazla 6 Coin / 12 XP. Ustalık: yanlışsız ve en fazla 1 isteğe bağlı ipucu.'
                : _sprint
                ? 'Günlük en iyi Sprint ile en fazla 10 Coin / 20 XP; yalnızca yeni eşikler ödenir.'
                : 'İlk resmî kulüp çiftinde en fazla 12 Coin / 24 XP. Ustalık: PAR, ipucusuz, geri almasız. Altın: PAR+1 ve en fazla 1 ipucu.',
            if (!_mystery && !_sprint)
              'İpucu sıradaki köprü futbolcusunu söyler; hangi kulübüne geçeceğini sen bulursun. Oyun bitince en kısa rota gösterilir.',
            'Gizemli Futbolcu ve iki Zincir modu ortak günde 24 Coin / 48 XP bütçesini kullanır. Fazlası kaybolmaz; sırada bekler.',
            rewardMap(_status['energy'])['enabled'] == true
                ? 'Yeni oyun: 1 enerji. Kayıtlı oyuna devam ücretsiz.'
                : 'Enerji sistemi şu anda kapalı; yeni oyun ücretsiz.',
            if (_mystery)
              'Seri yalnızca ilk denemelerde ilerler; süresi dolan dosya seriyi bozmaz. 5 seri +10, 10 seri +20 Coin (bir kez).',
            if (_mystery)
              'Gösterilen tüm bilgilere uyan başka bir futbolcu varsa o da doğru kabul edilir.',
            if (_status['linked'] != true)
              'Kazanımların saklanır. Cüzdana aktarılması için Google hesabını bağla.',
          ])
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: HubSpecNote(rule),
            ),
        ],
      ),
    ),
    if (_mystery) ...[
      const SizedBox(height: 12),
      _streakPanel(),
      const SizedBox(height: 12),
      HubSegmented<String>(
        label: 'Zorluk',
        options: _levels,
        value: _level,
        onChanged: _busy ? null : (v) => setState(() => _level = v),
      ),
      const SizedBox(height: 6),
      const Text('Zorluk, futbolcunun ne kadar tanındığına göre.'),
    ],
    const SizedBox(height: 16),
    FilledButton(
      onPressed: _busy ? null : () => _start(),
      child: Text(_sprint ? 'Sprinti başlat' : 'Yeni dosya aç'),
    ),
    if (!_sprint) ...[
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _busy ? null : () => _start(daily: true),
        icon: const Icon(Icons.today_outlined),
        label: Text(_mystery ? 'Günün gizemli futbolcusu' : 'Günün zinciri'),
      ),
      const SizedBox(height: 4),
      Text(
        _mystery
            ? 'Herkes bugün aynı futbolcuyu arar. Sonucu paylaşabilirsin.'
            : 'Herkes bugün aynı iki kulübü bağlar. Sonucu paylaşabilirsin.',
      ),
    ],
  ];

  /// Current and best streak with the one-time streak rewards.
  Widget _streakPanel() {
    final amber = hubAmber(context);
    return PitchPanel(
      child: Row(
        children: [
          Icon(Icons.local_fire_department_rounded, color: amber, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seri ${_status['streak'] ?? 0} · En iyi ${_status['longestStreak'] ?? 0}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final b in _rows(_status['streakRewards']))
                      HubPill(
                        '${_streakNames[b['id']] ?? b['id']} · +${b['coins']} Coin',
                        icon: b['earned'] == true
                            ? Icons.check_rounded
                            : Icons.lock_outline,
                        color: b['earned'] == true
                            ? amber
                            : PitchColors.of(context).muted,
                        background: b['earned'] == true
                            ? amber.withValues(alpha: .14)
                            : PitchColors.of(context).raised,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _game() {
    final path = _rows(_session['path']);
    final hints = _rows(_session['hints']);
    final disabled = _busy || _finished || _sprint && _seconds == 0;
    return [
      Text(
        _finished
            ? 'Sonuç kaydedildi'
            : _mystery
            ? 'Bu futbolcu kim?'
            : _sprint
            ? '$_seconds sn'
            : 'Hedefe kendi yolunu kur',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          if (_mystery)
            Text('Tahmin: ${3 - (_session['wrong'] as num? ?? 0)} / 3'),
          if (!_mystery)
            Text(
              'Hamle ${path.length} / ${_session['maxMoves']} · PAR ${_session['par']}',
            ),
          Text('Puan ${_session['score']}'),
          if (!_mystery && !_sprint && _session['daily'] != null)
            HubPill(
              'Günün zinciri',
              color: hubAmber(context),
              background: hubAmber(context).withValues(alpha: .14),
            ),
          if (_sprint)
            Text('${_session['chains']} zincir · Seri ${_session['streak']}'),
        ],
      ),
      const SizedBox(height: 16),
      if (_mystery && !_finished && _hoursLeft < 6)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: HubSpecNote(
            'Bu dosya ${_hoursLeft < 1 ? '1 saatten kısa' : '$_hoursLeft saat'} içinde kapanır. '
            'Bitirmezsen ilk deneme ödülü bu dosya için kullanılmış sayılır.',
          ),
        ),
      if (_mystery)
        PitchPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('BAŞLANGIÇ BİLGİLERİ', style: hubCaps(context)),
                  ),
                  if (_session['daily'] != null)
                    HubPill(
                      'Günün futbolcusu',
                      color: hubAmber(context),
                      background: hubAmber(context).withValues(alpha: .14),
                    )
                  else if (_levels[_session['difficulty']] != null)
                    HubPill(
                      _levels[_session['difficulty']]!,
                      color: PitchColors.of(context).accent,
                      background: PitchColors.of(
                        context,
                      ).accent.withValues(alpha: .12),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              for (final h in _rows(_session['initial']))
                Text(
                  '${h['text']}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              for (final h in hints)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        h['automatic'] == true
                            ? Icons.close_rounded
                            : Icons.lightbulb_outline,
                        size: 18,
                        color: h['automatic'] == true
                            ? PitchColors.of(context).muted
                            : hubAmber(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${h['text']}')),
                    ],
                  ),
                ),
            ],
          ),
        )
      else
        PitchPanel(
          child: Column(
            children: [
              _club(
                rewardMap(_session['current']),
                path.isEmpty ? 'Başlangıç' : 'Şu anki kulüp',
              ),
              const Icon(Icons.south_rounded),
              _club(rewardMap(_session['target']), 'Hedef'),
            ],
          ),
        ),
      if (!_mystery && path.isNotEmpty) ...[
        const SizedBox(height: 12),
        for (final step in path)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link),
            title: Text('${rewardMap(step['player'])['name']}'),
            subtitle: Text('${rewardMap(step['club'])['name']}'),
          ),
      ],
      if ('${_session['feedback'] ?? ''}'.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('${_session['feedback']}'),
        ),
      if (_session['deadEnd'] == true && !_finished)
        const Text('Çıkmaz rota. Geri alarak başka bir köprü deneyebilirsin.'),
      if (_session['bridgeHint'] != null && !_finished)
        PitchPanel(child: Text('${rewardMap(_session['bridgeHint'])['text']}')),
      if (!_finished) ...[
        const SizedBox(height: 16),
        if (_selected == null) ...[
          TextField(
            controller: _query,
            enabled: !disabled,
            onChanged: _search,
            decoration: InputDecoration(
              labelText: _mystery
                  ? 'Futbolcu ara'
                  : 'Bu kulüpte oynamış futbolcu ara',
            ),
          ),
          if (_searching) const LinearProgressIndicator(),
          for (final p in _results)
            ListTile(
              title: Text('${p['name']}'),
              subtitle: Text('${p['country']} · ${p['position']}'),
              onTap: disabled ? null : () => _choose(p),
            ),
          if (_mystery)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Tanınmayan, belirsiz veya tekrar edilen tahmin hakkını azaltmaz.',
              ),
            ),
        ] else ...[
          Text(
            '${_selected!['name']} ile sonraki kulübü seç',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          TextField(
            controller: _clubQuery,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Kulüplerde ara'),
          ),
          if (_clubs.isEmpty)
            const Text('Bu futbolcuyla kullanılabilir başka kulüp yok.'),
          for (final c in _clubs.where(
            (x) => '${x['name']}'.toLowerCase().contains(
              _clubQuery.text.toLowerCase(),
            ),
          ))
            ListTile(
              title: Text('${c['name']}'),
              leading: ClubBadge(club: Club.fromJson(c), size: 28),
              onTap: disabled
                  ? null
                  : () => _act('move', {
                      'playerId': _selected!['id'],
                      'clubId': c['id'],
                    }),
            ),
          TextButton(
            onPressed: disabled ? null : () => setState(_clear),
            child: const Text('Başka futbolcu seç'),
          ),
        ],
        if (!_mystery)
          OutlinedButton.icon(
            onPressed: disabled || path.isEmpty ? null : () => _act('undo'),
            icon: const Icon(Icons.undo),
            label: const Text('Son hamleyi geri al'),
          ),
        if (!_sprint) ..._help(disabled),
        if (_sprint)
          OutlinedButton(
            onPressed: disabled || _session['skipped'] == 1
                ? null
                : () => _act('skip'),
            child: const Text('Pas geç · −10 sn · 1 hak'),
          ),
        TextButton(
          onPressed: disabled ? null : _close,
          child: Text(
            _sprint
                ? 'Sprinti bitir'
                : _mystery
                ? 'Dosyayı kapat'
                : 'Teslim ol · çözümü gör',
          ),
        ),
      ] else ...[
        const SizedBox(height: 16),
        PitchPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_session['player'] != null)
                Text(
                  '${rewardMap(_session['player'])['name']}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              Text(
                _session['gaveUp'] == true
                    ? 'Teslim oldun'
                    : _medals[(rewardMap(_session['result'])['medal'] as num? ??
                              0)
                          .toInt()
                          .clamp(0, 4)],
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'Bu oyunda ${rewardMap(_session['result'])['coins']} Link Coin · ${rewardMap(_session['result'])['xp']} XP hakkı kazanıldı.',
              ),
              if (rewardMap(_session['result'])['expired'] == true)
                const HubSpecNote(
                  '24 saat içinde bitirilmediği için dosya kapandı. Serin bozulmadı.',
                ),
              if (_session['answer'] != null)
                Text(
                  'Senin cevabın da doğru: ${rewardMap(_session['answer'])['name']} gösterilen tüm bilgilere uyuyor.',
                ),
              if ((_session['alsoBy'] as List?)?.isNotEmpty == true)
                HubSpecNote(
                  'Bu bilgilere uyan diğer futbolcular: ${(_session['alsoBy'] as List).join(', ')}',
                ),
              if (rewardMap(_session['result'])['badge'] != null)
                Text(
                  'Seri ödülü: ${_streakNames[rewardMap(_session['result'])['badge']] ?? ''} tamamlandı!',
                  style: TextStyle(
                    color: hubAmber(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (rewardMap(_session['result'])['practice'] == true)
                const Text(
                  'Alıştırma sonucu. İlk resmî ekonomik sonuç değişmedi.',
                ),
              const Text(
                'Günlük bütçeyi aşan kazanım ödeme sırasında saklanır.',
              ),
            ],
          ),
        ),
        if (!_mystery &&
            !_sprint &&
            _rows(_session['solution']).isNotEmpty) ...[
          const SizedBox(height: 12),
          _solutionPanel(),
        ],
        if (!_sprint) ...[
          const SizedBox(height: 12),
          ShareResultButtons(
            text: _mystery ? mysteryShare(_session) : chainShare(_session),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                  _session = {};
                  _clear();
                }),
          child: const Text('Yeni oyuna hazırlan'),
        ),
      ],
    ];
  }

  /// The shortest route after a chain ends, with how many such routes exist.
  Widget _solutionPanel() {
    final steps = _rows(_session['solution']);
    final count = (_session['routeCount'] as num? ?? 1).toInt();
    return PitchPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EN KISA ROTA', style: hubCaps(context)),
          const SizedBox(height: 4),
          Text(
            count > 1
                ? 'PAR ${_session['par']} · $count farklı en kısa rota var; biri:'
                : 'PAR ${_session['par']} · tek en kısa rota:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          _club(rewardMap(_session['start']), 'Başlangıç'),
          for (final step in steps) ...[
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 2, bottom: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.south_rounded,
                    size: 18,
                    color: PitchColors.of(context).muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${rewardMap(step['player'])['name']}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: PitchColors.of(context).accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _club(rewardMap(step['club']), ''),
          ],
        ],
      ),
    );
  }

  int get _hoursLeft =>
      (((_session['expiresAt'] as num? ?? 0) - _serverNow) / 3600000).floor();

  List<Widget> _help(bool disabled) {
    final count = (_session['optionalHints'] as num? ?? 0).toInt();
    if (_session['optionalLeft'] == 0 && count < 3)
      return [const Text('Bu dosyada açılacak başka bilgi yok.')];
    if (count >= 3)
      return [const Text('Bu oyunun üç isteğe bağlı ipucu kullanıldı.')];
    if (rewardMap(_session['support'])['version'] == 1)
      return [
        const SizedBox(height: 12),
        Text('Destek çantası · $count / 3'),
        PaidHintButton(
          session: _session,
          sku: _mystery ? 'boost_basic' : 'boost_connection',
          label: _mystery ? 'Yeni bilgi aç' : 'Geçerli köprü ipucu',
          disabled: disabled,
          onUse: (payment) => _act('hint', payment),
          onWatch: () =>
              _watch(boostId: _mystery ? 'boost_basic' : 'boost_connection'),
        ),
      ];
    final credit =
        _session['freeHint'] == true ||
        (_session['adCredits'] as num? ?? 0) > 0;
    return [
      const SizedBox(height: 16),
      Text('İsteğe bağlı ipucu · $count / 3'),
      OutlinedButton.icon(
        onPressed: disabled || !credit ? null : () => _act('hint'),
        icon: const Icon(Icons.lightbulb_outline),
        label: Text(_mystery ? 'Yeni bilgi aç' : 'Geçerli köprü ipucu'),
      ),
      if (!credit && (_session['adRemaining'] as num? ?? 0) > 0)
        OutlinedButton.icon(
          onPressed: disabled ? null : _watch,
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('Reklam izle · 1 ipucu hakkı'),
        ),
      for (final b in _rows(
        _status['inventory'],
      ).where((x) => (x['quantity'] as num? ?? 0) > 0))
        TextButton(
          onPressed: disabled ? null : () => _act('hint', {'boost': b['id']}),
          child: Text(
            'Destek stoğunu ipucuna dönüştür · ${b['quantity']} adet',
          ),
        ),
    ];
  }

  List<Widget> _collection() => [
    Text(
      _mystery ? 'Oyuncu Dosyaları' : 'Zincir Arşivi',
      style: Theme.of(context).textTheme.headlineSmall,
    ),
    Text('Bekleyen ödeme: ${_status['pendingCoins'] ?? 0} Link Coin'),
    if (!_mystery)
      PitchPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sprint rekorların'),
            Text(
              '${rewardMap(_status['sprintBest'])['chains'] ?? 0} zincir · ${rewardMap(_status['sprintBest'])['score'] ?? 0} puan · ${rewardMap(_status['sprintBest'])['streak'] ?? 0} seri',
            ),
            Text(
              'Bugünün ödül eşiği: ${_medals[(rewardMap(_status['sprintToday'])['tier'] as num? ?? 0).toInt().clamp(0, 4)]}',
            ),
          ],
        ),
      ),
    if (_rows(_status['collection']).isEmpty)
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('Tamamladığın dosyalar burada saklanır.'),
      ),
    for (final r in _rows(_status['collection']))
      Card(
        child: ExpansionTile(
          title: Text(
            _mystery
                ? '${rewardMap(r['player'])['name']}'
                : '${rewardMap(r['start'])['name']} ↔ ${rewardMap(r['target'])['name']}',
          ),
          subtitle: Text(
            '${_medals[(r['bestMedal'] as num? ?? 0).toInt().clamp(0, 4)]} · ${r['solvedCount'] ?? 0} çözüm',
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'İlk resmî derece: ${_medals[(rewardMap(r['firstResult'])['medal'] as num? ?? 0).toInt().clamp(0, 4)]}',
                  ),
                  if (_mystery)
                    Text(
                      '${rewardMap(r['player'])['country']} · ${rewardMap(r['player'])['position']}',
                    ),
                  if (!_mystery)
                    Text(
                      'En iyi hamle: ${r['bestMoves'] ?? '—'} · PAR ${r['par']}',
                    ),
                  if (r['graphVersion'] != _version)
                    const Text('Önceki veri sürümüyle oynandı.'),
                  for (final step in _rows(r['route']))
                    Text(
                      '${rewardMap(step['player'])['name']} → ${rewardMap(step['club'])['name']}',
                    ),
                  for (final h in _rows(rewardMap(r['last'])['hints']))
                    Text('${h['text']}'),
                  if (!_sprint)
                    TextButton(
                      onPressed: _busy || _active
                          ? null
                          : () => _start(target: '${r['id']}'),
                      child: const Text('Alıştırma olarak yeniden aç'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    TextButton(
      onPressed: () => setState(() => _archive = false),
      child: const Text('Oyuna dön'),
    ),
  ];
}

/// Share card for a finished mystery file: never names the player.
String mysteryShare(Map<String, dynamic> session) {
  final wrong = (session['wrong'] as num? ?? 0).toInt();
  final found = session['found'] == true;
  final day = '${session['daily'] ?? ''}'.split('-').reversed.join('.');
  final hints = (session['optionalHints'] as num? ?? 0).toInt();
  return [
    'Linkball · Gizemli Futbolcu',
    if (session['daily'] != null) 'Günün futbolcusu · $day',
    '${'🟥' * wrong.clamp(0, 3)}${found ? '🟩' : ''}${'⬜' * (3 - wrong - (found ? 1 : 0)).clamp(0, 3)}'
        ' ${found ? 'Bulundu' : 'Bulunamadı'}',
    '$hints ipucu · ${session['score'] ?? 0} puan'
        '${(session['streak'] as num? ?? 0) > 1 ? ' · 🔥 ${session['streak']} seri' : ''}',
  ].join('\n');
}

/// Share card for a finished chain: the pair and PAR, never the route.
String chainShare(Map<String, dynamic> session) {
  final moves = (session['path'] as List? ?? const []).length;
  final found = session['found'] == true;
  final medal = (rewardMap(session['result'])['medal'] as num? ?? 0).toInt();
  final day = '${session['daily'] ?? ''}'.split('-').reversed.join('.');
  return [
    'Linkball · Zincir Ustalığı',
    if (session['daily'] != null) 'Günün zinciri · $day',
    '${rewardMap(session['start'])['name']} → ${rewardMap(session['target'])['name']}',
    found
        ? '${'🔗' * moves} $moves hamle · PAR ${session['par']}'
        : '⛓️‍💥 Bağlanamadı · PAR ${session['par']}',
    '${_medals[medal.clamp(0, 4)]} · ${(session['optionalHints'] as num? ?? 0).toInt()} ipucu',
  ].join('\n');
}
