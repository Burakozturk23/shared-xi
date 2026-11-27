import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../app/app_feedback.dart';
import '../app/game_audio.dart';
import '../models/rewarded_ad_models.dart';
import '../services/warm_up.dart';
import '../services/auth_service.dart';
import '../services/story_support_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/bot_arena.dart';
import '../widgets/club_race_arena.dart';
import '../widgets/five_slot_reel.dart';
import '../widgets/game_ui.dart';
import '../widgets/paid_hint_button.dart';
import '../widgets/rewarded_coin_card.dart';
import '../widgets/hint_panel.dart';
import '../widgets/shared_grid_arena.dart';
import '../widgets/hub_ui.dart' show hubAmber;

/// Account-owned Loto, Team Race, Çinko and Random Five sessions. The server
/// owns the board, the answers, the bot and every clock; the legacy route is
/// used only when the server explicitly reports that the pilot is closed.
class SupportedBotPage extends StatefulWidget {
  const SupportedBotPage({
    super.key,
    required this.mode,
    required this.legacy,
    this.difficulty,
    this.clubId,
    this.clubName,
    this.service,
    this.rewardCard,
  });
  final String mode;
  final String? difficulty, clubId, clubName;
  final Widget legacy;
  final StorySupportService? service;

  /// End-of-match coin bonus; defaults to the real ad card outside tests.
  final Widget Function(String placement)? rewardCard;
  @override
  State<SupportedBotPage> createState() => _SupportedBotPageState();
}

class _SupportedBotPageState extends State<SupportedBotPage>
    with WidgetsBindingObserver {
  late final StorySupportService _service;
  final _answer = TextEditingController();
  Map<String, dynamic> _data = {}, _run = {};
  List<Map<String, dynamic>> _suggestions = [];
  final Set<int> _cells = {};
  int? _hintCell;
  late String _difficulty = widget.difficulty ?? 'medium';
  bool _busy = false,
      _legacy = false,
      _accountChanged = false,
      _watching = false;
  String? _error, _owner;

  /// A real-time move the server's clock overtook ("next player"): shown briefly,
  /// never blocks play or the refresh the way an error does.
  String? _notice;
  bool _noticeRefresh = false;
  int _lastSync = 0;
  Timer? _poll, _search, _noticeTimer;
  StreamSubscription<dynamic>? _auth;
  int _searchEpoch = 0, _offset = 0;

  /// Background refresh: never shows the loading bar or locks input. A refresh
  /// that started before the player's own action never overwrites its result.
  bool _polling = false;
  int _actions = 0;
  String get _kind => widget.mode.substring(4);
  bool get _realtime => _kind == 'loto' || _kind == 'team_race';
  bool get _active => _run.isNotEmpty && _run['finished'] != true;
  bool get _paused => _run['paused'] == true;
  bool get _canPlay =>
      _active &&
      !_busy &&
      !_accountChanged &&
      _error == null &&
      !_paused &&
      (_realtime || _run['turn'] == 'user');
  String get _title => const {
    'loto': 'Football Loto',
    'team_race': 'Takım Yarışı',
    'cinko': 'Futbol Çinko',
    'random_five': 'Rastgele Beşler',
  }[_kind]!;
  int get _now => DateTime.now().millisecondsSinceEpoch + _offset;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service =
        widget.service ??
        StorySupportService(
          useCallable: 'actBotSupport',
          loadCallable: 'getBotSupport',
          watchPlacement: 'bot_support_hint',
        );
    if (widget.service == null)
      _auth = AuthService.authStateChanges.listen((user) {
        if (_owner != null && user?.uid != _owner && mounted) {
          setState(() {
            _accountChanged = true;
            _run = {};
            _suggestions = [];
            _answer.clear();
            _cells.clear();
            _error = 'Hesap değişti. Oyunu kapatıp yeniden aç.';
          });
        }
      });
    _load();
    if (widget.service == null) WarmUp.functions(['actBotSupport']);
    _poll = Timer.periodic(Duration(milliseconds: _realtime ? 1000 : 750), (_) {
      // A server that sends `rules` also sends botAt: no fixed-rate poll needed.
      if (_kind == 'loto' || _kind == 'team_race' && _run['rules'] != null)
        return _lotoTick();
      if (_busy || _error != null || _accountChanged || !_active || _paused)
        return;
      if (_realtime) {
        _refresh();
        return;
      }
      if (_run['turn'] != 'bot') return;
      final botAt = _run['botAt'] as num?;
      if (botAt == null || _now >= botAt || _now - _lastSync >= 10000)
        _refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_legacy || _accountChanged || _watching) return;
    // Real-time clocks pause in the background exactly like the legacy controllers.
    if (state == AppLifecycleState.paused &&
        _realtime &&
        _active &&
        !_paused &&
        (_run['pausesLeft'] == null || _pausesLeft > 0))
      _act('pause');
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _search?.cancel();
    _noticeTimer?.cancel();
    _auth?.cancel();
    _answer.dispose();
    super.dispose();
  }

  String _message(Object e) => e is FirebaseFunctionsException
      ? e.message ?? 'Oyunu yenile.'
      : 'İşlem tamamlanamadı. Yenile ile kaldığın yerden devam et.';
  Future<void> _work(Future<void> Function() task) async {
    if (_busy || _accountChanged) return;
    _actions++;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    var stale = false;
    try {
      await task();
    } catch (e) {
      if (mounted && !_accountChanged) {
        // The server clock moved on (next Loto player, closed round, no pause left).
        // A sticky error would stop the refresh and lock the board while the clock runs.
        stale =
            _run.isNotEmpty &&
            e is FirebaseFunctionsException &&
            (e.code == 'failed-precondition' || e.code == 'invalid-argument');
        _noticeRefresh = stale && e.code == 'failed-precondition';
        setState(() => stale ? _notice = _message(e) : _error = _message(e));
        // Long enough to read after the next player arrives; the next move clears it too.
        if (stale) {
          _noticeTimer?.cancel();
          _noticeTimer = Timer(const Duration(seconds: 6), () {
            if (mounted) setState(() => _notice = null);
          });
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    // Only a state the server moved on needs a catch-up; a refused move changed nothing.
    if (stale && mounted && _noticeRefresh) unawaited(_refresh());
  }

  // Loto, every second: redraw the clock, count down, and ask the server only when the
  // shown player's time is up, the bot is due to place, or 10 s passed without news.
  void _lotoTick() {
    if (!mounted || _accountChanged || !_active || _paused) return;
    // Loto: the shown player's clock. Team Race: the round's end while it runs.
    final deadline =
        (_kind == 'loto'
                ? _run['deadline']
                : _run['over'] == true
                ? null
                : _run['endsAt'])
            as num?;
    final botAt = _run['botAt'] as num?;
    final left = _seconds(_kind == 'loto' ? 'deadline' : 'endsAt');
    if (_kind == 'loto' && deadline != null && [5, 3, 1].contains(left)) {
      AppFeedback.sfx(
        Sfx.countdown,
        eventId: 'bot:${_run['id']}:cd:${_run['index']}:$left',
      );
    }
    setState(() {});
    if (_busy || _error != null) return;
    if (deadline != null && _now >= deadline ||
        botAt != null && _now >= botAt ||
        _now - _lastSync >= 10000)
      _refresh();
  }

  // Cues follow the server-confirmed session; event IDs stop polls repeating them.
  void _sounds(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
    String? action,
  ) {
    final id = after['id'];
    if (id == null) return;
    final same = before['id'] == id;
    if (!same && after['finished'] != true)
      AppFeedback.sfx(Sfx.matchStart, eventId: 'bot:$id:start');
    if (same && action != null) {
      final last = rewardMap(after['last']);
      switch ((_kind, action)) {
        case ('loto', 'place'):
          AppFeedback.sfx(Sfx.slotLock);
        case ('team_race', 'guess'):
          AppFeedback.sfx(
            (after['userFound'] as num? ?? 0) >
                    (before['userFound'] as num? ?? 0)
                ? Sfx.answerCorrect
                : Sfx.answerWrong,
          );
        case ('cinko', 'confirm'):
          AppFeedback.sfx(
            _list2(last['wrong']).isNotEmpty
                ? Sfx.answerWrong
                : _list2(last['correct']).length >= 3
                ? Sfx.perfectCombo
                : Sfx.slotLock,
          );
        case ('random_five', 'guess'):
          AppFeedback.sfx(
            after['turn'] == 'user' ? Sfx.answerWrong : Sfx.answerCorrect,
          );
        case (_, 'next'):
          AppFeedback.sfx(Sfx.roundTransition);
      }
    }
    if (same &&
        after['finished'] == true &&
        after['completed'] == true &&
        before['finished'] != true) {
      AppFeedback.sfx(
        after['winner'] == 1 ? Sfx.champion : Sfx.whistle,
        eventId: 'bot:$id:end',
      );
    }
  }

  void _accept(Map<String, dynamic> data, [String? action]) {
    if (!mounted || _accountChanged) return;
    setState(() {
      final previous = _run;
      _data = data;
      _legacy = data['legacy'] == true;
      _run = rewardMap(data['session']);
      if (_run['serverNow'] is num)
        _offset =
            (_run['serverNow'] as num).toInt() -
            DateTime.now().millisecondsSinceEpoch;
      _lastSync = _now;
      if (_run['revision'] != previous['revision'] ||
          _run['round'] != previous['round']) {
        _suggestions = [];
        _searchEpoch++;
        if (_kind != 'cinko') _cells.clear();
      }
      // Çinko keeps the player's selection across a hint (it bumps the revision): only
      // cells that got taken or closed drop out, and all of it once the turn passes.
      if (_kind == 'cinko') {
        if (_run['turn'] != 'user' || _run['finished'] == true) {
          _cells.clear();
        } else {
          _cells.removeWhere((i) {
            final c = rewardMap(_cellsOf(i));
            return (c['owner'] as num? ?? 0) != 0 || c['playable'] != true;
          });
        }
      }
      if (_hintCell != null &&
          rewardMap(_cellsOf(_hintCell!))['playable'] != true)
        _hintCell = null;
      if (!_legacy) _sounds(previous, _run, action);
    });
  }

  Future<void> _refresh() async {
    if (_polling || _busy || _accountChanged) return;
    _polling = true;
    final epoch = _actions;
    try {
      final data = await _service.load(widget.mode, widget.mode);
      if (epoch == _actions && !_busy) _accept(data);
    } catch (_) {
      // The next poll retries; the player's own actions report errors.
    } finally {
      _polling = false;
    }
  }

  Future<void> _load() => _work(() async {
    if (widget.service == null && _owner == null) {
      final user = await AuthService.ensureGuestSignedIn();
      _owner = user.uid;
    }
    _accept(await _service.load(widget.mode, widget.mode));
  });
  Future<void> _act(String action, [Map<String, dynamic> extra = const {}]) =>
      _work(() async {
        final data = await _service.use({
          'mode': widget.mode,
          'targetId': widget.mode,
          'action': action,
          'sessionId': _run['id'],
          'revision': _run['revision'],
          'version': action == 'start' ? _data['version'] : _run['version'],
          if (action == 'start') 'difficulty': _difficulty,
          if (action == 'start' && widget.clubId != null)
            'clubId': widget.clubId,
          ...extra,
        });
        _accept(data, action);
        _searchEpoch++;
        _suggestions = [];
        _answer.clear();
      });
  Future<void> _watch(Object target, {String? itemId}) => _work(() async {
    _watching = true;
    try {
      await _service.watch({
        'mode': widget.mode,
        'sessionId': _run['id'],
        'target': target,
        'boostId': 'boost_basic',
        if (itemId != null) 'itemId': itemId,
      });
    } finally {
      _watching = false;
    }
    _accept(await _service.load(widget.mode, widget.mode));
  });
  void _find(String query) {
    final epoch = ++_searchEpoch;
    _search?.cancel();
    setState(() => _suggestions = []);
    if (query.trim().length < 2 || !_canPlay) return;
    _search = Timer(const Duration(milliseconds: 250), () async {
      try {
        final result = await _service.finish('searchBotSupport', {
          'mode': widget.mode,
          'sessionId': _run['id'],
          'query': query.trim(),
        });
        if (!mounted || epoch != _searchEpoch || _accountChanged) return;
        setState(
          () => _suggestions = (result['players'] as List? ?? const [])
              .map(rewardMap)
              .toList(),
        );
      } catch (e) {
        if (mounted && epoch == _searchEpoch)
          setState(() => _error = _message(e));
      }
    });
  }

  String _label(dynamic raw) => rewardMap(raw)['label']?.toString() ?? '—';
  List<dynamic> _list(String key) => _run[key] as List? ?? const [];
  dynamic _cellsOf(int i) =>
      _list('cells').length > i ? _list('cells')[i] : null;
  int _seconds(String key) => _run[key] is num
      ? (((_run[key] as num).toInt() - _now) / 1000).ceil().clamp(0, 999)
      : 0;
  String get _subtitle => switch (_kind) {
    'loto' => 'Birebir kapışma · 16 kutu',
    'team_race' =>
      'Ortak oyuncu yarışı · ${((_run['round'] as num? ?? 0).toInt()) + 1}. tur',
    'cinko' => 'Taktik tahta · 5×5 düello',
    _ => 'Taktik düello · 5 kulüp',
  };
  PitchColors get _p => PitchColors.of(context);
  TextTheme get _text => Theme.of(context).textTheme;

  @override
  Widget build(BuildContext context) {
    if (_legacy) return widget.legacy;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              ArenaHeader(
                title: _title,
                subtitle: _subtitle,
                canPop: !_busy,
                actions: [
                  if (_realtime && _active)
                    ArenaIconButton(
                      tooltip: _paused
                          ? 'Devam et'
                          : _run['pausesLeft'] != null
                          ? 'Duraklat · $_pausesLeft hak'
                          : 'Duraklat',
                      icon: _paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      onPressed:
                          _busy ||
                              !_paused &&
                                  _run['pausesLeft'] != null &&
                                  _pausesLeft <= 0
                          ? null
                          : () => _act(_paused ? 'resume' : 'pause'),
                    ),
                  ArenaIconButton(
                    tooltip: 'Yenile',
                    icon: Icons.refresh_rounded,
                    onPressed: _busy || _accountChanged ? null : _load,
                  ),
                ],
              ),
              Divider(height: 1, color: _p.border),
              Expanded(
                child: ListView(
                  key: const ValueKey('bot-list'),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  children: [
                    if (_busy) const LinearProgressIndicator(),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: ArenaNote(
                          text: _error!,
                          icon: Icons.error_outline_rounded,
                          color: _p.error,
                        ),
                      ),
                    if (_run.isEmpty && !_busy && !_accountChanged) ..._setup(),
                    if (_notice != null &&
                        !(['loto', 'cinko'].contains(_kind) && _active))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Semantics(
                          liveRegion: true,
                          child: ArenaNote(
                            key: const ValueKey('bot-notice'),
                            text: _notice!,
                            icon: Icons.info_outline_rounded,
                          ),
                        ),
                      ),
                    if (_run.isNotEmpty && _kind == 'loto') _lotoScore(),
                    if (_run.isNotEmpty && _kind == 'cinko') _cinkoScore(),
                    if (_run.isNotEmpty && _kind == 'random_five') _fiveScore(),
                    if (_run.isNotEmpty && _kind == 'team_race') _raceScore(),
                    if (_run.isNotEmpty) ...[
                      if (![
                        'loto',
                        'cinko',
                        'random_five',
                        'team_race',
                      ].contains(_kind))
                        ArenaScoreRow(
                          assisted: _run['assisted'] == true,
                          user: _run['userScore'] ?? 0,
                          bot: _run['botScore'] ?? 0,
                          scoreLabel: _kind == 'team_race' ? 'TUR' : 'SKOR',
                        ),
                      if (_run['feedback'] != null && !_fiveBarShown) ...[
                        const SizedBox(height: 12),
                        ArenaNote(text: '${_run['feedback']}'),
                      ],
                      if (_paused) ...[
                        const SizedBox(height: 12),
                        const ArenaNote(
                          icon: Icons.pause_circle_outline_rounded,
                          text:
                              'Oyun duraklatıldı. Devam ettiğinde saat kaldığı yerden işler.',
                        ),
                      ],
                      const SizedBox(height: 14),
                      if (_kind == 'loto') ..._loto(),
                      if (_kind == 'team_race') ..._race(),
                      if (_kind == 'cinko') ..._cinko(),
                      if (_kind == 'random_five') ..._five(),
                      if (_active) ...[
                        const SizedBox(height: 12),
                        ArenaFinishLink(
                          onPressed: _busy ? null : () => _act('finish'),
                        ),
                      ],
                      if (!_active) ...[
                        const SizedBox(height: 16),
                        serverMatchResult(_run, bot: true),
                        ?_rewardCard(),
                        const SizedBox(height: 12),
                        ArenaPrimaryButton(
                          label: 'Yeni maç',
                          icon: Icons.replay_rounded,
                          onPressed: _busy || _data['availability'] != true
                              ? null
                              : () => _act('start'),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              if (_kind == 'loto' && _active) _lotoBar(),
              if (_fiveBarShown) _fiveBar(),
              if (_raceBarShown) _raceBar(),
              if (_kind == 'cinko' &&
                  _canPlay &&
                  _cells.isNotEmpty &&
                  _cinkoConnected)
                _cinkoBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _rewardCard() {
    final placement = const {
      'loto': 'loto_result',
      'team_race': 'team_race_result',
      'cinko': 'cinko_result',
      'random_five': 'random_five_result',
    }[_kind]!;
    return widget.rewardCard?.call(placement) ??
        (widget.service == null
            ? RewardedCoinCard(placement: placement)
            : null);
  }

  /// Turn line of the turn-based modes: "Sıra sende" / "Bot oynuyor…".
  Widget _turn() {
    final turn = _run['turn'];
    final mine = turn == 'user';
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: mine ? Arena.lime : Arena.bot,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            turn == 'bot'
                ? 'Bot oynuyor…'
                : turn == 'result'
                ? 'Tur sonucu'
                : 'Sıra sende',
            style: _text.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  List<Widget> _setup() => [
    ArenaCard(
      glow: _p.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.clubName == null
                ? 'Her hamle hesabına kaydedilir. Maç Coin vermez, sonunda isteğe bağlı bonus olabilir; yardımlı sonuç ayrı tutulur.'
                : '${widget.clubName} ile yarış. Her hamle hesabına kaydedilir; yardımlı sonuç ayrı tutulur.',
            style: _text.bodyMedium,
          ),
          if (widget.difficulty == null) ...[
            const SizedBox(height: 14),
            Text(
              'ZORLUK',
              style: _text.labelSmall?.copyWith(
                color: _p.muted,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final (id, label) in const [
                  ('easy', 'Kolay'),
                  ('medium', 'Orta'),
                  ('hard', 'Zor'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _difficulty == id,
                    onSelected: (_) => setState(() => _difficulty = id),
                  ),
              ],
            ),
            if (_kind == 'cinko') ...[
              const SizedBox(height: 8),
              Text(
                const {
                  'easy':
                      'Bot en bilinen 1.500 futbolcuyu bilir, bir hamlede en fazla 2 bağlı kutu alır, sık sık yanlış kutu işaretler.',
                  'medium':
                      'Bot ilk 4.000 futbolcuyu bilir, bir hamlede en fazla 3 bağlı kutu alır, ara sıra yanlış kutu işaretler.',
                  'hard':
                      'Bot neredeyse herkesi bilir, en uzun bağlı grubu alır, nadiren yanlış kutu işaretler.',
                }[_difficulty]!,
                key: const ValueKey('cinko-level-about'),
                style: _text.bodySmall?.copyWith(color: _p.muted),
              ),
            ],
          ],
        ],
      ),
    ),
    const SizedBox(height: 16),
    ArenaPrimaryButton(
      label: 'Maça başla',
      icon: Icons.sports_soccer_rounded,
      onPressed: _data['availability'] == true && _error == null
          ? () => _act('start')
          : null,
    ),
  ];

  Widget _support(
    Object target,
    String key,
    String about, {
    bool enabled = true,
  }) {
    final text = rewardMap(_run['hints'])[key];
    return ArenaHintCard(
      children: [
        if (text != null)
          Text('$text', style: _text.bodyMedium)
        else ...[
          Text(about),
          const Text('Kullanılırsa sonuç Yardımlı olarak kaydolur.'),
          const SizedBox(height: 10),
          hintEntry(
                _run,
                target: target,
                disabled: !_canPlay || !enabled,
                send: (p) => _act('hint', {'target': target, ...p}),
                watch: (id) => _watch(target, itemId: id),
              ) ??
              PaidHintButton(
                session: _run,
                sku: 'boost_basic',
                label: 'Temel bilgi',
                disabled: !_canPlay || !enabled,
                onUse: (payment) =>
                    _act('hint', {'target': target, ...payment}),
                onWatch: () => _watch(target),
              ),
        ],
      ],
    );
  }

  Widget _picker(void Function(Map<String, dynamic>) onPick, String label) =>
      ArenaSearch(
        controller: _answer,
        enabled: _canPlay,
        onChanged: _find,
        hint: label,
        suggestions: _suggestions,
        onPick: _canPlay ? onPick : null,
      );

  // Loto: shown player, 4×4 board, then the bot's board. Same pieces as the online Loto.
  List<Widget> _loto() {
    final placements = rewardMap(_run['placements']),
        bot = rewardMap(_run['botPlacements']);
    final current = rewardMap(_run['current']);
    final index = _run['index'] as num? ?? 16;
    final placed = placements.length;
    final open = _lotoOpen;
    return [
      if (_active)
        ArenaCard(
          glow: Arena.lime,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ArenaPill(
                    child: Text(
                      '${(index.toInt() + 1).clamp(1, 16)} / 16 OYUNCU',
                    ),
                  ),
                  ArenaPill(child: Text('Kartın $placed/16 kutu')),
                  ArenaPill(
                    key: const ValueKey('loto-pauses'),
                    dot: _pausesLeft > 0 ? Arena.lime : _p.error,
                    child: Text(
                      'Duraklatma $_pausesLeft/${_run['pauses'] ?? 2}',
                    ),
                  ),
                ],
              ),
              if (current.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    ArenaPlayerAvatar(
                      id: current['id'],
                      name: '${current['name']}',
                      size: 52,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${current['name']}',
                            key: const ValueKey('loto-current'),
                            style: _text.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            open
                                ? 'Kartında uyduğu boş kutuya dokun ya da pas geç.'
                                : 'Süre doldu · sıradaki futbolcu geliyor',
                            style: _text.bodyMedium?.copyWith(color: _p.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      const SizedBox(height: 12),
      ArenaSection(
        _active ? 'Senin kartın · $placed/16' : 'Senin kartın',
        icon: Icons.grid_4x4_rounded,
      ),
      _lotoBoard((i) {
        final cell = rewardMap(placements['$i']);
        final c = _lotoCriterion(i);
        return ArenaTile(
          key: ValueKey('loto-cell-$i'),
          compact: true,
          minHeight: 84,
          criterion: c,
          state: cell.isEmpty
              ? ArenaTileState.idle
              : cell['correct'] == true
              ? ArenaTileState.correct
              : cell['correct'] == false
              ? ArenaTileState.wrong
              : ArenaTileState.mine,
          player: cell.isEmpty ? null : cell,
          tag: cell.isEmpty
              ? null
              : cell['correct'] == true
              ? 'DOĞRU'
              : cell['correct'] == false
              ? 'YANLIŞ'
              : 'SEN',
          semantics: c.label,
          onTap: open && cell.isEmpty
              ? () => _act('place', {'index': index, 'target': i})
              : null,
        );
      }),
      if (_active && current.isNotEmpty) ...[
        const SizedBox(height: 12),
        _support(
          index.toInt(),
          'player_$index',
          'Temel destek oyuncunun milliyetini ve mevki grubunu verir. '
              'Saat durmaz; süreli oyunda reklamla alınamaz.',
        ),
      ],
      if (_active) ...[
        const SizedBox(height: 12),
        ArenaNote(
          icon: Icons.rule_rounded,
          text:
              'Gelen futbolcuyu kulüp, milliyet ya da lig kriterine uyan boş bir kutuya koy. '
              'Bot aynı 16 futbolcuyu kendi kartında oynar. Doğrular maç sonunda açılır: '
              'her doğru kutu +10. Maç başına ${_run['pauses'] ?? 2} duraklatma hakkın var; '
              'uygulamadan çıkmak da bir hak kullanır.',
        ),
      ],
      if (!_active && bot.isNotEmpty) ...[
        const SizedBox(height: 12),
        const ArenaSection('Bot kartı', icon: Icons.smart_toy_outlined),
        _lotoBoard((i) {
          final cell = rewardMap(bot['$i']);
          return ArenaTile(
            compact: true,
            minHeight: 64,
            criterion: _lotoCriterion(i),
            state: cell.isEmpty
                ? ArenaTileState.locked
                : cell['correct'] == true
                ? ArenaTileState.correct
                : ArenaTileState.wrong,
            tag: cell.isEmpty
                ? null
                : cell['correct'] == true
                ? 'DOĞRU'
                : 'YANLIŞ',
            player: cell.isEmpty ? null : cell,
          );
        }),
        const SizedBox(height: 8),
        Text(
          'Pas: ${_run['passed'] ?? 0} · Süre aşımı: ${_run['timedOut'] ?? 0}',
          style: _text.bodySmall?.copyWith(color: _p.muted),
        ),
      ],
    ];
  }

  ArenaCriterion _lotoCriterion(int i) => ArenaCriterion(
    rewardMap(_list('criteria').length > i ? _list('criteria')[i] : null),
  );

  // Rows of four, each as tall as its tallest tile (large text never clips a criterion).
  Widget _lotoBoard(Widget Function(int) cell) =>
      SharedMatrixBoard(size: 4, cell: cell);

  /// The shown player can still be placed: on the server clock, not paused, not busy.
  bool get _lotoOpen =>
      _canPlay && _run['current'] != null && _seconds('deadline') > 0;

  int get _pausesLeft => (_run['pausesLeft'] as num? ?? 2).toInt();

  // Me | clock ring | bot, as in the online Loto. Scores stay hidden until both cards are full.
  Widget _lotoScore() {
    final done = !_active;
    final placed = rewardMap(_run['placements']).length;
    final botIndex = (_run['botIndex'] as num? ?? 0).toInt();
    final level =
        const {
          'easy': 'Kolay',
          'medium': 'Orta',
          'hard': 'Zor',
        }['${_run['difficulty']}'] ??
        'Orta';
    final ticking = _active && !_paused && _run['current'] != null;
    return ClubRaceScoreCard(
      key: const ValueKey('loto-score'),
      me: ClubRaceSide(
        name: _run['assisted'] == true ? 'Yardımlı' : 'Yardımsız',
        score: (_run['userScore'] as num? ?? 0).toInt(),
        wrong: 0,
        display: done ? null : '$placed',
        caption: done
            ? '${((_run['userScore'] as num? ?? 0) / 10).round()} doğru'
            : 'Pas ${_run['passed'] ?? 0} · Süre ${_run['timedOut'] ?? 0}',
      ),
      rival: ClubRaceSide(
        name: '$level bot',
        score: (_run['botScore'] as num? ?? 0).toInt(),
        wrong: 0,
        display: done ? null : '$botIndex',
        caption: done
            ? '${((_run['botScore'] as num? ?? 0) / 10).round()} doğru'
            : '$botIndex/16 yerleştirdi',
      ),
      rivalTag: 'BOT',
      maxWrong: null,
      secondsLeft: ticking ? _seconds('deadline') : null,
      totalSeconds: ticking ? (_run['seconds'] as num? ?? 15).toInt() : null,
      status: done
          ? 'BİTTİ'
          : _paused
          ? 'DURAKLADI'
          : 'OYUNCU ${((_run['index'] as num? ?? 0).toInt() + 1).clamp(1, 16)}/16',
      myTurn: done ? null : !_paused,
    );
  }

  // Pinned like the online Loto bar: what to do now, and the pass.
  Widget _lotoBar() {
    final current = rewardMap(_run['current']);
    final open = _lotoOpen;
    final (String label, Color tone) = _paused
        ? (
            'Oyun duraklatıldı · devam edince saat kaldığı yerden işler',
            _p.muted,
          )
        : _notice != null
        ? ('$_notice Yeni futbolcuya bak.', hubAmber(context))
        : !open
        ? ('Sıradaki futbolcu geliyor…', _p.muted)
        : ('${current['name']} · kartında uyduğu kutuya dokun', Arena.lime);
    return Material(
      color: _p.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: _p.border)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                label,
                key: ValueKey(
                  _notice != null ? 'bot-notice' : 'loto-bar-label',
                ),
                style: _text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: tone,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ArenaSecondaryButton(
              key: const ValueKey('loto-pass'),
              label: 'Pas geç · 0 puan, kutu boş kalır',
              icon: Icons.redo_rounded,
              onPressed: open
                  ? () => _act('pass', {'index': _run['index']})
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // Team Race as the online Club-Club race: the two clubs, the players found, the bar.
  List<Widget> _race() {
    final round = (_run['round'] as num? ?? 0).toInt();
    final countdown = _seconds('startsAt');
    final total = (_run['total'] as num? ?? 0).toInt();
    final over = _run['over'] == true;
    final found = [for (final f in _list('found')) rewardMap(f)];
    final maxRounds = (_run['maxRounds'] as num?)?.toInt();
    return [
      if (_run['pausesLeft'] != null && _active)
        _line(
          'Duraklatma hakkı: $_pausesLeft/${_run['pauses'] ?? 2} · uygulamadan çıkmak da bir hak kullanır.',
          icon: Icons.pause_circle_outline_rounded,
        ),
      const SizedBox(height: 12),
      ClubRaceVersus(
        key: const ValueKey('race-versus'),
        left: rewardMap(_run['club']),
        right: rewardMap(_run['opponent']),
        answerCount: total,
        task: _active && !over && countdown > 0
            ? 'Hazır ol: tur $countdown sn sonra başlıyor.'
            : 'İki kulüpte de oynamış futbolcuları yaz.',
        footnote:
            'Her ismi ilk yazan alır · çok bulan turu kazanır · 3 tur alan maçı alır'
            '${maxRounds == null ? '' : ' (en fazla $maxRounds tur)'}',
      ),
      ArenaSection(
        'Bulunan ${found.length} / $total',
        icon: Icons.people_alt_outlined,
        trailing: Text(
          over
              ? 'Tur ${round + 1} bitti'
              : '${(total - found.length).clamp(0, total)} kalan',
          textAlign: TextAlign.end,
          style: _text.labelMedium?.copyWith(
            color: Arena.lime,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      if (found.isEmpty && !over)
        const ArenaNote(
          icon: Icons.bolt_rounded,
          text: 'Henüz kimse bulmadı. İlk ismi yazan puanı alır.',
        ),
      for (final f in found.reversed)
        ClubRaceFoundTile(player: f, mine: f['owner'] == 1, rivalLabel: 'Bot'),
      if (over && _list('missed').isNotEmpty) ...[
        const ArenaSection(
          'Kimsenin bulamadığı',
          icon: Icons.visibility_outlined,
        ),
        Text(
          _list('missed').map((p) => '${rewardMap(p)['name']}').join(' · '),
          style: _text.bodySmall?.copyWith(color: _p.muted),
        ),
      ],
      if (_active && over) ...[
        const SizedBox(height: 14),
        ArenaPrimaryButton(
          key: const ValueKey('race-next'),
          label: 'Sonraki tur',
          icon: Icons.arrow_forward_rounded,
          onPressed: _busy ? null : () => _act('next'),
        ),
      ],
      if (_active && !over && countdown == 0) ...[
        const SizedBox(height: 14),
        ArenaSecondaryButton(
          key: const ValueKey('race-end'),
          icon: Icons.flag_outlined,
          label: (_run['rules'] as num? ?? 1) >= 2
              ? 'Turu şimdi bitir · o anki skorla'
              : 'Turu bitir · bot kalan sürede oynar',
          onPressed: _canPlay
              ? () => _act('end_round', {'round': round})
              : null,
        ),
        const SizedBox(height: 12),
        _support(
          round,
          'round_$round',
          'Temel destek kalan ortak oyunculardan birinin milliyetini ve mevkisini verir.',
        ),
      ],
    ];
  }

  // Me | clock ring | bot: this round's finds, rounds won underneath.
  Widget _raceScore() {
    final over = _run['over'] == true;
    final countdown = _seconds('startsAt');
    final round = (_run['round'] as num? ?? 0).toInt();
    final level =
        const {
          'easy': 'Kolay',
          'medium': 'Orta',
          'hard': 'Zor',
        }['${_run['difficulty']}'] ??
        'Orta';
    final ticking = _active && !over && !_paused && _run['endsAt'] != null;
    final maxRounds = _run['maxRounds'];
    return ClubRaceScoreCard(
      key: const ValueKey('race-score'),
      me: ClubRaceSide(
        name: _run['assisted'] == true ? 'Yardımlı' : 'Yardımsız',
        score: (_run['userFound'] as num? ?? 0).toInt(),
        wrong: 0,
        caption: 'Tur galibiyeti ${_run['userScore'] ?? 0}/3',
      ),
      rival: ClubRaceSide(
        name: '$level bot',
        score: (_run['botFound'] as num? ?? 0).toInt(),
        wrong: 0,
        caption: 'Tur galibiyeti ${_run['botScore'] ?? 0}/3',
      ),
      rivalTag: 'BOT',
      maxWrong: null,
      secondsLeft: ticking && countdown == 0 ? _seconds('endsAt') : null,
      totalSeconds: ticking ? 70 : null,
      countdown: ticking && countdown > 0 ? countdown : null,
      status: !_active
          ? 'BİTTİ'
          : _paused
          ? 'DURAKLADI'
          : over
          ? 'TUR BİTTİ'
          : 'TUR ${round + 1}${maxRounds == null ? '' : '/$maxRounds'}',
      myTurn: null,
    );
  }

  // Pinned like the online race bar while the round runs.
  Widget _raceBar() => ClubRaceInputBar(
    key: const ValueKey('race-input'),
    controller: _answer,
    onChanged: _find,
    onSubmitted: (_) {
      if (_suggestions.length == 1) {
        _act('guess', {
          'round': _run['round'],
          'playerId': _suggestions.first['id'],
        });
      }
    },
    results: _suggestions,
    onPick: (p) => _act('guess', {'round': _run['round'], 'playerId': p['id']}),
    onSend: () {},
    selected: null,
    searching: false,
    noMatch: false,
    lockSeconds: 0,
    outOfWrong: false,
    sending: _busy,
    showSend: false,
    label: 'Futbolcu ara',
    hint: 'İki kulüpte oynamış futbolcu; öneriye dokun, gitsin',
  );

  bool get _raceBarShown =>
      _kind == 'team_race' &&
      _active &&
      !_paused &&
      _run['over'] != true &&
      _seconds('startsAt') == 0 &&
      !_accountChanged;

  Widget _line(String text, {IconData? icon}) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: _p.muted),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(text, style: _text.bodyMedium?.copyWith(color: _p.muted)),
        ),
      ],
    ),
  );

  // Çinko as the online board: pick connected open cells, then name the player in the bar.
  List<Widget> _cinko() {
    final myTurn = _active && _run['turn'] == 'user';
    final rules2 = (_run['rules'] as num? ?? 1) >= 2;
    final bonus = (_run['secondBonus'] as num? ?? 0).toInt();
    final passes = (_run['passes'] as num? ?? 0).toInt();
    final connected = _cinkoConnected;
    final one = _cells.length == 1 ? _cells.first : null;
    return [
      if (_active && rules2 && bonus > 0)
        _line(
          _run['botFirst'] == true
              ? 'Bu maçta bot önce başladı; sen +$bonus puanla başladın.'
              : 'Bu maçta sen önce başladın; bot +$bonus puanla başladı.',
          icon: Icons.flag_outlined,
        ),
      if (_notice != null && _active)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Semantics(
            liveRegion: true,
            child: ArenaNote(
              key: const ValueKey('bot-notice'),
              text: _notice!,
              icon: Icons.info_outline_rounded,
              color: hubAmber(context),
            ),
          ),
        ),
      const SizedBox(height: 12),
      ArenaSection(
        'Taktik alan · 5×5',
        icon: Icons.grid_on_rounded,
        trailing: passes > 0 && _active
            ? Text(
                'Pas serisi $passes/${_run['maxPasses'] ?? 4}',
                style: _text.labelSmall?.copyWith(color: hubAmber(context)),
              )
            : null,
      ),
      _cinkoBoard(),
      if (myTurn) ...[
        const SizedBox(height: 10),
        Text(
          _cells.isEmpty
              ? 'Bağlı kutulara dokun, sonra futbolcuyu yaz.'
              : !connected
              ? 'Seçili kutular yan yana ya da üst üste bağlı olmalı; çapraz sayılmaz.'
              : '${_cells.length} kutu seçili · doğrular +1, yanlışlar −1',
          key: const ValueKey('cinko-status'),
          textAlign: TextAlign.center,
          style: _text.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: _cells.isEmpty
                ? _p.muted
                : connected
                ? Arena.lime
                : _p.error,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ArenaSecondaryButton(
                key: const ValueKey('cinko-pass'),
                label: 'Pas geç',
                icon: Icons.redo_rounded,
                onPressed: _canPlay ? () => _act('pass') : null,
              ),
            ),
            if (_cells.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: ArenaSecondaryButton(
                  label: 'Seçimi temizle',
                  icon: Icons.close_rounded,
                  color: _p.muted,
                  onPressed: () => setState(_cells.clear),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (one != null)
          _support(
            one,
            'cell_$one',
            '${_label(_cellsOf(one))} kutusu için kullanılmamış bir adayın bilgisi.',
          )
        else
          const ArenaNote(
            icon: Icons.lightbulb_outline_rounded,
            text: 'Destek için tek bir açık kutu seç.',
          ),
      ],
      if (_active) ...[
        const SizedBox(height: 12),
        ArenaNote(
          icon: Icons.rule_rounded,
          text:
              'Sırayla oynanır: yan yana ya da üst üste bağlı açık kutuları seç (çapraz sayılmaz), '
              'sonra bir futbolcu yaz. Doğru kutu +1, yanlış kutu −1; uyan kutular senin olur, '
              'uymayanlar açık kalır. Her futbolcu maçta bir kez kullanılır. '
              '${rules2 && bonus > 0 ? 'İlk başlayan rastgele seçilir; ikinci başlayan maça $bonus puanla başlar. Dört pas üst üste gelirse ya da açık kutu kalmazsa maç biter.' : 'Açık kutu kalmazsa maç biter.'}',
        ),
      ],
      ..._cinkoMoves(),
    ];
  }

  // Selected cells form one group, joined side by side or one above the other.
  bool get _cinkoConnected {
    if (_cells.isEmpty) return false;
    final left = {..._cells};
    final queue = [left.first];
    left.remove(queue.first);
    for (var k = 0; k < queue.length; k++) {
      final c = queue[k];
      for (final n in [
        c - 5,
        c + 5,
        if (c % 5 > 0) c - 1,
        if (c % 5 < 4) c + 1,
      ]) {
        if (left.remove(n)) queue.add(n);
      }
    }
    return left.isEmpty;
  }

  // Me | VS | bot, with each side's cells and the second-start bonus.
  Widget _cinkoScore() {
    final userTurn = _run['turn'] == 'user';
    final cells = [for (final c in _list('cells')) rewardMap(c)];
    final mine = cells.where((c) => c['owner'] == 1).length;
    final theirs = cells.where((c) => c['owner'] == 2).length;
    final bonus = (_run['secondBonus'] as num? ?? 0).toInt();
    final botFirst = _run['botFirst'] == true;
    final level =
        const {
          'easy': 'Kolay',
          'medium': 'Orta',
          'hard': 'Zor',
        }['${_run['difficulty']}'] ??
        'Orta';
    return ClubRaceScoreCard(
      key: const ValueKey('cinko-score'),
      me: ClubRaceSide(
        name: _run['assisted'] == true ? 'Yardımlı' : 'Yardımsız',
        score: (_run['userScore'] as num? ?? 0).toInt(),
        wrong: 0,
        caption:
            'Kutu $mine${bonus > 0 && botFirst ? ' · +$bonus ikinci başlama' : ''}',
      ),
      rival: ClubRaceSide(
        name: '$level bot',
        score: (_run['botScore'] as num? ?? 0).toInt(),
        wrong: 0,
        caption:
            'Kutu $theirs${bonus > 0 && !botFirst ? ' · +$bonus ikinci başlama' : ''}',
      ),
      rivalTag: 'BOT',
      maxWrong: null,
      secondsLeft: null,
      totalSeconds: null,
      status: !_active
          ? 'BİTTİ'
          : userTurn
          ? 'SIRA SENDE'
          : 'BOT OYNUYOR',
      myTurn: _active ? userTurn : null,
    );
  }

  Widget _cinkoBoard() => SharedMatrixBoard(
    size: 5,
    minCellWidth: 62,
    scrollCellWidth: 66,
    cell: _cinkoCell,
  );

  Widget _cinkoCell(int i) {
    final cell = rewardMap(_cellsOf(i));
    final owner = cell['owner'] as num? ?? 0;
    final picked = _cells.contains(i);
    final closed = owner == 0 && cell['playable'] != true && _active;
    final player = rewardMap(cell['player']);
    final canTap = _canPlay && owner == 0 && cell['playable'] == true;
    return ArenaTile(
      key: ValueKey('cinko-cell-$i'),
      compact: true,
      minHeight: 76,
      criterion: ArenaCriterion(cell),
      player: player.isEmpty ? null : player,
      state: picked
          ? ArenaTileState.selected
          : owner == 1
          ? ArenaTileState.mine
          : owner == 2
          ? ArenaTileState.bot
          : closed || _active && _run['turn'] != 'user'
          ? ArenaTileState.locked
          : ArenaTileState.idle,
      tag: picked
          ? 'SEÇİLİ'
          : owner == 1
          ? 'SEN'
          : owner == 2
          ? 'BOT'
          : closed
          ? 'KAPALI'
          : null,
      semantics:
          '${_label(cell)}${owner == 1
              ? ', senin'
              : owner == 2
              ? ', botun'
              : ''}',
      onTap: canTap
          ? () => setState(() => picked ? _cells.remove(i) : _cells.add(i))
          : null,
    );
  }

  // The last moves of both sides, newest first (older sessions only keep the last one).
  List<Widget> _cinkoMoves() {
    final moves = [
      for (final m in _list('moves')) rewardMap(m),
      if (_list('moves').isEmpty && rewardMap(_run['last']).isNotEmpty)
        rewardMap(_run['last']),
    ];
    if (moves.isEmpty) return const [];
    return [
      const SizedBox(height: 12),
      const ArenaSection('Son hamleler', icon: Icons.history_rounded),
      for (final m in moves)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(
                m['pass'] == true
                    ? Icons.redo_rounded
                    : (m['points'] as num? ?? 0) > 0
                    ? Icons.add_circle_outline_rounded
                    : Icons.remove_circle_outline_rounded,
                size: 18,
                color: m['owner'] == 1 ? _p.accent : hubAmber(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${m['owner'] == 1 ? 'Sen' : 'Bot'} · '
                  '${m['pass'] == true ? 'pas' : '${rewardMap(m['player'])['name']} · ${(m['correct'] as List? ?? []).length} doğru, ${(m['wrong'] as List? ?? []).length} yanlış · ${(m['points'] as num? ?? 0) > 0 ? '+' : ''}${m['points'] ?? 0}'}',
                ),
              ),
            ],
          ),
        ),
    ];
  }

  // Sends the selected cells with the named player (older sessions: choose, then confirm).
  Future<void> _cinkoSend(Map<String, dynamic> p) async {
    final cells = _cells.toList()..sort();
    if ((_run['rules'] as num? ?? 1) >= 2) {
      return _act('confirm', {'cells': cells, 'playerId': p['id']});
    }
    await _act('choose', {'playerId': p['id']});
    if (_run['current'] != null) await _act('confirm', {'cells': cells});
  }

  // Pinned like the online input bar once a connected group is selected.
  Widget _cinkoBar() => ClubRaceInputBar(
    key: const ValueKey('cinko-input'),
    controller: _answer,
    onChanged: _find,
    onSubmitted: (_) {
      if (_suggestions.length == 1) _cinkoSend(_suggestions.first);
    },
    results: _suggestions,
    onPick: _cinkoSend,
    onSend: () {},
    selected: null,
    searching: false,
    noMatch: false,
    lockSeconds: 0,
    outOfWrong: false,
    sending: _busy,
    showSend: false,
    label: 'Futbolcu ara · ${_cells.length} kutu',
    hint: 'En az 2 harf; öneriye dokun, gitsin',
  );

  // Random Five as online: the fives so far, the current five on the reels, both answers.
  List<Widget> _five() {
    if ((_run['rules'] as num? ?? 1) < 2) return _fiveLegacy();
    final round = (_run['round'] as num? ?? 0).toInt();
    final total = (_run['totalRounds'] as num? ?? 5).toInt();
    final history = [for (final h in _list('history')) rewardMap(h)];
    final now = history.length > round ? history[round] : <String, dynamic>{};
    final closed = now['user'] != null && now['bot'] != null;
    final clubs = [for (final k in _list('clubs')) rewardMap(k)];
    final marks = <String, List<Color>>{};
    if (closed) {
      for (final (raw, tone) in [
        (now['user'], Arena.lime),
        (now['bot'], hubAmber(context)),
      ]) {
        for (final k in _list2(rewardMap(raw)['clubs'])) {
          (marks['${rewardMap(k)['id']}'] ??= []).add(tone);
        }
      }
    }
    int points(int n, String side) =>
        (rewardMap(history.length > n ? history[n][side] : null)['points']
                    as num? ??
                0)
            .toInt();
    Widget step(int n) {
      final done =
          history.length > n &&
          history[n]['user'] != null &&
          history[n]['bot'] != null;
      final current = n == round && !closed && _active;
      return Expanded(
        child: Container(
          key: ValueKey('five-step-$n'),
          margin: EdgeInsets.only(left: n == 0 ? 0 : 6),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: current ? _p.limeTint : _p.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: current ? Arena.lime.withValues(alpha: .6) : _p.border,
            ),
          ),
          child: Column(
            children: [
              Text(
                '${n + 1}',
                style: _text.labelSmall?.copyWith(color: _p.muted),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  done ? '+${points(n, 'user')} · +${points(n, 'bot')}' : '–',
                  style: _text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: done ? _p.text : _p.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final table = [
      for (final n in _list2(_run['fivePoints'])) (n as num).toInt(),
    ];
    return [
      Row(children: [for (var n = 0; n < total; n++) step(n)]),
      const SizedBox(height: 4),
      Text(
        'Kutularda: senin puanın · botun puanı',
        textAlign: TextAlign.center,
        style: _text.labelSmall?.copyWith(color: _p.muted),
      ),
      ArenaSection(
        'Beşli ${round + 1} / $total',
        icon: Icons.casino_outlined,
        trailing: Text(
          !_active
              ? 'Maç bitti'
              : closed
              ? 'Beşli açıldı'
              : 'Bot tahminini yaptı',
          textAlign: TextAlign.end,
          style: _text.labelMedium?.copyWith(
            color: Arena.lime,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      FiveSlotReel(
        round: round,
        clubs: clubs,
        decoys: [
          for (final h in history)
            for (final k in _list2(h['clubs'])) rewardMap(k),
        ],
        marks: marks,
      ),
      const SizedBox(height: 4),
      if (table.length == 6)
        Text(
          'Puan: 1 kulüp +${table[1]} · 2 kulüp +${table[2]} · 3 kulüp +${table[3]} · '
          '4 kulüp +${table[4]} · 5 kulüp +${table[5]}',
          key: const ValueKey('five-table'),
          textAlign: TextAlign.center,
          style: _text.labelSmall?.copyWith(color: _p.muted),
        ),
      const SizedBox(height: 8),
      if (closed)
        ..._fiveRecap(now, clubs, title: false)
      else if (_active) ...[
        ArenaNote(
          icon: Icons.bolt_rounded,
          text:
              'Bu beşli için tek tahmin: en çok kulübünde oynamış futbolcuyu yaz. '
              'Hiçbir kulübe uymayan isim için ${_run['wrongLeft'] ?? 3} deneme hakkın var; '
              'üçü de uymazsa beşli pas sayılır.',
        ),
        const SizedBox(height: 8),
        const ArenaNote(
          key: ValueKey('five-bot-locked'),
          icon: Icons.lock_rounded,
          text: 'Bot tahminini yaptı; sen cevaplayınca ikisi birlikte açılır.',
        ),
        const SizedBox(height: 10),
        ArenaSecondaryButton(
          key: const ValueKey('five-pass'),
          label: 'Pas geç · 0 puan',
          icon: Icons.redo_rounded,
          color: _p.muted,
          onPressed: _canPlay ? () => _act('pass') : null,
        ),
        const SizedBox(height: 12),
        _support(
          round,
          'round_$round',
          'Temel destek bir adayın beş kulüpten kaçına uyduğunu, milliyetini ve mevkisini verir.',
        ),
      ],
      if (_active && _run['turn'] == 'result') ...[
        const SizedBox(height: 12),
        ArenaPrimaryButton(
          key: const ValueKey('five-next'),
          label: 'Sonraki beşli',
          icon: Icons.arrow_forward_rounded,
          onPressed: _busy ? null : () => _act('next'),
        ),
      ],
      if (history.any((h) => (h['round'] as num? ?? -1) != round)) ...[
        const SizedBox(height: 4),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          initiallyExpanded: !_active,
          title: Text(
            'Önceki beşliler',
            style: _text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          children: [
            for (final h in history.reversed)
              if ((h['round'] as num? ?? -1) != round)
                ..._fiveRecap(h, [
                  for (final k in _list2(h['clubs'])) rewardMap(k),
                ]),
          ],
        ),
      ],
    ];
  }

  // One closed five: both answers (with the clubs they cover) and its best names.
  List<Widget> _fiveRecap(
    Map<String, dynamic> h,
    List<Map<String, dynamic>> clubs, {
    bool title = true,
  }) {
    Widget answer(dynamic raw, {required bool mine}) {
      final a = rewardMap(raw);
      final player = rewardMap(a['player']);
      if (a['pass'] == true || player.isEmpty) {
        return ArenaNote(
          icon: Icons.redo_rounded,
          text: mine
              ? 'Bu beşlide pas geçtin · 0 puan'
              : 'Bot bu beşlide pas geçti · 0 puan',
        );
      }
      final names = [for (final k in _list2(a['clubs'])) _label(k)];
      return ClubRaceFoundTile(
        player: player,
        mine: mine,
        points: (a['points'] as num? ?? 0).toInt(),
        rivalLabel: 'Bot',
        detail: names.isEmpty
            ? 'Beş kulübün hiçbirine uymadı'
            : '${names.length} kulüp · ${names.join(', ')}',
      );
    }

    final best = [for (final b in _list2(h['best'])) rewardMap(b)];
    return [
      if (title)
        ArenaSection(
          'Beşli ${(h['round'] as num? ?? 0).toInt() + 1}',
          icon: Icons.casino_outlined,
          trailing: Text(
            clubs.map(_label).join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: _text.labelSmall?.copyWith(color: _p.muted),
          ),
        ),
      answer(h['user'], mine: true),
      answer(h['bot'], mine: false),
      if (best.isNotEmpty)
        ArenaNote(
          icon: Icons.lightbulb_outline_rounded,
          color: hubAmber(context),
          text:
              'En iyi cevaplar: ${best.map((p) => '${p['name']} (${p['clubs']} kulüp · +${p['points'] ?? p['clubs']})').join(' · ')}',
        ),
    ];
  }

  bool get _fiveBarShown =>
      _kind == 'random_five' &&
      (_run['rules'] as num? ?? 1) >= 2 &&
      _active &&
      _run['turn'] == 'user' &&
      !_accountChanged;

  // Me | VS | bot with the last five's points.
  Widget _fiveScore() {
    final round = (_run['round'] as num? ?? 0).toInt();
    final history = [for (final h in _list('history')) rewardMap(h)];
    int last(String side) {
      for (final h in history.reversed) {
        if (h['user'] != null && h['bot'] != null) {
          return (rewardMap(h[side])['points'] as num? ?? 0).toInt();
        }
      }
      return 0;
    }

    final played = history
        .where((h) => h['user'] != null && h['bot'] != null)
        .isNotEmpty;
    final level =
        const {
          'easy': 'Kolay',
          'medium': 'Orta',
          'hard': 'Zor',
        }['${_run['difficulty']}'] ??
        'Orta';
    return ClubRaceScoreCard(
      key: const ValueKey('five-score'),
      me: ClubRaceSide(
        name: _run['assisted'] == true ? 'Yardımlı' : 'Yardımsız',
        score: (_run['userScore'] as num? ?? 0).toInt(),
        wrong: 0,
        caption: played ? 'Son beşli +${last('user')}' : 'Henüz beşli yok',
      ),
      rival: ClubRaceSide(
        name: '$level bot',
        score: (_run['botScore'] as num? ?? 0).toInt(),
        wrong: 0,
        caption: played ? 'Son beşli +${last('bot')}' : 'Henüz beşli yok',
      ),
      rivalTag: 'BOT',
      maxWrong: null,
      secondsLeft: null,
      totalSeconds: null,
      status: !_active
          ? 'BİTTİ'
          : _run['turn'] == 'result'
          ? 'BEŞLİ AÇILDI'
          : 'BEŞLİ ${round + 1}/${_run['totalRounds'] ?? 5}',
      myTurn: _active ? _run['turn'] == 'user' : null,
    );
  }

  // Pinned like the online bar: the last refusal, then the search.
  Widget _fiveBar() {
    final feedback = _run['feedback']?.toString();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (feedback != null)
          Material(
            color: _p.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  feedback,
                  key: const ValueKey('five-feedback'),
                  style: _text.labelLarge?.copyWith(
                    color: hubAmber(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ClubRaceInputBar(
          key: const ValueKey('five-input'),
          controller: _answer,
          onChanged: _find,
          onSubmitted: (_) {
            if (_suggestions.length == 1) {
              _act('guess', {'playerId': _suggestions.first['id']});
            }
          },
          results: _suggestions,
          onPick: (p) => _act('guess', {'playerId': p['id']}),
          onSend: () {},
          selected: null,
          searching: false,
          noMatch: false,
          lockSeconds: 0,
          outOfWrong: false,
          sending: _busy,
          showSend: false,
          label: 'Futbolcu ara',
          hint: 'En çok kulübe uyanı yaz; öneriye dokun, gitsin',
        ),
      ],
    );
  }

  List<Widget> _fiveLegacy() {
    final round = (_run['round'] as num? ?? 0).toInt();
    String move(dynamic raw) {
      final m = rewardMap(raw);
      return m.isEmpty
          ? '—'
          : m['pass'] == true
          ? 'Pas · 0'
          : '${rewardMap(m['player'])['name']} · +${_list2(m['clubs']).length}';
    }

    final clubs = _list('clubs');
    Widget clubCard(int i) => Expanded(
      child: ArenaTile(
        criterion: ArenaCriterion(
          rewardMap(clubs.length > i ? clubs[i] : null),
        ),
        minHeight: 84,
      ),
    );
    return [
      ArenaCard(
        glow: _p.accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ArenaPill(filled: true, child: Text('${round + 1}/5. TUR')),
                Text(
                  _run['botFirst'] == true
                      ? 'bu turda bot önce oynar'
                      : 'bu turda sen önce oynarsın',
                  style: _text.bodySmall?.copyWith(color: _p.muted),
                ),
              ],
            ),
            if (_active) ...[const SizedBox(height: 12), _turn()],
            if (_active && _run['turn'] == 'user') ...[
              const SizedBox(height: 4),
              Text(
                '${_run['wrongLeft'] ?? 3} deneme hakkı',
                style: _text.bodySmall?.copyWith(color: _p.muted),
              ),
            ],
          ],
        ),
      ),
      ArenaSection(
        'Aktif 5 kulüp',
        icon: Icons.shield_outlined,
        trailing: Text(
          'En az 1 kulüp',
          style: _text.labelSmall?.copyWith(color: Arena.lime),
        ),
      ),
      Row(children: [clubCard(0), clubCard(1)]),
      Row(children: [clubCard(2), clubCard(3), clubCard(4)]),
      for (final h in _list('history').map(rewardMap)) ...[
        if (h['user'] != null || h['bot'] != null) ...[
          const SizedBox(height: 10),
          ArenaNote(
            icon: Icons.history_rounded,
            text:
                '${(h['round'] as num? ?? 0).toInt() + 1}. tur · Sen: ${move(h['user'])} · '
                'Bot: ${move(h['bot'])}',
          ),
        ],
        // After both moves: the round's best answers (most clubs).
        if (_list2(h['best']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'En iyi cevaplar: ${_list2(h['best']).map((b) => '${rewardMap(b)['name']} (${rewardMap(b)['clubs']})').join(' · ')}',
              style: _text.bodySmall?.copyWith(color: _p.muted),
            ),
          ),
      ],
      if (_active && _run['turn'] == 'result') ...[
        const SizedBox(height: 14),
        ArenaPrimaryButton(
          label: 'Sonraki tur',
          icon: Icons.arrow_forward_rounded,
          onPressed: _busy ? null : () => _act('next'),
        ),
      ],
      if (_active && _run['turn'] == 'user') ...[
        const SizedBox(height: 14),
        ArenaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _picker(
                (p) => _act('guess', {'playerId': p['id']}),
                'Beş kulüpten en az birinde oynamış futbolcu',
              ),
              const SizedBox(height: 10),
              ArenaNote(
                text:
                    'Uymayan isim için ${_run['wrongLeft'] ?? 3} deneme hakkın var; üçü de uymazsa tur pas sayılır. '
                    'Her oyuncu maçta bir kez kullanılır.',
              ),
              const SizedBox(height: 10),
              ArenaSecondaryButton(
                label: 'Pas · 0 puan',
                color: _p.muted,
                onPressed: _canPlay ? () => _act('pass') : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _support(
          round,
          'round_$round',
          'Temel destek bir adayın beş kulüpten kaçına uyduğunu, milliyetini ve mevkisini verir.',
        ),
      ],
    ];
  }

  List<dynamic> _list2(dynamic raw) => raw is List ? raw : const [];
}
