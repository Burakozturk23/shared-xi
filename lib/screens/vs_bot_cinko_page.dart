import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_feedback.dart';
import '../controllers/vs_bot_cinko_controller.dart';
import '../controllers/vs_bot_controller.dart';
import '../models/cinko_models.dart';
import '../models/player.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/club_badge.dart';
import '../widgets/country_badge.dart';
import '../widgets/league_badge.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/rewarded_coin_card.dart';
import '../widgets/player_avatar.dart';

class VsBotCinkoPage extends StatefulWidget {
  const VsBotCinkoPage({super.key, this.controllerFactory});
  final VsBotCinkoController Function()? controllerFactory;

  @override
  State<VsBotCinkoPage> createState() => _VsBotCinkoPageState();
}

class _VsBotCinkoPageState extends State<VsBotCinkoPage>
    with WidgetsBindingObserver {
  late final VsBotCinkoController _c;
  final _answer = TextEditingController();
  final _focus = FocusNode();
  final _boardScroll = ScrollController();
  bool _foreground = true, _resumeOnForeground = false;
  bool _exitDialog = false, _allowExit = false, _zoom = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _c = (widget.controllerFactory?.call() ?? VsBotCinkoController())
      ..addListener(_changed);
    unawaited(_c.initialize());
  }

  void _changed() {
    if (!mounted) return;
    if (_c.phase == CinkoMatchPhase.loading) _answer.clear();
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && _c.phase == CinkoMatchPhase.playing) {
      _resumeOnForeground = true;
      _c.pause();
    } else if (_foreground && _resumeOnForeground && !_exitDialog) {
      _resumeOnForeground = false;
      _c.resume();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.removeListener(_changed);
    _c.dispose();
    _answer.dispose();
    _focus.dispose();
    _boardScroll.dispose();
    super.dispose();
  }

  Future<void> _requestExit() async {
    if (_exitDialog) return;
    final wasPlaying = _c.phase == CinkoMatchPhase.playing;
    _exitDialog = true;
    _c.pause();
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Maçtan çıkılsın mı?'),
        content: const Text('Bu tahtadaki ilerlemen kaybolur.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Oyuna dön'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çık'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _exitDialog = false;
    if (leave == true) {
      setState(() => _allowExit = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } else if (wasPlaying && _foreground) {
      _c.resume();
    } else if (wasPlaying) {
      _resumeOnForeground = true;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowExit || !_c.isInMatch,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(_requestExit());
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Futbol Çinko'),
        actions: [
          if (_c.phase == CinkoMatchPhase.playing)
            IconButton(
              tooltip: 'Oyunu duraklat',
              onPressed: () {
                _resumeOnForeground = false;
                _c.pause();
              },
              icon: const Icon(Icons.pause_rounded),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: switch (_c.phase) {
          CinkoMatchPhase.loading => _message(
            Icons.grid_on_rounded,
            'Tahta hazırlanıyor',
            'Kulüpler, milliyetler ve ligler yerlerini alıyor.',
            loading: true,
          ),
          CinkoMatchPhase.error => _message(
            Icons.refresh_rounded,
            'Tekrar deneyelim',
            _c.errorMessage!,
            action: PitchAction(label: 'Yeniden dene', onPressed: _c.restart),
          ),
          CinkoMatchPhase.paused => _message(
            Icons.pause_circle_outline,
            'Oyun duraklatıldı',
            'Tahtan ve sıran korunuyor.',
            action: PitchAction(
              label: 'Devam et',
              icon: Icons.play_arrow_rounded,
              onPressed: _foreground ? _c.resume : null,
            ),
          ),
          CinkoMatchPhase.ready => _game(ready: true),
          CinkoMatchPhase.playing => _game(),
          CinkoMatchPhase.finished => _result(),
        },
      ),
      bottomNavigationBar: _c.canSelect
          ? SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: PitchAction(
                label: _c.state.selectedCount == 0
                    ? 'Tahtadan kutu seç'
                    : '${_c.state.selectedCount} kutuyu onayla',
                icon: Icons.check_rounded,
                onPressed: _c.state.selectedCount == 0
                    ? null
                    : () {
                        if (_c.confirmSelection()) {
                          AppFeedback.answer(
                            correct: _c.lastMove!.wrong.isEmpty,
                          );
                        }
                      },
              ),
            )
          : null,
    ),
  );

  Color get _botColor => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFC4A7FF)
      : const Color(0xFF6B3ABE);

  Widget _message(
    IconData icon,
    String title,
    String description, {
    bool loading = false,
    Widget? action,
  }) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 32),
      Icon(icon, size: 48, color: PitchColors.of(context).accent),
      const SizedBox(height: 24),
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      Text(description),
      if (loading)
        const Padding(
          padding: EdgeInsets.only(top: 24),
          child: LinearProgressIndicator(),
        ),
      if (action != null)
        Padding(padding: const EdgeInsets.only(top: 24), child: action),
    ],
  );

  Widget _game({bool ready = false}) {
    final p = PitchColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (ready) ...[
          Text(
            'Bir futbolcu. Bir bağlantı.',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Tahtayı incele. Aynı futbolcuya uyan komşu kutuları birlikte kazan.',
            style: TextStyle(color: p.muted),
          ),
          const SizedBox(height: 16),
          _difficulty(),
          const SizedBox(height: 12),
          PitchAction(
            label: 'Maça başla',
            icon: Icons.play_arrow_rounded,
            onPressed: _foreground ? _c.begin : null,
          ),
        ] else ...[
          _scoreStrip(),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Icon(
                  _c.turn == VsBotCinkoTurn.bot
                      ? Icons.smart_toy_outlined
                      : Icons.touch_app_outlined,
                  color: _c.turn == VsBotCinkoTurn.bot ? _botColor : p.accent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _c.state.phase == CinkoPhase.revealing
                        ? 'Hamle sonucu'
                        : _c.turn == VsBotCinkoTurn.bot
                        ? 'Bot bağlantı kuruyor…'
                        : 'Sıra sende',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  '${_c.state.paintedCount}/${_c.state.totalCells}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: _c.state.paintedCount / _c.state.totalCells,
            backgroundColor: p.raised,
            color: p.accent,
            minHeight: 3,
          ),
          const SizedBox(height: 14),
          if (_c.canChoosePlayer) _answerPanel(),
          if (_c.canSelect) _selectionPanel(),
          if (_c.state.feedback != null) ...[
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Text(
                _c.state.feedback!,
                style: TextStyle(
                  color: _c.state.feedbackIsSuccess ? p.muted : p.error,
                ),
              ),
            ),
          ],
          if (_c.lastMove != null) ...[
            const SizedBox(height: 12),
            _moveTile(_c.lastMove!, latest: true),
          ],
        ],
        const SizedBox(height: 16),
        _board(),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _legend(Icons.person_outline, 'Sen', p.accent),
            _legend(Icons.smart_toy_outlined, 'Bot', _botColor),
            _legend(Icons.check_box_outlined, 'Seçili', p.accent),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Doğru +1 · Yanlış −1 · Pas 0\nYatay ve dikey bağlantı geçerli. L olur, çapraz olmaz.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (!ready &&
            _c.remainingPlayableCells <
                _c.state.totalCells - _c.state.paintedCount) ...[
          const SizedBox(height: 8),
          Text(
            'Kilitli kutular için kullanılmamış oyuncu kalmadı.',
            style: TextStyle(color: p.muted),
          ),
        ],
        if (_c.moves.length > 1) ...[const SizedBox(height: 12), _history()],
      ],
    );
  }

  Widget _difficulty() => PitchPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Botun seviyesi', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in VsBotDifficulty.values)
              ChoiceChip(
                label: Text(_difficultyLabel(d)),
                selected: _c.difficulty == d,
                onSelected: (_) => _c.setDifficulty(d),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(switch (_c.difficulty) {
          VsBotDifficulty.easy => 'Bot her hamlede 1 kutu kazanır.',
          VsBotDifficulty.medium =>
            'Bot bir hamlede en fazla 3 bağlı kutu kazanır.',
          VsBotDifficulty.hard => 'Bot mümkün olan en uzun bağlantıyı bulur.',
        }),
        const SizedBox(height: 4),
        Text(
          'Senin bağlantı uzunluğun sınırsız. Süre baskısı yok.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );

  String _difficultyLabel(VsBotDifficulty d) => switch (d) {
    VsBotDifficulty.easy => 'Kolay',
    VsBotDifficulty.medium => 'Orta',
    VsBotDifficulty.hard => 'Zor',
  };

  Widget _scoreStrip() => Row(
    children: [
      Expanded(
        child: _score(
          'Sen',
          _c.userScore,
          Icons.person_outline,
          PitchColors.of(context).accent,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _score(
          'Bot · ${_difficultyLabel(_c.difficulty)}',
          _c.botScore,
          Icons.smart_toy_outlined,
          _botColor,
        ),
      ),
    ],
  );

  Widget _score(String label, int value, IconData icon, Color color) =>
      PitchPanel(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('$value', style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      );

  Widget _answerPanel() => PitchPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '01  Futbolcunu seç',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('cinko-answer'),
          controller: _answer,
          focusNode: _focus,
          onChanged: _c.updateSuggestions,
          onSubmitted: (_) => _submit(),
          textInputAction: TextInputAction.done,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Futbolcu adı',
            hintText: 'Örn. Thierry Henry',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        if (_c.suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _c.suggestions.length,
              itemBuilder: (context, index) {
                final player = _c.suggestions[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: PlayerAvatar(player: player, size: 32),
                  title: Text(player.name),
                  subtitle: Text(player.countryLabel),
                  onTap: () => _submit(player),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 12),
        PitchAction(label: 'Kutuları seç', onPressed: _submit),
        TextButton(onPressed: _pass, child: const Text('Pas geç · 0 puan')),
      ],
    ),
  );

  void _submit([Player? player]) {
    final accepted = player == null
        ? _c.submitPlayerName(_answer.text)
        : _c.submitResolvedPlayer(player);
    if (accepted) {
      _answer.clear();
      _focus.unfocus();
      AppFeedback.selection();
    }
  }

  void _pass() {
    _answer.clear();
    _focus.unfocus();
    _c.pass();
  }

  Widget _selectionPanel() {
    final player = _c.state.currentPlayer!;
    return PitchPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '02  Bağlantını kur',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              PlayerAvatar(player: player, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${_c.state.selectedCount} kutu seçili',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: _c.cancelSelection,
                child: const Text('Oyuncuyu değiştir'),
              ),
              TextButton(onPressed: _pass, child: const Text('Pas geç')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _board() {
    final p = PitchColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'ORTAK TAHTA',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: p.muted),
              ),
            ),
            IconButton(
              tooltip: _zoom ? 'Tahtayı küçült' : 'Tahtayı büyüt',
              onPressed: () => setState(() => _zoom = !_zoom),
              icon: Icon(
                _zoom ? Icons.zoom_out_rounded : Icons.zoom_in_rounded,
              ),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(11) / 11;
            final minWidth =
                (_zoom ? 108 : 62) * scale * _c.gridSize +
                6 * (_c.gridSize - 1);
            final width = math.max(constraints.maxWidth, minWidth);
            final scrolls = width > constraints.maxWidth;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (scrolls)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Tahtayı yana kaydırabilirsin ↔',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                Scrollbar(
                  controller: _boardScroll,
                  thumbVisibility: scrolls,
                  child: SingleChildScrollView(
                    controller: _boardScroll,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.only(bottom: scrolls ? 12 : 0),
                    child: SizedBox(
                      width: width,
                      child: Column(
                        children: [
                          for (var row = 0; row < _c.gridSize; row++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: row == _c.gridSize - 1 ? 0 : 6,
                              ),
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (
                                      var col = 0;
                                      col < _c.gridSize;
                                      col++
                                    ) ...[
                                      if (col > 0) const SizedBox(width: 6),
                                      Expanded(
                                        child: _cell(row * _c.gridSize + col),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _cell(int index) {
    final cell = _c.state.cells[index];
    final p = PitchColors.of(context);
    final selected = cell.status == CinkoCellStatus.selected;
    final wrong = cell.status == CinkoCellStatus.wrongFlash;
    final owned = cell.status == CinkoCellStatus.correct;
    final locked = !owned && !wrong && !_c.isCellPlayable(index);
    final color = wrong
        ? p.error
        : cell.owner == 2
        ? _botColor
        : (selected || owned)
        ? p.accent
        : p.border;
    final statusIcon = wrong
        ? Icons.close_rounded
        : cell.owner == 2
        ? Icons.smart_toy_outlined
        : owned
        ? Icons.person_outline
        : selected
        ? Icons.check_box_rounded
        : locked
        ? Icons.lock_outline
        : Icons.check_box_outline_blank;
    final coordinate =
        '${String.fromCharCode(65 + index ~/ _c.gridSize)}${index % _c.gridSize + 1}';
    final status = wrong
        ? 'Yanlış'
        : owned
        ? (cell.owner == 2 ? 'Botun kutusu' : 'Senin kutun')
        : selected
        ? 'Seçili'
        : locked
        ? 'Oyuncu kalmadı'
        : 'Açık';
    final canTap = _c.canSelect && !owned && !locked;
    final club = _c.session!.clubs[cell.clubId];
    final claimant = _c.claimedByPlayer[index];
    return Semantics(
      label:
          '$coordinate, ${cell.label}, $status${claimant == null ? '' : ', ${claimant.name}'}',
      button: canTap,
      selected: selected,
      child: Tooltip(
        message:
            '${cell.label}\n$status${claimant == null ? '' : ' · ${claimant.name}'}',
        child: Material(
          color: (owned || selected || wrong)
              ? Color.alphaBlend(color.withValues(alpha: .13), p.surface)
              : locked
              ? p.raised
              : p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color, width: selected ? 2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: canTap
                ? () {
                    if (_c.toggleCell(index)) AppFeedback.selection();
                  }
                : null,
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(5, 7, 5, 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            coordinate,
                            style: TextStyle(fontSize: 9, color: p.muted),
                          ),
                        ),
                        Icon(
                          statusIcon,
                          size: 14,
                          color: (owned || selected || wrong) ? color : p.muted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (cell.type == CinkoCellType.club && club != null)
                      ClubBadge(club: club, size: 30)
                    else if (cell.type == CinkoCellType.country)
                      CountryBadge(country: cell.label, width: 30, height: 22)
                    else if (cell.type == CinkoCellType.league)
                      LeagueBadge(league: cell.label, size: 28)
                    else
                      Icon(Icons.shield_outlined, size: 28, color: p.muted),
                    const SizedBox(height: 6),
                    Text(
                      cell.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: p.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _legend(IconData icon, String text, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 5),
      Text(text, style: Theme.of(context).textTheme.labelSmall),
    ],
  );

  Widget _moveTile(CinkoMove move, {bool latest = false}) {
    final p = PitchColors.of(context);
    final title = move.passed ? 'Pas geçildi' : move.player!.name;
    return PitchPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            move.byUser ? Icons.person_outline : Icons.smart_toy_outlined,
            color: move.byUser ? p.accent : _botColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${latest ? 'Son hamle · ' : ''}${move.byUser ? 'Sen' : 'Bot'}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                if (!move.passed)
                  Text(
                    '${move.correct.length} doğru · ${move.wrong.length} yanlış',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${move.points >= 0 ? '+' : ''}${move.points}',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: move.points < 0 ? p.error : p.text),
          ),
        ],
      ),
    );
  }

  Widget _history() => ExpansionTile(
    key: const PageStorageKey<String>('cinko-history'),
    tilePadding: EdgeInsets.zero,
    title: const Text('Hamle geçmişi'),
    subtitle: Text('${_c.moves.length} hamle'),
    children: [
      for (final move in _c.moves.reversed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _moveTile(move),
        ),
    ],
  );

  Widget _result() {
    final won = _c.userScore > _c.botScore;
    final draw = _c.userScore == _c.botScore;
    final wrong = _c.moves
        .where((m) => m.byUser)
        .fold<int>(0, (sum, m) => sum + m.wrong.length);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        Icon(
          draw
              ? Icons.handshake_outlined
              : won
              ? Icons.emoji_events_outlined
              : Icons.smart_toy_outlined,
          size: 52,
          color: won
              ? PitchColors.of(context).limeInk
              : PitchColors.of(context).accent,
        ),
        const SizedBox(height: 16),
        Text(
          draw
              ? 'Berabere!'
              : won
              ? 'Saha senin!'
              : 'Bu kez bot kazandı.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          _c.endReason == CinkoEndReason.boardCompleted
              ? 'Tüm kutular tamamlandı.'
              : 'Açık kutular için kullanılmamış oyuncu kalmadı. Maç mevcut puanlarla bitti.',
        ),
        const SizedBox(height: 20),
        _scoreStrip(),
        const SizedBox(height: 12),
        Text(
          '${_c.state.paintedCount}/${_c.state.totalCells} kutu kazanıldı · Senin yanlış seçimin: $wrong',
        ),
        const SizedBox(height: 20),
        PitchAction(
          label: 'Yeniden oyna',
          icon: Icons.replay_rounded,
          onPressed: () {
            _zoom = false;
            _c.restart();
          },
        ),
        const SizedBox(height: 10),
        PitchAction(
          label: 'Kurallara dön',
          secondary: true,
          neutral: true,
          icon: Icons.arrow_back_rounded,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 16),
        const RewardedCoinCard(placement: 'cinko_result'),
        _history(),
        const SizedBox(height: 12),
        _board(),
      ],
    );
  }
}
