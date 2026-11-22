import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../models/grid_club_pool.dart';
import '../app/app_feedback.dart';
import '../app/game_audio.dart';
import '../models/rewarded_ad_models.dart';
import '../services/warm_up.dart';
import '../services/auth_service.dart';
import '../services/runtime_v4/game_data_v4_query_service.dart';
import '../services/story_support_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/bot_arena.dart';
import '../widgets/club_race_arena.dart';
import '../widgets/game_ui.dart';
import '../widgets/grid_criterion_label.dart';
import '../widgets/paid_hint_button.dart';
import '../widgets/rewarded_coin_card.dart';
import '../widgets/hint_panel.dart';
import '../widgets/hub_ui.dart' show hubAmber, upperTr;

/// Account-owned Grid session. Legacy route is selected only by the server's
/// explicit rollout response; a network error never creates a second game.
class SupportedGridPage extends StatefulWidget {
  const SupportedGridPage({
    super.key,
    required this.mode,
    required this.legacy,
    this.difficulty = 'medium',
    this.service,
    this.poolInput,
    this.rewardCard,
  });
  final String mode, difficulty;
  final Widget legacy;
  final StorySupportService? service;
  final Future<Map<String, dynamic>> Function()? poolInput;

  /// End-of-match coin bonus (bot only); defaults to the real ad card outside tests.
  final Widget Function(String placement)? rewardCard;
  @override
  State<SupportedGridPage> createState() => _SupportedGridPageState();
}

class _SupportedGridPageState extends State<SupportedGridPage>
    with WidgetsBindingObserver {
  late final StorySupportService _service;
  final _answer = TextEditingController();
  Map<String, dynamic> _data = {}, _run = {};
  List<Map<String, dynamic>> _suggestions = [];
  Object? _target;
  bool _busy = false, _legacy = false, _swap = false, _accountChanged = false;
  bool _polling = false, _searching = false, _noMatch = false;
  String? _error, _owner;
  late String _difficulty = widget.difficulty;

  /// One quiet load at the server's bot deadline (botAt) instead of a fixed-rate poll.
  Timer? _botTimer, _search;
  StreamSubscription<dynamic>? _auth;
  int _searchEpoch = 0;
  bool get _reverse => widget.mode.endsWith('reverse');
  bool get _random => widget.mode.endsWith('random');
  bool get _bot => widget.mode.startsWith('bot_');
  bool get _active => _run.isNotEmpty && _run['finished'] != true;
  bool get _canPlay =>
      _active &&
      !_busy &&
      !_accountChanged &&
      _error == null &&
      _run['turn'] == 'user';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service =
        widget.service ??
        StorySupportService(
          useCallable: 'actGridSupport',
          loadCallable: 'getGridSupport',
          watchPlacement: 'grid_support_hint',
        );
    if (widget.service == null) WarmUp.functions(['actGridSupport']);
    if (widget.service == null)
      _auth = AuthService.authStateChanges.listen((user) {
        if (_owner != null && user?.uid != _owner && mounted) {
          setState(() {
            _accountChanged = true;
            _run = {};
            _suggestions = [];
            _answer.clear();
            _error = 'Hesap değişti. Oyunu kapatıp yeniden aç.';
          });
        }
      });
    _load();
  }

  // The server plays the bot at botAt; ask once then (in server time), quietly, without the
  // progress bar. If the move is still pending the next answer schedules another check.
  void _scheduleBotLoad() {
    _botTimer?.cancel();
    if (_legacy ||
        _accountChanged ||
        _run['turn'] != 'bot' ||
        _run['finished'] == true)
      return;
    final botAt = (_run['botAt'] as num?)?.toInt();
    final serverNow = (_data['serverNow'] as num?)?.toInt();
    final wait = botAt != null && serverNow != null
        ? botAt - serverNow + 150
        : 750;
    _botTimer = Timer(
      Duration(milliseconds: wait.clamp(400, 5000)),
      _quietLoad,
    );
  }

  Future<void> _quietLoad() async {
    if (!mounted || _busy || _polling || _accountChanged || _error != null)
      return;
    _polling = true;
    try {
      final data = await _service.load(widget.mode, widget.mode);
      // A user action started meanwhile owns the newer state.
      if (!_busy) _accept(data);
    } catch (e) {
      if (mounted && !_accountChanged) setState(() => _error = _message(e));
    } finally {
      _polling = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_legacy && !_accountChanged)
      _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _botTimer?.cancel();
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
      AppFeedback.sfx(Sfx.matchStart, eventId: 'grid:$id:start');
    if (same && action == 'guess') {
      AppFeedback.sfx(
        after['feedback'] == 'Doğru.' ? Sfx.answerCorrect : Sfx.answerWrong,
      );
    } else if (same && action == 'place') {
      AppFeedback.sfx(Sfx.slotLock);
    }
    if (same &&
        after['finished'] == true &&
        after['completed'] == true &&
        before['finished'] != true) {
      AppFeedback.sfx(
        !_bot
            ? Sfx.achievement
            : after['winner'] == 1
            ? Sfx.champion
            : Sfx.whistle,
        eventId: 'grid:$id:end',
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
      // Follow the match being played (or a new one); after a match the pick stays the player's.
      if (_run['difficulty'] != null &&
          (previous['id'] != _run['id'] || _run['finished'] != true))
        _difficulty = '${_run['difficulty']}';
      if (!_legacy) _sounds(previous, _run, action);
      if (_run['turn'] != 'user' ||
          _run['finished'] == true ||
          _target is int &&
              (_reverse ? rewardMap(_run['axes']) : rewardMap(_run['cells']))
                  .containsKey('$_target') ||
          _target == 'pending' && _run['pending'] == null) {
        _target = null;
        _answer.clear();
        _suggestions = [];
        _searchEpoch++;
      }
    });
    _scheduleBotLoad();
  }

  Future<void> _load() => _work(() async {
    if (widget.service == null && _owner == null) {
      final user = await AuthService.ensureGuestSignedIn();
      _owner = user.uid;
    }
    _accept(await _service.load(widget.mode, widget.mode));
  });
  Future<Map<String, dynamic>> _pool() async {
    if (widget.poolInput != null) return widget.poolInput!();
    final pool = await GridClubPoolStore.load();
    if (pool.kind == GridPoolKind.broad)
      return {'clubIds': <String>[], 'minimumAnswers': 1};
    final clubs = pool.filter(
      await GameDataV4QueryService.instance.sharedXiClubCatalog(),
    );
    final supported = (_data['selectionClubIds'] as List? ?? const []).toSet();
    final ids = clubs
        .map((c) => 'club:${c.id}')
        .where(supported.contains)
        .toList();
    if (ids.isEmpty)
      throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message:
            'Bu seçimde desteklenen kulüp yok. Grid menüsünden havuzu genişlet.',
      );
    return {'clubIds': ids, 'minimumAnswers': pool.minimumAnswers};
  }

  Future<void> _act(String action, [Map<String, dynamic> extra = const {}]) =>
      _work(() async {
        final pool = action == 'start'
            ? await _pool()
            : const <String, dynamic>{};
        final data = await _service.use({
          'mode': widget.mode,
          'targetId': widget.mode,
          'action': action,
          'sessionId': _run['id'],
          'revision': _run['revision'],
          'version': action == 'start' ? _data['version'] : _run['version'],
          'difficulty': _difficulty,
          ...pool,
          ...extra,
        });
        _accept(data, action);
        _searchEpoch++;
        _suggestions = [];
        _answer.clear();
      });
  Future<void> _watch({String? itemId}) => _work(() async {
    final target = _target;
    await _service.watch({
      'mode': widget.mode,
      'sessionId': _run['id'],
      'target': target,
      'boostId': 'boost_basic',
      if (itemId != null) 'itemId': itemId,
    });
    _accept(await _service.load(widget.mode, widget.mode));
  });
  void _select(Object target) {
    if (!_canPlay) return;
    setState(() {
      _target = target;
      _answer.clear();
      _suggestions = [];
      _searchEpoch++;
    });
  }

  void _find(String query) {
    final epoch = ++_searchEpoch;
    _search?.cancel();
    final searchable = query.trim().length >= 2 && _canPlay;
    setState(() {
      _suggestions = [];
      _noMatch = false;
      _searching = searchable;
    });
    if (!searchable) return;
    final revision = _run['revision'];
    _search = Timer(const Duration(milliseconds: 250), () async {
      try {
        final result = await _service.finish('searchGridSupport', {
          'mode': widget.mode,
          'sessionId': _run['id'],
          'query': query.trim(),
        });
        if (!mounted ||
            epoch != _searchEpoch ||
            revision != _run['revision'] ||
            _accountChanged)
          return;
        setState(() {
          _suggestions =
              (result[_reverse ? 'criteria' : 'players'] as List? ?? const [])
                  .map(rewardMap)
                  .toList();
          _searching = false;
          _noMatch = _suggestions.isEmpty;
        });
      } catch (e) {
        if (mounted && epoch == _searchEpoch)
          setState(() {
            _searching = false;
            _error = _message(e);
          });
      }
    });
  }

  String _criterion(dynamic raw) => GridCriterionLabel.text(rewardMap(raw));
  List<dynamic> _list(String key) => _run[key] as List? ?? const [];
  String _cellCriteria(int i) {
    final rows = _list('rows'), cols = _list('cols');
    return '${i ~/ 3 + 1}. satır · ${i % 3 + 1}. sütun\n${_criterion(rows.length > i ~/ 3 ? rows[i ~/ 3] : null)} × '
        '${_criterion(cols.length > i % 3 ? cols[i % 3] : null)}';
  }

  String get _hintKey => _reverse
      ? 'axis_$_target'
      : _target == 'pending'
      ? 'pair_${_run['pairNumber']}'
      : 'cell_$_target';
  PitchColors get _p => PitchColors.of(context);
  TextTheme get _text => Theme.of(context).textTheme;
  String get _kindTitle => _reverse
      ? 'Tersten Grid'
      : _random
      ? 'Rastgele Grid'
      : 'Klasik Grid';
  String get _subtitle => _bot
      ? 'Bot düellosu · ${_levels[_difficulty] ?? 'Orta'}'
      : 'Solo antrenman · ${_reverse ? '6 eksen' : '9 kutu'}';

  // The input bar shows while a target waits for an answer (a verified pair only needs an
  // anchor). It stays up, disabled, while a request is in flight, so the list does not jump.
  bool get _answering =>
      _active &&
      !_accountChanged &&
      _error == null &&
      _run['turn'] == 'user' &&
      _target != null &&
      !(_target == 'pending' && rewardMap(_run['pending'])['player'] != null);

  @override
  Widget build(BuildContext context) {
    if (_legacy) return widget.legacy;
    final answering = _answering;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        body: SafeArea(
          child: GameContent(
            child: Column(
              children: [
                ArenaHeader(
                  title: _kindTitle,
                  subtitle: _subtitle,
                  tag: _bot ? 'VS BOT' : 'SOLO',
                  canPop: !_busy,
                  actions: [
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                      if (_run.isEmpty && !_busy && !_accountChanged)
                        ..._intro(),
                      if (_run.isNotEmpty) ...[
                        ..._feedback(),
                        _bot ? _scoreCard() : _header(),
                        ..._notes(),
                        const SizedBox(height: 14),
                        if (_active && _random) ..._pairArea(),
                        if (_reverse) _reverseBoard() else _board(),
                        if (answering) _targetCard(),
                        if (_active) ...[
                          const SizedBox(height: 14),
                          ArenaNote(icon: Icons.rule_rounded, text: _rules),
                          const SizedBox(height: 8),
                          ArenaFinishLink(
                            onPressed: _busy ? null : () => _act('finish'),
                          ),
                        ],
                        if (!_active) ...[
                          const SizedBox(height: 16),
                          serverMatchResult(_run, bot: _bot),
                          if (_bot) ?_rewardCard(),
                          _summary(),
                          const SizedBox(height: 12),
                          if (_bot) ...[
                            _levelPicker(),
                            const SizedBox(height: 12),
                          ],
                          ArenaPrimaryButton(
                            label: 'Yeni tahta',
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
                if (answering) _inputBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Before the first board: what is recorded, the rules, the bot level and the start.
  List<Widget> _intro() => [
    ArenaCard(
      glow: _p.accent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _p.limeTint,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Arena.lime.withValues(alpha: .35)),
            ),
            child: Icon(
              _reverse
                  ? Icons.swap_horiz_rounded
                  : _random
                  ? Icons.shuffle_rounded
                  : Icons.grid_view_rounded,
              color: Arena.lime,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _kindTitle,
                  style: _text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _bot
                      ? 'Her hamle hesabına kaydedilir. Maç Coin vermez, sonunda isteğe bağlı bonus olabilir; yardımlı rekor ayrı tutulur.'
                      : 'Her hamle hesabına kaydedilir. Oyun ödülsüzdür; yardımlı rekor ayrı tutulur.',
                  style: _text.bodyMedium?.copyWith(color: _p.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    ArenaNote(icon: Icons.rule_rounded, text: _rules),
    const SizedBox(height: 16),
    if (_bot) ...[_levelPicker(), const SizedBox(height: 16)],
    ArenaPrimaryButton(
      label: 'Tahtayı hazırla',
      icon: Icons.grid_view_rounded,
      onPressed: _data['availability'] == true && _error == null
          ? () => _act('start')
          : null,
    ),
  ];

  String get _rules => _reverse
      ? 'Bir satır ya da sütun başlığına dokun; üç futbolcunun ortak kulübünü, milliyetini, '
            'mevkisini ya da teknik direktörünü yaz.'
            '${_bot ? ' Her hamleden sonra sıra bota geçer; altı eksen bitince çok eksen alan kazanır.' : ''}'
      : _random
      ? 'Kulüp çifti üret, ortak futbolcuyu bul ve boş bir ÇAPA kutusuna yerleştir; çift o satırın '
            've sütunun başlığı olur. Başlıkları açılmış boş kutuları da doldurabilirsin.'
            '${_bot ? ' Her hamleden sonra sıra bota geçer. Aynı çizgide 3 kutu alan kazanır; üç çapa da bir çizgidir.' : ''}'
      : 'Boş bir kutuya dokun, satır ve sütuna uyan futbolcuyu yaz.'
            '${_bot ? ' Her hamleden sonra sıra bota geçer. Aynı çizgide (yatay, dikey ya da çapraz) 3 kutu alan kazanır; tahta dolarsa ya da hamle kalmazsa çok kutu alan.' : ''}';

  // The server's last answer, on top as in the online arena.
  List<Widget> _feedback() {
    final feedback = _run['feedback']?.toString();
    if (feedback == null) return const [];
    final ok = feedback == 'Doğru.';
    return [
      Semantics(
        liveRegion: true,
        child: ArenaNote(
          text: feedback,
          icon: ok
              ? Icons.check_circle_rounded
              : _active
              ? Icons.cancel_rounded
              : Icons.info_outline_rounded,
          color: ok
              ? _p.success
              : _active
              ? _p.error
              : null,
        ),
      ),
      const SizedBox(height: 10),
    ];
  }

  // Me | VS | bot: the online scoreboard without a clock.
  Widget _scoreCard() {
    final userTurn = _run['turn'] != 'bot';
    final level = _levels['${_run['difficulty'] ?? _difficulty}'] ?? 'Orta';
    final unit = _reverse ? 'eksen' : 'kutu';
    final user = (_run['userScore'] as num? ?? 0).toInt();
    final bot = (_run['botScore'] as num? ?? 0).toInt();
    return ClubRaceScoreCard(
      key: const ValueKey('grid-score'),
      me: ClubRaceSide(
        name: _run['assisted'] == true ? 'Yardımlı' : 'Yardımsız',
        score: user,
        wrong: 0,
        caption: '$user $unit',
      ),
      rival: ClubRaceSide(
        name: '$level bot',
        score: bot,
        wrong: 0,
        caption: '$bot $unit',
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

  // Who opened, the bot's last move and the record, under the scoreboard.
  List<Widget> _notes() {
    final records = rewardMap(
      _data[_run['assisted'] == true ? 'assistedRecords' : 'records'],
    );
    final record = rewardMap(records['${widget.mode}:${_run['difficulty']}']);
    return [
      if (_bot && _run['botFirst'] == true && _active)
        _line(
          'Bu maçta bot önce başladı.',
          _p.muted,
          icon: Icons.flag_outlined,
        ),
      if (_run['botNote'] != null)
        _line(
          '${_run['botNote']}',
          hubAmber(context),
          icon: Icons.smart_toy_outlined,
        ),
      if (record.isNotEmpty)
        _line(
          'Rekor ${record['best'] ?? 0} · ${record['completed'] ?? 0} tamamlanan'
          '${_bot ? ' · ${record['wins'] ?? 0} galibiyet' : ''}',
          _p.muted,
          icon: Icons.emoji_events_outlined,
        ),
    ];
  }

  static const _levels = {'easy': 'Kolay', 'medium': 'Orta', 'hard': 'Zor'};

  // Bot level for the next board; the server keeps it for the whole match.
  Widget _levelPicker() {
    final reverse = _reverse;
    final about = {
      'easy': reverse
          ? 'Bot sık sık yanlış kriter söyler.'
          : 'Bot sık sık pas geçer, üçlünü engellemez.',
      'medium': reverse
          ? 'Bot çoğu turda doğru kriteri bulur.'
          : 'Bot çoğu turda doğru oynar, üçlünü bazen engeller.',
      'hard': reverse
          ? 'Bot nadiren hata yapar.'
          : 'Bot nadiren hata yapar, üçlünü her zaman engeller.',
    };
    return ArenaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bot seviyesi', style: _text.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final level in _levels.keys)
                ChoiceChip(
                  key: ValueKey('grid-level-$level'),
                  label: Text(_levels[level]!),
                  selected: _difficulty == level,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() => _difficulty = level),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            about[_difficulty] ?? '',
            style: _text.bodySmall?.copyWith(color: _p.muted),
          ),
        ],
      ),
    );
  }

  Widget? _rewardCard() =>
      widget.rewardCard?.call('grid_result') ??
      (widget.service == null
          ? const RewardedCoinCard(placement: 'grid_result')
          : null);

  // Solo: assisted state, score and wrong answers.
  Widget _header() {
    final cost = (_run['wrongCost'] as num? ?? 0).toInt();
    Widget score(
      String label,
      String value,
      String note,
      Color color,
      bool lit,
    ) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: lit
              ? color.withValues(alpha: .08)
              : _p.background.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: lit ? color.withValues(alpha: .7) : _p.border,
            width: lit ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              upperTr(label),
              style: _text.labelMedium?.copyWith(
                color: _p.muted,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: _text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: lit ? color : _p.text,
              ),
            ),
            Text(note, style: _text.bodySmall?.copyWith(color: _p.muted)),
          ],
        ),
      ),
    );
    return ArenaCard(
      glow: _p.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ArenaPill(
                dot: _run['assisted'] == true ? Arena.bot : Arena.lime,
                child: Text(
                  _run['assisted'] == true
                      ? 'Yardımlı · Ayrı sonuç kaydı'
                      : 'Yardımsız',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              score(
                'Sen',
                '${_run['userScore'] ?? 0}',
                'puan',
                _p.accent,
                _active,
              ),
              const SizedBox(width: 10),
              score(
                'Yanlış',
                '${_run['wrong'] ?? 0}',
                cost > 0 ? 'her biri −$cost puan' : 'cezasız',
                _p.error,
                false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(String text, Color color, {IconData? icon}) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(text, style: _text.bodyMedium?.copyWith(color: color)),
        ),
      ],
    ),
  );

  // Criterion header of the board: a criterion map (badge, kind, name), or a text.
  Widget _axis(
    Object content, {
    Key? key,
    ArenaTileState state = ArenaTileState.idle,
    String? tag,
    VoidCallback? onTap,
  }) => ArenaTile(
    key: key,
    compact: true,
    minHeight: 74,
    state: state,
    tag: tag,
    onTap: onTap,
    criterion: ArenaCriterion(
      content is Map ? content : {'label': '$content', 'type': 'unknown'},
    ),
  );

  Widget _board() {
    final rows = _list('rows'), cols = _list('cols');
    Object label(List<dynamic> list, int i, String name) =>
        list.length > i && list[i] != null ? rewardMap(list[i]) : '$name ?';
    return Semantics(
      container: true,
      label: 'Grid tahtası',
      child: ArenaGrid(
        top: [
          for (var i = 0; i < 3; i++) _axis(label(cols, i, 'Sütun ${i + 1}')),
        ],
        left: [
          for (var i = 0; i < 3; i++) _axis(label(rows, i, 'Satır ${i + 1}')),
        ],
        cell: _cell,
      ),
    );
  }

  bool _known(int i) {
    final rows = _list('rows'), cols = _list('cols');
    return rows.length > i ~/ 3 &&
        cols.length > i % 3 &&
        rows[i ~/ 3] != null &&
        cols[i % 3] != null;
  }

  Widget _cell(int i) {
    final cell = rewardMap(rewardMap(_run['cells'])['$i']);
    final mine = cell['owner'] == 1, selected = _target == i;
    // Random: an empty anchor whose row and column are still unnamed.
    final anchor =
        _random && const [2, 4, 6].contains(i) && cell.isEmpty && !_known(i);
    final verified = rewardMap(rewardMap(_run['pending'])['player']).isNotEmpty;
    final placing = anchor && verified && _canPlay;
    final available = _canPlay && cell.isEmpty && (!_random || _known(i));
    final player = rewardMap(cell['player']);
    return ArenaTile(
      key: ValueKey('grid-cell-$i'),
      minHeight: 92,
      emptyPlus: available || selected || placing,
      semantics: anchor ? 'Çapa · ${_cellCriteria(i)}' : _cellCriteria(i),
      player: cell.isEmpty ? null : player,
      state: selected || placing
          ? ArenaTileState.selected
          : cell.isEmpty
          ? (available || anchor || !_active
                ? ArenaTileState.idle
                : ArenaTileState.locked)
          : mine
          ? ArenaTileState.mine
          : ArenaTileState.bot,
      tag: selected
          ? 'SEÇİLİ'
          : placing
          ? 'YERLEŞTİR'
          : anchor
          ? 'ÇAPA'
          : cell.isEmpty
          ? null
          : _bot
          ? (mine ? 'SEN' : 'BOT')
          : (cell['bonus'] as num? ?? 0) > 0
          ? '+${20 + (cell['bonus'] as num).toInt()}'
          : '+20',
      onTap: placing
          ? () => _act('place', {'target': i, 'swap': _swap})
          : available
          ? () => _select(i)
          : null,
    );
  }

  // Reverse: the nine players; tap an axis around them to name what they share.
  Widget _reverseBoard() {
    final axes = rewardMap(_run['axes']);
    final players = _list('witnesses');
    Widget axis(int i) {
      final a = rewardMap(axes['$i']);
      final name = '${i < 3 ? 'Satır' : 'Sütun'} ${i % 3 + 1}';
      if (a.isEmpty) {
        final chosen = _target == i;
        return _axis(
          '$name ?',
          key: ValueKey('grid-axis-$i'),
          state: chosen ? ArenaTileState.selected : ArenaTileState.idle,
          tag: chosen ? 'SEÇİLİ' : null,
          onTap: _canPlay ? () => _select(i) : null,
        );
      }
      return _axis(
        {
          'id': a['criterionId'],
          'label': a['label'],
          // "club:7" -> club, so the solved axis shows its crest, flag or TD mark.
          'type': '${a['criterionId'] ?? ''}'.split(':').first,
          'value': '${a['criterionId'] ?? ''}'.split(':').last,
        },
        state: a['owner'] == 1 ? ArenaTileState.mine : ArenaTileState.bot,
        tag: a['owner'] == 1 ? 'SEN' : (_bot ? 'BOT' : null),
      );
    }

    return Semantics(
      container: true,
      label: 'Tersten grid tahtası',
      child: ArenaGrid(
        top: [for (var i = 3; i < 6; i++) axis(i)],
        left: [for (var i = 0; i < 3; i++) axis(i)],
        cell: (i) => ArenaTile(
          minHeight: 84,
          player: players.length > i ? rewardMap(players[i]) : {'name': '—'},
        ),
      ),
    );
  }

  // After the game: an answer for every empty cell, or each axis' accepted criteria.
  Widget _summary() {
    final solutions = rewardMap(_run['solutions']);
    final accepted = _list('accepted');
    if (solutions.isEmpty && accepted.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ArenaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              accepted.isNotEmpty
                  ? 'Kabul edilen kriterler'
                  : 'Boş kalan kutulara örnek cevaplar',
              style: _text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (accepted.isNotEmpty)
              for (var i = 0; i < accepted.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${i < 3 ? 'Satır' : 'Sütun'} ${i % 3 + 1}: '
                    '${(accepted[i] as List? ?? const []).join(' · ')}',
                  ),
                )
            else
              for (final e in solutions.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${_cellCriteria(int.parse(e.key)).replaceAll('\n', ' · ')}: '
                    '${rewardMap(e.value)['name']}',
                  ),
                ),
          ],
        ),
      ),
    );
  }

  // Random: draw a pair, solve it, then put it on an anchor (as the online pair card).
  List<Widget> _pairArea() {
    final pending = rewardMap(_run['pending']);
    final rounds = (_run['roundsUsed'] as num? ?? 0).toInt();
    final section = ArenaSection(
      'Kulüp çiftleri',
      icon: Icons.link_rounded,
      trailing: Text(
        'Yerleştirilen çift: $rounds/3',
        style: _text.labelSmall?.copyWith(color: Arena.lime),
      ),
    );
    if (pending.isEmpty) {
      return [
        section,
        if (rounds < 3)
          ArenaPrimaryButton(
            icon: Icons.casino_outlined,
            label: 'Kulüp çifti üret',
            onPressed: _canPlay ? () => _act('generate') : null,
          )
        else
          const ArenaNote(
            icon: Icons.grid_on_rounded,
            text: 'Üç çift yerleşti; başlıkları açılmış boş kutuları doldur.',
          ),
        const SizedBox(height: 14),
      ];
    }
    final criteria = pending['criteria'] as List;
    final player = rewardMap(pending['player']);
    final a = _criterion(criteria[0]), b = _criterion(criteria[1]);
    final cancel = TextButton.icon(
      icon: const Icon(Icons.close_rounded, size: 18),
      onPressed: _canPlay ? () => _act('cancel') : null,
      label: const Text('Çifti iptal et'),
    );
    return [
      section,
      ClubRaceVersus(
        left: rewardMap(criteria[0]),
        right: rewardMap(criteria[1]),
        answerCount: null,
        task: player.isEmpty
            ? 'İki tarafta da oynamış bir futbolcu bul.'
            : '${player['name']} doğrulandı. Tahtada boş bir ÇAPA kutusuna dokun.',
        footnote: _swap
            ? '$b satır, $a sütun başlığı olur.'
            : '$a satır, $b sütun başlığı olur.',
      ),
      const SizedBox(height: 10),
      if (player.isEmpty) ...[
        ArenaPrimaryButton(
          icon: Icons.search_rounded,
          label: 'Ortak oyuncuyu bul',
          onPressed: _canPlay ? () => _select('pending') : null,
        ),
        Center(child: cancel),
      ] else
        // One row: flip the orientation, or drop the pair.
        Row(
          children: [
            Switch(
              key: const ValueKey('grid-swap'),
              value: _swap,
              onChanged: _canPlay ? (v) => setState(() => _swap = v) : null,
            ),
            const SizedBox(width: 6),
            Expanded(child: Text('Satır ↔ sütun', style: _text.bodyMedium)),
            cancel,
          ],
        ),
      const SizedBox(height: 4),
    ];
  }

  // The selected target and its paid hint; the answer goes in the bar below.
  Widget _targetCard() {
    final text = rewardMap(_run['hints'])[_hintKey];
    final title = _target == 'pending'
        ? 'Bekleyen kulüp çifti'
        : _reverse
        ? '${(_target as int) < 3 ? 'Satır' : 'Sütun'} ${(_target as int) % 3 + 1} · ortak kriter'
        : _cellCriteria(_target as int);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArenaCard(
            glow: Arena.lime,
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(
              children: [
                const Icon(Icons.adjust_rounded, color: Arena.lime, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: _text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Seçimi kaldır',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() {
                    _target = null;
                    _answer.clear();
                    _suggestions = [];
                    _searchEpoch++;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ArenaHintCard(
            children: [
              if (text != null)
                Text('$text', style: _text.bodyMedium)
              else ...[
                Text(
                  _reverse
                      ? 'Temel destek ortak kriterin türünü daraltır.'
                      : 'Temel destek geçerli bir adayın milliyet ve mevki grubunu verir.',
                ),
                const Text('Kullanılırsa sonuç Yardımlı olarak kaydolur.'),
                const SizedBox(height: 10),
                hintEntry(
                      _run,
                      target: _target,
                      disabled: !_canPlay,
                      send: (p) => _act('hint', {'target': _target, ...p}),
                      watch: (id) => _watch(itemId: id),
                    ) ??
                    PaidHintButton(
                      session: _run,
                      sku: 'boost_basic',
                      label: 'Temel bilgi',
                      disabled: !_canPlay,
                      onUse: (payment) =>
                          _act('hint', {'target': _target, ...payment}),
                      onWatch: _watch,
                    ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _pick(Map<String, dynamic> p) => _act(
    'guess',
    _reverse
        ? {'target': _target, 'answer': p['id']}
        : {'target': _target, 'playerId': p['id']},
  );

  // Pinned over the keyboard, as in the online arena. Reverse also sends typed text.
  Widget _inputBar() {
    final typed = _answer.text.trim();
    void sendTyped() => _act('guess', {'target': _target, 'answer': typed});
    return ClubRaceInputBar(
      key: const ValueKey('grid-input'),
      controller: _answer,
      onChanged: _find,
      onSubmitted: (_) {
        if (_reverse && typed.length >= 2) {
          sendTyped();
        } else if (_suggestions.length == 1) {
          _pick(_suggestions.first);
        }
      },
      results: [
        for (final r in _suggestions) _reverse ? {...r, 'name': r['label']} : r,
      ],
      onPick: _pick,
      onSend: sendTyped,
      showSend: _reverse,
      selected: _reverse && typed.length >= 2 ? {'name': typed} : null,
      searching: _searching,
      noMatch: !_reverse && _noMatch,
      lockSeconds: 0,
      outOfWrong: false,
      sending: _busy,
      label: _reverse ? 'Ortak kriter ara' : 'Futbolcu ara',
      hint: _reverse
          ? 'Kulüp, milliyet, mevki ya da TD; dokun, gitsin'
          : 'En az 2 harf; öneriye dokun, gitsin',
    );
  }
}
