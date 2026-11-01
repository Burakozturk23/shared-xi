import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../app/game_audio.dart';
import '../models/rewarded_ad_models.dart';
import '../services/auth_service.dart';
import '../services/career_transfer_service.dart';
import '../widgets/friend_match_invite_button.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/game_ui.dart';
import '../widgets/hub_ui.dart';
import '../widgets/online_ui.dart';
import '../services/game_error.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/fake_club_options.dart';
import 'online_mode_catalog.dart';

List<Map<String, dynamic>> _rows(dynamic v) =>
    (v is List ? v : const []).map(rewardMap).toList();

const _kinds = {
  'fake_club_duel': 'Sahte Kulüp',
  'mystery_duel': 'Gizem',
  'transfer': 'Transfer',
  'order': 'Kronoloji',
  'missing': 'Eksik kulüp',
  'mystery': 'Gizemli kariyer',
};
const _levels = {
  'beginner': 'Kolay',
  'normal': 'Orta',
  'legend': 'Zor',
  'easy': 'Kolay',
  'medium': 'Orta',
  'hard': 'Zor',
};
const _positions = {
  'GK': 'Kaleci',
  'DEF': 'Defans',
  'MID': 'Orta saha',
  'FWD': 'Forvet',
  'ATT': 'Forvet',
};

/// The correct answer of a finished round, in words.
String _answerText(Map<String, dynamic> r) {
  final options = _rows(r['options']);
  String name(Object? id) =>
      '${options.firstWhere((o) => o['id'] == id, orElse: () => const {})['name'] ?? ''}';
  if (r['kind'] == 'order' && r['answer'] is List) {
    return (r['answer'] as List).map(name).join(' → ');
  }
  return name(r['answer']);
}

class CareerTransferOnlinePage extends StatefulWidget {
  const CareerTransferOnlinePage({
    super.key,
    required this.mode,
    this.ranked = false,
    this.joinCode,
    this.service,
  });
  final String mode;
  final bool ranked;
  final String? joinCode;
  final CareerTransferService? service;
  @override
  State<CareerTransferOnlinePage> createState() =>
      _CareerTransferOnlinePageState();
}

class _CareerTransferOnlinePageState extends State<CareerTransferOnlinePage>
    with WidgetsBindingObserver {
  late final _service =
      widget.service ??
      CareerTransferService(
        mysteryChain: widget.mode == 'mystery_duel',
        fakeClub: widget.mode == 'fake_club_duel',
      );
  Map<String, dynamic> _room = {}, _availability = {};
  String _version = '';
  String? _error, _feedback;
  bool _busy = false,
      _connected = true,
      _joinedFromInvite = false,
      _polling = false,
      _resumed = true,
      _canPop = false,
      _accountChanged = false;
  final _code = TextEditingController(), _query = TextEditingController();
  Timer? _timer, _debounce;
  StreamSubscription<dynamic>? _auth;
  int _searchGeneration = 0, _mutationEpoch = 0, _pollTicks = 0;
  String? _observedUid;
  List<Map<String, dynamic>> _results = [], _order = [];
  dynamic _selected;
  DateTime _received = DateTime.now();
  bool get _playing => _room['status'] == 'playing';
  bool get _waiting => _room['status'] == 'waiting';
  bool get _finished =>
      ['finished', 'forfeit', 'cancelled'].contains(_room['status']);
  bool get _fakeClub => widget.mode == 'fake_club_duel';
  bool get _ranked =>
      (_playing || _waiting) ? _room['ranked'] == true : widget.ranked;
  bool get _enabled =>
      !_fakeClub || _availability[_ranked ? 'ranked' : 'friends'] == true;
  bool get _mystery => widget.mode == 'mystery_duel';
  bool get _career => widget.mode == 'career_race';
  int get _now =>
      (_room['serverNow'] as num? ?? 0).toInt() +
      DateTime.now().difference(_received).inMilliseconds;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _observedUid = AuthService.uid;
    _auth = AuthService.authStateChanges.listen((u) {
      if (_observedUid != null && _observedUid != u?.uid && mounted)
        setState(() {
          _accountChanged = true;
          _room = {};
          _error = 'Hesap değişti. Ekranı yeniden aç.';
        });
      _observedUid ??= u?.uid;
    });
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _resumed && (_playing || _waiting)) {
        setState(() {});
        if (++_pollTicks >= (_waiting ? 5 : 2) &&
            !_busy &&
            !_polling &&
            _connected &&
            !_accountChanged)
          _poll();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth?.cancel();
    _timer?.cancel();
    _debounce?.cancel();
    _code.dispose();
    _query.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed && _connected && !_busy && !_polling && (_playing || _waiting))
      _poll();
  }

  void _accept(Map<String, dynamic> room) {
    final changed =
        room['id'] != _room['id'] ||
        room['round'] != _room['round'] ||
        rewardMap(room['question'])['kind'] !=
            rewardMap(_room['question'])['kind'];
    _room = room;
    _received = DateTime.now();
    if (changed) {
      _order = _rows(rewardMap(room['question'])['options']);
      _selected = null;
      _results = [];
      _query.clear();
      _searchGeneration++;
    }
  }

  Future<void> _run(Future<void> Function() body) async {
    if (_accountChanged || _busy) return;
    _mutationEpoch++;
    setState(() {
      _busy = true;
      _error = null;
      _feedback = null;
    });
    try {
      await body();
      if (mounted) setState(() => _connected = true);
    } catch (e) {
      if (mounted)
        setState(() {
          final business =
              _room.isNotEmpty &&
              e is FirebaseFunctionsException &&
              [
                'invalid-argument',
                'failed-precondition',
                'already-exists',
                'aborted',
                'resource-exhausted',
              ].contains(e.code);
          if (business) {
            _feedback = gameErrorMessage(e);
          } else {
            _error = gameErrorMessage(e);
            _connected = false;
          }
        });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() => _run(() async {
    final status = await _service.onlineLoad(widget.mode);
    if (!mounted || _accountChanged) return;
    setState(() {
      _version = '${status['version']}';
      _availability = rewardMap(status['availability']);
      _accept(rewardMap(status['room']));
    });
    if (_room.isEmpty && !_joinedFromInvite && widget.joinCode != null) {
      _joinedFromInvite = true;
      await _enterImpl('join', code: widget.joinCode);
    }
  });
  Future<void> _enterImpl(String action, {String? code}) async {
    if (action == 'join' && !validRoomCode(code ?? ''))
      throw StateError('8 karakterli geçerli oda kodunu gir.');
    final r = await _service.mutate('enterCareerTransferOnline', {
      'mode': widget.mode,
      'version': _version,
      'action': action,
      if (code != null) 'code': code.trim().toUpperCase(),
    });
    if (mounted && !_accountChanged)
      setState(() => _accept(rewardMap(r['room'])));
  }

  Future<void> _enter(String action, {String? code}) =>
      _run(() => _enterImpl(action, code: code));
  Future<void> _poll() async {
    if (_accountChanged || _polling || _busy || !_connected) return;
    _polling = true;
    _pollTicks = 0;
    final epoch = _mutationEpoch;
    try {
      final r = await _service.poll({
        'mode': widget.mode,
        'version': _version,
        'roomId': _room['id'],
        'action': 'poll',
      });
      if (mounted && !_accountChanged && epoch == _mutationEpoch)
        setState(() => _accept(rewardMap(r['room'])));
    } catch (e) {
      if (mounted && !_accountChanged && epoch == _mutationEpoch)
        setState(() {
          _error = gameErrorMessage(e);
          _connected = false;
        });
    } finally {
      _polling = false;
    }
  }

  Future<void> _answer() => _run(() async {
    final q = rewardMap(_room['question']);
    final r = await _service.mutate('actCareerTransferOnline', {
      'mode': widget.mode,
      'version': _version,
      'roomId': _room['id'],
      'action': 'answer',
      'round': _room['round'],
      'roundToken': _room['roundToken'],
      'answer': q['kind'] == 'order'
          ? _order.map((x) => x['id']).toList()
          : _selected,
    });
    if (mounted && !_accountChanged)
      setState(() => _accept(rewardMap(r['room'])));
  });
  Future<void> _leave() async {
    if (_busy) return;
    if (_connected && (_playing || _waiting)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Maçtan ayrıl?'),
          content: Text(
            _playing
                ? 'Maç hükmen biter; bu maçtan Coin veya XP verilmez.'
                : 'Oda veya eşleşme araman iptal edilir.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Kal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ayrıl'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      await _run(() async {
        final r = await _service.mutate('actCareerTransferOnline', {
          'mode': widget.mode,
          'version': _version,
          'roomId': _room['id'],
          'action': 'leave',
        });
        if (mounted) setState(() => _accept(rewardMap(r['room'])));
      });
      if (_playing || _waiting) return;
    }
    if (mounted) {
      setState(() => _canPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  void _search(String text) {
    _debounce?.cancel();
    final generation = ++_searchGeneration;
    setState(() {
      _results = [];
      _selected = null;
    });
    if (text.trim().length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final r = await _service.search({
          'mode': 'transfer',
          'version': _version,
          'query': text,
        });
        if (mounted && generation == _searchGeneration && !_accountChanged)
          setState(() => _results = _rows(r['results']));
      } catch (_) {
        if (mounted && generation == _searchGeneration && !_accountChanged)
          setState(() => _feedback = 'Arama tamamlanmadı. Tekrar dene.');
      }
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _canPop || _accountChanged || !_connected,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: MusicScene(
      track: _waiting ? MusicTrack.menu : MusicTrack.competitive,
      quiet: _waiting,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: MediaQuery.textScalerOf(context).scale(16) > 24
              ? 144
              : 64,
          title: Text(
            _fakeClub
                ? 'Sahte Kulüp Düellosu'
                : _mystery
                ? 'Gizem Düellosu'
                : _career
                ? 'Kariyer Yarışı'
                : 'Transfer Düellosu',
            maxLines: 3,
          ),
          actions: [
            if (_waiting && _room['host'] == true && _room['ranked'] != true)
              FriendMatchInviteButton(
                mode: _fakeClub
                    ? OnlinePlayMode.fakeClubDuel
                    : _mystery
                    ? OnlinePlayMode.mysteryDuel
                    : _career
                    ? OnlinePlayMode.careerRace
                    : OnlinePlayMode.transferDuel,
                roomCode: '${_room['code']}',
              ),
            IconButton(
              tooltip: 'Yeniden bağlan',
              onPressed: _busy || _accountChanged ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: GameContent(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                GameErrorPanel(
                  message: _error!,
                  accountChanged: _accountChanged,
                  onRetry: _busy || _accountChanged ? null : _load,
                ),
              if (!_connected && (_playing || _waiting))
                const Text(
                  'Sunucudaki süre devam eder. Yeniden bağlanabilir veya geri dönebilirsin.',
                ),
              if (_feedback != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Semantics(liveRegion: true, child: Text(_feedback!)),
                ),
              if ((_room.isEmpty || _finished) &&
                  _version.isNotEmpty &&
                  _error == null)
                ..._lobby(),
              if ((_playing || _waiting) && _ranked != widget.ranked)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _ranked
                        ? 'Kayıtlı dereceli maçına devam ediyorsun.'
                        : 'Kayıtlı arkadaş maçına devam ediyorsun.',
                  ),
                ),
              if (_waiting)
                PitchPanel(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        _ranked ? 'Rakip aranıyor…' : 'Arkadaşını bekliyorsun',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      if (!_ranked) OnlineRoomCode(code: '${_room['code']}'),
                      Text(
                        _ranked
                            ? '30 saniye içinde eşleşme olmazsa arama kapanır.'
                            : 'Oda 5 dakika açık kalır. Aynı modu seçip kodla katılın.',
                      ),
                      if (_room['expiresAt'] is num)
                        Text(
                          'Kalan süre: ${(((_room['expiresAt'] as num) - _now) / 1000).ceil().clamp(0, 300)} sn',
                        ),
                      TextButton(
                        onPressed: _busy ? null : _leave,
                        child: const Text('Aramayı iptal et'),
                      ),
                    ],
                  ),
                ),
              if (_playing) ..._game(),
            ],
          ),
        ),
      ),
    ),
  );
  List<Widget> _lobby() => [
    if (_finished) ...[
      HubResultCard(
        tone:
            _room['status'] != 'forfeit' &&
                _room['status'] != 'cancelled' &&
                _room['result'] == 'win'
            ? HubResultTone.win
            : HubResultTone.neutral,
        icon: _room['result'] == 'win'
            ? Icons.emoji_events_rounded
            : Icons.sports_score_rounded,
        kicker: _room['ranked'] == true
            ? 'Dereceli düello'
            : 'Dostluk düellosu',
        title: _room['status'] == 'forfeit'
            ? 'Hükmen sonuç'
            : _room['status'] == 'cancelled'
            ? 'Oda kapandı'
            : {
                    'win': 'Kazandın',
                    'draw': 'Berabere',
                    'loss': 'Rakibin kazandı',
                  }[_room['result']] ??
                  'Maç bitti',
        subtitle:
            'Sen ${rewardMap(_room['mine'])['score'] ?? 0} – ${rewardMap(_room['theirs'])['score'] ?? 0} Rakip',
        notes: [
          _room['rewardEligible'] == true
              ? 'Günün ilk 5 geçerli dereceli maçı ortak ödül sınırına tabidir.'
              : _fakeClub && _room['ranked'] == true
              ? 'Coin / XP hakkı yok. Dereceli sonuç ELO ve istatistiklere işlenir.'
              : 'Bu maçtan Coin / XP / ELO ödülü yok.',
          if (_room['rewardEligible'] == true)
            'Galibiyet 3C / 8XP · beraberlik 2C / 6XP · mağlubiyet 1C / 4XP',
        ],
      ),
      if (_rows(_room['rounds']).isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: PitchPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Turlar', style: Theme.of(context).textTheme.titleMedium),
                for (final r in _rows(_room['rounds']))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Tur: ${_kinds[r['kind']] ?? 'Soru'}${_levels[r['difficulty']] != null ? ' (${_levels[r['difficulty']]})' : ''} · ${rewardMap(r['mine'])['correct'] == true ? 'Doğru' : 'Yanlış / süre doldu'} · ${rewardMap(r['mine'])['score'] ?? 0} puan'
                      '${rewardMap(r['theirs']).isNotEmpty ? ' · rakip ${rewardMap(r['theirs'])['score'] ?? 0}' : ''}'
                      '${_career && _answerText(r).isNotEmpty ? '\nCevap: ${_answerText(r)}' : ''}'
                      '${r['explanation'] != null ? '\n${r['explanation']}' : ''}',
                    ),
                  ),
              ],
            ),
          ),
        ),
    ],
    const SizedBox(height: 12),
    GameIntro(
      icon: _fakeClub
          ? Icons.search_off_rounded
          : _mystery
          ? Icons.person_search_outlined
          : _career
          ? Icons.route_outlined
          : Icons.swap_horiz_rounded,
      title: _fakeClub
          ? 'Sahte kulübü bul'
          : _mystery
          ? 'İpuçlarını takip et'
          : _career
          ? 'Kariyerleri çöz'
          : 'Transferi tanı',
      message: _fakeClub
          ? '10 futbolcu · her tur 10 saniye · can sınırı yok.'
          : _mystery
          ? '5 gizemli futbolcu · her tur 30 saniye.'
          : _career
          ? '6 tur: eksik kulüp, kronoloji ve gizemli kariyer. Doğruluk ve hız puan getirir.'
          : '5 transfer · her tur 30 saniye.',
    ),
    const GameStats(
      items: [
        (Icons.check_circle_outline, 'Tek kesin cevap'),
        (Icons.bolt_outlined, 'Enerji harcanmaz'),
      ],
    ),
    const SizedBox(height: 20),
    if (!_enabled)
      const Text(
        'Bu eşleşme türü henüz açılmadı. Doğrulama tamamlanınca kullanılabilir olacak.',
      ),
    if (widget.ranked)
      FilledButton(
        onPressed: _busy || !_connected || _version.isEmpty || !_enabled
            ? null
            : () => _enter('ranked'),
        child: const Text('Dereceli rakip bul'),
      )
    else ...[
      FilledButton(
        onPressed: _busy || !_connected || _version.isEmpty || !_enabled
            ? null
            : () => _enter('create'),
        child: const Text('Arkadaş odası oluştur'),
      ),
      const SizedBox(height: 20),
      RoomCodeField(
        controller: _code,
        enabled: !_busy && _connected,
        onChanged: (_) => setState(() {}),
      ),
      OutlinedButton(
        onPressed:
            _busy ||
                !_connected ||
                _version.isEmpty ||
                !_enabled ||
                !validRoomCode(_code.text)
            ? null
            : () => _enter('join', code: _code.text),
        child: const Text('Odaya katıl'),
      ),
    ],
  ];

  /// Career route as a timeline: one row per stop with its start year; the
  /// hidden stop is marked.
  Widget _route(Map<String, dynamic> q) {
    final p = PitchColors.of(context);
    final route = q['route'] as List;
    final years = q['years'] as List? ?? const [];
    return PitchPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < route.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 28,
                    child: Column(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: route[i] == '?' ? p.accent : p.raised,
                            border: Border.all(
                              color: route[i] == '?' ? p.accent : p.border,
                            ),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: route[i] == '?'
                                      ? p.background
                                      : p.text,
                                ),
                          ),
                        ),
                        if (i < route.length - 1)
                          Expanded(child: Container(width: 2, color: p.border)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12, top: 2),
                      child: Text(
                        route[i] == '?'
                            ? '? · eksik kulüp'
                            : '${route[i]}${years.length > i && '${years[i]}'.isNotEmpty ? ' · ${years[i]}' : ''}',
                        style: route[i] == '?'
                            ? Theme.of(
                                context,
                              ).textTheme.titleSmall?.copyWith(color: p.accent)
                            : Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Difficulty label; the Fake Club tiers go one step further (legend).
  String? _level(Map<String, dynamic> q) => q['kind'] == 'fake_club_duel'
      ? const {
          'easy': 'Kolay',
          'normal': 'Orta',
          'hard': 'Zor',
          'legend': 'Efsane',
        }[q['difficulty']]
      : _levels[q['difficulty']];

  /// Seconds until the next timed hint of a Mystery Duel round, if any.
  int? _nextHint(Map<String, dynamic> q) {
    final at = q['hintAt'];
    final start = _room['startsAt'] as num?;
    if (at is! List || start == null || _room.containsKey('reveal'))
      return null;
    for (final ms in at) {
      final left = ((start + (ms as num) - _now) / 1000).ceil();
      if (left > 0) return left;
    }
    return null;
  }

  List<Widget> _game() {
    final q = rewardMap(_room['question']);
    final before = _now < (_room['startsAt'] as num? ?? 0);
    final seconds = (((_room['deadline'] as num? ?? _now) - _now) / 1000)
        .ceil()
        .clamp(0, 30);
    final locked =
        _busy ||
        !_connected ||
        _room['submitted'] == true ||
        seconds == 0 ||
        before;
    return [
      PitchPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_kinds[q['kind']] != null || q['difficulty'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (_kinds[q['kind']] != null)
                      HubPill(
                        _kinds[q['kind']]!,
                        color: PitchColors.of(context).accent,
                        background: PitchColors.of(context).tint,
                      ),
                    if (_level(q) != null)
                      HubPill(
                        _level(q)!,
                        color: hubAmber(context),
                        background: PitchColors.of(
                          context,
                        ).background.withValues(alpha: .4),
                      ),
                    if ((q['multiplier'] as num? ?? 1) > 1)
                      HubPill(
                        'Son tur · puan ×${q['multiplier']}',
                        color: PitchColors.of(context).limeInk,
                        background: PitchColors.of(context).limeTint,
                      ),
                  ],
                ),
              ),
            Text(
              'Tur ${(_room['round'] as num? ?? 0) + 1} / ${_room['totalRounds']} · $seconds sn',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: before
                    ? 1
                    : ((((_room['deadline'] as num? ?? _now) - _now) /
                                  ((_room['deadline'] as num? ?? 1) -
                                      (_room['startsAt'] as num? ?? 0)))
                              .clamp(0, 1))
                          .toDouble(),
                minHeight: 6,
                color: seconds <= 5
                    ? PitchColors.of(context).error
                    : PitchColors.of(context).accent,
                backgroundColor: PitchColors.of(context).border,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sen ${rewardMap(_room['mine'])['score'] ?? 0} · Rakip ${rewardMap(_room['theirs'])['score'] ?? 0}',
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (before || q.isEmpty)
        const Text('Tur başlıyor…')
      else ...[
        if (q['kind'] == 'mystery_duel') ...[
          PitchPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${q['country']} · ${q['position']}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  q['hintAt'] is List
                      ? '${(q['hintAt'] as List).map((ms) => (ms as num) ~/ 1000).join(', ')}. saniyelerde '
                            'iki rakibe aynı yeni bilgi açılır. İlk bilgiden önce '
                            'verilen doğru cevap hız bonusu almaz.'
                      : '10. ve 20. saniyede iki rakibe aynı yeni bilgi açılır.',
                ),
                for (final (i, hint)
                    in (q['hints'] as List? ?? const []).indexed)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 18,
                          color: hubAmber(context),
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Text('${i + 1}. $hint')),
                      ],
                    ),
                  ),
                if (_nextHint(q) case final next?)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Sonraki bilgi $next sn sonra',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: PitchColors.of(context).muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_room['explanation'] != null && _room.containsKey('reveal'))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: PitchPanel(child: Text('${_room['explanation']}')),
            ),
          const SizedBox(height: 12),
        ],
        if (q['player'] != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${rewardMap(q['player'])['name']}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        if (q['route'] is List) _route(q),
        if (q['kind'] == 'transfer') ...[
          PitchPanel(
            child: Column(
              children: [
                Text(
                  '${q['year']}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: PitchColors.of(context).muted,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${rewardMap(q['from'])['name']}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: PitchColors.of(context).accent,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${rewardMap(q['to'])['name']}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '10. saniyede milliyet, 20. saniyede mevki açılır; açık her '
            'ipucu doğru cevabın taban puanını 15 düşürür.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (final hint in (q['hints'] as List? ?? const []))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 18,
                    color: hubAmber(context),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text('$hint')),
                ],
              ),
            ),
          if (_room['explanation'] != null && _room.containsKey('reveal'))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: PitchPanel(
                child: Text(
                  '${_room['correct'] == true ? 'Doğru' : 'Doğru cevap'}: '
                  '${_room['explanation']}',
                ),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _query,
            enabled: !locked,
            onChanged: _search,
            decoration: const InputDecoration(labelText: 'Futbolcu ara'),
          ),
          for (final p in _results)
            ListTile(
              title: Text('${p['name']}'),
              subtitle: Text(
                [
                  if ('${p['country'] ?? ''}'.isNotEmpty) '${p['country']}',
                  if (_positions[p['position']] != null)
                    _positions[p['position']],
                ].join(' · '),
              ),
              selected: _selected == p['id'],
              onTap: locked ? null : () => setState(() => _selected = p['id']),
            ),
        ] else if (q['kind'] == 'order') ...[
          const Text('En eskiden en yeniye sırala'),
          for (var i = 0; i < _order.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: PitchPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('${i + 1}. ${_order[i]['name']}'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          key: ValueKey('order-up-${_order[i]['id']}'),
                          tooltip: 'Yukarı taşı',
                          onPressed: locked || i == 0
                              ? null
                              : () => setState(() {
                                  final p = _order.removeAt(i);
                                  _order.insert(i - 1, p);
                                }),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          key: ValueKey('order-down-${_order[i]['id']}'),
                          tooltip: 'Aşağı taşı',
                          onPressed: locked || i == _order.length - 1
                              ? null
                              : () => setState(() {
                                  final p = _order.removeAt(i);
                                  _order.insert(i + 1, p);
                                }),
                          icon: const Icon(Icons.arrow_downward),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ] else if (_fakeClub) ...[
          const Text('Futbolcu olarak hangi kulüpte hiç oynamadı?'),
          Text(
            'Teknik direktörlük kariyeri sayılmaz.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          FakeClubOptions(
            options: _rows(q['options']),
            selectedId: (_selected as num?)?.toInt(),
            fakeClubId: (_room['reveal'] as num?)?.toInt(),
            onSelected: locked ? null : (id) => setState(() => _selected = id),
          ),
          if (_room['explanation'] != null) Text('${_room['explanation']}'),
        ] else ...[
          if (q['kind'] == 'missing')
            const Text('Soru işaretli durakta hangi kulüp var?'),
          if (q['kind'] == 'mystery') const Text('Bu kariyer kimin?'),
          const SizedBox(height: 8),
          for (final p in _rows(q['options']))
            Card(
              color: _room['reveal'] == p['id']
                  ? PitchColors.of(context).success.withValues(alpha: .14)
                  : null,
              child: ListTile(
                title: Text('${p['name']}'),
                subtitle: _room.containsKey('reveal')
                    ? Text(
                        [
                          if (_room['reveal'] == p['id']) 'Doğru cevap',
                          if (_room['opponentAnswer'] == p['id'])
                            'Rakibin seçimi',
                        ].join(' · '),
                      )
                    : null,
                selected: _selected == p['id'],
                leading: Icon(
                  _room['reveal'] == p['id']
                      ? Icons.check_circle_rounded
                      : _room.containsKey('reveal') && _selected == p['id']
                      ? Icons.cancel_rounded
                      : _selected == p['id']
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: _room['reveal'] == p['id']
                      ? PitchColors.of(context).success
                      : _room.containsKey('reveal') && _selected == p['id']
                      ? PitchColors.of(context).error
                      : null,
                ),
                onTap: locked
                    ? null
                    : () => setState(() => _selected = p['id']),
              ),
            ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: locked || q['kind'] != 'order' && _selected == null
              ? null
              : _answer,
          child: const Text('Kesin cevabımı gönder'),
        ),
        if (_room['submitted'] == true)
          const Text('Cevabın kaydedildi. Tur bitince sonuç açıklanacak.'),
        if (_room.containsKey('correct'))
          Text(_room['correct'] == true ? 'Doğru!' : 'Yanlış / süre doldu'),
      ],
    ];
  }
}
