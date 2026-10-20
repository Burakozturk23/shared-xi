import 'dart:async';
import '../app/route_appearance.dart';
import 'coach_honours_page.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../data/country_flags.dart';
import '../models/coach.dart';
import '../models/club.dart';
import '../widgets/club_badge.dart';
import '../models/rewarded_ad_models.dart';
import '../services/three_modes_service.dart';
import '../widgets/coach_avatar.dart';
import '../widgets/pitch_ui.dart';

List<Map<String, dynamic>> _maps(dynamic v) =>
    (v is List ? v : const []).map(rewardMap).toList();
List<String> _strings(dynamic v) => (v is List ? v : const []).map((x) => '$x').toList();
String _medal(Map<String, dynamic> r) => r['mastery'] == true ? 'Ustalık' :
    (r['best'] as num? ?? 0) >= 11 ? 'Altın' : (r['best'] as num? ?? 0) >= 8 ? 'Gümüş' :
    (r['best'] as num? ?? 0) >= 5 ? 'Bronz' : 'Madalyanı kazan';
String _nextMedal(Map<String, dynamic> r) => r['mastery'] == true ? 'Tüm madalyalar tamam' :
    (r['best'] as num? ?? 0) >= 11 ? 'Sıradaki: ipucusuz ustalık' :
    (r['best'] as num? ?? 0) >= 8 ? 'Sıradaki: 11 oyuncu' :
    (r['best'] as num? ?? 0) >= 5 ? 'Sıradaki: 8 oyuncu' : 'Sıradaki: 5 oyuncu';
String _formation(String v) => v.split('').join('-');
const _positions = {'GK': 'Kaleci', 'DEF': 'Defans', 'MID': 'Orta saha', 'FWD': 'Hücum'};

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
  bool get _coach => widget.mode == 'coach_xi';
  String get _title => _vault ? 'Kadro Kasası' : _coach ? 'Hoca 11' : 'Harf 11';
  String get _version => '${_status['version']}';
  bool get _finished => _session['finished'] == true;
  bool get _playing => _session.isNotEmpty && !_showHub;
  bool get _canStart => !_busy && (_session.isEmpty || _finished);
  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _debounce?.cancel(); _query.dispose(); super.dispose(); }

  Future<void> _run(Future<void> Function() body) async {
    if (mounted) setState(() { _busy = true; _error = null; });
    try { await body(); }
    catch (e) {
      if (mounted) setState(() => _error = e is FirebaseFunctionsException
          ? e.message ?? 'Bağlantı kurulamadı. Yenile ile tekrar dene.'
          : e.toString().replaceFirst('Bad state: ', ''));
    } finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _load() => _run(() async {
    final status = await _service.load(widget.mode);
    if (!mounted) return;
    setState(() { _status = status; _session = rewardMap(status['session']); });
  });
  void _clearSearch() { _generation++; _debounce?.cancel(); _query.clear(); _results = []; _searching = false; }
  Future<void> _start(String entry, {String? target, String? league}) => _run(() async {
    final r = await _service.mutate('startThreeMode', {'mode': widget.mode, 'version': _version,
      'entry': entry, 'formation': _form, if (_difficulty.isNotEmpty) 'difficulty': _difficulty,
      if (target != null) 'target': target, if (league != null) 'league': league});
    if (!mounted) return;
    setState(() { _session = rewardMap(r['session']); _archive = false; _showHub = false; _slot = 0; _clearSearch(); });
  });
  Future<void> _act(String action, [Map<String, dynamic> extra = const {}]) => _run(() async {
    final r = await _service.mutate('actThreeMode', {'mode': widget.mode, 'version': _version,
      'sessionId': _session['id'], 'revision': _session['revision'], 'action': action, ...extra});
    if (!mounted) return;
    setState(() {
      _session = rewardMap(r['session']); _clearSearch();
      if (!_vault && action == 'place') {
        final empty = _maps(_session['slots']).where((s) => s['player'] == null).toList();
        if (empty.isNotEmpty) _slot = (empty.first['slot'] as num).toInt();
      }
      if (r.containsKey('linked')) _status['linked'] = r['linked'];
    });
  });
  void _search(String value) {
    _debounce?.cancel(); final generation = ++_generation;
    setState(() { _results = []; _searching = value.trim().length >= 2; });
    if (!_searching) return;
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final r = await _service.search({'mode': widget.mode, 'version': _version, 'query': value});
        if (mounted && generation == _generation) setState(() { _results = _maps(r['results']); _searching = false; });
      } catch (_) {
        if (mounted && generation == _generation) setState(() {
          _searching = false; _error = 'Arama tamamlanmadı. Yanlış hakkın değişmedi; tekrar ara.';
        });
      }
    });
  }
  Future<bool> _confirm(String title, String message) async => await showDialog<bool>(
    context: context, builder: (ctx) => AlertDialog(title: Text(title), content: Text(message), actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Onayla')),
    ]),
  ) ?? false;
  Future<void> _changeFormation(String form) async {
    if (form == _session['formation']) return;
    if ((_session['score'] as num? ?? 0) > 0 && !await _confirm('Kadroyu sıfırla?',
        'Formasyon değişince yerleştirdiğin oyuncular silinir. Yanlış ve kullanılan ipuçları korunur.')) return;
    if (mounted) await _act('formation', {'formation': form, 'confirmReset': true});
  }
  Future<void> _finish() async {
    if (!_vault && _session['score'] == 11 || await _confirm('Oyunu bitir?',
        _vault ? 'Kasa açılır ve bu oyun için yıldız kazanamazsın.' : 'Mevcut kadron kaydedilir. Eksik kadroyu daha sonra yeni oyunda geliştirebilirsin.')) {
      if (mounted) await _act('finish');
    }
  }
  Future<void> _watch() => _run(() async {
    await _service.watchHint(widget.mode, '${_session['id']}');
    final r = await _service.load(widget.mode);
    if (mounted) setState(() { _status = r; _session = rewardMap(r['session']); });
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_title), actions: [
      if (_coach) IconButton(tooltip: 'Hoca başarı arşivi', icon: const Icon(Icons.emoji_events_outlined),
        onPressed: () => Navigator.of(context).push(LinkballRoute<void>(builder: (_) => const CoachHonoursPage()))),
      if (_playing && !_finished) IconButton(tooltip: 'Koleksiyonu incele', onPressed: _busy ? null :
        () => setState(() { _showHub = true; _archive = true; }), icon: const Icon(Icons.collections_bookmark_outlined)),
      IconButton(tooltip: 'Yenile',
      onPressed: _busy ? null : _load, icon: const Icon(Icons.refresh_rounded))]),
    body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640),
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: PitchPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            TextButton(onPressed: _busy ? null : _load, child: const Text('Yenile / bekleyen işlemi tamamla')),
          ]))),
        if (_playing) ..._game() else if (_status.isNotEmpty) ..._home(),
      ]),
    ))),
  );

  List<Widget> _home() {
    final entries = _maps(_status['entries']);
    final energy = rewardMap(_status['energy']);
    if (_vault) entries.sort((a, b) => '${a['league']}'.compareTo('${b['league']}'));
    final completed = entries.where((e) => rewardMap(e['record'])['solved'] == true).length;
    return [
      PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(_vault ? Icons.lock_open_rounded : _coach ? Icons.sports_rounded : Icons.abc_rounded, size: 40),
        const SizedBox(height: 12),
        Text(_vault ? 'Üç bayrak. Bir kulüp.' : _coach ? 'Bir hoca, senin ilk 11’in.' : 'Bir harf, senin ilk 11’in.',
          style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(_vault ? 'Farklı dönemlerde aynı kulüpte oynamış 11 futbolcu. Üç bayraktan kulübü bul; beş tahmin hakkın var.'
          : _coach ? 'Hocasıyla gerçekten çalışmış futbolculardan kadronu kur. Doğrulanamayan bağlar yanlış sayılmaz.'
          : 'Adı, soyadı veya bilinen lakabı verilen harfle başlayan futbolcularla kadronu kur.'),
        const SizedBox(height: 12),
        if (energy.isNotEmpty) Text(energy['enabled'] == true
          ? 'Enerji: ${energy['available']} / ${energy['capacity']}' : 'Enerji sistemi şu anda kapalı · ücretsiz oyun'),
        Text('$completed / ${entries.length} ${_vault ? 'kasa' : _coach ? 'hoca' : 'harf'} koleksiyonunda'),
        const SizedBox(height: 8),
        const Text('Yeni oyun: enerji sistemi açıkken 1 enerji. Devam etmek ve arşivi incelemek ücretsiz.'),
        const Text('Her oyunda 1 ücretsiz + en fazla 2 reklamlı ipucu. İpucunu kullanmak ustalığı/yıldızı etkiler.'),
      ])),
      const SizedBox(height: 16),
      if (_session.isNotEmpty && !_finished) ...[
        PitchAction(label: 'Kayıtlı oyuna devam et · ücretsiz', onPressed: _busy ? null :
          () => setState(() => _showHub = false)),
        const Text('Yeni bir oyun başlatmadan önce mevcut oturumu bitir.'),
        const SizedBox(height: 12),
      ],
      if (!_vault) ...[
        Wrap(spacing: 8, runSpacing: 8, children: ['433', '442', '352', '4231', '451'].map((f) => ChoiceChip(
          label: Text(_formation(f)), selected: _form == f,
          onSelected: _busy ? null : (_) => setState(() => _form = f))).toList()),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: {'': 'Karışık', 'easy': 'Kolay', 'medium': 'Orta', if (!_coach) 'hard': 'Zor'}
          .entries.map((d) => ChoiceChip(label: Text(d.value), selected: _difficulty == d.key,
            onSelected: _busy ? null : (_) => setState(() => _difficulty = d.key))).toList()),
        if (!_coach) const Text('Günün resmi denemesinde en az 8 oyuncu: +10 coin ve +20 XP, günde bir kez.'),
        if (_coach) const Padding(padding: EdgeInsets.only(top: 8),
          child: Text('7 hoca için maç kaynakları doğrulandı. Dönem kısıtlı zor seviye henüz açık değil.')),
      ],
      const SizedBox(height: 12),
      PitchAction(label: _vault ? 'Rastgele kasa aç' : _coach ? 'Hoca ruleti' : 'Harf ruleti',
        icon: Icons.shuffle_rounded, onPressed: !_canStart ? null : () => _start('random')),
      if (!_vault) ...[
        const SizedBox(height: 8),
        PitchAction(label: '${_coach ? 'Günün hocası' : 'Günün harfi'} · ${_status['dailyUsed'] == true ? 'Tekrar oyna' : 'Ücretsiz'}',
          secondary: true, icon: Icons.today_rounded, onPressed: !_canStart || _status['dailyUnavailable'] == true ? null : () => _start('daily')),
        if (_status['dailyUnavailable'] == true) const Text('Günlük içerik güncelleniyor; yarın yeniden açılacak. Rulet ve koleksiyon kullanılabilir.'),
        const Padding(padding: EdgeInsets.only(top: 8), child: Text('Günlük hedef ve formasyon herkes için aynı. İstanbul saatine göre gece yarısında yenilenir.')),
      ],
      const SizedBox(height: 16),
      if (_coach) ...[
        PitchRow(title: 'Hoca başarı arşivi', subtitle: 'Tarihsel kupalar, ödüller ve hoca profilleri',
          icon: Icons.emoji_events_outlined, onTap: () => Navigator.of(context).push(
            LinkballRoute<void>(builder: (_) => const CoachHonoursPage()))),
        const SizedBox(height: 12),
      ],
      PitchRow(title: _vault ? 'Kasa arşivi ve ligler' : _coach ? 'Hoca koleksiyonu' : 'Harf Pasaportu',
        subtitle: 'En iyi kadrolar ve kalıcı başarılar', icon: Icons.collections_bookmark_outlined,
        onTap: () => setState(() => _archive = !_archive),
        trailing: Icon(_archive ? Icons.expand_less : Icons.expand_more)),
      if (_archive) ...[
        if (_vault) ...[
          const PitchSectionTitle('Lig kasaları'),
          Text('Ligler veri sürümüne aittir: ${_status['leagueSnapshot']}. Lig bilindiği için en fazla 4 yıldız.'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: entries.map((e) => '${e['league']}').toSet().map((league) =>
            ActionChip(label: Text('$league · ${entries.where((e) => e['league'] == league && rewardMap(e['record'])['solved'] == true).length}/${entries.where((e) => e['league'] == league).length}'), onPressed: !_canStart ? null : () => _start('league', league: league))).toList()),
        ],
        PitchSectionTitle(_vault ? 'Kulüpler' : 'Koleksiyon'),
        Text(_vault ? '1 / 3 / 5 yıldız ödülleri bir kez kazanılır: toplam 25 coin + 50 XP. İlk 5 farklı kasa: +30 coin + 50 XP.'
          : '5 / 8 / 11 oyuncu ve ustalık madalyaları: toplam 40 coin + 80 XP. Ustalık: 11 oyuncu, sıfır ipucu, en fazla 3 yanlış.'),
        const SizedBox(height: 12),
        for (var i = 0; i < entries.length; i++) ...[
          if (_vault && (i == 0 || entries[i - 1]['league'] != entries[i]['league'])) PitchSectionTitle('${entries[i]['league']}'),
          Padding(padding: const EdgeInsets.only(bottom: 8), child: _entry(entries[i])),
        ],
      ],
      if (_status['linked'] != true) const Padding(padding: EdgeInsets.only(top: 12),
        child: Text('Misafir ilerlemen saklanır. Coin ve XP ödüllerini almak için aynı hesabı Google’a bağla.')),
    ];
  }

  Widget _entry(Map<String, dynamic> e) {
    final r = rewardMap(e['record']);
    return PitchRow(title: '${e['name']}', icon: _vault ? Icons.shield_outlined : Icons.military_tech_outlined,
      leading: _coach ? CoachAvatar(coach: Coach(id: '${e['portraitId'] ?? e['id']}', name: '${e['name']}', countries: const [], clubIds: const [])) :
        _vault && r['solved'] == true ? _clubBadge(e) : null,
      subtitle: _vault ? '${e['league']} · ${r['best'] ?? 0} yıldız' :
        '${r['best'] ?? 0}/11 · ${_medal(r)} · ${_nextMedal(r)}',
      onTap: _busy ? null : () => _showEntry(e),
    );
  }
  Widget _clubBadge(Map<String, dynamic> c) => ClubBadge(club: Club(id: int.tryParse('${c['id']}') ?? 0,
    name: '${c['name']}', league: '${c['league'] ?? ''}', country: '${c['country'] ?? ''}', badgeKey: c['badgeKey'] as String?));

  Future<void> _showEntry(Map<String, dynamic> e) async {
    final r = rewardMap(e['record']);
    final result = await showModalBottomSheet<String>(context: context, isScrollControlled: true,
      showDragHandle: true, builder: (ctx) => SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_vault && r['solved'] == true) _clubBadge(e),
          Text('${e['name']}', style: Theme.of(ctx).textTheme.headlineSmall),
          Text(_vault ? 'En iyi: ${r['best'] ?? 0} yıldız' : 'En iyi: ${r['best'] ?? 0}/11 · ${r['mastery'] == true ? 'Ustalık' : 'Geliştirilebilir'}'),
          if (!_vault) Text('${_medal(r)} · ${_nextMedal(r)}'),
          if (!_vault) Text('Oynanabilir düzenler: ${_strings(e['formations']).map(_formation).join(' / ')}'),
          if (_coach) TextButton.icon(icon: const Icon(Icons.emoji_events_outlined),
            label: const Text('Başarı arşivinde ara'),
            onPressed: () => Navigator.pop(ctx, 'honours')),
          if (_coach && e['avatarId'] != null) Text(e['avatarOwned'] == true ? 'Avatar sende' : 'Avatar kilitli'),
          if (r['bestFormation'] != null) Text(_formation('${r['bestFormation']}')),
          for (final p in _maps(r['bestLineup'])) if (p.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6),
            child: Text('${p['name']} · ${_positions[p['position']] ?? p['position']} · ${p['country']}')),
          if (r['lastLineup'] != null) ExpansionTile(title: const Text('Son kadron'), children: [
            for (final p in _maps(r['lastLineup'])) if (p.isNotEmpty) ListTile(dense: true,
              title: Text('${p['name']}'), subtitle: Text('${p['country']} · ${_positions[p['position']]}')),
          ]),
          if (_coach && _maps(e['bestEvidence']).isNotEmpty) ExpansionTile(title: const Text('Kadro bağlantıları'), children: [
            for (final p in _maps(e['bestEvidence'])) ListTile(title: Text('${p['name']}'),
              subtitle: SelectableText(_maps(p['links']).map((l) => '${l['club']} · ${l['date']}\n${_strings(l['sources']).join('\n')}').join('\n'))),
          ]),
          const SizedBox(height: 16),
          if (!_vault || r['solved'] == true) PitchAction(label: 'Bu hedefle oyna',
            onPressed: _canStart ? () => Navigator.pop(ctx, 'play') : null),
          if (_vault && r['solved'] != true) const Text('Kulübü rastgele veya lig kasasında çözerek arşivde aç.'),
          if (_coach && r['mastery'] == true && e['avatarId'] != null && e['avatarChoice'] == null) ...[
            const SizedBox(height: 16), const Text('Ustalık ödülünü bir kez seç. Avatar zaten sende ise sabit coin karşılığı verilir.'),
            const SizedBox(height: 8),
            PitchAction(label: 'Hoca avatarını al', onPressed: () => Navigator.pop(ctx, 'avatar')),
            const SizedBox(height: 8),
            PitchAction(label: '${e['avatarCoins']} coin seç', secondary: true, onPressed: () => Navigator.pop(ctx, 'coins')),
          ],
          if (e['avatarChoice'] != null) const Text('Özel ustalık ödülü alındı.'),
        ]),
      )));
    if (!mounted || result == null) return;
    if (result == 'honours') {
      await Navigator.of(context).push(LinkballRoute<void>(builder: (_) => CoachHonoursPage(
        initialCoachId: '${e['portraitId'] ?? e['id']}', initialQuery: '${e['name']}')));
    } else if (result == 'play') { await _start('archive', target: '${e['id']}'); }
    else if (await _confirm('Ödül seçimini onayla', 'Bu hedefte tek seferlik seçimin: ${result == 'avatar' ? 'avatar (zaten sahipsen coin)' : '${e['avatarCoins']} coin'}.')) {
      await _run(() async {
        final r = await _service.mutate('claimCoachMastery', {'mode': widget.mode, 'version': _version,
          'target': e['id'], 'choice': result});
        if (mounted) setState(() => _status = r);
      });
    }
  }

  List<Widget> _game() {
    final slots = _maps(_session['slots']);
    return [
      PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_coach) CoachAvatar(coach: Coach(id: '${_session['portraitId'] ?? ''}', name: '${_session['title']}', countries: const [], clubIds: const [])),
        if (_vault && _session['club'] is Map) _clubBadge(rewardMap(_session['club'])),
        Text('${_session['title']}', style: Theme.of(context).textTheme.headlineSmall),
        if ('${_session['context'] ?? ''}'.isNotEmpty) Text('${_session['context']}'),
        if (_vault) Text('${_session['historyNote']}'),
        if (_session['league'] != null) Text('${_session['league']}'),
        const SizedBox(height: 10),
        Text(_vault ? '${_session['remaining']} tahmin · ${_session['stars']} yıldız'
          : '${_session['score']}/11 oyuncu · ${_session['wrong']} yanlış'),
        Text('${_maps(_session['hints']).length} ipucu kullanıldı · ${_formation('${_session['formation']}')}'),
        if (!_vault) const Text('Ustalık: 11/11 · ipucusuz · en fazla 3 yanlış'),
        if (_session['entry'] == 'daily') Text(_session['dailyOfficial'] == true ? 'Bugünün resmi denemesi' : 'Günlük tekrar'),
        if (_session['energyCharged'] == true) const Text('Bu oturum için 1 enerji kullanıldı. Devam etmek ücretsiz.'),
      ])),
      const SizedBox(height: 12),
      if (!_vault && !_finished && _session['entry'] != 'daily') Wrap(spacing: 8, children:
        _strings(_session['formations']).map((f) => ChoiceChip(label: Text(_formation(f)),
          selected: _session['formation'] == f, onSelected: _busy ? null : (_) => _changeFormation(f))).toList()),
      if (_coach) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('${_session['coverage']}')),
      const SizedBox(height: 8),
      _pitch(slots),
      if ('${_session['feedback'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
        child: Semantics(liveRegion: true, child: Text('${_session['feedback']}', style: Theme.of(context).textTheme.titleSmall))),
      if (!_finished) ...[
        if (!_vault) Padding(padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text('Seçili mevki: ${_positions[slots[_slot]['position']]} · ${_slot + 1}')),
        TextField(controller: _query, enabled: !_busy, onChanged: _search,
          decoration: InputDecoration(labelText: _vault ? 'Kulüp ara ve seç' : 'Futbolcu ara ve seç',
            prefixIcon: const Icon(Icons.search), helperText: 'En az 2 harf. Bulunamayan isim yanlış sayılmaz.')),
        if (_searching) const LinearProgressIndicator(),
        if (!_searching && _query.text.length >= 2 && _results.isEmpty)
          const Padding(padding: EdgeInsets.all(8), child: Text('Eşleşen kimlik bulunamadı. Farklı bir yazım dene.')),
        for (final p in _results) ListTile(title: Text('${p['name']}'),
          subtitle: Text(_vault ? '${p['country']} · ${p['league'] ?? ''}' : '${p['country']} · ${_positions[p['position']] ?? 'Mevki bilinmiyor'}'),
          onTap: _busy ? null : () => _act(_vault ? 'guess' : 'place',
            _vault ? {'clubId': p['id']} : {'slot': _slot, 'playerId': p['id']})),
        if (!_vault && slots[_slot]['player'] != null) TextButton.icon(
          onPressed: _busy ? null : () => _act('clear', {'slot': _slot}),
          icon: const Icon(Icons.backspace_outlined), label: const Text('Seçili oyuncuyu kaldır')),
        const PitchSectionTitle('İpuçları'),
        Text(_session['freeHint'] == true ? '1 ücretsiz ipucun hazır.' : '${_session['adCredits']} reklamlı ipucun hazır.'),
        Wrap(spacing: 8, children: (_vault ? {'flag': 'Bayrak −1★', 'league': 'Lig −1★', 'player': 'Oyuncu −2★'}
          : _coach ? {'country': 'Ülke', 'club': 'Kulüp', 'years': 'Yıl'} : {'country': 'Ülke', 'club': 'Kulüp', 'league': 'Lig'})
          .entries.map((h) => ActionChip(label: Text(h.value), onPressed: _busy ||
              (_session['freeHint'] != true && (_session['adCredits'] as num? ?? 0) == 0) ||
              (_vault && h.key == 'league' && _session['league'] != null) ? null :
              () => _act('hint', {'hint': h.key, 'slot': _slot}))).toList()),
        if ((_session['adRemaining'] as num? ?? 0) > 0) TextButton.icon(onPressed: _busy ? null : _watch,
          icon: const Icon(Icons.play_circle_outline), label: Text('Reklamla ipucu hakkı al · ${_session['adRemaining']} kaldı')),
        const Text('Reklam izlemek yalnızca hak kazandırır. İpucunu kullanmadıkça ustalık etkilenmez.'),
        const SizedBox(height: 16),
        PitchAction(label: !_vault && _session['score'] == 11 ? 'Kadroyu tamamla' : 'Erken bitir',
          secondary: _vault || _session['score'] != 11, onPressed: _busy ? null : _finish),
        const Padding(padding: EdgeInsets.only(top: 8), child: Text('Geri çıkabilirsin; oyun sunucuda saklanır. Normal oyun 24 saat, günlük oyun gece yarısına kadar devam eder.')),
      ] else ..._result(),
      if (_coach && _finished) ...[
        const PitchSectionTitle('Doğrulanmış bağlar'),
        for (final slot in slots) if (slot['player'] != null) ...[
          Text('${rewardMap(slot['player'])['name']}', style: Theme.of(context).textTheme.titleSmall),
          for (final e in _maps(slot['evidence'])) Padding(padding: const EdgeInsets.only(bottom: 8),
            child: SelectableText('${e['club']} · ${e['date']}\n${_strings(e['sources']).join('\n')}')),
        ],
      ],
    ];
  }

  Widget _pitch(List<Map<String, dynamic>> slots) {
    final rows = _session['formation'] == '4231'
        ? [['FWD', 0, 0], ['MID', 1, 3], ['MID', 4, 5], ['DEF', 6, 9], ['GK', 10, 10]]
        : [['FWD', 0, 10], ['MID', 0, 10], ['DEF', 0, 10], ['GK', 0, 10]];
    return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(
      color: const Color(0xff103b34), border: Border.all(color: const Color(0xff4d8376)),
      borderRadius: BorderRadius.circular(20)), child: Column(children: [
        for (final row in rows) Padding(padding: const EdgeInsets.symmetric(vertical: 8),
          child: LayoutBuilder(builder: (context, constraints) {
            final line = slots.where((s) => s['position'] == row[0] &&
              (s['slot'] as num) >= (row[1] as int) && (s['slot'] as num) <= (row[2] as int)).toList();
            // Preserve the formation at ordinary type sizes; wrap for accessibility.
            final width = MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 130.0 :
              ((constraints.maxWidth - 6 * (line.length - 1)) / line.length).clamp(48.0, 106.0).toDouble();
            return Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 8,
              children: line.map((s) {
                final player = rewardMap(s['player']);
                final country = '${s['country'] ?? player['country'] ?? ''}';
                final chosen = !_vault && !_finished && s['slot'] == _slot;
                return SizedBox(width: width, child: Material(
                  color: chosen ? const Color(0xffd3f27c) : const Color(0xff1b5146),
                  borderRadius: BorderRadius.circular(10), child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _busy || _vault || _finished ? null : () => setState(() { _slot = (s['slot'] as num).toInt(); }),
                    child: Padding(padding: const EdgeInsets.all(8), child: Column(children: [
                      Text(_positions[row[0]]!, textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: chosen ? Colors.black87 : Colors.white70)),
                      const SizedBox(height: 4),
                      if (country.isNotEmpty) Semantics(label: country, child: ExcludeSemantics(
                        child: Text(flagFor(country), style: const TextStyle(fontSize: 22, fontFamily: 'Noto Color Emoji')))),
                      if (_vault && country.isEmpty && player.isEmpty)
                        const Icon(Icons.lock_outline_rounded, color: Colors.white70, size: 24)
                      else Text(player.isNotEmpty ? '${player['name']}' : _vault ? country : '+ Seç',
                        textAlign: TextAlign.center, style: TextStyle(color: chosen ? Colors.black : Colors.white)),
                    ])),
                  )),
                );
              }).toList());
          })),
      ]));
  }
  List<Widget> _result() {
    final r = rewardMap(_session['result']);
    return [
      const PitchSectionTitle('Oyun tamamlandı'),
      PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_vault ? '${r['score']} yıldız' : r['mastery'] == true ? 'Ustalık kazandın!' : '${r['score']}/11 kadro',
          style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        if (!_vault && _strings(r['newMedals']).isNotEmpty) Text('Yeni madalyalar: ${_strings(r['newMedals']).map((m) => {'1': 'Bronz', '2': 'Gümüş', '3': 'Altın', '4': 'Ustalık'}[m] ?? m).join(', ')}'),
        Text('Bu oyunda yeni ödül: ${r['coins']} coin · ${r['xp']} XP'),
        Text(_vault ? 'Aynı kulübün yıldız ödülleri tüm kasa çeşitlerinde ortaktır.' : 'Aynı hedefin madalyaları rulet, günlük ve arşivde ortaktır.'),
        if (_status['linked'] != true) const Text('Ödüllerin bekliyor. Aynı misafir hesabını Google’a bağlayınca aktarılır.'),
        if (r['avatarAvailable'] == true) const Text('Hoca koleksiyonunda avatar veya sabit coin ödülünü seçebilirsin.'),
      ])),
      const SizedBox(height: 16),
      PitchAction(label: 'Koleksiyona dön', onPressed: _busy ? null : () async {
        await _load(); if (mounted) setState(() => _archive = true);
      }),
    ];
  }
}
