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
import '../widgets/game_ui.dart';
import '../widgets/paid_hint_button.dart';
import '../widgets/pitch_ui.dart';

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
  });
  final String mode, difficulty;
  final Widget legacy;
  final StorySupportService? service;
  final Future<Map<String, dynamic>> Function()? poolInput;
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
  String get _title =>
      '${_bot ? 'Bot' : 'Solo'} · ${_reverse
          ? 'Tersten'
          : _random
          ? 'Rastgele'
          : 'Klasik'} Grid';
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
  Future<void> _watch() => _work(() async {
    final target = _target;
    await _service.watch({
      'mode': widget.mode,
      'sessionId': _run['id'],
      'target': target,
      'boostId': 'boost_basic',
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
    if (query.trim().length < 2 || !_canPlay || _reverse) return;
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

  String _criterion(dynamic raw) => rewardMap(raw)['label']?.toString() ?? '—';
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
  @override
  Widget build(BuildContext context) {
    if (_legacy) return widget.legacy;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title),
          actions: [
            IconButton(
              tooltip: 'Yenile',
              onPressed: _busy || _accountChanged ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_error!),
                ),
              if (_run.isEmpty && !_busy && !_accountChanged) ...[
                const Text(
                  'Her hamle hesabına kaydedilir. Oyun ödülsüzdür; yardımlı rekor ayrı tutulur.',
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _data['availability'] == true && _error == null
                      ? () => _act('start')
                      : null,
                  child: const Text('Tahtayı hazırla'),
                ),
              ],
              if (_run.isNotEmpty) ...[
                Text(
                  _run['assisted'] == true
                      ? 'Yardımlı · Ayrı sonuç kaydı'
                      : 'Yardımsız',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sen: ${_run['userScore'] ?? 0}${_bot ? ' · Bot: ${_run['botScore'] ?? 0}' : ''}',
                ),
                if (_run['feedback'] != null) Text('${_run['feedback']}'),
                if (_active && _bot)
                  Text(_run['turn'] == 'bot' ? 'Bot oynuyor…' : 'Sıra sende'),
                const SizedBox(height: 16),
                if (_reverse) ...[
                  for (var row = 0; row < 3; row++)
                    PitchPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${row + 1}. satır',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          for (var col = 0; col < 3; col++)
                            Text(
                              '${col + 1}. sütun · ${rewardMap(_list('witnesses')[row * 3 + col])['name']}',
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < 6; i++)
                        ChoiceChip(
                          label: Text(
                            '${i < 3 ? 'Satır' : 'Sütun'} ${i % 3 + 1}${rewardMap(_run['axes']).containsKey('$i') ? ' ✓' : ''}',
                          ),
                          selected: _target == i,
                          onSelected:
                              _canPlay &&
                                  !rewardMap(_run['axes']).containsKey('$i')
                              ? (_) => _select(i)
                              : null,
                        ),
                    ],
                  ),
                  for (final entry in rewardMap(_run['axes']).entries)
                    Text(
                      '${int.parse(entry.key) < 3 ? 'Satır' : 'Sütun'} ${int.parse(entry.key) % 3 + 1}: '
                      '${rewardMap(entry.value)['label']} · ${rewardMap(entry.value)['owner'] == 1 ? 'Sen' : 'Bot'}',
                    ),
                ] else
                  _board(),
                if (_active && _random) ...[
                  Text('Yerleştirilen çift: ${_run['roundsUsed']}/3'),
                  if (_run['pending'] == null)
                    FilledButton.tonal(
                      onPressed:
                          _canPlay && (_run['roundsUsed'] as num? ?? 0) < 3
                          ? () => _act('generate')
                          : null,
                      child: const Text('Kulüp çifti üret'),
                    ),
                  if (_run['pending'] != null) _pending(),
                ],
                if (_canPlay &&
                    _target != null &&
                    !(_target == 'pending' &&
                        rewardMap(_run['pending'])['player'] != null))
                  _entry(),
                if (_active)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: TextButton(
                      onPressed: _busy ? null : () => _act('finish'),
                      child: const Text('Bitir · Kısmi sonuç'),
                    ),
                  ),
                if (!_active) ...[
                  const SizedBox(height: 16),
                  serverMatchResult(_run, bot: _bot),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy || _data['availability'] != true
                        ? null
                        : () => _act('start'),
                    child: const Text('Yeni tahta'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _board() {
    final rows = _list('rows'), cols = _list('cols');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 3; i++)
          Text(
            'Satır ${i + 1}: ${_criterion(rows[i])} · Sütun ${i + 1}: ${_criterion(cols[i])}',
          ),
        const SizedBox(height: 12),
        Table(
          border: TableBorder.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            for (var row = 0; row < 3; row++)
              TableRow(
                children: [
                  for (var col = 0; col < 3; col++) _cell(row * 3 + col),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _cell(int i) {
    final cell = rewardMap(rewardMap(_run['cells'])['$i']);
    final available =
        _canPlay &&
        cell.isEmpty &&
        (!_random ||
            _list('rows')[i ~/ 3] != null && _list('cols')[i % 3] != null);
    return Semantics(
      label: _cellCriteria(i),
      selected: _target == i,
      child: Container(
        constraints: const BoxConstraints(minHeight: 100),
        color: _target == i
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        padding: const EdgeInsets.all(4),
        child: TextButton(
          key: ValueKey('grid-cell-$i'),
          onPressed: available ? () => _select(i) : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${i ~/ 3 + 1} / ${i % 3 + 1}'),
              Text(
                cell.isEmpty
                    ? 'Boş kutu'
                    : '${rewardMap(cell['player'])['name']}',
                textAlign: TextAlign.center,
              ),
              if (cell.isNotEmpty) Text(cell['owner'] == 1 ? 'Sen' : 'Bot'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pending() {
    final pending = rewardMap(_run['pending']);
    final criteria = pending['criteria'] as List;
    final player = rewardMap(pending['player']);
    return PitchPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${_criterion(criteria[0])} × ${_criterion(criteria[1])}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (player.isEmpty)
            FilledButton.tonal(
              onPressed: _canPlay ? () => _select('pending') : null,
              child: const Text('Ortak oyuncuyu bul'),
            ),
          if (player.isNotEmpty) ...[
            Text('${player['name']} doğrulandı. Boş çapaya yerleştir.'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Satır: ${_criterion(criteria[_swap ? 1 : 0])}'),
              subtitle: Text('Sütun: ${_criterion(criteria[_swap ? 0 : 1])}'),
              value: _swap,
              onChanged: _canPlay ? (v) => setState(() => _swap = v) : null,
            ),
            for (final i in [2, 4, 6])
              if (!rewardMap(_run['cells']).containsKey('$i'))
                OutlinedButton(
                  onPressed: _canPlay
                      ? () => _act('place', {'target': i, 'swap': _swap})
                      : null,
                  child: Text(
                    '${i ~/ 3 + 1}. satır / ${i % 3 + 1}. sütuna yerleştir',
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
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: PitchPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _target == 'pending'
                  ? 'Bekleyen kulüp çifti'
                  : _reverse
                  ? '${(_target as int) < 3 ? 'Satır' : 'Sütun'} ${(_target as int) % 3 + 1}'
                  : _cellCriteria(_target as int),
            ),
            TextField(
              controller: _answer,
              enabled: _canPlay,
              onChanged: _find,
              decoration: InputDecoration(
                labelText: _reverse
                    ? 'Üç oyuncunun ortak kriteri'
                    : 'Futbolcu ara · En az iki harf',
              ),
            ),
            if (_reverse)
              FilledButton(
                onPressed: _canPlay
                    ? () => _act('guess', {
                        'target': _target,
                        'answer': _answer.text,
                      })
                    : null,
                child: const Text('Kriteri doğrula'),
              ),
            for (final p in _suggestions)
              ListTile(
                title: Text('${p['name']}'),
                onTap: _canPlay
                    ? () => _act('guess', {
                        'target': _target,
                        'playerId': p['id'],
                      })
                    : null,
              ),
            const SizedBox(height: 12),
            if (text != null)
              Text('$text')
            else ...[
              Text(
                _reverse
                    ? 'Temel destek ortak kriterin türünü daraltır.'
                    : 'Temel destek geçerli bir adayın milliyet ve mevki grubunu verir.',
              ),
              const Text('Kullanılırsa sonuç Yardımlı olarak kaydolur.'),
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
      ),
    );
  }
}
