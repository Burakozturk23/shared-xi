import 'package:flutter/material.dart';

import '../app/app_feedback.dart';
import '../controllers/loto_bot_controller.dart';
import '../models/loto_models.dart';
import '../services/loto_generator.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/loto_board_view.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/rewarded_coin_card.dart';
import '../widgets/player_avatar.dart';

class LotoBotPage extends StatefulWidget {
  const LotoBotPage({super.key, this.controllerFactory});
  final LotoBotController Function()? controllerFactory;
  @override
  State<LotoBotPage> createState() => _LotoBotPageState();
}

class _LotoBotPageState extends State<LotoBotPage> with WidgetsBindingObserver {
  late final LotoBotController _c;
  String? _league;
  LotoDifficulty _difficulty = LotoDifficulty.medium;
  bool _foreground = true, _allowExit = false, _exitDialog = false;
  bool _reviewBot = false;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null ||
        (lifecycle != AppLifecycleState.paused &&
            lifecycle != AppLifecycleState.inactive &&
            lifecycle != AppLifecycleState.hidden);
    WidgetsBinding.instance.addObserver(this);
    _c = (widget.controllerFactory?.call() ?? LotoBotController())
      ..addListener(_changed);
  }

  void _changed() { if (mounted) setState(() {}); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _c.pause();
    // Resume controls must become enabled after returning to the foreground.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.removeListener(_changed);
    _c.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_c.phase == LotoBotPhase.loading) return;
    _reviewBot = false;
    await _c.prepare(league: _league, difficulty: _difficulty);
    if (!mounted || _c.phase != LotoBotPhase.ready) return;
    // The ready board is rendered once before either clock starts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _foreground && !_exitDialog) _c.begin();
    });
  }

  Future<void> _pickLeague() async {
    final selected = await showModalBottomSheet<String>(
      context: context, isScrollControlled: true, useSafeArea: true,
      builder: (_) => _LeaguePicker(selected: _league));
    if (mounted && selected != null) {
      setState(() => _league = selected.isEmpty ? null : selected);
    }
  }

  Future<void> _requestExit() async {
    if (_exitDialog) return;
    _exitDialog = true;
    final wasPlaying = _c.phase == LotoBotPhase.playing;
    _c.pause();
    final leave = await showDialog<bool>(context: context,
      builder: (context) => AlertDialog(
        title: const Text('Maçtan çıkılsın mı?'),
        content: const Text('Bu maçın ilerlemesi kaybolur.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Maça dön')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Maçtan çık')),
        ],
      ));
    if (!mounted) return;
    _exitDialog = false;
    if (leave == true) {
      setState(() => _allowExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } else if (wasPlaying && _foreground) {
      _c.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final inMatch = [LotoBotPhase.ready, LotoBotPhase.playing,
      LotoBotPhase.paused].contains(_c.phase);
    return PopScope(
      canPop: _allowExit || !inMatch,
      onPopInvokedWithResult: (didPop, result) { if (!didPop) _requestExit(); },
      child: Scaffold(
        appBar: AppBar(title: const Text('Football Loto'), actions: [
          if (_c.phase == LotoBotPhase.playing)
            IconButton(tooltip: 'Maçı duraklat', onPressed: _c.pause,
              icon: const Icon(Icons.pause_rounded)),
        ]),
        body: SafeArea(top: false, child: switch (_c.phase) {
          LotoBotPhase.setup => _setup(),
          LotoBotPhase.loading => _message('Tahtan hazırlanıyor',
            'Ligine uygun oyuncular ve kutular seçiliyor. Süren henüz başlamadı.',
            loading: true),
          LotoBotPhase.error => _message('Maç hazırlanamadı',
            'Bu seçim için tam bir tahta oluşturulamadı. Yeniden deneyebilir veya ligini değiştirebilirsin.',
            actions: [PitchAction(label: 'Yeniden dene', onPressed: _start),
              const SizedBox(height: 12),
              PitchAction(label: 'Seçimleri değiştir', secondary: true,
                onPressed: _c.reset)]),
          LotoBotPhase.paused => _message('Maç duraklatıldı',
            'Senin süren ve bot bekliyor. Kaldığın yerden devam edebilirsin.',
            actions: [PitchAction(label: 'Devam et', icon: Icons.play_arrow_rounded,
              onPressed: _foreground ? _c.resume : null)]),
          LotoBotPhase.ready || LotoBotPhase.playing => _game(),
          LotoBotPhase.finished => _result(),
        }),
      ),
    );
  }

  Widget _setup() => ListView(
    key: const PageStorageKey('loto-setup'), padding: const EdgeInsets.all(16),
    children: [
      Text('Bilgini tahtaya yerleştir.',
        style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('16 futbolcu, 16 kutu. Doğru eşleşmeleri bul, botun puanını geç.'),
      const SizedBox(height: 24),
      PitchRow(title: _league ?? 'Tüm ligler', subtitle: 'Oyuncu havuzunu seç',
        icon: Icons.emoji_events_outlined, highlight: true, onTap: _pickLeague),
      const PitchSectionTitle('Zorluk'),
      for (final difficulty in LotoDifficulty.values) ...[
        Semantics(button: true, selected: _difficulty == difficulty,
          child: PitchPanel(onTap: () {
            AppFeedback.selection();
            setState(() => _difficulty = difficulty);
          }, child: Row(children: [
            Icon(_difficulty == difficulty ? Icons.radio_button_checked
              : Icons.radio_button_off, color: PitchColors.of(context).accent),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(difficulty.label, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text('${difficulty.secondsPerPlayer} sn / oyuncu · ${_difficultyCaption(difficulty)}',
                  style: Theme.of(context).textTheme.bodySmall),
              ])),
          ]))),
        const SizedBox(height: 12),
      ],
      const SizedBox(height: 12),
      PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Maçın özeti', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          const Text('Her doğru yerleştirme +10 puan. Yanlış, pas ve süre aşımı 0 puan.'),
          const SizedBox(height: 8),
          Text('Cevaplar maç sonunda açılır. Sen ve bot aynı oyuncularla ayrı tahtalarda oynarsınız.',
            style: Theme.of(context).textTheme.bodySmall),
        ])),
      const SizedBox(height: 24),
      PitchAction(label: 'Maça başla', onPressed: _start),
    ],
  );

  String _difficultyCaption(LotoDifficulty difficulty) => switch (difficulty) {
    LotoDifficulty.easy => 'Daha tanıdık oyuncular, daha rahat bot.',
    LotoDifficulty.medium => 'Dengeli oyuncu havuzu ve bot.',
    LotoDifficulty.hard => 'Daha zor oyuncular, daha isabetli bot.',
  };

  Widget _message(String title, String text,
    {bool loading = false, List<Widget> actions = const []}) => ListView(
    padding: const EdgeInsets.all(24), children: [
      const SizedBox(height: 32),
      Align(alignment: Alignment.centerLeft, child: loading
        ? const SizedBox.square(dimension: 32, child: CircularProgressIndicator())
        : Icon(Icons.sports_soccer, size: 40, color: PitchColors.of(context).accent)),
      const SizedBox(height: 24),
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12), Text(text),
      if (actions.isNotEmpty) const SizedBox(height: 32), ...actions,
    ],
  );

  Widget _progress() => PitchPanel(padding: const EdgeInsets.all(12),
    child: Row(children: [
      Expanded(child: Text('Sen  ${_c.humanIndex}/16',
        style: Theme.of(context).textTheme.titleSmall)),
      Icon(Icons.sports_soccer, color: PitchColors.of(context).muted, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text('Bot  ${_c.botIndex}/16', textAlign: TextAlign.end,
        style: Theme.of(context).textTheme.titleSmall)),
    ]));

  Widget _game() => LayoutBuilder(builder: (context, constraints) {
    final compact = constraints.maxHeight < 520 ||
        MediaQuery.textScalerOf(context).scale(14) / 14 > 1.4;
    final index = _c.humanIndex;
    final board = LotoBoardView(board: _c.session!.board,
      players: _c.session!.players, placements: _c.humanPlacements,
      onPlace: _c.humanFinished || _c.phase != LotoBotPhase.playing ? null : (cell) {
        if (_c.place(cell, expectedIndex: index)) AppFeedback.selection();
      });
    if (compact) {
      return ListView(key: const PageStorageKey('loto-game-readable'),
        padding: const EdgeInsets.all(16), children: [
          _progress(), const SizedBox(height: 16), board,
          const SizedBox(height: 16), _activePlayer(),
        ]);
    }
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: _progress()),
      Expanded(child: ListView(key: const PageStorageKey('loto-board-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [board])),
      Container(decoration: BoxDecoration(color: PitchColors.of(context).background,
        border: Border(top: BorderSide(color: PitchColors.of(context).border))),
        padding: const EdgeInsets.all(16), child: _activePlayer()),
    ]);
  });

  Widget _activePlayer() {
    final index = _c.humanIndex;
    final player = _c.currentPlayer;
    final p = PitchColors.of(context);
    if (_c.phase == LotoBotPhase.ready) {
      return PitchAction(label: 'Oyuna başla', onPressed: _foreground ? _c.begin : null);
    }
    if (_c.humanFinished) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tahtanı tamamladın.', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Bot tamamlıyor: ${_c.botIndex}/16', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        PitchAction(label: 'Sonucu göster', onPressed: _c.completeBot),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          PlayerAvatar(player: player!, size: 40), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Oyuncu ${index + 1} / 16', style: Theme.of(context).textTheme.labelMedium),
              Text(player.name, style: Theme.of(context).textTheme.titleMedium),
            ])),
          const SizedBox(width: 12),
          Semantics(label: 'Kalan süre ${_c.seconds} saniye', excludeSemantics: true,
            child: Text('${_c.seconds} sn', style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: _c.seconds <= 5 ? p.error : p.accent))),
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: _c.seconds / _c.difficulty.secondsPerPlayer,
          color: _c.seconds <= 5 ? p.error : p.accent, backgroundColor: p.raised, minHeight: 4),
        const SizedBox(height: 8),
        Text('Uygun bir boş kutuya dokun. Cevaplar maç sonunda açılır.',
          style: Theme.of(context).textTheme.bodySmall),
        if (_c.notice.isNotEmpty) ...[
          const SizedBox(height: 4),
          Semantics(liveRegion: true, child: Text(_c.notice,
            style: Theme.of(context).textTheme.bodySmall)),
        ],
        const SizedBox(height: 8),
        PitchAction(label: 'Pas geç', secondary: true, neutral: true,
          icon: Icons.skip_next_rounded, onPressed: () => _c.pass(expectedIndex: index)),
      ]);
  }

  Widget _result() {
    final human = _c.score(), bot = _c.score(bot: true);
    final draw = human.points == bot.points, win = human.points > bot.points;
    final p = PitchColors.of(context);
    return ListView(key: const PageStorageKey('loto-result'),
      padding: const EdgeInsets.all(16), children: [
        PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(win ? Icons.emoji_events_outlined : Icons.sports_soccer,
              color: win ? p.success : p.accent, size: 40),
            const SizedBox(height: 16),
            Text(draw ? 'Berabere!' : win ? 'Maç senin!' : 'Bu kez bot kazandı.',
              style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('${_league ?? "Tüm ligler"} · ${_difficulty.label}',
              style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Wrap(spacing: 32, runSpacing: 12, children: [
              _scoreSummary('Sen', human), _scoreSummary('Bot', bot)]),
            const SizedBox(height: 12),
            Text('Doğru +10 · Yanlış, pas ve süre aşımı 0',
              style: Theme.of(context).textTheme.bodySmall),
          ])),
        const SizedBox(height: 16),
        PitchAction(label: 'Yeni maç', onPressed: _start, icon: Icons.replay_rounded),
        const SizedBox(height: 12),
        PitchAction(label: 'Lig ve zorluğu değiştir', secondary: true,
          onPressed: _c.reset, icon: Icons.tune_rounded),
        const RewardedCoinCard(placement: 'loto_result'),
        const PitchSectionTitle('Eşleşmeleri incele'),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('Sen'), selected: !_reviewBot,
            onSelected: (_) => setState(() => _reviewBot = false)),
          ChoiceChip(label: const Text('Bot'), selected: _reviewBot,
            onSelected: (_) => setState(() => _reviewBot = true)),
        ]),
        const SizedBox(height: 12),
        for (final id in _c.session!.board.playerQueue) ...[
          _reviewRow(id), const SizedBox(height: 12),
        ],
      ]);
  }

  Widget _scoreSummary(String who, LotoBotScore score) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(who, style: Theme.of(context).textTheme.titleSmall),
      Text('${score.points} puan', style: Theme.of(context).textTheme.headlineSmall),
      Text('${score.correct} doğru · ${score.wrong} yanlış',
        style: Theme.of(context).textTheme.bodySmall),
      Text('${score.passed} pas · ${score.timedOut} süre aşımı',
        style: Theme.of(context).textTheme.bodySmall),
    ]);

  Widget _reviewRow(int id) {
    final session = _c.session!, board = _c.session!.board;
    final placements = _reviewBot ? _c.botPlacements : _c.humanPlacements;
    final selected = placements.entries.where((e) => e.value == id);
    final cell = selected.isEmpty ? null : selected.first.key;
    final valid = board.validCellsForPlayer[id]!;
    final correct = cell != null && valid.contains(cell);
    final label = cell != null
        ? correct ? 'Doğru · +10' : 'Yanlış · 0'
        : _reviewBot
            ? 'Yerleştirilmedi · 0'
            : _c.skips[id] == LotoSkipReason.timeout
                ? 'Süre doldu · 0'
                : 'Pas · 0';
    final p = PitchColors.of(context);
    return PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(correct ? Icons.check_circle_outline : cell == null
            ? Icons.skip_next_rounded : Icons.cancel_outlined,
            color: correct ? p.success : cell == null ? p.muted : p.error),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(session.players[id]!.name, style: Theme.of(context).textTheme.titleSmall),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ])),
        ]),
        const SizedBox(height: 8),
        Text(cell == null ? 'Yerleştirme yapılmadı.' : 'Seçim: ${board.cells[cell].label}'),
        if (!correct) ...[
          const SizedBox(height: 4),
          Text('Uygun kutular: ${(valid.toList()..sort()).map((i) => board.cells[i].label).join(", ")}',
            style: Theme.of(context).textTheme.bodySmall),
        ],
      ]));
  }
}

class _LeaguePicker extends StatefulWidget {
  const _LeaguePicker({required this.selected});
  final String? selected;
  @override
  State<_LeaguePicker> createState() => _LeaguePickerState();
}

class _LeaguePickerState extends State<_LeaguePicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final leagues = LotoGenerator.availableLeagues()
      .where((league) => league != 'Super Liga Srbije')
      .where((league) => league.toLowerCase().contains(_query.toLowerCase())).toList();
    return Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(heightFactor: .85,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text('Lig havuzu', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(decoration: const InputDecoration(hintText: 'Lig ara',
              prefixIcon: Icon(Icons.search)), onChanged: (value) => setState(() => _query = value)),
            const SizedBox(height: 12),
            if (_query.isEmpty) ListTile(title: const Text('Tüm ligler'),
              trailing: widget.selected == null ? const Icon(Icons.check_rounded) : null,
              onTap: () => Navigator.pop(context, '')),
            for (final league in leagues) ListTile(title: Text(league),
              trailing: widget.selected == league ? const Icon(Icons.check_rounded) : null,
              onTap: () => Navigator.pop(context, league)),
            if (leagues.isEmpty) const Padding(padding: EdgeInsets.all(16),
              child: Text('Bu aramayla eşleşen lig bulunamadı.')),
          ]),
      ));
  }
}
