import '../services/warm_up.dart';
import '../widgets/letter_slot_reveal.dart';
import '../widgets/paid_hint_button.dart';
import '../widgets/hint_panel.dart';
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../app/app_feedback.dart';
import '../app/game_audio.dart';
import '../data/country_flags.dart';
import '../models/club.dart';
import '../widgets/club_badge.dart';
import '../models/rewarded_ad_models.dart';
import '../services/three_modes_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/hub_ui.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/share_result.dart';
import '../widgets/vault_open_reveal.dart';

List<Map<String, dynamic>> _maps(dynamic v) =>
    (v is List ? v : const []).map(rewardMap).toList();
List<String> _strings(dynamic v) =>
    (v is List ? v : const []).map((x) => '$x').toList();
String _medal(Map<String, dynamic> r) => r['mastery'] == true
    ? 'Ustalık'
    : (r['best'] as num? ?? 0) >= 11
    ? 'Altın'
    : (r['best'] as num? ?? 0) >= 8
    ? 'Gümüş'
    : (r['best'] as num? ?? 0) >= 5
    ? 'Bronz'
    : 'Madalyanı kazan';
String _nextMedal(Map<String, dynamic> r) => r['mastery'] == true
    ? 'Tüm madalyalar tamam'
    : (r['best'] as num? ?? 0) >= 11
    ? 'Sıradaki: ipucusuz ustalık'
    : (r['best'] as num? ?? 0) >= 8
    ? 'Sıradaki: 11 oyuncu'
    : (r['best'] as num? ?? 0) >= 5
    ? 'Sıradaki: 8 oyuncu'
    : 'Sıradaki: 5 oyuncu';
String _formation(String v) => v.split('').join('-');

const _levels = {'easy': 'Kolay', 'medium': 'Orta', 'hard': 'Zor'};

/// Share card for a finished letter XI: score as squares, never the names.
String letterShare(Map<String, dynamic> session) {
  final score = (session['score'] as num? ?? 0).toInt();
  final day = '${session['day'] ?? ''}'.split('-').reversed.join('.');
  return [
    'Linkball · Harf 11 · ${'${session['title']}'.split(' ').first}',
    if (session['entry'] == 'daily') 'Günün harfi · $day',
    '${'🟩' * score}${'⬜' * (11 - score)} $score/11',
    '${session['wrong'] ?? 0} yanlış · ${(session['hints'] as List?)?.length ?? 0} ipucu',
  ].join('\n');
}

/// Share card for a finished vault; today's vault never names the club.
String vaultShare(Map<String, dynamic> session) {
  final stars = (session['stars'] as num? ?? 0).toInt();
  final guesses = 5 - (session['remaining'] as num? ?? 0).toInt();
  final daily = session['entry'] == 'daily';
  final day = '${session['day'] ?? ''}'.split('-').reversed.join('.');
  return [
    'Linkball · Kadro Kasası',
    daily ? 'Günün kasası · $day' : '${session['title']}',
    session['won'] == true
        ? '${'⭐' * stars}${'☆' * (5 - stars)} · $guesses/5 tahmin'
        : '🔒 Kasa açılmadı · $guesses/5 tahmin',
    if ((session['hints'] as List?)?.isNotEmpty == true)
      '💡 ${(session['hints'] as List).length} ipucu',
  ].join('\n');
}

const _positions = {
  'GK': 'Kaleci',
  'DEF': 'Defans',
  'MID': 'Orta saha',
  'FWD': 'Hücum',
};

/// The same server-backed contract powers all entry routes and collections.
class ThreeModesPage extends StatefulWidget {
  const ThreeModesPage({super.key, required this.mode, this.service});
  final String mode;
  final ThreeModesService? service;
  @override
  State<ThreeModesPage> createState() => _ThreeModesPageState();
}

class _ThreeModesPageState extends State<ThreeModesPage> {
  late final ThreeModesService _service = widget.service ?? ThreeModesService();
  final _query = TextEditingController();
  Map<String, dynamic> _status = {}, _session = {};
  List<Map<String, dynamic>> _results = [];
  Timer? _debounce;
  int _generation = 0, _slot = 0;
  bool _busy = true, _searching = false, _archive = false, _showHub = false;
  String? _error;
  String _form = '433', _difficulty = '';
  bool get _vault => widget.mode == 'squad_vault';
  String get _title => _vault ? 'Kadro Kasası' : 'Harf 11';
  String get _version => '${_status['version']}';
  bool get _finished => _session['finished'] == true;
  bool get _playing => _session.isNotEmpty && !_showHub;
  bool get _canStart => !_busy && (_session.isEmpty || _finished);
  @override
  void initState() {
    super.initState();
    if (widget.service == null) WarmUp.functions(const ['startThreeMode', 'actThreeMode']);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() body) async {
    if (mounted)
      setState(() {
        _busy = true;
        _error = null;
      });
    try {
      await body();
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is FirebaseFunctionsException
              ? e.message ?? 'Bağlantı kurulamadı. Yenile ile tekrar dene.'
              : e.toString().replaceFirst('Bad state: ', ''),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() => _run(() async {
    final status = await _service.load(widget.mode);
    if (!mounted) return;
    setState(() {
      _status = status;
      _session = rewardMap(status['session']);
    });
  });
  void _clearSearch() {
    _generation++;
    _debounce?.cancel();
    _query.clear();
    _results = [];
    _searching = false;
  }

  Future<void> _start(String entry, {String? target, String? league}) async {
    var drawn = false;
    await _run(() async {
        final r = await _service.mutate('startThreeMode', {
          'mode': widget.mode,
          'version': _version,
          'entry': entry,
          'formation': _form,
          if (_difficulty.isNotEmpty) 'difficulty': _difficulty,
          if (target != null) 'target': target,
          if (league != null) 'league': league,
        });
        if (!mounted) return;
        setState(() {
          _session = rewardMap(r['session']);
          _archive = false;
          _showHub = false;
          _slot = 0;
          _clearSearch();
        });
        drawn = _vault || entry == 'random' || entry == 'daily';
      });
    // A drawn letter (roulette or today's) lands on a slot-machine reel, once the
    // server has answered.
    // A new vault opens: the door, then its first three flags.
    if (drawn && _vault && mounted && _session['finished'] != true) {
      await VaultOpenReveal.show(
        context,
        flags: [
          for (final s in _maps(_session['slots']))
            if ('${s['country'] ?? ''}'.isNotEmpty)
              (country: '${s['country']}', position: _positions['${s['position']}'] ?? '${s['position']}'),
        ],
        guesses: (_session['remaining'] as num? ?? 5).toInt(),
        difficulty: _session['difficulty'] as String?,
        daily: entry == 'daily',
      );
      return;
    }
    if (drawn && mounted) {
      await LetterSlotReveal.show(
        context,
        letter: '${_session['letter'] ?? '${_session['title'] ?? ''}'.split(' ').first}',
        difficulty: _session['letterDifficulty'] as String?,
        daily: entry == 'daily',
      );
    }
  }
  Future<void> _act(
    String action, [
    Map<String, dynamic> extra = const {},
  ]) => _run(() async {
    final r = await _service.mutate('actThreeMode', {
      'mode': widget.mode,
      'version': _version,
      'sessionId': _session['id'],
      'revision': _session['revision'],
      'action': action,
      ...extra,
    });
    if (!mounted) return;
    final before = _session;
    setState(() {
      _session = rewardMap(r['session']);
      _clearSearch();
      // A wrong pick is felt; a placed Harf 11 player keeps its slot-lock cue.
      if (!(!_vault && action == 'place'))
        AppFeedback.answerFrom(before, _session);
      if (!_vault && action == 'place') AppFeedback.sfx(Sfx.slotLock);
      if (!_vault && action == 'place') {
        final empty = _maps(
          _session['slots'],
        ).where((s) => s['player'] == null).toList();
        if (empty.isNotEmpty) _slot = (empty.first['slot'] as num).toInt();
      }
      if (r.containsKey('linked')) _status['linked'] = r['linked'];
    });
  });
  void _search(String value) {
    _debounce?.cancel();
    final generation = ++_generation;
    setState(() {
      _results = [];
      _searching = value.trim().length >= 2;
    });
    if (!_searching) return;
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final r = await _service.search({
          'mode': widget.mode,
          'version': _version,
          'query': value,
        });
        if (mounted && generation == _generation)
          setState(() {
            _results = _maps(r['results']);
            _searching = false;
          });
      } catch (_) {
        if (mounted && generation == _generation)
          setState(() {
            _searching = false;
            _error = 'Arama tamamlanmadı. Yanlış hakkın değişmedi; tekrar ara.';
          });
      }
    });
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Onayla'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _changeFormation(String form) async {
    if (form == _session['formation']) return;
    if ((_session['score'] as num? ?? 0) > 0 &&
        !await _confirm(
          'Kadroyu sıfırla?',
          'Formasyon değişince yerleştirdiğin oyuncular silinir. Yanlış ve kullanılan ipuçları korunur.',
        ))
      return;
    if (mounted)
      await _act('formation', {'formation': form, 'confirmReset': true});
  }

  Future<void> _finish() async {
    if (!_vault && _session['score'] == 11 ||
        await _confirm(
          'Oyunu bitir?',
          _vault
              ? 'Kasa açılır ve bu oyun için yıldız kazanamazsın.'
              : 'Mevcut kadron kaydedilir. Eksik kadroyu daha sonra yeni oyunda geliştirebilirsin.',
        )) {
      if (mounted) await _act('finish');
    }
  }

  Future<void> _watch({String? boostId, String? itemId}) => _run(() async {
    await _service.watchHint(
      widget.mode,
      '${_session['id']}',
      boostId: boostId,
      itemId: itemId,
    );
    final r = await _service.load(widget.mode);
    if (mounted)
      setState(() {
        _status = r;
        _session = rewardMap(r['session']);
      });
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_title),
      actions: [
        if (_playing && !_finished)
          IconButton(
            tooltip: 'Koleksiyonu incele',
            onPressed: _busy
                ? null
                : () => setState(() {
                    _showHub = true;
                    _archive = true;
                  }),
            icon: const Icon(Icons.collections_bookmark_outlined),
          ),
        IconButton(
          tooltip: 'Yenile',
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: PitchPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        TextButton(
                          onPressed: _busy ? null : _load,
                          child: const Text('Yenile / bekleyen işlemi tamamla'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_playing) ..._game() else if (_status.isNotEmpty) ..._home(),
            ],
          ),
        ),
      ),
    ),
  );

  List<Widget> _home() {
    final entries = _maps(_status['entries']);
    final energy = rewardMap(_status['energy']);
    if (_vault)
      entries.sort((a, b) => '${a['league']}'.compareTo('${b['league']}'));
    final completed = entries
        .where((e) => rewardMap(e['record'])['solved'] == true)
        .length;
    final palette = PitchColors.of(context);
    final unit = _vault ? 'kasa' : 'harf';
    final stars = entries.fold<int>(
      0,
      (n, e) => n + ((rewardMap(e['record'])['best'] as num?) ?? 0).toInt(),
    );
    final stats = [
      HubStatTile(
        label: 'Koleksiyon',
        value: '$completed / ${entries.length}',
        note: '$unit tamamlandı',
      ),
      if (_vault)
        HubStatTile(
          label: 'Kasa ustalığı',
          value: '$stars / ${entries.length * 5}',
          note: 'toplam yıldız',
        ),
      if (energy.isNotEmpty)
        energy['enabled'] == true
            ? HubStatTile(
                label: 'Enerji',
                value: '${energy['available']} / ${energy['capacity']}',
                note: 'yeni oyun 1 enerji',
              )
            : const HubStatTile(
                label: 'Enerji',
                value: '—',
                note: 'sistem kapalı · ücretsiz',
              ),
    ];
    return [
      HubHeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: HubIconBox(
                _vault ? Icons.lock_open_rounded : Icons.abc_rounded,
                size: 52,
                background: palette.background.withValues(alpha: .4),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _vault ? 'Üç bayrak. Bir kulüp.' : 'Bir harf, senin ilk 11’in.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _vault
                  ? 'Farklı dönemlerde aynı kulüpte oynamış 11 futbolcu. Üç bayraktan kulübü bul; beş tahmin hakkın var.'
                  : 'Adı, soyadı veya bilinen lakabı verilen harfle başlayan futbolcularla kadronu kur.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palette.muted),
            ),
            const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, tile) in stats.indexed) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: tile),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            const HubSpecNote(
              'Yeni oyun: enerji sistemi açıkken 1 enerji. Devam etmek ve arşivi incelemek ücretsiz.',
            ),
            const SizedBox(height: 6),
            const HubSpecNote(
              'Her oyunda 1 ücretsiz + en fazla 2 reklamlı ipucu. İpucunu kullanmak ustalığı/yıldızı etkiler.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (_session.isNotEmpty && !_finished) ...[
        PitchAction(
          label: 'Kayıtlı oyuna devam et · ücretsiz',
          onPressed: _busy ? null : () => setState(() => _showHub = false),
        ),
        const Text('Yeni bir oyun başlatmadan önce mevcut oturumu bitir.'),
        const SizedBox(height: 12),
      ],
      if (!_vault) ...[
        // Formations stay chips: "4-2-3-1" would break mid-label in a
        // five-way segmented control at 320 px.
        Text('FORMASYON', style: hubCaps(context)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['433', '442', '352', '4231', '451']
              .map(
                (f) => ChoiceChip(
                  label: Text(_formation(f)),
                  selected: _form == f,
                  onSelected: _busy ? null : (_) => setState(() => _form = f),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        HubSegmented<String>(
          label: 'Zorluk',
          options: {
            '': 'Karışık',
            'easy': 'Kolay',
            'medium': 'Orta',
            'hard': 'Zor',
          },
          value: _difficulty,
          onChanged: _busy ? null : (v) => setState(() => _difficulty = v),
        ),
        const SizedBox(height: 8),
        const Text(
          'Günün resmi denemesinde en az 8 oyuncu (orta harfte 7): +10 coin ve +20 XP, günde bir kez. '
          'Ş, İ, Ç gibi zor harfler günün harfi olmaz; rulet önce ustalaşmadığın harfleri getirir.',
        ),
      ],
      if (_vault) ...[
        HubSegmented<String>(
          label: 'Zorluk',
          options: const {
            '': 'Karışık',
            'easy': 'Kolay',
            'medium': 'Orta',
            'hard': 'Zor',
          },
          value: _difficulty,
          onChanged: _busy ? null : (v) => setState(() => _difficulty = v),
        ),
        const SizedBox(height: 8),
        const Text(
          'Zorluk, kadrodaki oyuncuların ne kadar tanındığına göre. Rastgele kasa önce henüz çözmediğin kulüpleri getirir.',
        ),
        const SizedBox(height: 4),
        const Text(
          'Günün kasasını açarsan: +10 coin ve +20 XP, günde bir kez.',
        ),
      ],
      const SizedBox(height: 12),
      PitchAction(
        label: _vault ? 'Rastgele kasa aç' : 'Harf ruleti',
        icon: Icons.shuffle_rounded,
        onPressed: !_canStart ? null : () => _start('random'),
      ),
      ...[
        const SizedBox(height: 8),
        PitchAction(
          label:
              '${_vault ? 'Günün kasası' : 'Günün harfi'} · ${_status['dailyUsed'] == true ? 'Tekrar oyna' : 'Ücretsiz'}',
          secondary: true,
          icon: Icons.today_rounded,
          onPressed: !_canStart || _status['dailyUnavailable'] == true
              ? null
              : () => _start('daily'),
        ),
        if (_status['dailyUnavailable'] == true)
          const Text(
            'Günlük içerik güncelleniyor; yarın yeniden açılacak. Rulet ve koleksiyon kullanılabilir.',
          ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Günlük hedef ve formasyon herkes için aynı. İstanbul saatine göre gece yarısında yenilenir.',
          ),
        ),
      ],
      const SizedBox(height: 16),
      PitchRow(
        title: _vault ? 'Kasa arşivi ve ligler' : 'Harf Pasaportu',
        subtitle: 'En iyi kadrolar ve kalıcı başarılar',
        icon: Icons.collections_bookmark_outlined,
        onTap: () => setState(() => _archive = !_archive),
        trailing: Icon(_archive ? Icons.expand_less : Icons.expand_more),
      ),
      if (_archive) ...[
        if (_vault) ...[
          const PitchSectionTitle('Lig kasaları'),
          Text(
            'Ligler veri sürümüne aittir: ${_status['leagueSnapshot']}. Lig bilindiği için en fazla 4 yıldız.',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entries
                .map((e) => '${e['league']}')
                .toSet()
                .map(
                  (league) => ActionChip(
                    label: Text(
                      '$league · ${entries.where((e) => e['league'] == league && rewardMap(e['record'])['solved'] == true).length}/${entries.where((e) => e['league'] == league).length}',
                    ),
                    onPressed: !_canStart
                        ? null
                        : () => _start('league', league: league),
                  ),
                )
                .toList(),
          ),
        ],
        PitchSectionTitle(_vault ? 'Kulüpler' : 'Koleksiyon'),
        if (!_vault) ...[_passport(entries), const SizedBox(height: 12)],
        Text(
          _vault
              ? '1 / 3 / 5 yıldız ödülleri bir kez kazanılır: toplam 25 coin + 50 XP. İlk 5 farklı kasa: +30 coin + 50 XP.'
              : '5 / 8 / 11 oyuncu ve ustalık madalyaları: toplam 40 coin + 80 XP. Ustalık: 11 oyuncu, sıfır ipucu, en fazla 3 yanlış.',
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < entries.length; i++) ...[
          if (_vault &&
              (i == 0 || entries[i - 1]['league'] != entries[i]['league']))
            PitchSectionTitle('${entries[i]['league']}'),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _entry(entries[i]),
          ),
        ],
      ],
      if (_status['linked'] != true)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'Misafir ilerlemen saklanır. Coin ve XP ödüllerini almak için aynı hesabı Google’a bağla.',
          ),
        ),
    ];
  }

  Widget _entry(Map<String, dynamic> e) {
    final r = rewardMap(e['record']);
    return PitchRow(
      title: '${e['name']}',
      icon: _vault ? Icons.shield_outlined : Icons.military_tech_outlined,
      leading: _vault && r['solved'] == true ? _clubBadge(e) : null,
      subtitle: _vault
          ? '${e['league']} · ${r['best'] ?? 0} yıldız'
          : [
              ?_levels['${e['difficulty']}'],
              '${r['best'] ?? 0}/11',
              _medal(r),
              _nextMedal(r),
            ].join(' · '),
      onTap: _busy ? null : () => _showEntry(e),
    );
  }

  /// Harf Pasaportu: letters completed with all eleven and the next reward.
  Widget _passport(List<Map<String, dynamic>> entries) {
    final p = PitchColors.of(context);
    final done = entries
        .where((e) => ((rewardMap(e['record'])['best'] as num?) ?? 0) >= 11)
        .length;
    final milestones = _maps(_status['passport']);
    final next = milestones
        .where((m) => m['claimed'] != true && (m['at'] as num) > done)
        .firstOrNull;
    return PitchPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('HARF PASAPORTU', style: hubCaps(context)),
          const SizedBox(height: 6),
          Text(
            '$done / ${entries.length} harf tamamlandı',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: entries.isEmpty ? 0 : done / entries.length,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            backgroundColor: p.raised,
          ),
          const SizedBox(height: 8),
          Text(
            next == null
                ? 'Tüm pasaport ödüllerini aldın.'
                : 'Sıradaki ödül ${next['at']} harfte: +${next['coins']} coin, +${next['xp']} XP',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in entries)
                Semantics(
                  label:
                      '${e['letter'] ?? e['name']} ${((rewardMap(e['record'])['best'] as num?) ?? 0) >= 11 ? 'tamamlandı' : 'açık'}',
                  excludeSemantics: true,
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          ((rewardMap(e['record'])['best'] as num?) ?? 0) >= 11
                          ? p.accent.withValues(alpha: .22)
                          : p.raised,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${e['letter'] ?? e['name']}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color:
                            ((rewardMap(e['record'])['best'] as num?) ?? 0) >=
                                11
                            ? p.accent
                            : p.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _clubBadge(Map<String, dynamic> c) => ClubBadge(
    club: Club(
      id: int.tryParse('${c['id']}') ?? 0,
      name: '${c['name']}',
      league: '${c['league'] ?? ''}',
      country: '${c['country'] ?? ''}',
      badgeKey: c['badgeKey'] as String?,
    ),
  );

  Future<void> _showEntry(Map<String, dynamic> e) async {
    final r = rewardMap(e['record']);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_vault && r['solved'] == true) _clubBadge(e),
              Text(
                '${e['name']}',
                style: Theme.of(ctx).textTheme.headlineSmall,
              ),
              Text(
                _vault
                    ? 'En iyi: ${r['best'] ?? 0} yıldız'
                    : 'En iyi: ${r['best'] ?? 0}/11 · ${r['mastery'] == true ? 'Ustalık' : 'Geliştirilebilir'}',
              ),
              if (!_vault) Text('${_medal(r)} · ${_nextMedal(r)}'),
              if (!_vault)
                Text(
                  'Oynanabilir düzenler: ${_strings(e['formations']).map(_formation).join(' / ')}',
                ),
              if (r['bestFormation'] != null)
                Text(_formation('${r['bestFormation']}')),
              for (final p in _maps(r['bestLineup']))
                if (p.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${p['name']} · ${_positions[p['position']] ?? p['position']} · ${p['country']}',
                    ),
                  ),
              if (r['lastLineup'] != null)
                ExpansionTile(
                  title: const Text('Son kadron'),
                  children: [
                    for (final p in _maps(r['lastLineup']))
                      if (p.isNotEmpty)
                        ListTile(
                          dense: true,
                          title: Text('${p['name']}'),
                          subtitle: Text(
                            '${p['country']} · ${_positions[p['position']]}',
                          ),
                        ),
                  ],
                ),
              const SizedBox(height: 16),
              if (!_vault || r['solved'] == true)
                PitchAction(
                  label: 'Bu hedefle oyna',
                  onPressed: _canStart
                      ? () => Navigator.pop(ctx, 'play')
                      : null,
                ),
              if (_vault && r['solved'] != true)
                const Text(
                  'Kulübü rastgele veya lig kasasında çözerek arşivde aç.',
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result == 'play') await _start('archive', target: '${e['id']}');
  }

  List<Widget> _game() {
    final slots = _maps(_session['slots']);
    return [
      PitchPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_vault && _session['club'] is Map)
              _clubBadge(rewardMap(_session['club'])),
            Text(
              '${_session['title']}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if ('${_session['context'] ?? ''}'.isNotEmpty)
              Text('${_session['context']}'),
            if (_vault) Text('${_session['historyNote']}'),
            if (_session['league'] != null) Text('${_session['league']}'),
            if (_vault && !_finished) ...[
              const SizedBox(height: 10),
              _starMeter((_session['stars'] as num? ?? 0).toInt()),
            ],
            const SizedBox(height: 10),
            Text(
              _vault
                  ? _finished
                        ? '${_session['remaining']} tahmin · ${_session['stars']} yıldız'
                        : '${_session['remaining']} tahmin hakkı kaldı'
                  : '${_session['score']}/11 oyuncu · ${_session['wrong']} yanlış',
            ),
            Text(
              '${_maps(_session['hints']).length} ipucu kullanıldı · ${_formation('${_session['formation']}')}',
            ),
            if (!_vault)
              const Text('Ustalık: 11/11 · ipucusuz · en fazla 3 yanlış'),
            if (_session['entry'] == 'daily')
              Text(
                _session['dailyOfficial'] == true
                    ? 'Bugünün resmi denemesi'
                    : 'Günlük tekrar',
              ),
            if (_session['energyCharged'] == true)
              const Text(
                'Bu oturum için 1 enerji kullanıldı. Devam etmek ücretsiz.',
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (!_vault && !_finished && _session['entry'] != 'daily')
        Wrap(
          spacing: 8,
          children: _strings(_session['formations'])
              .map(
                (f) => ChoiceChip(
                  label: Text(_formation(f)),
                  selected: _session['formation'] == f,
                  onSelected: _busy ? null : (_) => _changeFormation(f),
                ),
              )
              .toList(),
        ),
      const SizedBox(height: 8),
      _pitch(slots),
      if ('${_session['feedback'] ?? ''}'.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Semantics(
            liveRegion: true,
            child: Text(
              '${_session['feedback']}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ),
      if (!_finished) ...[
        if (!_vault)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              'Seçili mevki: ${_positions[slots[_slot]['position']]} · ${_slot + 1}',
            ),
          ),
        TextField(
          controller: _query,
          enabled: !_busy,
          onChanged: _search,
          decoration: InputDecoration(
            labelText: _vault ? 'Kulüp ara ve seç' : 'Futbolcu ara ve seç',
            prefixIcon: const Icon(Icons.search),
            helperText: 'En az 2 harf. Bulunamayan isim yanlış sayılmaz.',
          ),
        ),
        if (_searching) const LinearProgressIndicator(),
        if (!_searching && _query.text.length >= 2 && _results.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Eşleşen kimlik bulunamadı. Farklı bir yazım dene.'),
          ),
        for (final p in _results)
          ListTile(
            title: Text('${p['name']}'),
            subtitle: Text(
              _vault
                  ? '${p['country']} · ${p['league'] ?? ''}'
                  : '${p['country']} · ${_positions[p['position']] ?? 'Mevki bilinmiyor'}',
            ),
            onTap: _busy
                ? null
                : () => _act(
                    _vault ? 'guess' : 'place',
                    _vault
                        ? {'clubId': p['id']}
                        : {'slot': _slot, 'playerId': p['id']},
                  ),
          ),
        if (!_vault && slots[_slot]['player'] != null)
          TextButton.icon(
            onPressed: _busy ? null : () => _act('clear', {'slot': _slot}),
            icon: const Icon(Icons.backspace_outlined),
            label: const Text('Seçili oyuncuyu kaldır'),
          ),
        const PitchSectionTitle('İpuçları'),
        if (hintEntry(_session, target: _slot, disabled: _busy,
            send: (p) => _act('hint', {'slot': _slot, ...p}),
            watch: (id) => _watch(itemId: id)) case final w?)
          w
        else if (rewardMap(_session['support'])['version'] == 1) ...[
          for (final h
              in (_vault
                      ? {
                          'flag': 'Bayrak −1★',
                          'league': 'Lig −1★',
                          'player': 'Oyuncu −2★',
                        }
                      : const {
                          'country': 'Ülke',
                          'club': 'Kulüp',
                          'league': 'Lig',
                          'shape': 'İsim kalıbı',
                        })
                  .entries)
            PaidHintButton(
              session: _session,
              sku: _vault && h.key == 'player'
                  ? 'boost_strong'
                  : ['club', 'years'].contains(h.key)
                  ? 'boost_connection'
                  : 'boost_basic',
              label: h.value,
              disabled:
                  _busy ||
                  _maps(_session['hints']).length >= 3 ||
                  (_vault && h.key == 'league' && _session['league'] != null),
              onUse: (payment) =>
                  _act('hint', {'hint': h.key, 'slot': _slot, ...payment}),
              onWatch: () => _watch(
                boostId: _vault && h.key == 'player'
                    ? 'boost_strong'
                    : ['club', 'years'].contains(h.key)
                    ? 'boost_connection'
                    : 'boost_basic',
              ),
            ),
        ] else ...[
          Text(
            _session['freeHint'] == true
                ? '1 ücretsiz ipucun hazır.'
                : '${_session['adCredits']} reklamlı ipucun hazır.',
          ),
          Wrap(
            spacing: 8,
            children:
                (_vault
                        ? {
                            'flag': 'Bayrak −1★',
                            'league': 'Lig −1★',
                            'player': 'Oyuncu −2★',
                          }
                        : const {
                            'country': 'Ülke',
                            'club': 'Kulüp',
                            'league': 'Lig',
                            'shape': 'İsim kalıbı',
                          })
                    .entries
                    .map(
                      (h) => ActionChip(
                        label: Text(h.value),
                        onPressed:
                            _busy ||
                                (_session['freeHint'] != true &&
                                    (_session['adCredits'] as num? ?? 0) ==
                                        0) ||
                                (_vault &&
                                    h.key == 'league' &&
                                    _session['league'] != null)
                            ? null
                            : () =>
                                  _act('hint', {'hint': h.key, 'slot': _slot}),
                      ),
                    )
                    .toList(),
          ),
          if ((_session['adRemaining'] as num? ?? 0) > 0)
            TextButton.icon(
              onPressed: _busy ? null : _watch,
              icon: const Icon(Icons.play_circle_outline),
              label: Text(
                'Reklamla ipucu hakkı al · ${_session['adRemaining']} kaldı',
              ),
            ),
        ],
        const Text(
          'Reklam izlemek yalnızca hak kazandırır. İpucunu kullanmadıkça ustalık etkilenmez.',
        ),
        const SizedBox(height: 16),
        PitchAction(
          label: !_vault && _session['score'] == 11
              ? 'Kadroyu tamamla'
              : 'Erken bitir',
          secondary: _vault || _session['score'] != 11,
          onPressed: _busy ? null : _finish,
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Geri çıkabilirsin; oyun sunucuda saklanır. Normal oyun 24 saat, günlük oyun gece yarısına kadar devam eder.',
          ),
        ),
      ] else
        ..._result(),
    ];
  }

  Widget _pitch(List<Map<String, dynamic>> slots) {
    final rows = _session['formation'] == '4231'
        ? [
            ['FWD', 0, 0],
            ['MID', 1, 3],
            ['MID', 4, 5],
            ['DEF', 6, 9],
            ['GK', 10, 10],
          ]
        : [
            ['FWD', 0, 10],
            ['MID', 0, 10],
            ['DEF', 0, 10],
            ['GK', 0, 10],
          ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xff103b34),
        border: Border.all(color: const Color(0xff4d8376)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final line = slots
                      .where(
                        (s) =>
                            s['position'] == row[0] &&
                            (s['slot'] as num) >= (row[1] as int) &&
                            (s['slot'] as num) <= (row[2] as int),
                      )
                      .toList();
                  // Preserve the formation at ordinary type sizes; wrap for accessibility.
                  final width = MediaQuery.textScalerOf(context).scale(1) > 1.4
                      ? 130.0
                      : ((constraints.maxWidth - 6 * (line.length - 1)) /
                                line.length)
                            .clamp(48.0, 106.0)
                            .toDouble();
                  return Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 8,
                    children: line.map((s) {
                      final player = rewardMap(s['player']);
                      final country =
                          '${s['country'] ?? player['country'] ?? ''}';
                      final chosen =
                          !_vault && !_finished && s['slot'] == _slot;
                      return SizedBox(
                        width: width,
                        child: Material(
                          color: chosen
                              ? const Color(0xffd3f27c)
                              : const Color(0xff1b5146),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: _busy || _vault || _finished
                                ? null
                                : () => setState(() {
                                    _slot = (s['slot'] as num).toInt();
                                  }),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                children: [
                                  Text(
                                    _positions[row[0]]!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: chosen
                                          ? Colors.black87
                                          : Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (country.isNotEmpty)
                                    Semantics(
                                      label: country,
                                      child: ExcludeSemantics(
                                        child: Text(
                                          flagFor(country),
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontFamily: 'Noto Color Emoji',
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (_vault &&
                                      country.isEmpty &&
                                      player.isEmpty)
                                    const Icon(
                                      Icons.lock_outline_rounded,
                                      color: Colors.white70,
                                      size: 24,
                                    )
                                  else
                                    Text(
                                      player.isNotEmpty
                                          ? '${player['name']}'
                                          : _vault
                                          ? country
                                          : '+ Seç',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: chosen
                                            ? Colors.black
                                            : Colors.white,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Stars still available in this vault; each wrong guess or hint costs.
  Widget _starMeter(int stars) {
    final amber = hubAmber(context);
    final level = _levels['${_session['difficulty']}'];
    return Semantics(
      label: '$stars yıldız kaldı',
      excludeSemantics: true,
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 5; i++)
                Icon(
                  i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: i < stars ? amber : PitchColors.of(context).muted,
                  size: 22,
                ),
            ],
          ),
          if (level != null)
            HubPill(
              level,
              color: amber,
              background: amber.withValues(alpha: .14),
            ),
          Text(
            'Yanlış tahmin ve ipucu yıldız düşürür. Ödül için en az 1 yıldızla aç.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  List<Widget> _result() {
    final r = rewardMap(_session['result']);
    final medals = _vault
        ? const <String>[]
        : _strings(r['newMedals'])
              .map(
                (m) =>
                    {
                      '1': 'Bronz',
                      '2': 'Gümüş',
                      '3': 'Altın',
                      '4': 'Ustalık',
                    }[m] ??
                    m,
              )
              .toList();
    final score = (r['score'] as num? ?? 0).toInt();
    return [
      const SizedBox(height: 8),
      HubResultCard(
        tone: r['mastery'] == true || medals.isNotEmpty
            ? HubResultTone.gold
            : score > 0
            ? HubResultTone.good
            : HubResultTone.neutral,
        icon: r['mastery'] == true || medals.isNotEmpty
            ? Icons.military_tech_rounded
            : _vault
            ? Icons.lock_open_rounded
            : Icons.groups_rounded,
        kicker: 'Oyun tamamlandı',
        title: _vault
            ? _session['won'] == true
                  ? '$score yıldız'
                  : 'Kasa açılmadı'
            : r['mastery'] == true
            ? 'Ustalık kazandın!'
            : '$score/11 kadro',
        subtitle: medals.isEmpty
            ? null
            : '${medals.length == 1 ? 'Yeni madalya' : 'Yeni madalyalar'}: ${medals.join(', ')}',
        coins: (r['coins'] as num?)?.toInt(),
        xp: (r['xp'] as num?)?.toInt(),
        notes: [
          if (r['passport'] != null)
            'Harf Pasaportu: ${r['passport'] == 'all' ? 'tüm harfler' : '${r['passport']} harf'} tamamlandı!',
          if (_vault && _session['won'] == true && score == 0)
            'Kasayı açtın ama yıldızın kalmadı; ödül için en az 1 yıldız gerekir.',
          _vault
              ? 'Aynı kulübün yıldız ödülleri tüm kasa çeşitlerinde ortaktır.'
              : 'Aynı hedefin madalyaları rulet, günlük ve arşivde ortaktır.',
          if (_status['linked'] != true)
            'Ödüllerin bekliyor. Aynı misafir hesabını Google’a bağlayınca aktarılır.',
        ],
      ),
      const SizedBox(height: 12),
      ShareResultButtons(
        text: _vault ? vaultShare(_session) : letterShare(_session),
      ),
      const SizedBox(height: 16),
      PitchAction(
        label: 'Koleksiyona dön',
        onPressed: _busy
            ? null
            : () async {
                await _load();
                if (mounted) setState(() => _archive = true);
              },
      ),
    ];
  }
}
