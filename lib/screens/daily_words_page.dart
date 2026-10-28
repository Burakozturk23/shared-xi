import 'dart:async';
import '../widgets/paid_hint_button.dart';
import '../services/game_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/daily_words.dart';
import '../app/app_feedback.dart';
import '../app/route_appearance.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/game_ui.dart';
import '../models/rewarded_ad_models.dart';
import '../services/auth_service.dart';
import '../services/daily_words_service.dart';
import '../widgets/pitch_ui.dart';

List<Map<String, dynamic>> _rows(dynamic raw) =>
    (raw is List ? raw : const []).map((r) => rewardMap(r)).toList();

class DailyWordsPage extends StatefulWidget {
  const DailyWordsPage({super.key, required this.mode, this.service});
  final String mode;
  final DailyWordsService? service;
  @override
  State<DailyWordsPage> createState() => _DailyWordsPageState();
}

class _DailyWordsPageState extends State<DailyWordsPage>
    with WidgetsBindingObserver {
  late final _service = widget.service ?? DailyWordsService();
  final _answer = TextEditingController();
  final _scroll = ScrollController();
  final _clock = Stopwatch();
  StreamSubscription<dynamic>? _auth;
  Timer? _ticker;
  Map<String, dynamic> _status = {}, _session = {};
  bool _busy = false,
      _changedAccount = false,
      _records = false,
      _archive = false,
      _resumed = true;
  bool _vibrate = false;
  String? _error, _owner, _lettersKey;
  List<String> _letters = [];
  final List<int> _chosen = [];
  bool get _weekly => widget.mode == 'passa_weekly';
  bool get _lingo => widget.mode == 'daily_lingo';
  bool get _practice => widget.mode == 'anagram_practice';
  bool get _anagram => widget.mode == 'daily_anagram' || _practice;
  bool get _finished => _session['finished'] == true;
  bool get _offline => _status['offline'] == true;
  int get _now =>
      (_session['serverNow'] as num? ?? _status['serverNow'] as num? ?? 0)
          .toInt() +
      _clock.elapsedMilliseconds;
  int get _seconds => (((_session['deadline'] as num? ?? _now) - _now) / 1000)
      .ceil()
      .clamp(0, 240);
  bool get _locked =>
      _busy ||
      _error != null ||
      _changedAccount ||
      _offline ||
      _archive ||
      _finished ||
      _status['availability'] != true ||
      _weekly && _session.isNotEmpty && _seconds == 0;
  List<Map<String, dynamic>> get _rounds => _rows(_session['rounds']);
  Map<String, dynamic> get _round =>
      _rounds.isEmpty ? {} : _rounds[(_session['index'] as num? ?? 0).toInt()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _owner = AuthService.uid;
    _auth = AuthService.authStateChanges.listen((u) {
      if (_owner != null && u?.uid != _owner && mounted) {
        setState(() {
          _changedAccount = true;
          _status = {};
          _session = {};
          _answer.clear();
          _letters = [];
          _chosen.clear();
          _error = 'Hesap değişti. Ekranı yeniden aç.';
        });
      }
      _owner ??= u?.uid;
    });
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted ||
          !_resumed ||
          _changedAccount ||
          _records ||
          _archive ||
          _session.isEmpty ||
          _finished)
        return;
      if (_weekly) setState(() {});
      if (!_busy &&
          !_offline &&
          _error == null &&
          (_weekly && _seconds == 0 ||
              !_weekly &&
                  _now >= (_session['closesAt'] as num? ?? double.infinity)))
        _load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth?.cancel();
    _ticker?.cancel();
    _answer.dispose();
    _scroll.dispose();
    _clock.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed && !_busy && !_changedAccount && !_archive) _load();
  }

  void _accept(Map<String, dynamic> status) {
    _status = status;
    _setSession(rewardMap(status['session']));
    _clock
      ..reset()
      ..start();
  }

  void _setSession(Map<String, dynamic> value) {
    final old = _session['questionId'];
    _session = value;
    if (old != value['questionId']) _answer.clear();
    if (_anagram && _rounds.isNotEmpty) {
      final key =
          '${value['packId']}|${_round['questionId']}|${_round['scrambledLetters']}';
      if (_lettersKey != key) {
        _lettersKey = key;
        _letters = '${_round['scrambledLetters'] ?? ''}'.split('');
        _chosen.clear();
      }
    }
  }

  Future<void> _run(Future<void> Function() body) async {
    if (!mounted || _changedAccount || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await body();
    } catch (e) {
      if (mounted && !_changedAccount)
        setState(() => _error = _errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() => _run(() async {
    final firstLoad = _status.isEmpty;
    final status = await _service
        .load(widget.mode)
        .timeout(const Duration(seconds: 30));
    if (status['availability'] is! bool) {
      throw StateError('Günlük içerik alınamadı. Yeniden bağlanmayı dene.');
    }
    if (mounted && !_changedAccount) {
      setState(() {
        _accept(status);
        _archive = false;
      });
      if (firstLoad && _scroll.hasClients) _scroll.jumpTo(0);
    }
  });
  Future<void> _act(String action, [Map<String, dynamic> payment = const {}]) =>
      _run(() async {
        final response = await _service
            .mutate({
              'mode': widget.mode,
              'period': _session['period'] ?? _status['period'],
              'packId': _session['packId'] ?? _status['packId'],
              'contentVersion':
                  _session['contentVersion'] ?? _status['contentVersion'],
              'revision': _session['revision'],
              'questionId': _session['questionId'],
              'action': action,
              if (_practice && action == 'start')
                'expectedEnergyCost': _status['energyCost'],
              if (action == 'guess') 'answer': _answer.text,
              ...payment,
            })
            .timeout(const Duration(seconds: 30));
        if (!mounted || _changedAccount) return;
        setState(() {
          _setSession(rewardMap(response['session']));
          _clock
            ..reset()
            ..start();
          _answer.clear();
          _chosen.clear();
        });
        if (_vibrate) AppFeedback.selection();
        final status = await _service
            .load(widget.mode)
            .timeout(const Duration(seconds: 30));
        if (!mounted || _changedAccount) return;
        setState(() => _accept(status));
        if (_scroll.hasClients && ['next', 'start'].contains(action))
          _scroll.jumpTo(0);
      });
  Widget _paidHint(
    String action,
    String sku,
    String label, {
    bool disabled = false,
  }) => PaidHintButton(
    session: _session,
    sku: sku,
    label: label,
    disabled: _locked || disabled,
    onUse: (payment) => _act(action, payment),
    onWatch: () => _run(() async {
      await _service.watchHint(_session, sku);
      final status = await _service.load(widget.mode);
      if (mounted && !_changedAccount) setState(() => _accept(status));
    }),
  );
  Future<void> _history(String period) => _run(() async {
    final value = await _service
        .history(widget.mode, period)
        .timeout(const Duration(seconds: 30));
    if (!mounted || _changedAccount) return;
    setState(() {
      _archive = true;
      _records = false;
      _setSession(rewardMap(value['session']));
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  });
  Future<void> _giveup() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cevabı gösterip bitir?'),
        content: Text(
          _practice
              ? 'Bu sekizli seri kapanır. Yeni seri ekranında görünen enerji bedeliyle başlar. Sayfadan çıkmak ilerlemeni korur.'
              : 'Bu resmî sonuç kilitlenir. Coin, XP veya üçleme hakkı kazanılmaz. Sayfadan çıkmak ise ilerlemeni korur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Devam et'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bitir'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) await _act('giveup');
  }

  List<Widget> _appBarActions() => [
    if (!_practice)
      IconButton(
        tooltip: '30 günlük arşiv',
        onPressed: _busy || _changedAccount || _status.isEmpty
            ? null
            : () => setState(() {
                _records = !_records;
              }),
        icon: const Icon(Icons.calendar_month_outlined),
      ),
    IconButton(
      tooltip: 'Yenile',
      onPressed: _busy || _changedAccount ? null : _load,
      icon: const Icon(Icons.refresh),
    ),
  ];
  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
    return Scaffold(
      appBar: AppBar(
        title: Text(dailyWordsTitle(widget.mode), maxLines: 2),
        toolbarHeight: largeText ? 96 : 64,
        actions: largeText ? null : _appBarActions(),
        bottom: largeText
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: _appBarActions(),
                ),
              )
            : null,
      ),
      body: GameContent(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            if (_status.isEmpty) ...[
              _welcome(),
              const SizedBox(height: 16),
              if (_busy) _loadingPanel(),
            ] else if (_busy) ...[
              Semantics(
                label: 'Oyun eşitleniyor',
                child: const LinearProgressIndicator(),
              ),
              const SizedBox(height: 12),
            ],
            if (_error != null) _errorPanel(),
            if (_status['notice'] != null) _notice('${_status['notice']}'),
            if (_status.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text('${_session['period'] ?? _status['period']}'),
                  ),
                  Chip(
                    label: Text(
                      _practice
                          ? 'Yeni seri: ${_status['energyCost'] ?? 0} enerji'
                          : '0 enerji',
                    ),
                  ),
                  Chip(
                    label: Text(
                      _weekly
                          ? '29 harf'
                          : _lingo
                          ? '6 tahmin'
                          : _practice
                          ? '8 futbolcu'
                          : _anagram
                          ? '3 futbolcu'
                          : '7 harf',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_archive) ...[
                const Text('Arşiv · Salt okunur · Ödülsüz görüntüleme'),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          _archive = false;
                          _load();
                        },
                  child: const Text('Bugüne dön'),
                ),
              ],
              if (_records)
                ..._archivePanel()
              else ...[
                if (_status['availability'] != true && !_archive)
                  _notice(
                    '${_status['reason'] ?? 'Bugünün içeriği henüz hazır değil.'}',
                  ),
                if (_session.isEmpty)
                  ..._intro()
                else if (_lingo)
                  ..._lingoPanel()
                else if (_anagram)
                  ..._anagramPanel()
                else
                  ..._passaPanel(),
                if (_finished) ..._resultPanel(),
                if (_practice && _finished)
                  FilledButton(
                    onPressed:
                        _busy || _offline || _changedAccount || _error != null
                        ? null
                        : () => _act('start'),
                    child: Text(
                      'Yeni seri · ${_status['energyCost'] ?? 0} enerji',
                    ),
                  ),
                if (_session.isNotEmpty && !_finished && !_archive)
                  TextButton(
                    onPressed: _locked ? null : _giveup,
                    child: const Text('Cevabı göster / bırak'),
                  ),
                const SizedBox(height: 18),
                if (!_practice) ..._trioPanel(),
                if (widget.mode == 'passa_daily')
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      LinkballRoute(
                        builder: (_) => DailyWordsPage(
                          mode: 'passa_weekly',
                          service: widget.service,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.timelapse),
                    label: const Text('Haftalık Klasik · 29 harf / 240 sn'),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _errorMessage(Object error) => gameErrorMessage(error);

  Widget _welcome() => GameIntro(
    icon: _lingo
        ? Icons.text_fields_rounded
        : _anagram
        ? Icons.shuffle_rounded
        : Icons.abc_rounded,
    title: _lingo
        ? 'Bir kelime. Altı şans.'
        : _anagram
        ? 'Harfleri çöz, futbolcuyu bul.'
        : _weekly
        ? 'Haftanın büyük çemberi'
        : 'Yedi harf, yedi futbol sorusu.',
    message: _lingo
        ? 'Futbolcu, kulüp veya ülkeyi bul. Her tahminde harflerin konumunu keşfet.'
        : _practice
        ? '8 futbolcu, her turda 3 tahmin. 24 saat içinde aynı seriye dön. İpuçları puanı azaltır; Coin/XP ödülü yoktur.'
        : _anagram
        ? 'Üç futbolcunun karışık harflerini doğru sıraya koy.'
        : _weekly
        ? '29 harf, Ğ dahil. 240 saniye boyunca çöz; her soruda bir pas hakkın var. Süre arka planda da ilerler. Haftada tek resmî sonuç.'
        : 'İpuçlarını oku, harfle başlayan ya da harfi içeren cevabı bul. Süre sınırı yok; her soruda bir pas hakkın var.',
  );

  Widget _loadingPanel() => PitchPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Günlük içerik yükleniyor',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text('Günün bulmacası ve kayıtlı ilerlemen kontrol ediliyor.'),
        const SizedBox(height: 16),
        const LinearProgressIndicator(
          semanticsLabel: 'Günlük içerik yükleniyor',
        ),
        const SizedBox(height: 16),
        Text(
          _practice
              ? 'Seri yalnız Başlat ile açılır; yükleme enerji harcamaz.'
              : 'Yükleme enerji veya destek hakkı harcamaz.',
        ),
      ],
    ),
  );

  Widget _errorPanel() => GameErrorPanel(
    message: _error!,
    accountChanged: _changedAccount,
    onRetry: _busy ? null : _load,
  );

  Widget _notice(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: PitchPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: PitchColors.of(context).accent,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );

  List<Widget> _intro() => _archive
      ? [const Text('Bu tarihte bu oyun için kayıt yok.')]
      : [
          _welcome(),
          if (_practice) ...[
            const SizedBox(height: 16),
            PitchAction(
              onPressed: _locked ? null : () => _act('start'),
              label:
                  'Sekizli seriyi başlat · ${_status['energyCost'] ?? 0} enerji',
            ),
          ],
          if (_weekly) ...[
            const SizedBox(height: 16),
            PitchAction(
              onPressed: _locked ? null : () => _act('start'),
              label: '240 saniyeyi başlat',
            ),
          ],
        ];
  List<Widget> _lingoPanel() {
    final guesses = _rows(_session['guesses']);
    final length = (_session['length'] as num? ?? 5).toInt();
    final category =
        {
          'player': 'Futbolcu',
          'club': 'Kulüp',
          'country': 'Ülke',
        }[_session['category']] ??
        '';
    final typed = dailyWordKey(_answer.text);
    final keyboard = <String, String>{};
    const order = {'absent': 0, 'present': 1, 'exact': 2};
    for (final guess in guesses) {
      final word = '${guess['word']}';
      final marks = List<String>.from(guess['marks'] as List);
      for (var i = 0; i < word.length; i++) {
        if ((order[marks[i]] ?? -1) > (order[keyboard[word[i]]] ?? -1))
          keyboard[word[i]] = marks[i];
      }
    }
    return [
      PitchPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Günün kelimesi',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('$category · $length harf · ${6 - guesses.length} hak kaldı'),
          ],
        ),
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
          final width = ((constraints.maxWidth - (length - 1) * 4) / length)
              .clamp(36 * scale, 58 * scale)
              .toDouble();
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              children: List.generate(
                6,
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: List.generate(length, (col) {
                      final word = row < guesses.length
                          ? '${guesses[row]['word']}'
                          : row == guesses.length && !_finished
                          ? typed
                          : '';
                      final letter = col < word.length ? word[col] : '';
                      final mark = row < guesses.length
                          ? '${(guesses[row]['marks'] as List)[col]}'
                          : null;
                      return Padding(
                        padding: EdgeInsets.only(
                          right: col == length - 1 ? 0 : 4,
                        ),
                        child: _tile(
                          letter,
                          width: width,
                          mark: mark,
                          semantics: 'Satır ${row + 1}, sütun ${col + 1}',
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      if (!_finished) ...[
        const SizedBox(height: 12),
        _input(
          'Tahminini yaz',
          action: 'guess',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 4,
          runSpacing: 5,
          children: 'QWERTYUIOPASDFGHJKLZXCVBNM'
              .split('')
              .map(
                (letter) => Semantics(
                  label:
                      '$letter${keyboard[letter] == null ? '' : ', ${dailyWordMark(keyboard[letter]!)}'}',
                  button: true,
                  child: SizedBox(
                    width: MediaQuery.textScalerOf(context).scale(14) > 20
                        ? 48
                        : 40,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        minimumSize: const Size(36, 48),
                        backgroundColor: _markColor(keyboard[letter]),
                      ),
                      onPressed: _locked
                          ? null
                          : () {
                              if (dailyWordKey(_answer.text).length < length)
                                setState(() => _answer.text += letter);
                            },
                      child: Column(
                        children: [
                          Text(
                            letter,
                            style: TextStyle(
                              color: keyboard[letter] == null
                                  ? PitchColors.of(context).text
                                  : Colors.white,
                            ),
                          ),
                          if (keyboard[letter] != null)
                            Icon(
                              _markIcon(keyboard[letter]),
                              size: 12,
                              color: Colors.white,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _locked
                ? null
                : () {
                    if (_answer.text.isNotEmpty)
                      setState(
                        () => _answer.text = _answer.text.substring(
                          0,
                          _answer.text.length - 1,
                        ),
                      );
                  },
            icon: const Icon(Icons.backspace_outlined),
            label: const Text('Sil'),
          ),
        ),
        if (_session['hintUsed'] == true)
          _notice('İpucu: ${_session['hint']}')
        else if (rewardMap(_session['support'])['version'] == 1)
          _paidHint(
            'hint',
            'boost_basic',
            'Bağlam ipucu',
            disabled: _session['hintAvailable'] != true,
          )
        else
          OutlinedButton.icon(
            onPressed: _locked || _session['hintAvailable'] != true
                ? null
                : () => _act('hint'),
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('Bağlam ipucu · 3. tahminden sonra'),
          ),
        const Text(
          'Ç/Ğ/İ/Ö/Ş/Ü ve aksanlar A–Z biçimine çevrilir. Boşluk ve noktalama sayılmaz.',
          style: TextStyle(fontSize: 12),
        ),
      ] else ...[
        const SizedBox(height: 12),
        Text(
          '${_session['display']} · ${_session['answer']}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    ];
  }

  Color _markColor(String? mark) => switch (mark) {
    'exact' => const Color(0xff236847),
    'present' => const Color(0xff73591c),
    'absent' => const Color(0xff394944),
    _ => PitchColors.of(context).raised,
  };
  IconData _markIcon(String? mark) => switch (mark) {
    'exact' => Icons.check,
    'present' => Icons.swap_horiz,
    _ => Icons.close,
  };
  Widget _tile(
    String letter, {
    required double width,
    String? mark,
    String semantics = '',
  }) => Semantics(
    label:
        '$semantics $letter ${mark == null ? 'boş veya gönderilmedi' : dailyWordMark(mark)}',
    excludeSemantics: true,
    child: Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: mark == null ? PitchColors.of(context).raised : _markColor(mark),
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            letter.isEmpty ? ' ' : letter,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: mark == null ? null : Colors.white,
              fontSize: 18,
            ),
          ),
          if (mark != null)
            Icon(_markIcon(mark), size: 14, color: Colors.white),
        ],
      ),
    ),
  );
  Widget _input(
    String label, {
    required String action,
    ValueChanged<String>? onChanged,
  }) => Column(
    children: [
      TextField(
        controller: _answer,
        enabled: !_locked,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.characters,
        maxLength: _lingo ? 30 : 100,
        decoration: InputDecoration(labelText: label, counterText: ''),
        onChanged: onChanged,
        onSubmitted: (_) {
          if (!_locked) _act(action);
        },
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _locked ? null : () => _act(action),
          child: const Text('Yanıtla'),
        ),
      ),
    ],
  );
  List<Widget> _anagramPanel() {
    final round = _round;
    final index = (_session['index'] as num? ?? 0).toInt();
    final ended = round['status'] != 'pending';
    final guesses = List<String>.from(round['guesses'] as List? ?? []);
    return [
      Text(
        'Futbolcu ${index + 1}/${_practice ? 8 : 3} · ${_session['score'] ?? 0}/${_practice ? 800 : 300} puan',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text('${3 - guesses.length} tahmin kaldı · Süresiz'),
      const SizedBox(height: 16),
      if (!ended && !_finished) ...[
        Wrap(
          spacing: 6,
          runSpacing: 8,
          children: List.generate(
            _letters.length,
            (i) => SizedBox(
              width: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _locked || _chosen.contains(i)
                    ? null
                    : () => setState(() {
                        _chosen.add(i);
                        _answer.text = _chosen.map((n) => _letters[n]).join();
                      }),
                child: Text(_letters[i]),
              ),
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: _locked ? null : () => _act('shuffle'),
              icon: const Icon(Icons.shuffle),
              label: const Text('Yeniden karıştır'),
            ),
            TextButton(
              onPressed: _locked
                  ? null
                  : () => setState(() {
                      _chosen.clear();
                      _answer.clear();
                    }),
              child: const Text('Temizle'),
            ),
          ],
        ),
        _input(
          'Harfleri seç veya adını yaz',
          action: 'guess',
          onChanged: (_) => setState(() => _chosen.clear()),
        ),
        if (guesses.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: _notice('Denemelerin: ${guesses.join(' · ')}'),
          ),
        const SizedBox(height: 12),
        if (round['bio'] == true)
          _notice('Ülke / mevki: ${round['hint']}')
        else if (rewardMap(_session['support'])['version'] == 1)
          _paidHint('bio', 'boost_basic', 'Ülke + mevki · −15 puan')
        else
          OutlinedButton(
            onPressed: _locked ? null : () => _act('bio'),
            child: const Text('Ülke + mevki · −15 puan'),
          ),
        if (round['first'] == true)
          _notice('İlk harf: ${round['firstLetter']}')
        else if (rewardMap(_session['support'])['version'] == 1)
          _paidHint('first', 'boost_first_letter', 'İlk harf · −25 puan')
        else
          OutlinedButton(
            onPressed: _locked ? null : () => _act('first'),
            child: const Text('İlk harf · −25 puan'),
          ),
        TextButton(
          onPressed: _locked ? null : () => _act('reveal'),
          child: const Text('Bu cevabı aç · 0 puan'),
        ),
      ] else ...[
        PitchPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${round['name'] ?? ''}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text('${round['answer'] ?? ''} · ${round['score'] ?? 0} puan'),
              Text(
                round['status'] == 'correct'
                    ? 'Doğru!'
                    : 'Bu futbolcu kapandı.',
              ),
            ],
          ),
        ),
        if (!_finished) ...[
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _locked ? null : () => _act('next'),
            child: const Text('Sonraki futbolcu'),
          ),
        ],
      ],
    ];
  }

  List<Widget> _passaPanel() {
    final q = rewardMap(_session['question']);
    final rounds = _rounds;
    final correct = rounds.where((r) => r['status'] == 'correct').length;
    final wrong = rounds
        .where((r) => ['wrong', 'timeout'].contains(r['status']))
        .length;
    final letters = List.generate(rounds.length, (i) {
      final r = rounds[i];
      final active = !_finished && i == _session['index'];
      final icon = r['status'] == 'correct'
          ? Icons.check
          : ['wrong', 'timeout'].contains(r['status'])
          ? Icons.close
          : r['passed'] == true
          ? Icons.redo
          : Icons.more_horiz;
      final dark = Theme.of(context).brightness == Brightness.dark;
      final color = r['status'] == 'correct'
          ? (dark ? const Color(0xff6cdda3) : const Color(0xff236847))
          : ['wrong', 'timeout'].contains(r['status'])
          ? Theme.of(context).colorScheme.error
          : r['passed'] == true
          ? (dark ? const Color(0xfff2ca66) : const Color(0xff73591c))
          : Theme.of(context).colorScheme.onSurfaceVariant;
      return Semantics(
        label:
            '${r['letter']}, ${r['status'] == 'correct'
                ? 'doğru'
                : r['status'] == 'wrong'
                ? 'yanlış'
                : r['passed'] == true
                ? 'pas kullanıldı'
                : 'bekliyor'}${active ? ', şu anki soru' : ''}',
        excludeSemantics: true,
        child: Container(
          width: 48,
          margin: const EdgeInsets.only(right: 5, bottom: 5),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: color.withAlpha(20),
            border: Border.all(
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).dividerColor,
              width: active ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '${r['letter']}',
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
              Icon(icon, size: 15, color: color),
            ],
          ),
        ),
      );
    });
    return [
      Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          Text(
            '$correct doğru',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('$wrong yanlış'),
          Text(
            '${rounds.where((r) => r['status'] != 'pending').length}/${rounds.length} tamamlandı',
          ),
        ],
      ),
      if (_weekly && !_finished) ...[
        Semantics(
          label: 'Kalan süre $_seconds saniye',
          child: Text(
            '$_seconds sn',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _vibrate,
          onChanged: (v) => setState(() => _vibrate = v),
          title: const Text('Yanıtlarda titreşim'),
        ),
      ],
      const SizedBox(height: 10),
      Wrap(spacing: 4, runSpacing: 4, children: letters),
      if (!_finished) ...[
        const SizedBox(height: 16),
        PitchPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: PitchColors.of(context).tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${q['letter']} ${q['rule'] == 'contains' ? 'içinde geçer' : 'ile başlar'}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: PitchColors.of(context).accent,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${q['prompt']}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                q['passAvailable'] == true
                    ? '1 pas hakkın var.'
                    : 'Pas kullanıldı. Cevapla veya boş bırak.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _input('Cevabın', action: 'guess'),
        if (q['hint'] != null)
          _notice('${q['hint']}')
        else if (rewardMap(_session['support'])['version'] == 1)
          _paidHint('hint', 'boost_basic', 'Cevabın uzunluğu'),
        Wrap(
          spacing: 10,
          children: [
            OutlinedButton(
              onPressed: _locked || q['passAvailable'] != true
                  ? null
                  : () => _act('pass'),
              child: const Text('Pas'),
            ),
            TextButton(
              onPressed: _locked ? null : () => _act('skip'),
              child: const Text('Boş bırak · yanlış'),
            ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _resultPanel() {
    final result = rewardMap(_session['result']);
    final reason =
        {
          'completed': 'Resmî sonuç kaydedildi.',
          'timeout': 'Süre doldu; sonuç kaydedildi.',
          'expired': _practice
              ? '24 saatlik devam süresi doldu.'
              : 'Gün değişti; bu oyun arşivlendi.',
          'giveup': 'Cevap açıldı; ödülsüz sonuç.',
          'void':
              'Soru incelemeye alındı. Bu sonuç başarısızlık veya ödüllü tamamlama sayılmaz.',
        }[result['reason']] ??
        '';
    return [
      const SizedBox(height: 16),
      PitchPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${result['medal'] ?? 'Sonuç'}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (result['assisted'] == true)
              const Text('Yardımlı · Yardımsız seri ve ustalığa eklenmez.'),
            const SizedBox(height: 8),
            Text(reason),
            Text(
              '${result['solved'] ?? 0} doğru · ${_session['attempts'] ?? 0} geçerli yanıt',
            ),
            Text('${result['coins'] ?? 0} Link Coin · ${result['xp'] ?? 0} XP'),
            if (_lingo) Text('${_rows(_session['guesses']).length}/6 tahmin'),
            if (result['rewardEnabled'] == false)
              Text(
                _practice
                    ? 'Antrenman: Coin ve XP ödülü yoktur.'
                    : 'Bu test aşamasında ödüller kapalı.',
              ),
            if (_status['linked'] != true && (result['xp'] as num? ?? 0) > 0)
              const Text(
                'Ödül hakkın bu misafir hesapta saklı. Aktarmak için aynı hesabı Google’a bağla.',
              ),
            const SizedBox(height: 8),
            Text(
              _practice
                  ? 'Yeni seri başlatabilir veya sonucunu paylaşabilirsin.'
                  : _weekly
                  ? 'Yeni hafta: Pazartesi 00.00 · İstanbul'
                  : 'Yeni bulmaca: 00.00 · İstanbul',
            ),
          ],
        ),
      ),
      if (!_lingo)
        ..._rounds.map(
          (r) => ExpansionTile(
            title: Text(
              _anagram
                  ? '${r['name'] ?? 'Futbolcu'} · ${r['score'] ?? 0} puan'
                  : '${r['letter']} · ${r['status'] == 'correct' ? 'Doğru' : 'Kapalı'}',
            ),
            childrenPadding: const EdgeInsets.all(12),
            children: [
              Text(
                _anagram
                    ? '${r['answer']} · Ülke/mevki ipucu: ${r['bio'] == true ? 'açıldı' : 'yok'} · İlk harf: ${r['first'] == true ? 'açıldı' : 'yok'}'
                    : '${r['prompt']}\n${r['answer']}\n${r['explanation']}',
              ),
            ],
          ),
        ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () async {
          await Clipboard.setData(
            ClipboardData(text: dailyWordsShare(_session)),
          );
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cevapsız paylaşım özeti kopyalandı.'),
              ),
            );
        },
        icon: const Icon(Icons.copy_outlined),
        label: const Text('Sonucu paylaşmak için kopyala'),
      ),
    ];
  }

  List<Widget> _trioPanel() {
    final completed = rewardMap(_status['dailyCompletion']);
    final bonus = rewardMap(_status['bonus']);
    return [
      Text('Günlük üçleme', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        children: ['daily_lingo', 'passa_daily', 'daily_anagram']
            .map(
              (mode) => ActionChip(
                avatar: Icon(
                  completed[mode] == true
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  size: 17,
                ),
                label: Text(
                  mode == 'daily_lingo'
                      ? 'Lingo'
                      : mode == 'passa_daily'
                      ? 'Mini'
                      : 'Anagram',
                ),
                onPressed: mode == widget.mode
                    ? null
                    : () => Navigator.of(context).push(
                        LinkballRoute(
                          builder: (_) => DailyWordsPage(
                            mode: mode,
                            service: widget.service,
                          ),
                        ),
                      ),
              ),
            )
            .toList(),
      ),
      Text(
        bonus.isNotEmpty
            ? 'Üçleme tamamlandı · ${bonus['coins']} Coin / ${bonus['xp']} XP'
            : 'Üç geçerli günlük sonuç: +2 Coin / +4 XP. Tam başarıda toplam 11 Coin / 22 XP. Haftalık ve pratik dahil değil.',
      ),
      if (_status['rewardsEnabled'] != true)
        const Text('Bu test aşamasında Coin / XP kazanımı kapalı.'),
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _archivePanel() {
    final data = rewardMap(_status['archive']);
    final days = _rows(data['days']);
    return [
      Text(
        'Günlük seri · ${data['streak'] ?? 0} gün',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const Text(
        'Son 30 gün · Geçmiş sonuçlar değiştirilemez, tekrar ödül verilmez.',
      ),
      if (_weekly)
        ..._rows(data['weeks']).map(
          (w) => ListTile(
            title: Text('${w['period']} haftası'),
            subtitle: Text('${rewardMap(w['result'])['medal'] ?? 'Oynanıyor'}'),
            onTap: _busy || _offline ? null : () => _history('${w['period']}'),
          ),
        ),
      ...days.map((d) {
        final result = rewardMap(rewardMap(d['results'])[widget.mode]);
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${d['day']}'),
          leading: Icon(
            d['status'] == 'completed'
                ? Icons.check_circle_outline
                : Icons.calendar_today_outlined,
          ),
          subtitle: Text(
            result.isNotEmpty
                ? '${result['medal']} · ${result['solved']} doğru'
                : d['status'] == 'missed'
                ? 'Oynanmadı'
                : 'Günlük ilerleme kayıtlı',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _weekly || _busy || _offline
              ? null
              : () => _history('${d['day']}'),
        );
      }),
      TextButton(
        onPressed: () => setState(() => _records = false),
        child: const Text('Oyuna dön'),
      ),
    ];
  }
}
