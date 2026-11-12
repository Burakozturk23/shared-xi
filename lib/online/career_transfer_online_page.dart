import 'dart:async';
import '../app/app_feedback.dart';
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
import '../widgets/bot_arena.dart';
import '../widgets/club_race_arena.dart';
import '../services/warm_up.dart';
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
  String? _revealFelt;
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
  Timer? _timer, _debounce, _retry;

  /// Quiet retries after a brief connection drop; reset by any good reply.
  int _linkMisses = 0;
  static const _maxLinkMisses = 3;
  static const _weakLink =
      'Bağlantı zayıf · yeniden deneniyor. Maç sunucuda sürüyor.';

  /// A lost socket or slow reply in a live room: keep the match on screen and
  /// try [again] shortly instead of dropping to the error panel at once.
  bool _quietRetry(Object e, Future<void> Function() again) {
    if (_accountChanged ||
        !_connected ||
        _room.isEmpty ||
        _finished ||
        !isTransientGameError(e) ||
        _linkMisses >= _maxLinkMisses)
      return false;
    _linkMisses++;
    _feedback = _weakLink;
    _retry?.cancel();
    _retry = Timer(Duration(seconds: _linkMisses), () {
      if (mounted && _connected && !_busy && !_polling && !_accountChanged)
        again();
    });
    return true;
  }

  void _linkBack() {
    _linkMisses = 0;
    if (_feedback == _weakLink) _feedback = null;
  }

  StreamSubscription<dynamic>? _auth;
  int _searchGeneration = 0, _mutationEpoch = 0, _pollTicks = 0;
  String? _observedUid;
  List<Map<String, dynamic>> _results = [], _order = [];
  dynamic _selected;

  /// Transfer Duel: rounds already revealed, right (true) or not, for the dots.
  final Map<int, bool> _roundResults = {};
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
    // Isınma: the duel functions start while the screen loads.
    WarmUp.functions(const [
      'enterCareerTransferOnline',
      'actCareerTransferOnline',
    ]);
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
    _retry?.cancel();
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
    // A new match starts its round dots afresh.
    if (room['id'] != _room['id']) _roundResults.clear();
    final changed =
        room['id'] != _room['id'] ||
        room['round'] != _room['round'] ||
        rewardMap(room['question'])['kind'] !=
            rewardMap(_room['question'])['kind'];
    // The round's result is felt once, when its reveal first arrives (polls repeat it).
    final reveal = '${room['id']}|${room['round']}';
    if (room.containsKey('reveal') && _revealFelt != reveal) {
      _revealFelt = reveal;
      if (room['round'] is num)
        _roundResults[(room['round'] as num).toInt()] = room['correct'] == true;
      AppFeedback.answer(correct: room['correct'] == true);
    }
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
      if (mounted)
        setState(() {
          _connected = true;
          _linkBack();
        });
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
          } else if (!_quietRetry(e, _load)) {
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
    // An invite joins its room even when the last match's result is still on
    // screen (the saved room is finished); a match in progress is kept.
    final invite = widget.joinCode?.trim().toUpperCase();
    final over =
        _room.isEmpty ||
        [
          'finished',
          'forfeit',
          'cancelled',
          'expired',
        ].contains(_room['status']);
    if (over &&
        !_joinedFromInvite &&
        invite != null &&
        '${_room['code'] ?? ''}'.toUpperCase() != invite) {
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
        setState(() {
          _linkBack();
          _accept(rewardMap(r['room']));
        });
    } catch (e) {
      if (mounted && !_accountChanged && epoch == _mutationEpoch)
        setState(() {
          if (!_quietRetry(e, _poll)) {
            _error = gameErrorMessage(e);
            _connected = false;
          }
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

  bool get _transferArena =>
      (widget.mode == 'transfer_duel' || _mystery || _fakeClub || _career) &&
      _playing;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _canPop || _accountChanged || !_connected,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: MusicScene(
      track: _waiting ? MusicTrack.menu : MusicTrack.competitive,
      quiet: _waiting,
      child: _transferArena
          ? Scaffold(
              body: SafeArea(child: GameContent(child: _transfer())),
            )
          : Scaffold(
              body: SafeArea(
                child: GameContent(
                  child: Column(
                    children: [
                      ArenaHeader(
                        title: _title,
                        subtitle: _finished
                            ? 'Maç sonucu · ${_ranked ? 'Dereceli' : 'Arkadaş maçı'}'
                            : _waiting
                            ? (_ranked
                                  ? 'Rastgele eşleşme'
                                  : 'Arkadaş maçı · Oda ${_room['code'] ?? ''}')
                            : (_ranked ? 'Dereceli eşleşme' : 'Arkadaş maçı'),
                        tag: _finished
                            ? 'SONUÇ'
                            : _waiting
                            ? 'LOBİ'
                            : 'ONLINE',
                        actions: [
                          ArenaIconButton(
                            tooltip: 'Yeniden bağlan',
                            icon: Icons.refresh_rounded,
                            onPressed: _busy || _accountChanged ? null : _load,
                          ),
                        ],
                      ),
                      Divider(height: 1, color: PitchColors.of(context).border),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (_busy) const LinearProgressIndicator(),
                            if (_error != null)
                              GameErrorPanel(
                                message: _error!,
                                accountChanged: _accountChanged,
                                onRetry: _busy || _accountChanged
                                    ? null
                                    : _load,
                              ),
                            if (!_connected && (_playing || _waiting))
                              const Text(
                                'Sunucudaki süre devam eder. Yeniden bağlanabilir veya geri dönebilirsin.',
                              ),
                            if (_feedback != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(_feedback!),
                                ),
                              ),
                            if ((_room.isEmpty || _finished) &&
                                _version.isNotEmpty &&
                                _error == null)
                              ..._lobby(),
                            if ((_playing || _waiting) &&
                                _ranked != widget.ranked)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  _ranked
                                      ? 'Kayıtlı dereceli maçına devam ediyorsun.'
                                      : 'Kayıtlı arkadaş maçına devam ediyorsun.',
                                ),
                              ),
                            if (_waiting) ..._waitingRoom(),
                            if (_playing) ..._game(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    ),
  );
  String get _title => _fakeClub
      ? 'Sahte Kulüp Düellosu'
      : _mystery
      ? 'Gizem Düellosu'
      : _career
      ? 'Kariyer Yarışı'
      : 'Transfer Düellosu';

  OnlinePlayMode get _playMode => _fakeClub
      ? OnlinePlayMode.fakeClubDuel
      : _mystery
      ? OnlinePlayMode.mysteryDuel
      : _career
      ? OnlinePlayMode.careerRace
      : OnlinePlayMode.transferDuel;

  /// How the duel is played, for the setup and the waiting room.
  String get _modeRules => _fakeClub
      ? '10 futbolcu, her tur 10 saniye: dört kulüpten futbolcunun hiç oynamadığı sahte '
            'kulübü bul. Doğru cevap 100 puan ve kalan süreye göre +50’ye kadar hız bonusu; '
            'son tur ×2. Maç 2 kolay, 3 orta, 3 zor, 2 efsane soruyla zorlaşır.'
      : _mystery
      ? '5 gizemli futbolcu, her tur 30 saniye: ülke ve mevkiyle başlarsınız; 8, 16 ve 24. '
            'saniyelerde ikinize aynı yeni bilgi açılır. Dört şıktan birine dokun; doğru cevap '
            '100 puan, hız bonusu ilk bilgiyle +50 başlar.'
      : _career
      ? '6 tur: üç eksik kulüp, iki kronoloji, bir gizemli kariyer. Doğru cevap 100 puan ve '
            'kalan süreye göre +50’ye kadar hız bonusu alır.'
      : '6 transfer, kolaydan zora; tur 45 sn, son tur ×2 puan. Transferi yapan futbolcuyu yaz; '
            'dört ipucu sırayla açılır (milliyet, mevki, bir kulübü, baş harfler), her biri −12 puan.';

  /// Setup (no room) and, after a match, its result above a new start.
  List<Widget> _lobby() {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final can = !_busy && _connected && _version.isNotEmpty && _enabled;
    return [
      if (_finished) ..._result(),
      if (_finished) const ArenaSection('Yeni maç', icon: Icons.replay_rounded),
      if (!_finished)
        ArenaCard(
          glow: p.accent,
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: p.tint,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: p.accent.withValues(alpha: .5)),
                ),
                child: Icon(_playMode.icon, color: p.accent, size: 34),
              ),
              const SizedBox(height: 12),
              Text(
                _fakeClub
                    ? 'Sahte kulübü bul'
                    : _mystery
                    ? 'İpuçlarını takip et'
                    : _career
                    ? 'Kariyerleri çöz'
                    : 'Transferi tanı',
                textAlign: TextAlign.center,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                _playMode.subtitle,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: p.muted),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  ArenaPill(
                    child: Text(widget.ranked ? 'Dereceli' : 'Dostluk'),
                  ),
                  const ArenaPill(child: Text('Tek kesin cevap')),
                  const ArenaPill(child: Text('Enerji harcanmaz')),
                ],
              ),
            ],
          ),
        ),
      if (!_finished) ...[
        const SizedBox(height: 12),
        ArenaNote(icon: Icons.rule_rounded, text: _modeRules),
      ],
      if (!_enabled) ...[
        const SizedBox(height: 12),
        ArenaNote(
          icon: Icons.block_rounded,
          color: p.error,
          text:
              'Bu eşleşme türü henüz açılmadı. Doğrulama tamamlanınca kullanılabilir olacak.',
        ),
      ],
      const SizedBox(height: 16),
      if (widget.ranked)
        ArenaPrimaryButton(
          label: 'Dereceli rakip bul',
          icon: Icons.search_rounded,
          onPressed: can ? () => _enter('ranked') : null,
        )
      else ...[
        ArenaPrimaryButton(
          label: 'Arkadaş odası oluştur',
          icon: Icons.add_rounded,
          onPressed: can ? () => _enter('create') : null,
        ),
        const ArenaSection('Koda katıl', icon: Icons.vpn_key_outlined),
        RoomCodeField(
          controller: _code,
          enabled: !_busy && _connected,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        ArenaSecondaryButton(
          label: 'Odaya katıl',
          icon: Icons.login_rounded,
          onPressed: can && validRoomCode(_code.text)
              ? () => _enter('join', code: _code.text)
              : null,
        ),
      ],
    ];
  }

  /// The result card and every round: kind, my and the rival's points, the answer.
  List<Widget> _result() {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final rounds = _rows(_room['rounds']);
    return [
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
      if (rounds.isNotEmpty) ...[
        ArenaSection(
          'Turlar · ${rewardMap(_room['mine'])['correct'] ?? rounds.where((r) => rewardMap(r['mine'])['correct'] == true).length}/${rounds.length} doğru',
          icon: Icons.format_list_numbered_rounded,
        ),
        for (final (i, r) in rounds.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Builder(
              builder: (context) {
                final mine = rewardMap(r['mine']);
                final theirs = rewardMap(r['theirs']);
                final ok = mine['correct'] == true;
                final answer = _answerText(r);
                return ArenaCard(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (ok ? p.success : p.error).withValues(
                            alpha: .18,
                          ),
                          border: Border.all(color: ok ? p.success : p.error),
                        ),
                        child: Icon(
                          ok ? Icons.check_rounded : Icons.close_rounded,
                          size: 16,
                          color: ok ? p.success : p.error,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${i + 1}. ${_kinds[r['kind']] ?? 'Soru'}'
                              '${_levels[r['difficulty']] != null ? ' · ${_levels[r['difficulty']]}' : ''}',
                              style: text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (r['explanation'] != null)
                              Text(
                                '${r['explanation']}',
                                style: text.bodySmall?.copyWith(color: p.muted),
                              )
                            else if (answer.isNotEmpty)
                              Text(
                                'Cevap: $answer',
                                style: text.bodySmall?.copyWith(color: p.muted),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '+${mine['score'] ?? 0}',
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: ok ? Arena.lime : p.muted,
                            ),
                          ),
                          if (theirs.isNotEmpty)
                            Text(
                              'Rakip +${theirs['score'] ?? 0}',
                              style: text.labelSmall?.copyWith(
                                color: hubAmber(context),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    ];
  }

  /// Waiting for a rival: the seats, the room code and the time left.
  List<Widget> _waitingRoom() {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final left = _room['expiresAt'] is num
        ? (((_room['expiresAt'] as num) - _now) / 1000).ceil().clamp(0, 300)
        : null;
    Widget seat(String name, Color tone, bool here) => Expanded(
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tone.withValues(alpha: here ? .14 : .04),
              border: Border.all(
                color: tone.withValues(alpha: here ? .8 : .3),
                width: 2,
              ),
            ),
            child: Icon(
              here ? Icons.person_rounded : Icons.hourglass_empty_rounded,
              color: here ? tone : p.muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
    return [
      ArenaCard(
        glow: p.accent,
        child: Column(
          children: [
            Text(
              _ranked ? 'Rakip aranıyor…' : 'Arkadaşını bekliyorsun',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              _ranked
                  ? '30 saniye içinde eşleşme olmazsa arama kapanır.'
                  : 'Oda 5 dakika açık kalır. Aynı modu seçip kodla katılın.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: p.muted),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                seat('Sen', Arena.lime, true),
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                ),
                seat(_ranked ? 'Rakip' : 'Arkadaşın', hubAmber(context), false),
              ],
            ),
            if (left != null) ...[
              const SizedBox(height: 12),
              ArenaPill(child: Text('Kalan süre: $left sn')),
            ],
          ],
        ),
      ),
      if (!_ranked) ...[
        const SizedBox(height: 12),
        OnlineRoomCode(code: '${_room['code']}'),
        if (_room['host'] == true) ...[
          const SizedBox(height: 8),
          Center(
            child: FriendMatchInviteButton(
              mode: _playMode,
              roomCode: '${_room['code']}',
            ),
          ),
        ],
      ],
      const ArenaSection('Nasıl oynanır', icon: Icons.rule_rounded),
      ArenaNote(icon: Icons.info_outline_rounded, text: _modeRules),
      const SizedBox(height: 12),
      ArenaSecondaryButton(
        label: _ranked ? 'Aramayı iptal et' : 'Odayı kapat',
        icon: Icons.close_rounded,
        color: p.error,
        onPressed: _busy ? null : _leave,
      ),
    ];
  }

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
        .clamp(0, 60);
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

  static const _months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', //
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  /// "Ağustos 2021 · Yaz transferi": the month and its window, from the move's date.
  static String _window(Map<String, dynamic> q) {
    // Summer-2026 moves known to the season only: no month to show.
    if (q['season'] == 'summer') return '${q['year']} · Yaz transferi';
    final m = int.tryParse('${q['month'] ?? ''}');
    if (m == null || m < 1 || m > 12) return '${q['year'] ?? ''}';
    final window = m >= 6 && m <= 9
        ? 'Yaz transferi'
        : m == 12 || m <= 2
        ? 'Kış transferi'
        : 'Dönem dışı transfer';
    return '${_months[m - 1]} ${q['year']} · $window';
  }

  /// Career Race: the round's kind and level, then the route (a missing stop
  /// marked), the player to order, or the mystery career's clubs.
  Widget _careerClue(Map<String, dynamic> q) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final route = [for (final r in q['route'] as List? ?? const []) '$r'];
    final years = [for (final y in q['years'] as List? ?? const []) '$y'];
    final player = rewardMap(q['player']);
    Widget stop(int i) {
      final missing = route[i] == '?';
      final year = i < years.length && years[i].isNotEmpty ? years[i] : null;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: missing ? p.limeTint : p.raised,
                  border: Border.all(
                    color: missing ? Arena.lime : p.border,
                    width: missing ? 2 : 1,
                  ),
                ),
                child: Text(
                  missing ? '?' : '${i + 1}',
                  style: text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: missing ? Arena.lime : p.muted,
                  ),
                ),
              ),
              if (i < route.length - 1)
                Container(width: 2, height: 22, color: p.border),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                children: [
                  if (!missing) ...[
                    CriterionMark(
                      ArenaCriterion({'label': route[i], 'type': 'club'}),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      missing ? 'Eksik durak' : route[i],
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: missing ? Arena.lime : null,
                      ),
                    ),
                  ),
                  if (year != null)
                    Text(
                      year,
                      style: text.labelMedium?.copyWith(color: p.muted),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ArenaCard(
      glow: p.accent,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (_kinds[q['kind']] != null)
                ArenaPill(child: Text(_kinds[q['kind']]!)),
              if (_level(q) != null)
                ArenaPill(dot: hubAmber(context), child: Text(_level(q)!)),
            ],
          ),
          const SizedBox(height: 10),
          if (player.isNotEmpty)
            Text(
              '${player['name']}',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          Text(switch (q['kind']) {
            'missing' => 'Soru işaretli durakta hangi kulüp var?',
            'order' => 'Bu üç dönemi en eskiden en yeniye sırala.',
            _ => 'Bu kariyer kimin?',
          }, style: text.bodyMedium?.copyWith(color: p.muted)),
          if (route.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (var i = 0; i < route.length; i++) stop(i),
          ],
        ],
      ),
    );
  }

  /// Career Race order rounds: one period with its up / down moves.
  Widget _orderRow(int i, String? blocked) {
    final p = PitchColors.of(context);
    final o = _order[i];
    final locked = blocked != null || _busy || !_connected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ArenaCard(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        child: Row(
          children: [
            Text(
              '${i + 1}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: Arena.lime,
              ),
            ),
            const SizedBox(width: 12),
            CriterionMark(
              ArenaCriterion({
                'label': '${o['name']}'.split(' (').first,
                'type': 'club',
              }),
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text('${o['name']}')),
            IconButton(
              key: ValueKey('order-up-${o['id']}'),
              tooltip: 'Yukarı taşı',
              color: p.accent,
              onPressed: locked || i == 0
                  ? null
                  : () => setState(() {
                      final x = _order.removeAt(i);
                      _order.insert(i - 1, x);
                    }),
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
            IconButton(
              key: ValueKey('order-down-${o['id']}'),
              tooltip: 'Aşağı taşı',
              color: p.accent,
              onPressed: locked || i == _order.length - 1
                  ? null
                  : () => setState(() {
                      final x = _order.removeAt(i);
                      _order.insert(i + 1, x);
                    }),
              icon: const Icon(Icons.arrow_downward_rounded),
            ),
          ],
        ),
      ),
    );
  }

  /// Fake Club Duel: the player and the question, with level and the final ×2.
  Widget _fakeClue(Map<String, dynamic> q) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final player = rewardMap(q['player']);
    return ArenaCard(
      glow: p.accent,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (_level(q) != null)
                ArenaPill(dot: hubAmber(context), child: Text(_level(q)!)),
              if ((q['multiplier'] as num? ?? 1) > 1)
                ArenaPill(
                  filled: true,
                  color: Arena.lime,
                  child: Text('Son tur · puan ×${q['multiplier']}'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ArenaPlayerAvatar(
                id: player['id'],
                name: '${player['name'] ?? ''}',
                size: 52,
                ring: p.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${player['name'] ?? ''}',
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if ('${player['country'] ?? ''}'.isNotEmpty)
                      Text(
                        '${player['country']}',
                        style: text.bodySmall?.copyWith(color: p.muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Futbolcu olarak hangi kulüpte hiç oynamadı?',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            'Teknik direktörlük kariyeri sayılmaz.',
            style: text.bodySmall?.copyWith(color: p.muted),
          ),
        ],
      ),
    );
  }

  /// Mystery Duel: the country and position everyone starts from.
  Widget _mysteryClue(Map<String, dynamic> q) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    return ArenaCard(
      glow: p.accent,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: p.tint,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.accent.withValues(alpha: .5)),
            ),
            child: Icon(Icons.question_mark_rounded, color: p.accent, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_levels[q['difficulty']] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ArenaPill(
                      dot: hubAmber(context),
                      child: Text(_levels[q['difficulty']]!),
                    ),
                  ),
                Text(
                  '${q['country']} · ${q['position']}',
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  'Bu futbolcu kim?',
                  style: text.bodyMedium?.copyWith(color: p.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Mystery Duel: one of four players; a tap sends it. After the round the
  /// right one, mine and the rival's are marked.
  Widget _mysteryOption(
    Map<String, dynamic> o,
    String? blocked, {
    bool club = false,
  }) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final revealed = _room.containsKey('reveal');
    final right = revealed && _room['reveal'] == o['id'];
    final mine = _selected == o['id'];
    final theirs = revealed && _room['opponentAnswer'] == o['id'];
    final tone = right
        ? p.success
        : revealed && mine
        ? p.error
        : mine
        ? Arena.lime
        : p.border;
    final tags = [
      if (right) 'Doğru cevap',
      if (mine) 'Senin cevabın',
      if (theirs) 'Rakibin seçimi',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: right
            ? p.success.withValues(alpha: .1)
            : mine
            ? p.limeTint
            : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: tone, width: mine || right ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: blocked != null || _busy || !_connected
              ? null
              : () {
                  setState(() => _selected = o['id']);
                  _answer();
                },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (club)
                  CriterionMark(
                    ArenaCriterion({'label': '${o['name']}', 'type': 'club'}),
                    size: 36,
                  )
                else
                  ArenaPlayerAvatar(
                    id: o['id'],
                    name: '${o['name']}',
                    size: 40,
                    ring: right || mine ? tone : null,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${o['name']}',
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (tags.isNotEmpty)
                        Text(
                          tags.join(' · '),
                          style: text.labelSmall?.copyWith(
                            color: tone,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  right
                      ? Icons.check_circle_rounded
                      : revealed && mine
                      ? Icons.cancel_rounded
                      : mine
                      ? Icons.radio_button_checked
                      : Icons.send_rounded,
                  color: tone == p.border ? p.accent : tone,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Transfer Duel clues: the room's own schedule (45 s rounds, four clues at
  /// 8/16/24/34 s, 12 points each); rooms from before: 10 s and 20 s, 15 points.
  static const _hintAt = [10000, 20000];
  static const _hintNames = ['Milliyet', 'Mevki'];
  static const _clueNames = [
    'Milliyet',
    'Mevki ve yaş',
    'Kariyerinden bir kulüp',
    'Baş harfler',
  ];

  /// The live Transfer Duel: score and clock, the move, the hints and what an
  /// answer is worth now, and the search bar over the keyboard (a tap sends).
  Widget _transfer() {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final q = rewardMap(_room['question']);
    final start = (_room['startsAt'] as num? ?? 0).toInt();
    final deadline = (_room['deadline'] as num? ?? _now).toInt();
    final before = _now < start;
    final revealed = _room.containsKey('reveal');
    final left = ((deadline - _now) / 1000).ceil().clamp(0, 60);
    final round = (_room['round'] as num? ?? 0).toInt();
    final total = (_room['totalRounds'] as num? ?? 5).toInt();
    final hints = [for (final h in q['hints'] as List? ?? const []) '$h'];
    final mine = rewardMap(_room['mine']), theirs = rewardMap(_room['theirs']);
    // Clue times: Transfer 10 s / 20 s (each costs 15), Mystery the room's hintAt.
    final hintTimes = _mystery
        ? [
            for (final ms in q['hintAt'] as List? ?? const [8000, 16000, 24000])
              (ms as num).toInt(),
          ]
        : _fakeClub || _career
        ? const <int>[]
        : q['hintAt'] is List
        ? [for (final ms in q['hintAt'] as List) (ms as num).toInt()]
        : _hintAt;
    final hintCost = (q['hintCost'] as num? ?? 15).toInt();
    final hintNames = hintTimes.length == _clueNames.length
        ? _clueNames
        : _hintNames;
    // Round length: Fake Club 10 s, Career Race 20 / 25 s, Transfer and Mystery 30 s.
    final roundMs = _fakeClub
        ? 10000
        : _career
        ? (q['kind'] == 'order' ? 25000 : 20000)
        : (q['duration'] as num? ?? 30000).toInt();
    final elapsed = _now - start;
    // What a right answer is worth now, by the server's formula.
    final worth = _career
        ? 100 + (50 * (deadline - _now).clamp(0, roundMs) / roundMs).floor()
        : _fakeClub
        ? (100 + (50 * (deadline - _now).clamp(0, roundMs) / roundMs).floor()) *
              (q['multiplier'] as num? ?? 1).toInt()
        : _mystery
        ? 100 +
              (elapsed < hintTimes.first
                  ? 0
                  : (50 *
                            (30000 - elapsed).clamp(0, 30000) /
                            (30000 - hintTimes.first))
                        .floor())
        : (100 -
                  hintCost * hints.length +
                  (50 * (deadline - _now).clamp(0, roundMs) / roundMs)
                      .floor()) *
              (q['multiplier'] as num? ?? 1).toInt();
    final blocked = before
        ? 'Tur başlıyor'
        : revealed
        ? 'Tur kapandı · sıradaki geliyor'
        : _room['submitted'] == true
        ? 'Cevabın kilitlendi · rakip bekleniyor'
        : left == 0
        ? 'Süre doldu'
        : null;
    ClubRaceSide side(String name, Map<String, dynamic> t) => ClubRaceSide(
      name: name,
      score: (t['score'] as num? ?? 0).toInt(),
      wrong: 0,
      caption: 'Doğru ${t['correct'] ?? 0}',
    );
    Widget club(Map<String, dynamic> c) => Expanded(
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.raised,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.border),
            ),
            child: CriterionMark(
              ArenaCriterion({'label': '${c['name'] ?? ''}', 'type': 'club'}),
              size: 44,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${c['name'] ?? ''}',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
    final reveal = _room['reveal'] is num
        ? (_room['reveal'] as num).toInt()
        : null;
    final them = _room['opponentAnswer'];
    // Order rounds reveal a list of periods; compare by value.
    final rivalRight = them != null && '${_room['reveal']}' == '$them';
    return Column(
      children: [
        ArenaHeader(
          title: _career
              ? 'Kariyer Yarışı'
              : _fakeClub
              ? 'Sahte Kulüp Düellosu'
              : _mystery
              ? 'Gizem Düellosu'
              : 'Transfer Düellosu',
          subtitle: _ranked
              ? 'Rastgele eşleşme'
              : 'Arkadaş maçı · Oda ${_room['code'] ?? _room['id'] ?? ''}',
          tag: 'CANLI 1v1',
          canPop: false,
          actions: [
            ArenaIconButton(
              tooltip: 'Yeniden bağlan',
              icon: Icons.refresh_rounded,
              onPressed: _busy || _accountChanged ? null : _load,
            ),
          ],
        ),
        Divider(height: 1, color: p.border),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              if (_error != null)
                GameErrorPanel(
                  message: _error!,
                  accountChanged: _accountChanged,
                  onRetry: _busy || _accountChanged ? null : _load,
                ),
              if (_feedback != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Semantics(
                    liveRegion: true,
                    child: ArenaNote(text: _feedback!),
                  ),
                ),
              ClubRaceScoreCard(
                me: side('Sen', mine),
                rival: side('Rakip', theirs),
                maxWrong: null,
                secondsLeft: left,
                totalSeconds: roundMs ~/ 1000,
                countdown: before ? ((start - _now) / 1000).ceil() : null,
                status: 'TUR ${round + 1}/$total',
              ),
              const SizedBox(height: 12),
              Semantics(
                label: 'Tur ${round + 1} / $total',
                excludeSemantics: true,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < total; i++)
                      Container(
                        width: total > 6 ? 24 : 30,
                        height: total > 6 ? 24 : 30,
                        margin: EdgeInsets.symmetric(
                          horizontal: total > 6 ? 3 : 4,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _roundResults.containsKey(i)
                              ? (_roundResults[i]! ? p.success : p.error)
                                    .withValues(alpha: .2)
                              : i == round
                              ? p.limeTint
                              : p.raised,
                          border: Border.all(
                            width: i == round ? 2 : 1,
                            color: _roundResults.containsKey(i)
                                ? (_roundResults[i]! ? p.success : p.error)
                                : i == round
                                ? Arena.lime
                                : p.border,
                          ),
                        ),
                        child: _roundResults.containsKey(i)
                            ? Icon(
                                _roundResults[i]!
                                    ? Icons.check_rounded
                                    : Icons.close_rounded,
                                size: 16,
                                color: _roundResults[i]! ? p.success : p.error,
                              )
                            : Text(
                                '${i + 1}',
                                style: text.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: i == round ? Arena.lime : p.muted,
                                ),
                              ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (before || q.isEmpty)
                const ArenaNote(
                  icon: Icons.timer_outlined,
                  text:
                      'Tur başlıyor: ikiniz aynı soruyu aynı anda göreceksiniz.',
                )
              else ...[
                if (_career)
                  _careerClue(q)
                else if (_fakeClub)
                  _fakeClue(q)
                else if (_mystery)
                  _mysteryClue(q)
                else
                  ArenaCard(
                    glow: p.accent,
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ArenaPill(child: Text(_window(q))),
                            if (_levels[q['difficulty']] != null)
                              ArenaPill(
                                dot: hubAmber(context),
                                child: Text(_levels[q['difficulty']]!),
                              ),
                            if ((q['multiplier'] as num? ?? 1) > 1)
                              ArenaPill(
                                filled: true,
                                color: Arena.lime,
                                child: Text(
                                  'Son tur · puan ×${q['multiplier']}',
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Semantics(
                          label:
                              '${rewardMap(q['from'])['name']} kulübünden ${rewardMap(q['to'])['name']} kulübüne',
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              club(rewardMap(q['from'])),
                              Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  color: p.accent,
                                  size: 28,
                                ),
                              ),
                              club(rewardMap(q['to'])),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Bu transferi yapan futbolcu kim?',
                          textAlign: TextAlign.center,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                ArenaCard(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < hintTimes.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                i < hints.length
                                    ? Icons.lightbulb_rounded
                                    : Icons.lock_clock_outlined,
                                size: 20,
                                color: i < hints.length
                                    ? hubAmber(context)
                                    : p.muted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  i < hints.length
                                      ? (_mystery
                                            ? '${i + 1}. ${hints[i]}'
                                            : hints[i])
                                      : _mystery
                                      ? '${i + 1}. bilgi · ${((start + hintTimes[i] - _now) / 1000).ceil().clamp(0, 60)} sn sonra açılır'
                                      : '${hintNames[i]} · ${((start + hintTimes[i] - _now) / 1000).ceil().clamp(0, 60)} sn sonra açılır · −$hintCost',
                                  style: i < hints.length
                                      ? text.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        )
                                      : text.bodyMedium?.copyWith(
                                          color: p.muted,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!revealed && _room['submitted'] != true && left > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: ArenaPill(
                            filled: true,
                            color: Arena.lime,
                            child: Text('Şimdi doğru bilirsen +$worth puan'),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_mystery) ...[
                  const ArenaSection(
                    'Tahminini seç',
                    icon: Icons.person_search_outlined,
                  ),
                  for (final o in _rows(q['options']))
                    _mysteryOption(o, blocked),
                ],
                if (_career && q['kind'] == 'order') ...[
                  const ArenaSection(
                    'Eskiden yeniye sırala',
                    icon: Icons.swap_vert_rounded,
                  ),
                  for (var i = 0; i < _order.length; i++) _orderRow(i, blocked),
                  const SizedBox(height: 4),
                  ArenaPrimaryButton(
                    label: blocked ?? 'Sıralamayı gönder',
                    icon: Icons.send_rounded,
                    onPressed: blocked != null || _busy || !_connected
                        ? null
                        : _answer,
                  ),
                ] else if (_career) ...[
                  ArenaSection(
                    q['kind'] == 'missing'
                        ? 'Eksik kulübü seç'
                        : 'Futbolcuyu seç',
                    icon: q['kind'] == 'missing'
                        ? Icons.shield_outlined
                        : Icons.person_search_outlined,
                  ),
                  for (final o in _rows(q['options']))
                    _mysteryOption(o, blocked, club: q['kind'] == 'missing'),
                ],
                if (_fakeClub) ...[
                  const ArenaSection(
                    'Sahte kulübü seç',
                    icon: Icons.search_off_rounded,
                  ),
                  FakeClubOptions(
                    options: _rows(q['options']),
                    selectedId: (_selected as num?)?.toInt(),
                    fakeClubId: (_room['reveal'] as num?)?.toInt(),
                    onSelected: blocked != null || _busy || !_connected
                        ? null
                        : (id) {
                            setState(() => _selected = id);
                            _answer();
                          },
                  ),
                ],
                if (revealed) ...[
                  const SizedBox(height: 12),
                  ArenaCard(
                    glow: _room['correct'] == true ? p.success : p.error,
                    child: Row(
                      children: [
                        if (_fakeClub || _career)
                          Icon(
                            _room['correct'] == true
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            size: 40,
                            color: _room['correct'] == true
                                ? p.success
                                : p.error,
                          )
                        else
                          ArenaPlayerAvatar(
                            id: reveal,
                            name: '${_room['explanation'] ?? ''}'
                                .split(' · ')
                                .first,
                            size: 48,
                            ring: _room['correct'] == true
                                ? p.success
                                : p.error,
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_room['correct'] == true ? 'Doğru' : 'Doğru cevap'}: '
                                '${_room['explanation'] ?? _answerText({...q, 'answer': _room['reveal']})}',
                                style: text.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                them == null
                                    ? 'Rakip cevap vermedi'
                                    : rivalRight
                                    ? 'Rakip de bildi'
                                    : 'Rakip yanlış cevap verdi',
                                style: text.bodySmall?.copyWith(color: p.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              ArenaNote(
                icon: Icons.rule_rounded,
                text: _career
                    ? 'Altı tur: üç eksik kulüp, iki kronoloji, bir gizemli kariyer. İkiniz aynı soruyu '
                          'görürsünüz; turda tek cevap hakkın var. Şıkka dokunmak cevabı gönderir; '
                          'kronolojide dönemleri sıralayıp gönder. Doğru cevap 100 puan ve kalan süreye göre '
                          '+50’ye kadar hız bonusu alır. İkiniz de cevaplayınca tur kapanır ve 2 sn sonra '
                          'sıradaki başlar.'
                    : _fakeClub
                    ? 'Dört kulüpten birinde futbolcu A takımda hiç oynamadı; o sahte kulübü bul. '
                          'Bir kulübe dokunmak cevabını gönderir; turda tek hakkın var. Doğru cevap 100 '
                          'puan ve kalan süreye göre +50’ye kadar hız bonusu; son tur ×2. Maç zorlaşarak '
                          'ilerler: 2 kolay, 3 orta, 3 zor, 2 efsane. İkiniz de cevaplayınca sonuç açılır '
                          've 2 sn sonra sıradaki tur başlar.'
                    : _mystery
                    ? 'İkinize aynı futbolcunun ülkesi ve mevkisi verilir; '
                          '${hintTimes.map((ms) => ms ~/ 1000).join(', ')}. saniyelerde ikinize aynı yeni '
                          'bilgi açılır. Bir şıkka dokunmak cevabını gönderir; turda tek hakkın var. Doğru '
                          'cevap 100 puan; hız bonusu ilk bilgiyle +50 başlar ve süre azaldıkça düşer. '
                          'İkiniz de cevaplayınca tur kapanır ve 2 sn sonra sıradaki başlar.'
                    : 'İkiniz aynı transferi görürsünüz; turda tek cevap hakkın var. Doğru cevap 100 '
                          'puan ve kalan süreye göre +50’ye kadar hız bonusu alır. 10. saniyede milliyet, '
                          '20. saniyede mevki açılır; açık her ipucu taban puanını 15 düşürür. İkiniz de '
                          'cevaplayınca tur kapanır ve 2 sn sonra sıradaki başlar.',
              ),
              const SizedBox(height: 16),
              ArenaSecondaryButton(
                label: 'Maçtan ayrıl (hükmen yenilgi)',
                icon: Icons.logout_rounded,
                color: p.error,
                onPressed: _busy ? null : _leave,
              ),
            ],
          ),
        ),
        if (!before && q.isNotEmpty && widget.mode == 'transfer_duel')
          ClubRaceInputBar(
            controller: _query,
            onChanged: _search,
            onSubmitted: (_) {
              if (_selected != null && blocked == null) _answer();
            },
            results: _results,
            onPick: (r) {
              if (_busy || blocked != null) return;
              setState(() => _selected = r['id']);
              _answer();
            },
            onSend: _answer,
            selected: null,
            searching: false,
            noMatch: false,
            lockSeconds: 0,
            outOfWrong: false,
            sending: _busy || !_connected,
            blocked: blocked,
          ),
      ],
    );
  }
}
