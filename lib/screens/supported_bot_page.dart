import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../app/app_feedback.dart';
import '../app/game_audio.dart';
import '../models/rewarded_ad_models.dart';
import '../services/auth_service.dart';
import '../services/story_support_service.dart';
import '../widgets/paid_hint_button.dart';
import '../widgets/pitch_ui.dart';

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
  });
  final String mode;
  final String? difficulty, clubId, clubName;
  final Widget legacy;
  final StorySupportService? service;
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
      if (_realtime || _run['turn'] == 'bot') _load();
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
  Future<void> _watch(Object target) => _work(() async {
    _watching = true;
    try {
      await _service.watch({
        'mode': widget.mode,
        'sessionId': _run['id'],
        'target': target,
        'boostId': 'boost_basic',
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
  @override
  Widget build(BuildContext context) {
    if (_legacy) return widget.legacy;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title),
          actions: [
            if (_realtime && _active)
              IconButton(
                tooltip: _paused ? 'Devam et' : 'Duraklat',
                onPressed: _busy
                    ? null
                    : () => _act(_paused ? 'resume' : 'pause'),
                icon: Icon(
                  _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                ),
              ),
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
              if (_run.isEmpty && !_busy && !_accountChanged) ..._setup(),
              if (_run.isNotEmpty) ...[
                Text(
                  _run['assisted'] == true
                      ? 'Yardımlı · Ayrı sonuç kaydı'
                      : 'Yardımsız',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _kind == 'team_race'
                      ? 'Tur galibiyeti · Sen: ${_run['userScore'] ?? 0} · Bot: ${_run['botScore'] ?? 0}'
                      : 'Sen: ${_run['userScore'] ?? 0} · Bot: ${_run['botScore'] ?? 0}',
                ),
                if (_run['feedback'] != null) Text('${_run['feedback']}'),
                if (_paused)
                  const Text(
                    'Oyun duraklatıldı. Devam ettiğinde saat kaldığı yerden işler.',
                  ),
                if (_active && !_realtime)
                  Text(
                    _run['turn'] == 'bot'
                        ? 'Bot oynuyor…'
                        : _run['turn'] == 'result'
                        ? 'Tur sonucu'
                        : 'Sıra sende',
                  ),
                const SizedBox(height: 12),
                if (_kind == 'loto') ..._loto(),
                if (_kind == 'team_race') ..._race(),
                if (_kind == 'cinko') ..._cinko(),
                if (_kind == 'random_five') ..._five(),
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
                  Text(
                    _run['completed'] == true
                        ? (_run['winner'] == 1
                              ? 'Kazandın'
                              : _run['winner'] == 2
                              ? 'Bot kazandı'
                              : 'Beraberlik')
                        : 'Oyun tamamlanmadan bitti',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Text(
                    'Coin/XP, sıralama veya ustalık ödülü yok. Yardımlı sonuçlar ayrı tutulur.',
                  ),
                  FilledButton(
                    onPressed: _busy || _data['availability'] != true
                        ? null
                        : () => _act('start'),
                    child: const Text('Yeni maç'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _setup() => [
    Text(
      widget.clubName == null
          ? 'Her hamle hesabına kaydedilir. Maç ödülsüzdür; yardımlı sonuç ayrı tutulur.'
          : '${widget.clubName} ile yarış. Her hamle hesabına kaydedilir; yardımlı sonuç ayrı tutulur.',
    ),
    const SizedBox(height: 12),
    if (widget.difficulty == null)
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
    const SizedBox(height: 12),
    FilledButton(
      onPressed: _data['availability'] == true && _error == null
          ? () => _act('start')
          : null,
      child: const Text('Maça başla'),
    ),
  ];
  Widget _support(
    Object target,
    String key,
    String about, {
    bool enabled = true,
  }) {
    final text = rewardMap(_run['hints'])[key];
    return PitchPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (text != null)
            Text('$text')
          else ...[
            Text(about),
            const Text('Kullanılırsa sonuç Yardımlı olarak kaydolur.'),
            PaidHintButton(
              session: _run,
              sku: 'boost_basic',
              label: 'Temel bilgi',
              disabled: !_canPlay || !enabled,
              onUse: (payment) => _act('hint', {'target': target, ...payment}),
              onWatch: () => _watch(target),
            ),
          ],
        ],
      ),
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
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 72),
                      child: cell(row * columns + col),
                    )
                  : const SizedBox.shrink(),
          ],
        ),
    ],
  );
  Widget _picker(void Function(Map<String, dynamic>) onPick, String label) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _answer,
            enabled: _canPlay,
            onChanged: _find,
            decoration: InputDecoration(labelText: label),
          ),
          for (final p in _suggestions)
            ListTile(
              title: Text('${p['name']}'),
              onTap: _canPlay ? () => onPick(p) : null,
            ),
        ],
      );
  List<Widget> _loto() {
    final placements = rewardMap(_run['placements']),
        bot = rewardMap(_run['botPlacements']);
    final current = rewardMap(_run['current']);
    final index = _run['index'] as num? ?? 16;
    return [
      if (_active && current.isNotEmpty) ...[
        Text(
          '${index.toInt() + 1}/16 · ${current['name']}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text('Kalan süre: ${_seconds('deadline')} sn'),
      ],
      if (_active)
        Text('Bot ${_run['botIndex'] ?? 0}/16 oyuncuyu yerleştirdi.'),
      const SizedBox(height: 8),
      _board(
        4,
        16,
        (i) => Semantics(
          label: _label(_list('criteria')[i]),
          child: Card(
            child: InkWell(
              key: ValueKey('loto-cell-$i'),
              onTap:
                  _canPlay &&
                      current.isNotEmpty &&
                      !placements.containsKey('$i')
                  ? () => _act('place', {'index': index, 'target': i})
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _label(_list('criteria')[i]),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (placements.containsKey('$i'))
                      Text(
                        '${rewardMap(placements['$i'])['name']}'
                        '${rewardMap(placements['$i'])['correct'] == null
                            ? ''
                            : rewardMap(placements['$i'])['correct'] == true
                            ? ' ✓'
                            : ' ✗'}',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      if (_active && current.isNotEmpty) ...[
        OutlinedButton(
          onPressed: _canPlay ? () => _act('pass', {'index': index}) : null,
          child: const Text('Pas · 0 puan'),
        ),
        _support(
          index.toInt(),
          'player_$index',
          'Temel destek oyuncunun milliyetini ve mevki grubunu verir. '
              'Saat durmaz; süreli oyunda reklamla alınamaz.',
        ),
      ],
      if (!_active && bot.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('Bot tahtası', style: Theme.of(context).textTheme.titleMedium),
        for (final e in bot.entries)
          Text(
            '${_label(_list('criteria')[int.parse(e.key)])}: '
            '${rewardMap(e.value)['name']} ${rewardMap(e.value)['correct'] == true ? '✓' : '✗'}',
          ),
        Text(
          'Pas: ${_run['passed'] ?? 0} · Süre aşımı: ${_run['timedOut'] ?? 0}',
        ),
      ],
    ];
  }

  List<Widget> _race() {
    final round = (_run['round'] as num? ?? 0).toInt();
    final countdown = _seconds('startsAt');
    return [
      Text(
        '${round + 1}. tur · ${_label(_run['club'])} × ${_label(_run['opponent'])}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Text(
        'Bu tur: Sen ${_run['userFound'] ?? 0} · Bot ${_run['botFound'] ?? 0} · Kalan ${_run['remaining'] ?? 0}',
      ),
      if (_active && _run['over'] != true && countdown > 0)
        Text('Başlıyor: $countdown'),
      for (final f in _list('found'))
        Text(
          '${rewardMap(f)['name']} · ${rewardMap(f)['owner'] == 1 ? 'Sen' : 'Bot'}',
        ),
      if (_active && _run['over'] == true)
        FilledButton(
          onPressed: _busy ? null : () => _act('next'),
          child: const Text('Sonraki tur'),
        ),
      if (_active && _run['over'] != true && countdown == 0) ...[
        _picker(
          (p) => _act('guess', {'round': round, 'playerId': p['id']}),
          'İki kulüpte oynamış futbolcu',
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

  List<Widget> _cinko() {
    final current = rewardMap(_run['current']);
    final last = rewardMap(_run['last']);
    return [
      if (last.isNotEmpty)
        Text(
          '${last['owner'] == 1 ? 'Sen' : 'Bot'}: ${last['pass'] == true ? 'pas · 0' : '${rewardMap(last['player'])['name']} · ${(last['points'] as num? ?? 0) >= 0 ? '+' : ''}${last['points']}'}',
        ),
      _board(
        5,
        _list('cells').length,
        (i) => _cinkoCell(i, current.isNotEmpty),
      ),
      if (_active && _run['turn'] == 'user') ...[
        if (current.isEmpty) ...[
          _picker(
            (p) => _act('choose', {'playerId': p['id']}),
            'Oyuncu seç · En az iki harf',
          ),
          OutlinedButton(
            onPressed: _canPlay ? () => _act('pass') : null,
            child: const Text('Pas · 0 puan'),
          ),
          if (_hintCell != null)
            _support(
              _hintCell!,
              'cell_$_hintCell',
              '${_label(_cellsOf(_hintCell!))} kutusu için kullanılmamış bir adayın bilgisi.',
            )
          else
            const Text('Destek için tahtadan açık bir kutu seç.'),
        ] else ...[
          Text(
            '${current['name']} · bağlı kutuları seç',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          FilledButton(
            onPressed: _canPlay && _cells.isNotEmpty
                ? () => _act('confirm', {'cells': _cells.toList()..sort()})
                : null,
            child: Text('Seçimi onayla · ${_cells.length} kutu'),
          ),
          TextButton(
            onPressed: _canPlay ? () => _act('cancel') : null,
            child: const Text('Oyuncuyu değiştir'),
          ),
          OutlinedButton(
            onPressed: _canPlay ? () => _act('pass') : null,
            child: const Text('Pas · 0 puan'),
          ),
        ],
      ],
    ];
  }

  Widget _cinkoCell(int i, bool selecting) {
    final cell = rewardMap(_cellsOf(i));
    final owner = cell['owner'] as num? ?? 0;
    final scheme = Theme.of(context).colorScheme;
    final chosen = selecting ? _cells.contains(i) : _hintCell == i;
    return Semantics(
      label:
          '${_label(cell)}${owner == 1
              ? ', senin'
              : owner == 2
              ? ', botun'
              : ''}',
      selected: chosen,
      child: Card(
        color: owner == 1
            ? scheme.primaryContainer
            : owner == 2
            ? scheme.tertiaryContainer
            : chosen
            ? scheme.secondaryContainer
            : null,
        child: InkWell(
          key: ValueKey('cinko-cell-$i'),
          onTap: _canPlay && owner == 0 && cell['playable'] == true
              ? () => setState(() {
                  if (selecting) {
                    _cells.contains(i) ? _cells.remove(i) : _cells.add(i);
                  } else {
                    _hintCell = _hintCell == i ? null : i;
                  }
                })
              : null,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _label(cell),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (cell['player'] != null)
                  Text(
                    '${rewardMap(cell['player'])['name']}',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ),
        ),
      ),
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

    return [
      Text(
        '${round + 1}/5. tur',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final c in _list('clubs')) Chip(label: Text(_label(c))),
        ],
      ),
      for (final h in _list('history'))
        if (rewardMap(h)['user'] != null)
          Text(
            '${(rewardMap(h)['round'] as num? ?? 0).toInt() + 1}. tur · Sen: ${move(rewardMap(h)['user'])} · '
            'Bot: ${move(rewardMap(h)['bot'])}',
          ),
      if (_active && _run['turn'] == 'result')
        FilledButton(
          onPressed: _busy ? null : () => _act('next'),
          child: const Text('Sonraki tur'),
        ),
      if (_active && _run['turn'] == 'user') ...[
        _picker(
          (p) => _act('guess', {'playerId': p['id']}),
          'Beş kulüpten en az birinde oynamış futbolcu',
        ),
        OutlinedButton(
          onPressed: _canPlay ? () => _act('pass') : null,
          child: const Text('Pas · 0 puan'),
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
