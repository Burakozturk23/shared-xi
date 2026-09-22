import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/classic_grid_bot_controller.dart';
import '../controllers/vs_bot_controller.dart';
import '../models/grid_criterion.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/player_avatar.dart';

/// Modern, self-contained 3×3 grid game.
///
/// The route only starts a V4 session after it is opened from the rules page;
/// no legacy Repository initialization is needed for this mode.
class ClassicGridPage extends StatefulWidget {
  const ClassicGridPage({
    super.key,
    this.difficulty = VsBotDifficulty.medium,
    this.controllerFactory,
  });

  final VsBotDifficulty difficulty;
  final ClassicGridBotController Function()? controllerFactory;

  @override
  State<ClassicGridPage> createState() => _ClassicGridPageState();
}

class _ClassicGridPageState extends State<ClassicGridPage>
    with WidgetsBindingObserver {
  late final ClassicGridBotController _c;
  final TextEditingController _answerController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _foreground = true;
  bool _allowExit = false;
  bool _exitDialog = false;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground =
        lifecycle == null ||
        (lifecycle != AppLifecycleState.paused &&
            lifecycle != AppLifecycleState.inactive &&
            lifecycle != AppLifecycleState.hidden);
    WidgetsBinding.instance.addObserver(this);
    _c =
        (widget.controllerFactory?.call() ??
              ClassicGridBotController(difficulty: widget.difficulty))
          ..addListener(_changed);
    unawaited(_c.prepare());
  }

  void _changed() {
    if (!mounted) return;
    if ((_c.selectedIndex == null || _c.turn != ClassicGridTurn.user) &&
        _answerController.text.isNotEmpty) {
      _answerController.clear();
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _c.pause();
    } else if (_c.phase == ClassicGridPhase.paused && !_exitDialog) {
      _c.resume();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.removeListener(_changed);
    _c.dispose();
    _answerController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _requestExit() async {
    if (_exitDialog) return;
    _exitDialog = true;
    final wasInMatch = _c.isInMatch;
    _c.pause();
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grid’den çıkılsın mı?'),
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
    } else if (wasInMatch &&
        _foreground &&
        _c.phase == ClassicGridPhase.paused) {
      _c.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final inMatch = _c.isInMatch;
    return PopScope(
      canPop: _allowExit || !inMatch,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_requestExit());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Klasik Grid'),
          actions: [
            if (_c.phase == ClassicGridPhase.playing)
              IconButton(
                tooltip: 'Oyunu duraklat',
                onPressed: _c.pause,
                icon: const Icon(Icons.pause_rounded),
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: switch (_c.phase) {
            ClassicGridPhase.loading => _message(
              Icons.grid_view_rounded,
              'Tahta hazırlanıyor',
              'V4 futbolcu havuzundan her hücresi çözülebilir bir grid kuruluyor.',
              loading: true,
            ),
            ClassicGridPhase.error => _message(
              Icons.cloud_off_outlined,
              'Grid hazırlanamadı',
              _c.errorMessage ?? 'Uygun bir tahta bulunamadı.',
              actions: [
                PitchAction(label: 'Yeniden dene', onPressed: _c.retry),
                const SizedBox(height: 12),
                PitchAction(
                  label: 'Geri dön',
                  secondary: true,
                  neutral: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            ClassicGridPhase.paused => _message(
              Icons.pause_circle_outline_rounded,
              'Oyun duraklatıldı',
              'Sıra ve tahta korunuyor. Hazır olduğunda kaldığın yerden devam et.',
              actions: [
                PitchAction(
                  label: 'Devam et',
                  icon: Icons.play_arrow_rounded,
                  onPressed: _foreground ? _c.resume : null,
                ),
              ],
            ),
            ClassicGridPhase.ready => _game(ready: true),
            ClassicGridPhase.playing => _game(),
            ClassicGridPhase.finished => _result(),
          },
        ),
      ),
    );
  }

  Widget _message(
    IconData icon,
    String title,
    String text, {
    bool loading = false,
    List<Widget> actions = const <Widget>[],
  }) {
    final p = PitchColors.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 32),
        Icon(icon, size: 44, color: p.accent),
        const SizedBox(height: 20),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(text),
        if (loading) ...[
          const SizedBox(height: 24),
          const LinearProgressIndicator(minHeight: 4),
        ],
        if (actions.isNotEmpty) ...[const SizedBox(height: 28), ...actions],
      ],
    );
  }

  Widget _game({bool ready = false}) {
    final p = PitchColors.of(context);
    final turnText = _c.turn == ClassicGridTurn.user
        ? 'Sıra sende'
        : 'Bot düşünüyor…';
    return ListView(
      key: const PageStorageKey('classic-grid-game'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _scoreStrip(p),
        const SizedBox(height: 12),
        PitchPanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                _c.turn == ClassicGridTurn.user
                    ? Icons.touch_app_outlined
                    : Icons.smart_toy_outlined,
                color: _c.turn == ClassicGridTurn.user ? p.accent : p.error,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ready ? 'Tahtayı incele, sonra başla.' : turnText,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                '${_c.userScore + _c.botScore}/9',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _board(p, enabled: !ready),
        if (_c.feedback != null) ...[
          const SizedBox(height: 10),
          _feedbackBanner(p),
        ],
        if (!ready &&
            _c.selectedIndex != null &&
            _c.turn == ClassicGridTurn.user) ...[
          const SizedBox(height: 12),
          _answerPanel(p),
        ],
        if (ready) ...[
          const SizedBox(height: 16),
          PitchAction(
            label: 'Tahtayı başlat',
            icon: Icons.play_arrow_rounded,
            onPressed: _c.begin,
          ),
          const SizedBox(height: 10),
          Text(
            'Bir kutu seç, satır ve sütun kriterlerinin kesişimine uyan oyuncuyu yaz. Yanlış cevapta sıra bota geçer.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (!ready && _c.selectedIndex == null) ...[
          const SizedBox(height: 14),
          Text(
            _c.turn == ClassicGridTurn.user
                ? 'Boş bir kutuya dokun ve ortak oyuncuyu bul.'
                : 'Bot hamlesini tamamlıyor…',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const PitchSectionTitle('Nasıl kazanırsın?'),
        PitchPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: p.limeInk),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Yatay, dikey veya çapraz üç kutuyu tamamla. Bir oyuncuyu aynı tahtada ikinci kez kullanamazsın.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scoreStrip(PitchColors p) => Row(
    children: [
      Expanded(child: _scoreCard('Sen', _c.userScore, p.accent)),
      const SizedBox(width: 12),
      Expanded(child: _scoreCard('Bot', _c.botScore, p.error)),
    ],
  );

  Widget _scoreCard(String title, int score, Color color) => PitchPanel(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color),
          ),
        ),
        Text('$score', style: Theme.of(context).textTheme.headlineSmall),
      ],
    ),
  );

  Widget _board(PitchColors p, {required bool enabled}) {
    final rows = _c.rows;
    final cols = _c.cols;
    if (rows.length != 3 || cols.length != 3) {
      return PitchPanel(
        child: Text(
          'Kriterler yükleniyor…',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return PitchPanel(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rowHeaderWidth = (constraints.maxWidth * .24)
              .clamp(68.0, 96.0)
              .toDouble();
          return Column(
            children: [
              Row(
                children: [
                  SizedBox(width: rowHeaderWidth),
                  for (final criterion in cols)
                    Expanded(child: _criterionHeader(criterion)),
                ],
              ),
              const SizedBox(height: 6),
              for (var row = 0; row < 3; row++)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: rowHeaderWidth,
                      height: 88,
                      child: _criterionHeader(rows[row], rowHeader: true),
                    ),
                    for (var col = 0; col < 3; col++)
                      Expanded(
                        child: SizedBox(
                          height: 88,
                          child: _cell(row * 3 + col, p, enabled: enabled),
                        ),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _criterionHeader(GridCriterion criterion, {bool rowHeader = false}) {
    final p = PitchColors.of(context);
    final type = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.all(3),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: p.raised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_criterionIcon(criterion), color: p.accent, size: 18),
          const SizedBox(height: 3),
          Text(
            criterion.label,
            maxLines: rowHeader ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: type.labelSmall?.copyWith(
              color: p.text,
              fontWeight: FontWeight.w600,
              fontSize: 10,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  IconData _criterionIcon(GridCriterion criterion) => switch (criterion.type) {
    GridCriterionType.club => Icons.shield_outlined,
    GridCriterionType.country => Icons.flag_outlined,
    GridCriterionType.position => Icons.sports_soccer_outlined,
    GridCriterionType.goals => Icons.emoji_events_outlined,
  };

  Widget _cell(int index, PitchColors p, {required bool enabled}) {
    final owner = _c.owners[index];
    final player = _c.cells[index];
    final selected = _c.selectedIndex == index;
    final canTap =
        enabled &&
        _c.phase == ClassicGridPhase.playing &&
        _c.turn == ClassicGridTurn.user &&
        owner == 0;
    final color = owner == 1
        ? p.accent
        : owner == 2
        ? p.error
        : selected
        ? p.accent
        : p.border;
    final bg = owner == 1
        ? p.tint.withValues(alpha: .65)
        : owner == 2
        ? p.error.withValues(alpha: .12)
        : selected
        ? p.tint.withValues(alpha: .35)
        : p.surface;
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
          side: BorderSide(color: color, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: canTap ? () => _c.openCell(index) : null,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: player == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selected ? Icons.edit_rounded : Icons.add_rounded,
                        color: selected ? p.accent : p.muted,
                        size: 22,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selected ? 'Cevapla' : 'Boş',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PlayerAvatar(player: player, size: 29),
                      const SizedBox(height: 3),
                      Text(
                        player.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: owner == 1 ? p.accent : p.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _answerPanel(PitchColors p) {
    final index = _c.selectedIndex!;
    final row = _c.rows[index ~/ 3];
    final col = _c.cols[index % 3];
    return PitchPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bu kesişimi doldur',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '${row.label}  ×  ${col.label}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _answerController,
            focusNode: _focusNode,
            autofocus: true,
            onChanged: _c.updateSuggestions,
            onSubmitted: (_) => _submit(),
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'Oyuncu adını yaz',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          if (_c.suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 184),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _c.suggestions.length,
                separatorBuilder: (_, _) => Divider(color: p.border, height: 1),
                itemBuilder: (context, itemIndex) {
                  final player = _c.suggestions[itemIndex];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: PlayerAvatar(player: player, size: 34),
                    title: Text(player.name),
                    subtitle: Text(
                      '${player.position} · ${player.countryLabel}',
                    ),
                    onTap: () {
                      _c.submitPlayer(player);
                      _answerController.clear();
                      _focusNode.requestFocus();
                    },
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PitchAction(
                  label: 'İptal',
                  secondary: true,
                  neutral: true,
                  icon: Icons.close_rounded,
                  onPressed: () {
                    _c.cancelSelection();
                    _focusNode.unfocus();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: PitchAction(label: 'Cevabı gönder', onPressed: _submit),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _submit() {
    _c.submitAnswer(_answerController.text);
    _answerController.clear();
    _focusNode.unfocus();
  }

  Widget _feedbackBanner(PitchColors p) {
    final color = _c.feedbackOk ? p.success : p.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          Icon(
            _c.feedbackOk ? Icons.check_circle_outline : Icons.info_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(_c.feedback!)),
        ],
      ),
    );
  }

  Widget _result() {
    final p = PitchColors.of(context);
    final userWon =
        _c.lineWinner == 1 ||
        (_c.lineWinner == 0 && _c.userScore > _c.botScore);
    final draw = _c.lineWinner == 0 && _c.userScore == _c.botScore;
    final title = draw
        ? 'Tahta berabere'
        : userWon
        ? 'Grid’i kazandın!'
        : 'Bot grid’i kazandı';
    final subtitle = _c.lineWinner == 1
        ? 'Üç kutuyu aynı çizgide tamamladın.'
        : _c.lineWinner == 2
        ? 'Bot üç kutuyu aynı çizgide tamamladı.'
        : 'Tahta doldu; daha çok kutu alan kazandı.';
    return ListView(
      key: const PageStorageKey('classic-grid-result'),
      padding: const EdgeInsets.all(16),
      children: [
        PitchPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                userWon ? Icons.emoji_events_outlined : Icons.grid_view_rounded,
                size: 44,
                color: userWon ? p.success : p.accent,
              ),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Sen  ${_c.userScore}  –  ${_c.botScore}  Bot',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PitchAction(
          label: 'Yeni tahta',
          icon: Icons.replay_rounded,
          onPressed: _c.retry,
        ),
        const SizedBox(height: 12),
        PitchAction(
          label: 'Bot menüsüne dön',
          secondary: true,
          neutral: true,
          icon: Icons.arrow_back_rounded,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
