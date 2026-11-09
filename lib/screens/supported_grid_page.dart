import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../models/grid_club_pool.dart';
import '../app/app_feedback.dart';
import '../app/game_audio.dart';
import '../models/rewarded_ad_models.dart';
import '../services/auth_service.dart';
import '../services/runtime_v4/game_data_v4_query_service.dart';
import '../services/story_support_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/bot_arena.dart';
import '../widgets/game_ui.dart';
import '../widgets/grid_criterion_label.dart';
import '../widgets/paid_hint_button.dart';
import '../widgets/rewarded_coin_card.dart';
import '../widgets/hint_panel.dart';

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
  String? _error, _owner;
  Timer? _poll, _search;
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
    _poll = Timer.periodic(const Duration(milliseconds: 750), (_) {
      if (!_busy && _error == null && _run['turn'] == 'bot' && !_accountChanged)
        _load();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_legacy && !_accountChanged)
      _load();
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
          'difficulty': widget.difficulty,
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
    setState(() => _suggestions = []);
    if (query.trim().length < 2 || !_canPlay) return;
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
        setState(
          () => _suggestions =
              (result[_reverse ? 'criteria' : 'players'] as List? ?? const [])
                  .map(rewardMap)
                  .toList(),
        );
      } catch (e) {
        if (mounted && epoch == _searchEpoch)
          setState(() => _error = _message(e));
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
      ? 'Bot düellosu · ${const {'easy': 'Kolay', 'medium': 'Orta', 'hard': 'Zor'}['${_run['difficulty'] ?? widget.difficulty}'] ?? 'Orta'}'
      : 'Solo antrenman · ${_reverse ? '6 eksen' : '9 kutu'}';

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
                    if (_run.isEmpty && !_busy && !_accountChanged) ...[
                      ArenaCard(
                        glow: _p.accent,
                        child: Text(
                          'Her hamle hesabına kaydedilir. Oyun ödülsüzdür; yardımlı rekor ayrı tutulur.',
                          style: _text.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ArenaPrimaryButton(
                        label: 'Tahtayı hazırla',
                        icon: Icons.grid_view_rounded,
                        onPressed:
                            _data['availability'] == true && _error == null
                            ? () => _act('start')
                            : null,
                      ),
                    ],
                    if (_run.isNotEmpty) ...[
                      _header(),
                      const SizedBox(height: 16),
                      if (_reverse) _reverseBoard() else _board(),
                      const SizedBox(height: 12),
                      if (_active && _random) ...[
                        ArenaSection(
                          'Kulüp çiftleri',
                          icon: Icons.link_rounded,
                          trailing: Text(
                            'Yerleştirilen çift: ${_run['roundsUsed']}/3',
                            style: _text.labelSmall?.copyWith(color: Arena.lime),
                          ),
                        ),
                        if (_run['pending'] == null)
                          ArenaPrimaryButton(
                            icon: Icons.casino_outlined,
                            label: 'Kulüp çifti üret',
                            onPressed:
                                _canPlay &&
                                    (_run['roundsUsed'] as num? ?? 0) < 3
                                ? () => _act('generate')
                                : null,
                          ),
                        if (_run['pending'] != null) _pending(),
                      ],
                      if (_canPlay &&
                          _target != null &&
                          !(_target == 'pending' &&
                              rewardMap(_run['pending'])['player'] != null))
                        _entry(),
                      if (_active) ...[
                        const SizedBox(height: 12),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget? _rewardCard() =>
      widget.rewardCard?.call('grid_result') ??
      (widget.service == null
          ? const RewardedCoinCard(placement: 'grid_result')
          : null);

  // Score, record, turn and the last messages from the server.
  Widget _header() {
    final records = rewardMap(
      _data[_run['assisted'] == true ? 'assistedRecords' : 'records'],
    );
    final record = rewardMap(records['${widget.mode}:${_run['difficulty']}']);
    final feedback = _run['feedback']?.toString();
    final cost = (_run['wrongCost'] as num? ?? 0).toInt();
    final userTurn = _run['turn'] != 'bot';
    Widget score(String label, String value, String note, Color color, bool lit) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: lit ? color.withValues(alpha: .08) : _p.background.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: lit ? color.withValues(alpha: .7) : _p.border, width: lit ? 1.6 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
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
              if (_active && _bot)
                ArenaPill(
                  filled: true,
                  color: userTurn ? Arena.lime : Arena.bot,
                  dot: userTurn ? Arena.lime : Arena.bot,
                  child: Text(userTurn ? 'Sıra sende' : 'Bot oynuyor…'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              score(
                'Sen',
                '${_run['userScore'] ?? 0}',
                _bot ? 'kutu / eksen' : 'puan',
                _p.accent,
                _active && userTurn,
              ),
              const SizedBox(width: 10),
              _bot
                  ? score(
                      'Bot',
                      '${_run['botScore'] ?? 0}',
                      const {'easy': 'Kolay', 'medium': 'Orta', 'hard': 'Zor'}[
                              '${_run['difficulty'] ?? widget.difficulty}'] ??
                          'Orta',
                      Arena.bot,
                      _active && !userTurn,
                    )
                  : score(
                      'Yanlış',
                      '${_run['wrong'] ?? 0}',
                      cost > 0 ? 'her biri −$cost puan' : 'cezasız',
                      _p.error,
                      false,
                    ),
            ],
          ),
          if (record.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: _p.border),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.emoji_events_outlined, size: 18, color: Arena.bot),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rekor ${record['best'] ?? 0} · ${record['completed'] ?? 0} tamamlanan'
                    '${_bot ? ' · ${record['wins'] ?? 0} galibiyet' : ''}',
                    style: _text.bodySmall?.copyWith(color: _p.muted),
                  ),
                ),
              ],
            ),
          ],
          if (_bot && _run['botFirst'] == true && _active)
            _line('Bu maçta bot önce başladı.', _p.muted),
          if (_run['botNote'] != null) _line('${_run['botNote']}', Arena.bot, icon: Icons.smart_toy_outlined),
          if (feedback != null)
            _line(
              feedback,
              feedback == 'Doğru.' ? _p.success : _p.error,
              icon: feedback == 'Doğru.'
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
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
  Widget _axis(Object content, {ArenaTileState state = ArenaTileState.idle, String? tag}) =>
      ArenaTile(
        compact: true,
        minHeight: 74,
        state: state,
        tag: tag,
        criterion: ArenaCriterion(
          content is Map ? content : {'label': '$content', 'type': 'unknown'},
        ),
      );

  Widget _grid(
    Widget Function(int i) cell,
    List<Widget> top,
    List<Widget> left,
  ) => Column(
    children: [
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: _p.limeTint,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Arena.lime.withValues(alpha: .3)),
                  ),
                  child: const Icon(Icons.grid_3x3_rounded, color: Arena.lime),
                ),
              ),
            ),
            for (final w in top) Expanded(child: w),
          ],
        ),
      ),
      for (var row = 0; row < 3; row++)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: left[row]),
              for (var col = 0; col < 3; col++)
                Expanded(child: cell(row * 3 + col)),
            ],
          ),
        ),
    ],
  );

  Widget _board() {
    final rows = _list('rows'), cols = _list('cols');
    Object label(List<dynamic> list, int i) =>
        list.length > i && list[i] != null ? rewardMap(list[i]) : '—';
    return Semantics(
      container: true,
      label: 'Grid tahtası',
      child: _grid(
        _cell,
        [for (var i = 0; i < 3; i++) _axis(label(cols, i))],
        [for (var i = 0; i < 3; i++) _axis(label(rows, i))],
      ),
    );
  }

  Widget _cell(int i) {
    final cell = rewardMap(rewardMap(_run['cells'])['$i']);
    final mine = cell['owner'] == 1, selected = _target == i;
    final available =
        _canPlay &&
        cell.isEmpty &&
        (!_random ||
            _list('rows')[i ~/ 3] != null && _list('cols')[i % 3] != null);
    final player = rewardMap(cell['player']);
    return ArenaTile(
      key: ValueKey('grid-cell-$i'),
      minHeight: 92,
      emptyPlus: available || selected,
      semantics: _cellCriteria(i),
      player: cell.isEmpty ? null : player,
      state: selected
          ? ArenaTileState.selected
          : cell.isEmpty
          ? (available || !_active ? ArenaTileState.idle : ArenaTileState.locked)
          : mine
          ? ArenaTileState.mine
          : ArenaTileState.bot,
      tag: selected
          ? 'SEÇİLİ'
          : cell.isEmpty
          ? null
          : _bot
          ? (mine ? 'SEN' : 'BOT')
          : (cell['bonus'] as num? ?? 0) > 0
          ? '+${20 + (cell['bonus'] as num).toInt()}'
          : '+20',
      onTap: available ? () => _select(i) : null,
    );
  }

  // Reverse: the nine players with each axis' found criterion around them.
  Widget _reverseBoard() {
    final axes = rewardMap(_run['axes']);
    final players = _list('witnesses');
    Widget axis(int i) {
      final a = rewardMap(axes['$i']);
      if (a.isEmpty) {
        return _axis(
          '${i < 3 ? 'Satır' : 'Sütun'} ${i % 3 + 1} ?',
          state: _target == i ? ArenaTileState.selected : ArenaTileState.idle,
        );
      }
      return _axis(
        {'label': a['label'], 'type': 'unknown'},
        state: a['owner'] == 1 ? ArenaTileState.mine : ArenaTileState.bot,
        tag: a['owner'] == 1 ? 'SEN' : 'BOT',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _grid(
          (i) => ArenaTile(
            minHeight: 84,
            player: players.length > i ? rewardMap(players[i]) : {'name': '—'},
          ),
          [for (var i = 3; i < 6; i++) axis(i)],
          [for (var i = 0; i < 3; i++) axis(i)],
        ),
        const SizedBox(height: 12),
        ArenaNote(
          icon: Icons.touch_app_outlined,
          text:
              'Bir satır ya da sütun seç; üç oyuncunun ortak kulübünü, '
              'milliyetini, mevkisini ya da teknik direktörünü yaz.',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < 6; i++)
              ChoiceChip(
                label: Text(
                  '${i < 3 ? 'Satır' : 'Sütun'} ${i % 3 + 1}${axes.containsKey('$i') ? ' ✓' : ''}',
                ),
                selected: _target == i,
                onSelected: _canPlay && !axes.containsKey('$i')
                    ? (_) => _select(i)
                    : null,
              ),
          ],
        ),
      ],
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

  Widget _pending() {
    final pending = rewardMap(_run['pending']);
    final criteria = pending['criteria'] as List;
    final player = rewardMap(pending['player']);
    Widget side(dynamic raw) => Expanded(
      child: ArenaTile(compact: true, minHeight: 70, criterion: ArenaCriterion(rewardMap(raw))),
    );
    return ArenaCard(
      glow: Arena.lime,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              side(criteria[0]),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.close_rounded, color: _p.muted, size: 18),
              ),
              side(criteria[1]),
            ],
          ),
          const SizedBox(height: 10),
          if (player.isEmpty)
            ArenaPrimaryButton(
              icon: Icons.search_rounded,
              label: 'Ortak oyuncuyu bul',
              onPressed: _canPlay ? () => _select('pending') : null,
            ),
          if (player.isNotEmpty) ...[
            ArenaNote(
              icon: Icons.verified_outlined,
              color: _p.success,
              text: '${player['name']} doğrulandı. Boş çapaya yerleştir.',
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Satır: ${_criterion(criteria[_swap ? 1 : 0])}'),
              subtitle: Text('Sütun: ${_criterion(criteria[_swap ? 0 : 1])}'),
              value: _swap,
              onChanged: _canPlay ? (v) => setState(() => _swap = v) : null,
            ),
            for (final i in [2, 4, 6])
              if (!rewardMap(_run['cells']).containsKey('$i'))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ArenaSecondaryButton(
                    icon: Icons.place_outlined,
                    label: '${i ~/ 3 + 1}. satır / ${i % 3 + 1}. sütuna yerleştir',
                    onPressed: _canPlay
                        ? () => _act('place', {'target': i, 'swap': _swap})
                        : null,
                  ),
                ),
          ],
          TextButton(
            onPressed: _canPlay ? () => _act('cancel') : null,
            child: const Text('Çifti iptal et'),
          ),
        ],
      ),
    );
  }

  Widget _entry() {
    final text = rewardMap(_run['hints'])[_hintKey];
    final title = _target == 'pending'
        ? 'Bekleyen kulüp çifti'
        : _reverse
        ? '${(_target as int) < 3 ? 'Satır' : 'Sütun'} ${(_target as int) % 3 + 1}'
        : _cellCriteria(_target as int);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArenaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(Icons.adjust_rounded, color: Arena.lime, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: _text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!_reverse)
                  ArenaSearch(
                    controller: _answer,
                    enabled: _canPlay,
                    onChanged: _find,
                    hint: 'Futbolcu ara · En az iki harf',
                    suggestions: _suggestions,
                    onPick: _canPlay
                        ? (p) => _act('guess', {'target': _target, 'playerId': p['id']})
                        : null,
                  )
                else ...[
                  TextField(
                    controller: _answer,
                    enabled: _canPlay,
                    onChanged: _find,
                    decoration: InputDecoration(
                      labelText: 'Ortak kriter ara · Kulüp, milliyet, mevki veya TD',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: _p.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  for (final p in _suggestions)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Material(
                        color: _p.raised,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: _p.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          dense: true,
                          leading: CriterionMark(ArenaCriterion(p), size: 28),
                          title: Text('${p['label']}'),
                          subtitle: Text(
                            const {
                                  'club': 'Kulüp',
                                  'country': 'Milliyet',
                                  'position': 'Mevki',
                                  'coach': 'Teknik direktör',
                                }['${p['type']}'] ??
                                '',
                          ),
                          onTap: _canPlay
                              ? () => _act('guess', {'target': _target, 'answer': p['id']})
                              : null,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  ArenaPrimaryButton(
                    icon: Icons.fact_check_outlined,
                    label: 'Kriteri doğrula',
                    onPressed: _canPlay
                        ? () => _act('guess', {
                            'target': _target,
                            'answer': _answer.text,
                          })
                        : null,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
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
}
