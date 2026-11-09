import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../app/app_feedback.dart';
import '../app/game_audio.dart';
import '../models/rewarded_ad_models.dart';
import '../services/auth_service.dart';
import '../services/story_support_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/bot_arena.dart';
import '../widgets/game_ui.dart';
import '../widgets/paid_hint_button.dart';
import '../widgets/rewarded_coin_card.dart';
import '../widgets/hint_panel.dart';

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
  Timer? _poll, _search;
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
    _poll = Timer.periodic(Duration(milliseconds: _realtime ? 1000 : 750), (_) {
      if (_busy || _error != null || _accountChanged || !_active || _paused)
        return;
      if (_realtime || _run['turn'] == 'bot') _refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_legacy || _accountChanged || _watching) return;
    // Real-time clocks pause in the background exactly like the legacy controllers.
    if (state == AppLifecycleState.paused && _realtime && _active && !_paused)
      _act('pause');
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _search?.cancel();
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
    });
    try {
      await task();
    } catch (e) {
      if (mounted && !_accountChanged) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    if (_kind == 'loto' &&
        after['finished'] != true &&
        [5, 3, 1].contains(_seconds('deadline'))) {
      AppFeedback.sfx(
        Sfx.countdown,
        eventId: 'bot:$id:cd:${after['index']}:${_seconds('deadline')}',
      );
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
      if (_run['revision'] != previous['revision'] ||
          _run['round'] != previous['round']) {
        _suggestions = [];
        _searchEpoch++;
        if (_kind != 'cinko' || _run['current'] == null) _cells.clear();
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
                      tooltip: _paused ? 'Devam et' : 'Duraklat',
                      icon: _paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      onPressed: _busy
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
                    if (_run.isNotEmpty) ...[
                      ArenaScoreRow(
                        assisted: _run['assisted'] == true,
                        user: _run['userScore'] ?? 0,
                        bot: _run['botScore'] ?? 0,
                        scoreLabel: _kind == 'team_race' ? 'TUR' : 'SKOR',
                      ),
                      if (_run['feedback'] != null) ...[
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
        (widget.service == null ? RewardedCoinCard(placement: placement) : null);
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

  Widget _clock(String text, {bool urgent = false}) => ArenaPill(
    filled: true,
    color: urgent ? _p.error : _p.accent,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.timer_outlined,
          size: 16,
          color: urgent ? _p.error : _p.accent,
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(text)),
      ],
    ),
  );

  List<Widget> _setup() => [
    ArenaCard(
      glow: _p.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.clubName == null
                ? 'Her hamle hesabına kaydedilir. Maç ödülsüzdür; yardımlı sonuç ayrı tutulur.'
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

  // Rows grow with their content, so 320px and large text never clip a criterion.
  Widget _board(int columns, int count, Widget Function(int) cell) => Table(
    defaultVerticalAlignment: TableCellVerticalAlignment.intrinsicHeight,
    children: [
      for (var row = 0; row * columns < count; row++)
        TableRow(
          children: [
            for (var col = 0; col < columns; col++)
              row * columns + col < count
                  ? cell(row * columns + col)
                  : const SizedBox.shrink(),
          ],
        ),
    ],
  );

  Widget _picker(void Function(Map<String, dynamic>) onPick, String label) =>
      ArenaSearch(
        controller: _answer,
        enabled: _canPlay,
        onChanged: _find,
        hint: label,
        suggestions: _suggestions,
        onPick: _canPlay ? onPick : null,
      );

  List<Widget> _loto() {
    final placements = rewardMap(_run['placements']),
        bot = rewardMap(_run['botPlacements']);
    final current = rewardMap(_run['current']);
    final index = _run['index'] as num? ?? 16;
    final seconds = _seconds('deadline');
    ArenaTileState state(Map<dynamic, dynamic> placed) => placed.isEmpty
        ? ArenaTileState.idle
        : placed['correct'] == true
        ? ArenaTileState.correct
        : placed['correct'] == false
        ? ArenaTileState.wrong
        : ArenaTileState.mine;
    String? tag(Map<dynamic, dynamic> placed) => placed.isEmpty
        ? null
        : placed['correct'] == true
        ? '✓ DOĞRU'
        : placed['correct'] == false
        ? '✗ YANLIŞ'
        : 'SEN';
    return [
      if (_active)
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
                  ArenaPill(
                    filled: true,
                    child: Text('${(index.toInt() + 1).clamp(1, 16)} / 16 OYUNCU'),
                  ),
                  Text(
                    'Bot ${_run['botIndex'] ?? 0}/16 oyuncuyu yerleştirdi.',
                    style: _text.bodySmall?.copyWith(color: _p.muted),
                  ),
                  if (current.isNotEmpty)
                    _clock('$seconds sn', urgent: seconds <= 5),
                ],
              ),
              if (current.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    ArenaPlayerAvatar(
                      id: current['id'],
                      name: '${current['name']}',
                      size: 64,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${current['name']}',
                            style: _text.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Uyduğu bir kutuya dokun; yanlış kutu puan getirmez.',
                            style: _text.bodySmall?.copyWith(color: _p.muted),
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
      const SizedBox(height: 14),
      _board(4, 16, (i) {
        final placed = rewardMap(placements['$i']);
        final c = ArenaCriterion(rewardMap(_list('criteria').length > i ? _list('criteria')[i] : null));
        return ArenaTile(
          key: ValueKey('loto-cell-$i'),
          criterion: c,
          state: state(placed),
          player: placed.isEmpty ? null : placed,
          tag: tag(placed),
          semantics: c.label,
          onTap: _canPlay && current.isNotEmpty && placed.isEmpty
              ? () => _act('place', {'index': index, 'target': i})
              : null,
        );
      }),
      if (_active && current.isNotEmpty) ...[
        const SizedBox(height: 12),
        ArenaSecondaryButton(
          label: 'Pas · 0 puan, kutu boş kalır',
          onPressed: _canPlay ? () => _act('pass', {'index': index}) : null,
        ),
        const SizedBox(height: 12),
        _support(
          index.toInt(),
          'player_$index',
          'Temel destek oyuncunun milliyetini ve mevki grubunu verir. '
              'Saat durmaz; süreli oyunda reklamla alınamaz.',
        ),
      ],
      if (!_active && bot.isNotEmpty) ...[
        const ArenaSection('Bot tahtası', icon: Icons.smart_toy_outlined),
        _board(4, 16, (i) {
          final placed = rewardMap(bot['$i']);
          return ArenaTile(
            compact: true,
            minHeight: 64,
            criterion: ArenaCriterion(rewardMap(_list('criteria').length > i ? _list('criteria')[i] : null)),
            state: placed.isEmpty
                ? ArenaTileState.locked
                : placed['correct'] == true
                ? ArenaTileState.correct
                : ArenaTileState.wrong,
            player: placed.isEmpty ? null : placed,
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

  List<Widget> _race() {
    final round = (_run['round'] as num? ?? 0).toInt();
    final countdown = _seconds('startsAt');
    final total = (_run['total'] as num? ?? 0).toInt();
    final user = (_run['userFound'] as num? ?? 0).toInt();
    final bot = (_run['botFound'] as num? ?? 0).toInt();
    Widget club(dynamic raw) {
      final c = ArenaCriterion(rewardMap(raw));
      return Expanded(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _p.raised,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _p.border),
              ),
              child: CriterionMark(c, size: 44),
            ),
            const SizedBox(height: 8),
            Text(
              c.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
    }

    Widget meter(String title, int value, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title · $value',
              style: _text.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            // A drawn bar: a LinearProgressIndicator here would read as "loading".
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: _p.border,
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: total == 0 ? 0 : (value / total).clamp(0, 1),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return [
      ArenaCard(
        glow: _p.accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.hub_outlined, color: _p.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${round + 1}. TUR · ORTAK OYUNCU',
                    style: _text.labelLarge?.copyWith(
                      color: _p.accent,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            if (_active && _run['over'] != true && countdown > 0) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: _clock('Başlıyor: $countdown'),
              ),
            ],
            if (_active &&
                _run['over'] != true &&
                countdown == 0 &&
                _run['endsAt'] != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: _clock(
                  'Kalan süre: ${_seconds('endsAt')} sn',
                  urgent: _seconds('endsAt') <= 10,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                club(_run['club']),
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _p.accent.withValues(alpha: .5)),
                        ),
                        child: Icon(Icons.bolt_rounded, color: _p.accent),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$total ortak',
                        style: _text.labelSmall?.copyWith(color: _p.muted),
                      ),
                    ],
                  ),
                ),
                club(_run['opponent']),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                meter('SEN', user, _p.accent),
                const SizedBox(width: 10),
                meter('BOT', bot, Arena.bot),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Bu tur: Sen $user · Bot $bot/$total buldu · Kalan ${_run['remaining'] ?? 0}',
              style: _text.bodySmall?.copyWith(color: _p.muted),
            ),
          ],
        ),
      ),
      if (_list('found').isNotEmpty) ...[
        const ArenaSection('Bulunan oyuncular', icon: Icons.people_alt_outlined),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in _list('found').map(rewardMap))
              _foundChip(f, f['owner'] == 1),
          ],
        ),
      ],
      if (_run['over'] == true && _list('missed').isNotEmpty) ...[
        const ArenaSection('Kimsenin bulamadığı', icon: Icons.visibility_outlined),
        Text(
          _list('missed').map((p) => '${rewardMap(p)['name']}').join(' · '),
          style: _text.bodySmall?.copyWith(color: _p.muted),
        ),
      ],
      if (_active && _run['over'] == true) ...[
        const SizedBox(height: 14),
        ArenaPrimaryButton(
          label: 'Sonraki tur',
          icon: Icons.arrow_forward_rounded,
          onPressed: _busy ? null : () => _act('next'),
        ),
      ],
      if (_active && _run['over'] != true && countdown == 0) ...[
        const SizedBox(height: 14),
        _picker(
          (p) => _act('guess', {'round': round, 'playerId': p['id']}),
          'İki kulüpte oynamış futbolcu',
        ),
        const SizedBox(height: 10),
        ArenaSecondaryButton(
          icon: Icons.fast_forward_rounded,
          label: 'Turu bitir · bot kalan sürede oynar',
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

  Widget _foundChip(Map<dynamic, dynamic> f, bool mine) {
    final color = mine ? _p.accent : Arena.bot;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ArenaPlayerAvatar(id: f['id'], name: '${f['name']}', size: 28, ring: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${f['name']} · ${mine ? 'Sen' : 'Bot'}',
              overflow: TextOverflow.ellipsis,
              style: _text.labelMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _cinko() {
    final current = rewardMap(_run['current']);
    final last = rewardMap(_run['last']);
    final lastText = last.isEmpty
        ? null
        : '${last['owner'] == 1 ? 'Sen' : 'Bot'}: ${last['pass'] == true ? 'pas · 0' : '${rewardMap(last['player'])['name']} · ${(last['points'] as num? ?? 0) >= 0 ? '+' : ''}${last['points']}'}';
    Widget dot(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: _text.labelSmall?.copyWith(color: c)),
      ],
    );
    return [
      ArenaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_active) _turn(),
            if (lastText != null) ...[
              const SizedBox(height: 10),
              ArenaNote(
                text: lastText,
                icon: last['owner'] == 1
                    ? Icons.person_outline_rounded
                    : Icons.smart_toy_outlined,
                color: last['owner'] == 1 ? _p.accent : Arena.bot,
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      ArenaCard(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
              child: Row(
                children: [
                  Icon(Icons.grid_on_rounded, size: 18, color: Arena.lime),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'TAKTİK ALAN (5×5)',
                      style: _text.labelMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  dot(_p.accent, 'Sen'),
                  const SizedBox(width: 8),
                  dot(Arena.bot, 'Bot'),
                ],
              ),
            ),
            _board(
              5,
              _list('cells').length,
              (i) => _cinkoCell(i, current.isNotEmpty),
            ),
          ],
        ),
      ),
      if (_active && _run['turn'] == 'user') ...[
        const SizedBox(height: 14),
        if (current.isEmpty) ...[
          _picker(
            (p) => _act('choose', {'playerId': p['id']}),
            'Oyuncu seç · En az iki harf',
          ),
          const SizedBox(height: 8),
          Text(
            'Her oyuncu maçta bir kez kullanılır; doğru kutu +1, yanlış kutu −1.',
            style: _text.bodySmall?.copyWith(color: _p.muted),
          ),
          const SizedBox(height: 10),
          ArenaSecondaryButton(
            label: 'Pas · 0 puan',
            onPressed: _canPlay ? () => _act('pass') : null,
          ),
          const SizedBox(height: 12),
          if (_hintCell != null)
            _support(
              _hintCell!,
              'cell_$_hintCell',
              '${_label(_cellsOf(_hintCell!))} kutusu için kullanılmamış bir adayın bilgisi.',
            )
          else
            const ArenaNote(
              icon: Icons.lightbulb_outline_rounded,
              text: 'Destek için tahtadan açık bir kutu seç.',
            ),
        ] else ...[
          ArenaCard(
            glow: Arena.lime,
            child: Row(
              children: [
                ArenaPlayerAvatar(
                  id: current['id'],
                  name: '${current['name']}',
                  size: 48,
                  ring: Arena.lime,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${current['name']} · bağlı kutuları seç',
                    style: _text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ArenaPrimaryButton(
            icon: Icons.format_paint_outlined,
            label: 'Seçimi onayla · ${_cells.length} kutu',
            onPressed: _canPlay && _cells.isNotEmpty
                ? () => _act('confirm', {'cells': _cells.toList()..sort()})
                : null,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ArenaSecondaryButton(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Oyuncuyu değiştir',
                  onPressed: _canPlay ? () => _act('cancel') : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ArenaSecondaryButton(
                  label: 'Pas · 0 puan',
                  color: _p.muted,
                  onPressed: _canPlay ? () => _act('pass') : null,
                ),
              ),
            ],
          ),
        ],
      ],
    ];
  }

  Widget _cinkoCell(int i, bool selecting) {
    final cell = rewardMap(_cellsOf(i));
    final owner = cell['owner'] as num? ?? 0;
    final chosen = selecting ? _cells.contains(i) : _hintCell == i;
    final player = rewardMap(cell['player']);
    return ArenaTile(
      key: ValueKey('cinko-cell-$i'),
      compact: true,
      minHeight: 66,
      criterion: ArenaCriterion(cell),
      player: player.isEmpty ? null : player,
      state: owner == 1
          ? ArenaTileState.mine
          : owner == 2
          ? ArenaTileState.bot
          : chosen
          ? ArenaTileState.selected
          : cell['playable'] == true || !_active
          ? ArenaTileState.idle
          : ArenaTileState.locked,
      semantics:
          '${_label(cell)}${owner == 1
              ? ', senin'
              : owner == 2
              ? ', botun'
              : ''}',
      onTap: _canPlay && owner == 0 && cell['playable'] == true
          ? () => setState(() {
              if (selecting) {
                _cells.contains(i) ? _cells.remove(i) : _cells.add(i);
              } else {
                _hintCell = _hintCell == i ? null : i;
              }
            })
          : null,
    );
  }

  List<Widget> _five() {
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
        criterion: ArenaCriterion(rewardMap(clubs.length > i ? clubs[i] : null)),
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
