import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/daily_footballer_controller.dart';
import '../models/daily_footballer.dart';
import '../services/daily_footballer_store.dart';
import '../services/auth_service.dart';
import '../services/story_support_service.dart';
import '../models/rewarded_ad_models.dart';
import '../widgets/paid_hint_button.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/hub_ui.dart';
import '../widgets/pitch_ui.dart';

class DailyFootballerPage extends StatefulWidget {
  const DailyFootballerPage({super.key, this.controller});
  final DailyFootballerController? controller;
  @override
  State<DailyFootballerPage> createState() => _DailyFootballerPageState();
}

class _DailyFootballerPageState extends State<DailyFootballerPage>
    with WidgetsBindingObserver {
  DailyFootballerController? _game;
  final _search = TextEditingController();
  Timer? _timer;
  StreamSubscription<dynamic>? _auth;
  String? _owner;
  bool _failed = false;
  String? _shownDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.controller == null)
      _auth = AuthService.authStateChanges.listen((user) {
        if (_owner != null && user?.uid != _owner && mounted) {
          _game?.removeListener(_changed);
          _game?.dispose();
          setState(() {
            _game = null;
            _failed = true;
            _search.clear();
          });
        }
      });
    _boot();
    _timer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _game?.refreshDay(),
    );
  }

  Future<void> _boot() async {
    setState(() => _failed = false);
    try {
      DailyFootballerController? game = widget.controller;
      if (game == null) {
        final user = await AuthService.ensureGuestSignedIn();
        _owner = user.uid;
        game = DailyFootballerController(
          catalog: await loadDailyFootballers(),
          store: LocalDailyFootballerStore(
            userId: user.uid,
            currentUser: () => AuthService.uid,
          ),
          server: StorySupportService(
            useCallable: 'actDailyFootballer',
            loadCallable: 'getDailyFootballer',
            watchPlacement: 'daily_footballer_hint',
          ),
          watchAd: () => watchDailyFootballerAd(),
        );
      }
      if (!mounted) {
        if (widget.controller == null) game.dispose();
        return;
      }
      _game = game;
      game.addListener(_changed);
      await game.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _changed() {
    if (!mounted) return;
    final day = _game?.round?.dayKey;
    if (day != _shownDay) {
      _shownDay = day;
      _search.clear();
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _game?.refreshDay(force: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _auth?.cancel();
    _search.dispose();
    _game?.removeListener(_changed);
    if (widget.controller == null) _game?.dispose();
    super.dispose();
  }

  void _help() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Altı iz, tek futbolcu.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            for (final rule in const [
              (
                '6 tahmin',
                'En az iki harf yaz ve listeden bir futbolcu seç. Aynı futbolcu ikinci kez tahmin edilemez.',
              ),
              (
                '✓ Eşleşti · × Farklı',
                'Ülke, kulüp, lig ve mevkiyi karşılaştır. Renklerin yanında simge ve açıklama da var.',
              ),
              (
                '↑ Daha yüksek · ↓ Daha düşük',
                'Oklar hedef futbolcunun yaşının veya forma numarasının, tahmininden daha yüksek ya da düşük olduğunu gösterir.',
              ),
              (
                'İsim ipucu',
                'İlk tahmininden sonra destek panelindeki koşullarla bir kez açılır. Yeni günlük oturumda ipucu ve ek tahmin aynı tek reklam hakkını paylaşır.',
              ),
              (
                'Son bir tahmin',
                'Altı yanlışın ardından ödüllü reklamla yalnızca bir ek hak alabilirsin. Sonucu görürsen oyun biter.',
              ),
              (
                'Her gün aynı bulmaca',
                'Aynı veri sürümünü kullanan herkes için hedef aynıdır. Gün Türkiye saatiyle 00.00’da yenilenir; bağlı hesapta sunucu ilerlemen korunur.',
              ),
            ]) ...[
              Text(rule.$1, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(rule.$2),
              const SizedBox(height: 16),
            ],
            if (_game != null)
              Text(
                '${_game!.catalog.players.length} futbolcu · 17 kulüp. Kadro verisi: ${_game!.round?.asOf ?? _game!.catalog.asOf}. '
                'Ülke, kaynakta kayıtlı vatandaşlıktır. Mevkiler kaleci, defans, orta saha ve forvet olarak gruplanır. '
                'Kulüp ve forma numarası bu tarihli kadro paketine göre değerlendirilir. Kaynak: ESPN kadro kayıtları.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anladım'),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final game = _game, round = _game?.round;
    final p = PitchColors.of(context);
    return PopScope(
      canPop: !(game?.busy ?? false),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Günün Futbolcusu'),
          actions: [
            IconButton(
              tooltip: 'Yenile',
              onPressed: game?.busy == true ? null : () => game?.initialize(),
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Nasıl oynanır?',
              onPressed: _help,
              icon: const Icon(Icons.help_outline_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: round == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _failed || game?.message != null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Günün futbolcusu yüklenemedi.'),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () =>
                                    game == null ? _boot() : game.initialize(),
                                child: const Text('Tekrar dene'),
                              ),
                            ],
                          )
                        : const CircularProgressIndicator(),
                  ),
                )
              : ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    if (game!.busy) const LinearProgressIndicator(),
                    HubHeroCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: HubPill(
                              'GÜNLÜK OYUNCU DOSYASI · ${round.dayKey.split('-').reversed.join('.')}',
                              color: p.accent,
                              background: p.background.withValues(alpha: .4),
                              dot: true,
                            ),
                          ),
                          if (round.guesses.isEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              'Sahadaki gizli ismi bul.',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Her tahmin yeni bir iz bırakır. Altı özelliği karşılaştır, doğru isme yaklaş.',
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(color: p.muted),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              for (var i = 0; i < round.limit; i++)
                                Expanded(
                                  child: Container(
                                    height: 6,
                                    margin: const EdgeInsets.only(right: 5),
                                    decoration: BoxDecoration(
                                      color: i < round.guesses.length
                                          ? (round.won ? p.success : p.accent)
                                          : p.border,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Wraps under large text instead of squeezing.
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            alignment: WrapAlignment.spaceBetween,
                            children: [
                              Text(
                                '${round.guesses.length}/${round.limit} tahmin',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              Text(
                                round.finished
                                    ? 'Oyun tamamlandı'
                                    : '${round.remaining} hak kaldı',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(color: p.accent),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (game.message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          game.message!,
                          key: const ValueKey('daily-footballer-message'),
                          style: TextStyle(color: p.accent),
                        ),
                      ),
                    const SizedBox(height: 18),
                    if (round.canGuess) ...[
                      TextField(
                        key: const ValueKey('daily-footballer-search'),
                        controller: _search,
                        enabled: !game.busy,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Futbolcu ara',
                          hintText: 'En az 2 harf yaz',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Aramayı temizle',
                                  onPressed: () => setState(_search.clear),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                      if (_search.text.trim().length >= 2)
                        _suggestions(game, round),
                      const SizedBox(height: 12),
                    ],
                    if (round.finished) _result(round),
                    if (round.canExtra)
                      PitchPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Son bir şansın var.',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              round.serverOwned
                                  ? 'Altı tahmin bitti. Kalan günlük reklam hakkınla ek tahmin alabilir veya sonucu görebilirsin. Ek tahmin sonucu Yardımlı yapar.'
                                  : 'Altı tahmin bitti. Reklamı tamamla ve bir kez daha dene ya da sonucu gör.',
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              key: const ValueKey('daily-extra'),
                              onPressed:
                                  game.busy ||
                                      round.serverOwned &&
                                          (rewardMap(
                                                        round
                                                            .serverData?['support'],
                                                      )['adRemaining']
                                                      as num? ??
                                                  0) <=
                                              0
                                  ? null
                                  : game.unlockExtra,
                              icon: const Icon(Icons.ondemand_video_rounded),
                              label: const Text('Reklam izle · +1 tahmin'),
                            ),
                            TextButton(
                              onPressed: game.busy ? null : game.reveal,
                              child: const Text('Sonucu gör'),
                            ),
                          ],
                        ),
                      ),
                    if (round.hintUsed)
                      PitchRow(
                        title: 'İsim ipucun',
                        subtitle: round.hint,
                        icon: Icons.lightbulb_outline_rounded,
                        highlight: true,
                        trailing: const Icon(Icons.check_rounded),
                      ),
                    if (!round.hintUsed && !round.finished && !round.canExtra)
                      PitchPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                HubIconBox(
                                  Icons.lightbulb_outline_rounded,
                                  color: hubAmber(context),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Bir harf, yeni bir iz.',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        round.guesses.isEmpty
                                            ? 'İlk tahmininden sonra isim ipucunu açabilirsin.'
                                            : round.serverOwned
                                            ? 'Destek çantası, Coin veya doğrulanmış reklam. Sonuç Yardımlı olarak kaydolur.'
                                            : 'Ödüllü reklamı tamamla, isim ipucunu aç.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: p.muted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (round.serverOwned)
                              PaidHintButton(
                                session: round.serverData!,
                                sku: 'boost_basic',
                                label: 'İsim ipucu',
                                disabled:
                                    game.busy ||
                                    game.message != null ||
                                    !round.canHint,
                                onUse: game.paidHint,
                                onWatch: game.unlockHint,
                              )
                            else
                              OutlinedButton.icon(
                                key: const ValueKey('daily-hint'),
                                onPressed: game.busy || !round.canHint
                                    ? null
                                    : game.unlockHint,
                                icon: const Icon(Icons.ondemand_video_rounded),
                                label: const Text('Reklam izle · İpucu'),
                              ),
                          ],
                        ),
                      ),
                    HubSectionHeader(
                      'Tahminlerin',
                      trailing: Text('6 KRİTER', style: hubCaps(context)),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        HubPill(
                          'Eşleşti',
                          icon: Icons.check_rounded,
                          color: p.success,
                          background: p.success.withValues(alpha: .12),
                        ),
                        HubPill(
                          'Farklı',
                          icon: Icons.close_rounded,
                          color: p.error,
                          background: p.error.withValues(alpha: .12),
                        ),
                        HubPill(
                          '↑ / ↓ Hedefin yönü',
                          icon: Icons.swap_vert_rounded,
                          color: hubAmber(context),
                          background: hubAmber(context).withValues(alpha: .12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (round.guesses.isEmpty) _firstGuessPreview(),
                    for (var i = round.guesses.length - 1; i >= 0; i--)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _guessCard(round, i),
                      ),
                    const SizedBox(height: 8),
                    PitchPanel(
                      child: Row(
                        children: [
                          Icon(Icons.lock_clock_outlined, color: p.accent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              round.serverOwned
                                  ? 'Türkiye saatiyle 00.00’da yeni futbolcu. İlerlemen hesabında saklanır.'
                                  : 'Türkiye saatiyle 00.00’da yeni futbolcu. İlerlemen bu cihazda saklanır.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Before the first guess: the six traits every guess is compared on.
  Widget _firstGuessPreview() {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    const traits = ['ÜLKE', 'KULÜP', 'LİG', 'MEVKİ', 'YAŞ', 'FORMA'];
    return PitchPanel(
      child: Column(
        children: [
          HubIconBox(Icons.track_changes_rounded, size: 52),
          const SizedBox(height: 12),
          Text('İlk tahminini yap', style: text.titleMedium),
          const SizedBox(height: 6),
          Text(
            'İlk futbolcunu seç. Ülke, kulüp, lig, mevki, yaş ve forma numarası burada karşılaştırılacak.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: p.muted),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final trait in traits)
                Container(
                  constraints: const BoxConstraints(minWidth: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: p.background.withValues(alpha: .4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.border),
                  ),
                  child: Column(
                    children: [
                      Text(trait, style: hubCaps(context)),
                      const SizedBox(height: 2),
                      Text('–', style: text.labelLarge),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _suggestions(
    DailyFootballerController game,
    DailyFootballerRound round,
  ) {
    final matches = game.catalog.search(_search.text, round);
    if (matches.isEmpty)
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Eşleşen yeni futbolcu yok. Farklı bir isim dene.'),
      );
    return Column(
      children: [
        for (final player in matches)
          ListTile(
            key: ValueKey('guess-${player.id}'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(player.name),
            subtitle: Text('${player.club} · ${player.positionLabel}'),
            trailing: const Icon(Icons.arrow_forward_rounded),
            enabled: !game.busy,
            onTap: () async {
              FocusScope.of(context).unfocus();
              await game.guess(player.id);
              if (mounted &&
                  game.round?.guesses.any((g) => g.id == player.id) == true)
                setState(_search.clear);
            },
          ),
      ],
    );
  }

  Widget _result(DailyFootballerRound round) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: HubResultCard(
      tone: round.won ? HubResultTone.good : HubResultTone.neutral,
      icon: round.won ? Icons.person_search_rounded : Icons.lock_rounded,
      kicker: round.won ? 'Gizli ismi buldun!' : 'Bugünün dosyası kapandı',
      title: round.target.name,
      titleKey: const ValueKey('daily-answer'),
      subtitle:
          '${round.target.club} · ${round.target.country} · #${round.target.shirtNumber}',
      notes: [
        if (round.won) '${round.guesses.length}/${round.limit} tahminde buldun',
        if (round.assisted) 'Yardımlı sonuç · Ayrı başarı kaydı',
        'Yeni futbolcu yarın seni bekliyor.',
      ],
    ),
  );

  Widget _guessCard(DailyFootballerRound round, int index) => PitchPanel(
    key: ValueKey('guess-card-$index'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${index + 1}. ${round.guesses[index].name}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final minWidth =
                90 * MediaQuery.textScalerOf(context).scale(14) / 14;
            final cols = (constraints.maxWidth / minWidth)
                .floor()
                .clamp(1, 3)
                .toInt();
            final clues = round.compare(round.guesses[index]);
            return Column(
              children: [
                for (var start = 0; start < clues.length; start += cols)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: start + cols < clues.length ? 8 : 0,
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var col = 0; col < cols; col++) ...[
                            if (col > 0) const SizedBox(width: 8),
                            Expanded(child: _clue(clues[start + col])),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );

  Widget _clue(FootballerClue clue) {
    final p = PitchColors.of(context);
    final match = clue.match == FootballerMatch.same;
    final color = match ? p.success : p.muted;
    final icon = switch (clue.match) {
      FootballerMatch.same => Icons.check_rounded,
      FootballerMatch.different => Icons.close_rounded,
      FootballerMatch.higher => Icons.arrow_upward_rounded,
      FootballerMatch.lower => Icons.arrow_downward_rounded,
    };
    return Semantics(
      label: '${clue.label}: ${clue.value}. ${clue.feedback}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(minHeight: 108),
        decoration: BoxDecoration(
          color: match ? color.withValues(alpha: .1) : p.raised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: match ? color : p.border),
        ),
        child: Column(
          children: [
            Text(
              clue.label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: p.muted),
            ),
            const SizedBox(height: 5),
            Text(
              clue.value,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Icon(icon, size: 18, color: color),
            Text(
              clue.feedback,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
