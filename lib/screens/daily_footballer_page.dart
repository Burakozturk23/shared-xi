import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/daily_footballer_controller.dart';
import '../models/daily_footballer.dart';
import '../services/daily_footballer_store.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/pitch_ui.dart';

class DailyFootballerPage extends StatefulWidget {
  const DailyFootballerPage({super.key, this.controller});
  final DailyFootballerController? controller;
  @override
  State<DailyFootballerPage> createState() => _DailyFootballerPageState();
}

class _DailyFootballerPageState extends State<DailyFootballerPage> with WidgetsBindingObserver {
  DailyFootballerController? _game;
  final _search = TextEditingController();
  Timer? _timer;
  bool _failed = false;
  String? _shownDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _game?.refreshDay());
  }
  Future<void> _boot() async {
    setState(() => _failed = false);
    try {
      final game = widget.controller ?? DailyFootballerController(
        catalog: await loadDailyFootballers(), store: LocalDailyFootballerStore(),
        watchAd: () => watchDailyFootballerAd());
      if (!mounted) { if (widget.controller == null) game.dispose(); return; }
      _game = game;
      game.addListener(_changed);
      await game.initialize();
      if (mounted) setState(() {});
    } catch (_) { if (mounted) setState(() => _failed = true); }
  }
  void _changed() {
    if (!mounted) return;
    final day = _game?.round?.dayKey;
    if (day != _shownDay) { _shownDay = day; _search.clear(); }
    setState(() {});
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _game?.refreshDay();
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel(); _search.dispose();
    _game?.removeListener(_changed);
    if (widget.controller == null) _game?.dispose();
    super.dispose();
  }

  void _help() => showModalBottomSheet<void>(
    context: context, isScrollControlled: true, showDragHandle: true,
    builder: (context) => SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min,
        children: [
          Text('Altı iz, tek futbolcu.', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          for (final rule in const [
            ('6 tahmin', 'En az iki harf yaz ve listeden bir futbolcu seç. Aynı futbolcu ikinci kez tahmin edilemez.'),
            ('✓ Eşleşti · × Farklı', 'Ülke, kulüp, lig ve mevkiyi karşılaştır. Renklerin yanında simge ve açıklama da var.'),
            ('↑ Daha yüksek · ↓ Daha düşük', 'Oklar hedef futbolcunun yaşının veya forma numarasının, tahmininden daha yüksek ya da düşük olduğunu gösterir.'),
            ('Reklamlı ipucu', 'İlk tahmininden sonra bir ödüllü reklamı tamamlayarak isim ipucunu bir kez açabilirsin.'),
            ('Son bir tahmin', 'Altı yanlışın ardından ödüllü reklamla yalnızca bir ek hak alabilirsin. Sonucu görürsen oyun biter.'),
            ('Her gün aynı bulmaca', 'Aynı veri sürümünü kullanan herkes için hedef aynıdır. Gün Türkiye saatiyle 00.00’da yenilenir; ilerlemen bu cihazda saklanır.'),
          ]) ...[
            Text(rule.$1, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4), Text(rule.$2), const SizedBox(height: 16),
          ],
          if (_game != null) Text(
            '${_game!.catalog.players.length} futbolcu · 17 kulüp. Kadro verisi: ${_game!.round?.asOf ?? _game!.catalog.asOf}. '
            'Ülke, kaynakta kayıtlı vatandaşlıktır. Mevkiler kaleci, defans, orta saha ve forvet olarak gruplanır. '
            'Kulüp ve forma numarası bu tarihli kadro paketine göre değerlendirilir. Kaynak: ESPN kadro kayıtları.',
            style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Anladım')),
        ],
      ),
    )),
  );

  @override
  Widget build(BuildContext context) {
    final game = _game, round = _game?.round;
    final p = PitchColors.of(context);
    return PopScope(canPop: !(game?.busy ?? false), child: Scaffold(
      appBar: AppBar(title: const Text('Günün Futbolcusu'), actions: [
        IconButton(tooltip: 'Nasıl oynanır?', onPressed: _help, icon: const Icon(Icons.help_outline_rounded)),
      ]),
      body: SafeArea(child: round == null
        ? Center(child: Padding(padding: const EdgeInsets.all(24), child:
          _failed || game?.message != null ? Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Günün futbolcusu yüklenemedi.'), const SizedBox(height: 12),
            FilledButton(onPressed: () => game == null ? _boot() : game.initialize(), child: const Text('Tekrar dene')),
          ]) : const CircularProgressIndicator()))
        : ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [
            if (game!.busy) const LinearProgressIndicator(),
            Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24), border: Border.all(color: p.accent.withValues(alpha: .4)),
              gradient: LinearGradient(colors: [p.tint, p.surface])),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('GÜNLÜK OYUNCU DOSYASI · ${round.dayKey.split('-').reversed.join('.')}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: p.accent)),
                if (round.guesses.isEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Sahadaki gizli ismi bul.', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('Her tahmin yeni bir iz bırakır. Altı özelliği karşılaştır, doğru isme yaklaş.'),
                ],
                const SizedBox(height: 18),
                Row(children: [for (var i = 0; i < round.limit; i++) Expanded(child: Container(
                  height: 6, margin: const EdgeInsets.only(right: 5), decoration: BoxDecoration(
                    color: i < round.guesses.length ? (round.won ? p.success : p.accent) : p.border,
                    borderRadius: BorderRadius.circular(8)))),
                ]),
                const SizedBox(height: 8),
                Text('${round.guesses.length}/${round.limit} tahmin · ${round.finished ? 'Oyun tamamlandı' : '${round.remaining} hak kaldı'}'),
              ]),
            ),
            if (game.message != null) Padding(padding: const EdgeInsets.only(top: 12),
              child: Text(game.message!, key: const ValueKey('daily-footballer-message'),
                style: TextStyle(color: p.accent))),
            const SizedBox(height: 18),
            if (round.canGuess) ...[
              TextField(key: const ValueKey('daily-footballer-search'), controller: _search,
                enabled: !game.busy, onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: 'Futbolcu ara', hintText: 'En az 2 harf yaz',
                  prefixIcon: const Icon(Icons.search_rounded), suffixIcon: _search.text.isEmpty ? null : IconButton(
                    tooltip: 'Aramayı temizle', onPressed: () => setState(_search.clear), icon: const Icon(Icons.close_rounded)))),
              if (_search.text.trim().length >= 2) _suggestions(game, round),
              const SizedBox(height: 12),
            ],
            if (round.finished) _result(round),
            if (round.canExtra) PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Son bir şansın var.', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8), const Text('Altı tahmin bitti. Reklamı tamamla ve bir kez daha dene ya da sonucu gör.'),
              const SizedBox(height: 12),
              FilledButton.icon(key: const ValueKey('daily-extra'), onPressed: game.busy ? null : game.unlockExtra,
                icon: const Icon(Icons.ondemand_video_rounded), label: const Text('Reklam izle · +1 tahmin')),
              TextButton(onPressed: game.busy ? null : game.reveal, child: const Text('Sonucu gör')),
            ])),
            if (round.hintUsed) PitchRow(title: 'İsim ipucun', subtitle: round.hint,
              icon: Icons.lightbulb_outline_rounded, highlight: true, trailing: const Icon(Icons.check_rounded)),
            if (!round.hintUsed && !round.finished && !round.canExtra) PitchPanel(child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Bir harf, yeni bir iz.', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4), Text(round.guesses.isEmpty ? 'İlk tahmininden sonra isim ipucunu açabilirsin.' : 'Ödüllü reklamı tamamla, isim ipucunu aç.'),
                const SizedBox(height: 10),
                OutlinedButton.icon(key: const ValueKey('daily-hint'), onPressed: game.busy || !round.canHint ? null : game.unlockHint,
                  icon: const Icon(Icons.ondemand_video_rounded), label: const Text('Reklam izle · İpucu')),
              ],
            )),
            const SizedBox(height: 22),
            Text('Tahminlerin', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('✓ Eşleşti   × Farklı   ↑ / ↓ Hedefin yönü', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            if (round.guesses.isEmpty) const PitchPanel(child: Text('İlk futbolcunu seç. Ülke, kulüp, lig, mevki, yaş ve forma numarası burada karşılaştırılacak.')),
            for (var i = round.guesses.length - 1; i >= 0; i--) Padding(
              padding: const EdgeInsets.only(bottom: 12), child: _guessCard(round, i)),
            const SizedBox(height: 8),
            Text('Türkiye saatiyle 00.00’da yeni futbolcu. İlerlemen bu cihazda saklanır.',
              style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        )),
    ));
  }

  Widget _suggestions(DailyFootballerController game, DailyFootballerRound round) {
    final matches = game.catalog.search(_search.text, round);
    if (matches.isEmpty) return const Padding(padding: EdgeInsets.all(12),
      child: Text('Eşleşen yeni futbolcu yok. Farklı bir isim dene.'));
    return Column(children: [for (final player in matches) ListTile(
      key: ValueKey('guess-${player.id}'), contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(player.name), subtitle: Text('${player.club} · ${player.positionLabel}'),
      trailing: const Icon(Icons.arrow_forward_rounded), enabled: !game.busy,
      onTap: () async {
        FocusScope.of(context).unfocus();
        await game.guess(player.id);
        if (mounted && game.round?.guesses.any((g) => g.id == player.id) == true) setState(_search.clear);
      },
    )]);
  }

  Widget _result(DailyFootballerRound round) => Padding(padding: const EdgeInsets.only(bottom: 12), child: PitchPanel(
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Icon(round.won ? Icons.emoji_events_outlined : Icons.sports_soccer_rounded, size: 40,
        color: PitchColors.of(context).limeInk),
      const SizedBox(height: 12),
      Text(round.won ? 'Gizli ismi buldun!' : 'Bugünün dosyası kapandı.', textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(round.target.name, key: const ValueKey('daily-answer'), textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall),
      Text('${round.target.club} · ${round.target.country} · #${round.target.shirtNumber}', textAlign: TextAlign.center),
      const SizedBox(height: 8), const Text('Yeni futbolcu yarın seni bekliyor.', textAlign: TextAlign.center),
    ]),
  ));

  Widget _guessCard(DailyFootballerRound round, int index) => PitchPanel(
    key: ValueKey('guess-card-$index'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${index + 1}. ${round.guesses[index].name}', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (context, constraints) {
        final minWidth = 90 * MediaQuery.textScalerOf(context).scale(14) / 14;
        final cols = (constraints.maxWidth / minWidth).floor().clamp(1, 3).toInt();
        final clues = round.compare(round.guesses[index]);
        return Column(children: [
          for (var start = 0; start < clues.length; start += cols)
            Padding(padding: EdgeInsets.only(bottom: start + cols < clues.length ? 8 : 0),
              child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var col = 0; col < cols; col++) ...[
                  if (col > 0) const SizedBox(width: 8),
                  Expanded(child: _clue(clues[start + col])),
                ],
              ]))),
        ]);
      }),
    ]),
  );

  Widget _clue(FootballerClue clue) {
    final p = PitchColors.of(context);
    final match = clue.match == FootballerMatch.same;
    final color = match ? p.success : p.muted;
    final icon = switch (clue.match) {
      FootballerMatch.same => Icons.check_rounded, FootballerMatch.different => Icons.close_rounded,
      FootballerMatch.higher => Icons.arrow_upward_rounded, FootballerMatch.lower => Icons.arrow_downward_rounded,
    };
    return Semantics(label: '${clue.label}: ${clue.value}. ${clue.feedback}', excludeSemantics: true,
      child: Container(padding: const EdgeInsets.all(10), constraints: const BoxConstraints(minHeight: 108),
        decoration: BoxDecoration(color: match ? color.withValues(alpha: .1) : p.raised,
          borderRadius: BorderRadius.circular(14), border: Border.all(color: match ? color : p.border)),
        child: Column(children: [
          Text(clue.label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: p.muted)),
          const SizedBox(height: 5), Text(clue.value, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6), Icon(icon, size: 18, color: color),
          Text(clue.feedback, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
        ]),
      ),
    );
  }
}
