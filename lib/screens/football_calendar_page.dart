import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../app/game_audio.dart';
import '../models/rewarded_ad_models.dart';
import '../services/daily_matches_gateway.dart';
import '../widgets/club_identity_badge.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/game_ui.dart';
import '../widgets/paid_hint_button.dart';
import '../theme/ortak_saha_theme.dart';

class FootballCalendarPage extends StatefulWidget {
  const FootballCalendarPage({super.key, this.gateway});
  final DailyMatchesGateway? gateway;
  @override
  State<FootballCalendarPage> createState() => _FootballCalendarPageState();
}

class _FootballCalendarPageState extends State<FootballCalendarPage>
    with WidgetsBindingObserver {
  late final DailyMatchesGateway _gateway =
      widget.gateway ?? FirebaseDailyMatchesGateway();
  final _answer = TextEditingController();
  final _scroll = ScrollController();
  Map<String, dynamic>? _data, _round, _match;
  bool _busy = false, _showCalendar = false;
  String? _message;
  String _filter = 'Tümü';
  Map<String, dynamic> get _bonus => rewardMap(_data?['bonus']);
  bool get _bonusReady =>
      _bonus['enabled'] == true &&
      (_bonus['pro'] == true || _bonus['testingOnly'] != true) &&
      number(_bonus, 'remaining') > 0;
  String bonusLabel(String text) =>
      '${_bonus['pro'] == true ? 'Pro bonusu' : 'Reklam izle'} · $text';
  List<Map<String, dynamic>> get _matches =>
      (_data?['matches'] as List? ?? []).map(rewardMap).toList();
  int number(Map<String, dynamic>? m, String key) =>
      (m?[key] as num? ?? 0).toInt();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _run(_refresh);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _answer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _run(_refresh);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted)
        setState(
          () => _message = e is FirebaseFunctionsException
              ? (e.code == 'not-found' || e.code == 'unimplemented'
                    ? 'Günün maçları güncellemesi sunucuya henüz yüklenmedi.'
                    : e.message ?? 'Bağlantı kurulamadı. Tekrar dene.')
              : e is StateError
              ? e.message.toString()
              : 'Bağlantı kurulamadı. Hakların korunuyor; tekrar dene.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    final data = await _gateway.call('status').timeout(const Duration(seconds: 30));
    if (!mounted) return;
    setState(() {
      _data = data;
      if (_round != null && _round!['day'] != data['dayKey']) {
        _round = null;
        _match = null;
        _message = 'Yeni gün başladı. Bugünün maçlarından birini seç.';
      }
      if (_round != null) {
        for (final m in _matches) {
          final s = rewardMap(m['session']);
          if (s['key'] == _round!['key']) _round = s;
        }
      }
    });
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  Future<void> _start(Map<String, dynamic> match) async {
    final data = await _gateway.call('start', {
      'fixtureId': match['fixtureId'],
    }).timeout(const Duration(seconds: 30));
    if (!mounted) return;
    setState(() {
      _match = match;
      _round = rewardMap(data['session']);
      _answer.clear();
    });
    _scrollToTop();
  }

  Future<void> _play(String action) async {
    if (_round == null) return;
    final text = _answer.text.trim();
    if (action == 'answer' && text.isEmpty) return;
    final before = (_round!['foundPlayers'] as List? ?? []).length;
    final data = await _gateway.call('play', {
      'key': _round!['key'],
      'action': action,
      if (action == 'answer') 'answer': text,
    }).timeout(const Duration(seconds: 30));
    if (!mounted) return;
    setState(() {
      _round = rewardMap(data['session']);
      if ((_round!['foundPlayers'] as List? ?? []).length > before)
        _answer.clear();
    });
    if (_round!['finished'] == true) {
      _scrollToTop();
      await _refresh();
    }
  }

  Future<void> _watch(String placement) async {
    await _gateway.watch(
      placement,
      key: placement == 'daily_streak' ? null : _round?['key']?.toString(),
    );
    await _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bonusun kaydedildi.')),
      );
    }
  }

  Widget _tag(String text, {IconData? icon}) => Chip(
    avatar: icon == null ? null : Icon(icon, size: 16, color: PitchColors.of(context).accent),
    label: Text(text, style: const TextStyle(fontSize: 12)),
    visualDensity: VisualDensity.compact,
  );
  Widget _teams(Map<String, dynamic> m) => LayoutBuilder(builder: (context, constraints) {
    if (constraints.maxWidth < 260 || MediaQuery.textScalerOf(context).scale(14) > 19) {
      return Column(children: [
        for (final side in ['home', 'away']) ...[
          if (side == 'away') const Divider(height: 24),
          Row(children: [
            ClubIdentityBadge(
              clubId: number(m, '${side}ClubId'),
              clubName: '${m['${side}Name'] ?? ''}',
              size: 48,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('${m['${side}Name'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w700))),
          ]),
        ],
      ]);
    }
    return Row(
    children: [
      for (final side in ['home', 'away']) ...[
        if (side == 'away')
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('×', style: TextStyle(fontSize: 24)),
          ),
        Expanded(
          child: Column(
            children: [
              ClubIdentityBadge(
                clubId: number(m, '${side}ClubId'),
                clubName: '${m['${side}Name'] ?? ''}',
                size: 54,
              ),
              const SizedBox(height: 8),
              Text(
                '${m['${side}Name'] ?? ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    ],
    );
  });
  String _kickoff(Map<String, dynamic> m) {
    if (m['status'] == 'TBD') return 'Saat bekleniyor';
    final date = DateTime.tryParse(
      '${m['kickoff']}',
    )?.toUtc().add(const Duration(hours: 3));
    return date == null
        ? 'Saat bekleniyor'
        : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} TSİ';
  }

  Widget _fixture(Map<String, dynamic> m, {bool featured = false}) {
    final session = rewardMap(m['session']);
    final started = session.isNotEmpty;
    final finished = session['finished'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PitchPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 6,
              children: [
                if (featured) _tag('GÜNÜN SEÇİMİ', icon: Icons.star_rounded),
                if (m['isDerby'] == true)
                  _tag('DERBİ', icon: Icons.local_fire_department_rounded),
                _tag('${m['leagueName'] ?? ''}'),
                _tag(_kickoff(m)),
              ],
            ),
            const SizedBox(height: 14),
            _teams(m),
            const SizedBox(height: 18),
            Text(
              '${m['sharedCount']} ortak oyuncu · Kazanmak için 3 doğru',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              '3 can · Süre baskısı yok · En fazla 60 coin',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 14),
            PitchAction(
              label: finished
                  ? 'Sonucu gör'
                  : started
                  ? 'Maça devam et'
                  : 'Mücadeleye başla',
              onPressed: _busy || (!started && number(_data, 'remaining') == 0)
                  ? null
                  : () => _run(() => _start(m)),
              icon: finished ? Icons.check_circle_outline : Icons.sports_soccer,
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> get _feed => rewardMap(_data?['feed']);
  List<Map<String, dynamic>> get _calendar =>
    (_data?['calendar'] as List? ?? _data?['matches'] as List? ?? []).map(rewardMap).toList();

  String _dayLabel(String? value) {
    final date = DateTime.tryParse(value ?? '');
    if (date == null) return 'Bugünün programı';
    const months = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _statusLabel(Map<String, dynamic> match) {
    if (match['stale'] == true) return 'Güncelleme bekleniyor';
    return switch (match['status']) {
      'FT' || 'AET' || 'PEN' => 'Tamamlandı',
      'PST' => 'Ertelendi', 'CANC' => 'İptal edildi',
      'SUSP' || 'ABD' => 'Durduruldu', 'AWD' || 'WO' => 'Hükmen sonuç',
      'TBD' => 'Saat kesinleşmedi',
      '1H' || '2H' || 'HT' || 'ET' || 'P' || 'LIVE' => 'Sürüyor · son kayıt',
      _ => 'Planlandı',
    };
  }

  Widget _sourceInfo() {
    final sources = rewardMap(_feed['sources']);
    final supplemental = rewardMap(sources['supplemental']);
    final apiState = supplemental['state'] ?? 'pending';
    final snapshot = _feed['snapshotUpdatedAt'] != null;
    final updated = (_feed['snapshotUpdatedAt'] as num?)?.toInt();
    return PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.update_rounded, size: 18, color: PitchColors.of(context).accent),
        const SizedBox(width: 8), Expanded(child: Text('Takvim bilgisi',
          style: Theme.of(context).textTheme.titleSmall))]),
      const SizedBox(height: 8),
      Text(snapshot && updated != null
        ? 'Takvim kaydı: ${_dayLabel(DateTime.fromMillisecondsSinceEpoch(updated, isUtc: true)
            .add(const Duration(hours: 3)).toIso8601String())}. Maç saatleri değişebilir.'
        : 'Saatler Türkiye saatine göredir. Son alınan fikstür gösterilir.'),
      if (['error', 'unconfigured', 'pending'].contains(apiState)) ...[
        const SizedBox(height: 8),
        const Text('Süper Lig, Avrupa Ligi ve Konferans Ligi güncellemesi bekleniyor.'),
      ],
      if (_feed['competitions'] is List) ExpansionTile(tilePadding: EdgeInsets.zero,
        title: const Text('Veri kapsamı'),
        children: [Text('${(_feed['competitions'] as List).join(', ')}.'),
          const Text('Süper Lig, Avrupa Ligi ve Konferans Ligi ayrı kaynaktan günlük güncellenir. Anlık skor sunulmaz.')]),
      if (_feed['state'] == 'out-of-coverage') ...[
        const SizedBox(height: 8), const Text('Kayıtlı takvimin tarih aralığı sona erdi; yeni takvim bekleniyor.'),
      ],
    ]));
  }

  Widget _calendarFixture(Map<String, dynamic> match) {
    final playable = _matches.where((m) => m['fixtureId'] == match['fixtureId']).firstOrNull;
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: PitchPanel(child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 6, runSpacing: 4, children: [
          _tag('${match['leagueName'] ?? ''}'), _tag(_kickoff(match)), _tag(_statusLabel(match)),
        ]),
        const SizedBox(height: 14), _teams(match), const SizedBox(height: 14),
        if (['FT', 'AET', 'PEN'].contains(match['status']) &&
            match['homeScore'] != null && match['awayScore'] != null)
          Text('${match['homeScore']} – ${match['awayScore']}', textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall),
        if (playable != null) ...[
          const SizedBox(height: 8), PitchAction(label: 'Ortak oyuncuları bul',
            onPressed: _busy || (rewardMap(playable['session']).isEmpty && number(_data, 'remaining') == 0)
              ? null : () => _run(() => _start(playable))),
        ] else Text(match['stale'] == true ? 'Yeni oyun için fikstürün güncellenmesi gerekiyor.' :
          ['PST', 'CANC', 'SUSP', 'ABD', 'AWD', 'WO', 'TBD'].contains(match['status'])
            ? 'Bu maç şu anda oyuna açık değil.' :
              'Takvimde yer alıyor; bugünün ortak oyuncu oyunları arasında değil.',
          style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
      ],
    )));
  }

  Widget _emptyFixtures() {
    final filtering = _filter != 'Tümü';
    final hasCalendar = _calendar.isNotEmpty;
    final title = filtering ? 'Bu seçime uygun maç yok' : !_showCalendar && hasCalendar
      ? 'Bugün için uygun oyun bulunamadı' : _feed.isEmpty ? 'Bu seçime uygun maç yok' :
        'Bu kaynaklarda bugün için maç yok';
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: PitchPanel(child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Icon(Icons.event_note_rounded, size: 36, color: PitchColors.of(context).accent),
        const SizedBox(height: 12), Text(title, textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8), Text(filtering ? 'Diğer ligleri ve maçları görmek için filtreyi temizle.' :
          hasCalendar ? 'Oyun için iki kulüp arasında en az 4 doğrulanmış ortak oyuncu gerekiyor. Günün programını fikstürden inceleyebilirsin.' :
          'Takvim yenilendiğinde maçlar burada görünür. Maç olmayan günler serini etkilemez.',
          textAlign: TextAlign.center),
        const SizedBox(height: 12),
        PitchAction(label: filtering ? 'Tümünü göster' : hasCalendar && !_showCalendar ? 'Fikstürü incele' : 'Listeyi yenile',
          secondary: true, onPressed: _busy ? null : () {
            if (filtering) { setState(() => _filter = 'Tümü'); }
            else if (hasCalendar && !_showCalendar) { setState(() => _showCalendar = true); }
            else { _run(_refresh); }
          }),
      ],
    )));
  }

  Widget _lobby() {
    final p = PitchColors.of(context);
    final filtered = (_showCalendar ? _calendar : _matches).where((m) =>
      _filter == 'Tümü' || (_filter == 'Türkiye' ? m['leagueId'] == 203 :
        _filter == 'Derbiler' ? m['isDerby'] == true : [2, 3, 848].contains(m['leagueId']))).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: p.tint, borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.sports_soccer_rounded, color: p.accent)),
          const SizedBox(width: 12), Expanded(child: Text(_dayLabel(_data?['dayKey']?.toString()),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: p.accent)))]),
        const SizedBox(height: 16), Text('Maç onların. Hafıza senin.', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8), const Text('İki takımda da oynamış 3 futbolcuyu bul.'),
        const SizedBox(height: 16), Wrap(spacing: 8, runSpacing: 4, children: [
          _tag('${number(_data, 'remaining')}/${number(_data, 'dailyLimit') == 0 ? 3 : number(_data, 'dailyLimit')} maç hakkı',
            icon: Icons.confirmation_number_outlined),
          _tag('${number(_data, 'streak')} günlük seri', icon: Icons.local_fire_department),
          _tag('0 enerji', icon: Icons.bolt_outlined),
        ]),
      ])),
      if (number(_data, 'pendingCoins') > 0) ...[
        const SizedBox(height: 12), PitchPanel(child: Text('${number(_data, 'pendingCoins')} coin hesabında saklanıyor. '
          'Misafir hesabını Google’a bağladığında cüzdanına aktarılır.')),
      ],
      if (number(_data, 'repairStreak') > 0) ...[
        const SizedBox(height: 12), PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${number(_data, 'repairStreak')} günlük serini koru', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8), const Text('Bugünkü galibiyetinden önce seri korumasını kullanabilirsin.'),
          const SizedBox(height: 12), PitchAction(label: bonusLabel('Serimi koru'), icon: Icons.shield_outlined,
            onPressed: _busy || !_bonusReady ? null : () => _run(() => _watch('daily_streak'))),
        ])),
      ],
      const SizedBox(height: 24),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ChoiceChip(label: Text('Oyna · ${_matches.length}'), selected: !_showCalendar,
          onSelected: (_) => setState(() => _showCalendar = false)),
        ChoiceChip(label: Text('Fikstür · ${_calendar.length}'), selected: _showCalendar,
          onSelected: (_) => setState(() => _showCalendar = true)),
      ]),
      PitchSectionTitle(_showCalendar ? 'Günün programı' : 'Bugünün seçilmiş maçları'),
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final f in ['Tümü', 'Türkiye', 'Avrupa', 'Derbiler']) ChoiceChip(label: Text(f),
          selected: _filter == f, onSelected: (_) => setState(() => _filter = f)),
      ]),
      const SizedBox(height: 16),
      if (filtered.isEmpty) _emptyFixtures(),
      for (var i = 0; i < filtered.length; i++)
        _showCalendar ? _calendarFixture(filtered[i]) : _fixture(filtered[i], featured: i == 0),
      if (_feed.isNotEmpty) ...[_sourceInfo(), const SizedBox(height: 16)],
      PitchPanel(child: ExpansionTile(tilePadding: EdgeInsets.zero, childrenPadding: const EdgeInsets.only(bottom: 8),
        title: const Text('Nasıl oynanır ve kazanılır?'), children: const [
          Text('3 doğru: 30 coin. Devam ederek ödülünü artır; tüm oyuncuları bulmak +15 coin bonus getirir. '
            'Maç başına en fazla 60 coin.\n\nGünde 3 maç ve 3 can. Süre sınırı yok. '
            'Maç hakkı başlatınca kullanılır; yarım bıraktığın maça aynı gün dönebilirsin.\n\n'
            'İpucu koşulları oyun içindeki destek panelinde görünür. Yardımlı sonuç ustalık/yardımsız seriye eklenmez. '
            '2x ödül ve seri koruması için mevcut bonus hakların korunur.\n\n'
            'Maç olmayan günler seriyi etkilemez. Oynanabilir günü kaçırırsan seri sıfırlanır; '
            '31 günü aşan aralarda yeni seri başlar.'),
        ])),
    ]);
  }

  Widget _game() {
    final r = _round!;
    final found = (r['foundPlayers'] as List? ?? []).map(rewardMap).toList();
    final finished = r['finished'] == true;
    final won = found.length >= 3;
    final all = found.length == number(r, 'total');
    final p = PitchColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PitchPanel(
          child: Column(
            children: [
              _teams(_match!),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                children: [
                  _tag('${number(r, 'lives')} can', icon: Icons.favorite),
                  _tag(
                    '${found.length}/${number(r, 'total')} bulundu',
                    icon: Icons.sports_soccer,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (found.length / 3).clamp(0, 1),
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 10),
              Text(
                finished
                    ? (won ? 'Hedef tamamlandı. Maç bitti.' : 'Maç tamamlandı.')
                    : won
                    ? 'Hedef tamam! Ek ödül için devam edebilirsin.'
                    : '${3 - found.length} doğru daha bul, kazan.',
                style: TextStyle(color: p.accent, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!finished) ...[
          TextField(
            controller: _answer,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _run(() => _play('answer')),
            decoration: const InputDecoration(
              labelText: 'Futbolcunun adı veya soyadı',
              hintText: 'Örn. Gökhan Gönül',
              prefixIcon: Icon(Icons.person_search_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          PitchAction(
            label: 'Cevabı kontrol et',
            busy: _busy,
            onPressed: _busy ? null : () => _run(() => _play('answer')),
            icon: Icons.check,
          ),
          if (r['feedback'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '${r['feedback']}',
                semanticsLabel: '${r['feedback']}',
              ),
            ),
          if (r['hint'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: PitchPanel(child: Text('İpucu: ${r['hint']}')),
            ),
          const SizedBox(height: 12),
          if (rewardMap(r['support'])['version'] == 1)
            PaidHintButton(session: r, sku: 'boost_basic', label: 'Ortak oyuncu ipucu',
              disabled: _busy || _message != null || r['hintUsed'] == true,
              onUse: (payment) => _run(() async {
                final data = await _gateway.call('play', {'key': r['key'], 'action': 'hint',
                  'revision': r['revision'], ...payment});
                if (mounted) setState(() => _round = rewardMap(data['session']));
              }), onWatch: () => _run(() => _watch('daily_match_hint')))
          else if (r['hintUsed'] != true)
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(() => _play('hint')),
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('Ücretsiz ipucunu göster'),
            )
          else if (r['adHint'] != true)
            OutlinedButton.icon(
              onPressed: _busy || !_bonusReady
                  ? null
                  : () => _run(() => _watch('daily_hint')),
              icon: const Icon(Icons.play_circle_outline),
              label: Text(bonusLabel('İpucunu genişlet')),
            ),
          if (won) ...[
            const SizedBox(height: 12),
            PitchAction(
              label: 'Ödülümü al ve bitir',
              secondary: true,
              onPressed: _busy ? null : () => _run(() => _play('finish')),
              icon: Icons.savings_outlined,
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Acele etme. Üç yanlışta maç biter. Hedefi geçtiysen kazandığın coin korunur.',
            textAlign: TextAlign.center,
          ),
        ] else ...[
          PitchPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  all
                      ? Icons.emoji_events
                      : won
                      ? Icons.verified
                      : Icons.sports_soccer,
                  size: 52,
                  color: p.accent,
                ),
                const SizedBox(height: 12),
                Text(
                  all
                      ? 'Kusursuz futbol hafızası!'
                      : won
                      ? 'Maçı kazandın!'
                      : 'Bir sonraki maç senin.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${number(r, 'reward') * (r['doubled'] == true ? 2 : 1)} Link Coin',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (r['assisted'] == true) const Text('Yardımlı sonuç · Ustalık ve yardımsız seri dışında',
                  textAlign: TextAlign.center),
                if (all)
                  const Text(
                    'Tüm oyuncuları bulma bonusu dahil.',
                    textAlign: TextAlign.center,
                  ),
                if (won && r['doubled'] != true) ...[
                  const SizedBox(height: 16),
                  PitchAction(
                    label: bonusLabel('${number(r, 'reward') * 2} coine katla'),
                    icon: Icons.play_circle_outline,
                    onPressed: _busy || !_bonusReady
                        ? null
                        : () => _run(() => _watch('daily_double')),
                  ),
                ],
                if (r['doubled'] == true)
                  const Text(
                    '2x bonusun kaydedildi.',
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() {
                            _round = null;
                            _match = null;
                          });
                          _run(_refresh);
                        },
                  child: const Text('Diğer maçlara dön'),
                ),
              ],
            ),
          ),
        ],
        if (found.isNotEmpty) ...[
          const PitchSectionTitle('Bulduğun oyuncular'),
          for (final player in found)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.check_circle, color: p.accent),
              title: Text('${player['name']}'),
              subtitle: Text('${player['country']}'),
            ),
        ],
        if (finished && (r['remainingPlayers'] as List? ?? []).isNotEmpty)
          ExpansionTile(
            title: const Text('Kaçırdığın oyuncuları keşfet'),
            children: [
              for (final player in (r['remainingPlayers'] as List).map(
                rewardMap,
              ))
                ListTile(
                  title: Text('${player['name']}'),
                  subtitle: Text('${player['country']}'),
                ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_round == null ? 'Günün Maçları' : 'Ortak oyuncuları bul', maxLines: 2),
      toolbarHeight: MediaQuery.textScalerOf(context).scale(16) > 24 ? 96 : 64,
      leading: _round == null
          ? null
          : IconButton(
              tooltip: 'Maç listesine dön',
              icon: const Icon(Icons.arrow_back),
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {
                        _round = null;
                        _match = null;
                      });
                      _run(_refresh);
                    },
            ),
      actions: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: _busy ? null : () => _run(_refresh),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: GameContent(
      child: RefreshIndicator(
        onRefresh: () => _run(_refresh),
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            if (_busy && _data == null) const PitchPanel(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Günün programı hazırlanıyor', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                SizedBox(height: 8), Text('Maç takvimi ve kayıtlı oyunların kontrol ediliyor.'),
                SizedBox(height: 16), LinearProgressIndicator(),
              ])),
            if (_busy && _data != null) const LinearProgressIndicator(),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(_message!), const SizedBox(height: 12),
                  if (_data != null) PitchAction(label: 'Tekrar dene', secondary: true,
                    onPressed: _busy ? null : () => _run(_refresh)),
                ])),
              ),
            if (_data == null && !_busy)
              PitchAction(
                label: 'Tekrar dene',
                onPressed: () => _run(_refresh),
              ),
            // Match list keeps the menu theme; the puzzle itself uses the puzzle theme.
            if (_data != null) MusicScene(track: _round == null ? MusicTrack.menu : MusicTrack.puzzle,
              child: _round == null ? _lobby() : _game()),
          ],
        ),
      ),
    ),
  );
}
