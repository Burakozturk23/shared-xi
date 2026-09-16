import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_feedback.dart';
import '../controllers/vs_bot_controller.dart' show VsBotDifficulty;
import '../controllers/vs_bot_random_five_controller.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/club_badge.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/player_avatar.dart';

class VsBotRandomFivePage extends StatefulWidget {
  const VsBotRandomFivePage({super.key, this.controllerFactory});
  final VsBotRandomFiveController Function()? controllerFactory;

  @override
  State<VsBotRandomFivePage> createState() => _VsBotRandomFivePageState();
}

class _VsBotRandomFivePageState extends State<VsBotRandomFivePage>
    with WidgetsBindingObserver {
  late final VsBotRandomFiveController _c;
  final _answer = TextEditingController();
  final _focus = FocusNode();
  bool _foreground = true, _resumeOnForeground = false;
  bool _exitDialog = false, _allowExit = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _c = (widget.controllerFactory?.call() ?? VsBotRandomFiveController())
      ..addListener(_changed);
    unawaited(_c.initialize());
  }

  void _changed() {
    if (!mounted) return;
    if (_c.phase == FiveMatchPhase.loading) _answer.clear();
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && _c.phase == FiveMatchPhase.playing) {
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
    super.dispose();
  }

  Future<void> _requestExit() async {
    if (_exitDialog) return;
    final wasPlaying = _c.phase == FiveMatchPhase.playing;
    _exitDialog = true;
    _c.pause();
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Maçtan çıkılsın mı?'),
        content: const Text('Bu maçtaki ilerlemen kaybolur.'),
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

  Color get _botColor => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFC4A7FF)
      : const Color(0xFF6B3ABE);

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowExit || !_c.isInMatch,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(_requestExit());
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Rastgele Beşler'),
        actions: [
          if (_c.phase == FiveMatchPhase.playing)
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
          FiveMatchPhase.loading => _message(
            'Beşli hazırlanıyor',
            'Bağlantısı bol kulüpler yerlerini alıyor.',
            loading: true,
          ),
          FiveMatchPhase.error => _message(
            'Tekrar deneyelim',
            _c.feedback!,
            action: PitchAction(label: 'Yeniden dene', onPressed: _c.newMatch),
          ),
          FiveMatchPhase.paused => _message(
            'Oyun duraklatıldı',
            'Kulüplerin, cevabın ve sıran korunuyor.',
            action: PitchAction(
              label: 'Devam et',
              icon: Icons.play_arrow_rounded,
              onPressed: _foreground ? _c.resume : null,
            ),
          ),
          FiveMatchPhase.ready => _ready(),
          FiveMatchPhase.playing || FiveMatchPhase.roundResult => _match(),
          FiveMatchPhase.finished => _result(),
        },
      ),
      bottomNavigationBar: _c.phase == FiveMatchPhase.roundResult
          ? SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: PitchAction(
                label: _c.roundNumber == VsBotRandomFiveController.maxTurnsEach
                    ? 'Maç sonucunu gör'
                    : 'Sonraki tur',
                onPressed: _foreground
                    ? () {
                        _answer.clear();
                        _focus.unfocus();
                        _c.nextRound();
                      }
                    : null,
              ),
            )
          : null,
    ),
  );

  Widget _message(
    String title,
    String description, {
    bool loading = false,
    Widget? action,
  }) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 24),
      Icon(Icons.hub_outlined, size: 48, color: PitchColors.of(context).accent),
      const SizedBox(height: 20),
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      Text(description),
      const SizedBox(height: 24),
      if (loading) const LinearProgressIndicator(),
      if (action != null) action,
    ],
  );

  String _difficultyLabel(VsBotDifficulty d) => switch (d) {
    VsBotDifficulty.easy => 'Kolay',
    VsBotDifficulty.medium => 'Orta',
    VsBotDifficulty.hard => 'Zor',
  };

  Widget _ready() => ListView(
    key: const PageStorageKey<String>('five-ready'),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    children: [
      Text(
        '5 TUR · MAKS. 25 PUAN',
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: PitchColors.of(context).accent),
      ),
      const SizedBox(height: 12),
      Text(
        'Bir isim.\nBeş bağlantı.',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 12),
      const Text(
        'Beş kulübü incele. Bir futbolcuyla olabildiğince çoğunu bağla.',
      ),
      const SizedBox(height: 20),
      PitchPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Botun seviyesi',
              style: Theme.of(context).textTheme.titleSmall,
            ),
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
            const SizedBox(height: 10),
            Text(switch (_c.difficulty) {
              VsBotDifficulty.easy =>
                'Bot 1–2 kulübe uyan cevapları tercih eder.',
              VsBotDifficulty.medium =>
                'Bot en fazla 3 kulübe uyan cevapları tercih eder.',
              VsBotDifficulty.hard =>
                'Bot kalan oyunculardan en çok kulübe uyanı bulur.',
            }),
            if (_c.difficulty != VsBotDifficulty.hard) ...[
              const SizedBox(height: 6),
              Text(
                'Bu aralıkta cevap yoksa en az bağlantılı oyuncuyu seçer.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      PitchAction(
        label: 'Maça başla',
        icon: Icons.play_arrow_rounded,
        onPressed: _foreground ? _c.begin : null,
      ),
      const SizedBox(height: 20),
      Text('İLK BEŞLİN', style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 10),
      _clubBoard(),
      const SizedBox(height: 16),
      Text(
        'Her eşleşen kulüp +1 · Pas 0\nHer turda birer cevap verirsiniz. Kullanılan futbolcu maç boyunca tekrar seçilemez.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );

  Widget _scores() => Row(
    children: [
      Expanded(
        child: _score('Sen', _c.userScore, PitchColors.of(context).accent),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _score(
          'Bot · ${_difficultyLabel(_c.difficulty)}',
          _c.botScore,
          _botColor,
        ),
      ),
    ],
  );

  Widget _score(String label, int score, Color color) => PitchPanel(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: color),
        ),
        const SizedBox(height: 4),
        Text('$score', style: Theme.of(context).textTheme.headlineMedium),
      ],
    ),
  );

  Widget _match() {
    final reviewing = _c.phase == FiveMatchPhase.roundResult;
    return ListView(
      key: PageStorageKey<String>('five-round-${_c.roundNumber}'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _scores(),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            'TUR ${_c.roundNumber} / 5 · ${reviewing
                ? 'Tur tamamlandı'
                : _c.canAnswer
                ? 'Sıra sende'
                : 'Bot düşünüyor…'}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: _c.history.length / 5,
          backgroundColor: PitchColors.of(context).raised,
          minHeight: 3,
        ),
        const SizedBox(height: 18),
        Text(
          reviewing ? 'Bağlantılarınız' : 'Bu beş kulübü kim birleştirir?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        _clubBoard(),
        if (reviewing) ...[
          const SizedBox(height: 10),
          Text(
            'İşaretler her cevabın eşleştiği kulüpleri gösterir.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 18),
        if (_c.canAnswer) _answerPanel(),
        if (_c.userMove != null)
          _move('Senin cevabın', _c.userMove!, PitchColors.of(context).accent),
        if (!reviewing && !_c.canAnswer) ...[
          const SizedBox(height: 14),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          const Text('Bot aynı beş kulüp için cevabını seçiyor…'),
        ],
        if (_c.botMove != null) ...[
          const SizedBox(height: 10),
          _move('Botun cevabı', _c.botMove!, _botColor),
        ],
        if (_c.history.isNotEmpty) ...[const SizedBox(height: 16), _history()],
      ],
    );
  }

  Widget _clubBoard() => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = constraints.maxWidth >= 600 * scale
          ? 3
          : constraints.maxWidth >= 320 * scale
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < _c.clubs.length; i++)
            SizedBox(width: width, child: _club(_c.clubs[i], i)),
        ],
      );
    },
  );

  Widget _club(Club club, int index) {
    final p = PitchColors.of(context);
    final mine = _c.userMove?.matchedClubs.any((c) => c.id == club.id) ?? false;
    final theirs =
        _c.botMove?.matchedClubs.any((c) => c.id == club.id) ?? false;
    return PitchPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClubBadge(club: club, size: 32),
              const Spacer(),
              Text(
                '0${index + 1}',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: p.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(club.name, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            club.league.isEmpty ? club.country : club.league,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (mine || theirs) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                if (mine)
                  Text(
                    '✓ Sen',
                    style: TextStyle(
                      color: p.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (theirs)
                  Text(
                    '✓ Bot',
                    style: TextStyle(
                      color: _botColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _answerPanel() => PitchPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Futbolcunu bul', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          'Bir isim, eşleştiği her kulüp için +1 puan.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('five-answer'),
          controller: _answer,
          focusNode: _focus,
          onChanged: _c.updateSuggestions,
          onSubmitted: (_) => _submit(),
          textInputAction: TextInputAction.done,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Futbolcu adı',
            hintText: 'Bir futbolcu ara',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        if (_c.suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              primary: false,
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
        if (_c.feedback != null) ...[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(
              _c.feedback!,
              style: TextStyle(color: PitchColors.of(context).error),
            ),
          ),
        ],
        const SizedBox(height: 14),
        PitchAction(
          label: 'Cevabı gönder',
          icon: Icons.check_rounded,
          onPressed: _submit,
        ),
        TextButton(
          onPressed: () {
            if (_c.pass()) {
              _answer.clear();
              _focus.unfocus();
            }
          },
          child: const Text('Pas geç · 0 puan'),
        ),
      ],
    ),
  );

  void _submit([Player? player]) {
    final accepted = player == null
        ? _c.submitGuess(_answer.text)
        : _c.submitPlayer(player);
    if (accepted) {
      _answer.clear();
      _focus.unfocus();
      AppFeedback.answer(correct: true);
    }
  }

  Widget _move(String title, FiveMove move, Color color) => PitchPanel(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: color),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (move.player != null) ...[
              PlayerAvatar(player: move.player!, size: 36),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                move.player?.name ?? 'Pas geçildi',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '+${move.score}',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: color),
            ),
          ],
        ),
        if (!move.passed) ...[
          const SizedBox(height: 8),
          Text(
            move.matchedClubs.map((c) => c.name).join(' · '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    ),
  );

  Widget _history() => ExpansionTile(
    // Separate from scroll offsets (double) to store expansion as bool safely.
    key: const PageStorageKey<String>('five-history'),
    tilePadding: EdgeInsets.zero,
    title: const Text('Tur geçmişi'),
    subtitle: Text('${_c.history.length} tur tamamlandı'),
    children: [
      for (var i = 0; i < _c.history.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${i + 1}. TUR',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _c.history[i].board.clubs.map((c) => c.name).join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              _move('Sen', _c.history[i].user, PitchColors.of(context).accent),
              const SizedBox(height: 8),
              _move('Bot', _c.history[i].bot, _botColor),
            ],
          ),
        ),
    ],
  );

  Widget _result() {
    final won = _c.userScore > _c.botScore;
    final draw = _c.userScore == _c.botScore;
    return ListView(
      key: const PageStorageKey<String>('five-result'),
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 16),
        Icon(
          draw
              ? Icons.handshake_outlined
              : won
              ? Icons.emoji_events_outlined
              : Icons.smart_toy_outlined,
          size: 52,
          color: won ? PitchColors.of(context).limeInk : _botColor,
        ),
        const SizedBox(height: 16),
        Text(
          draw
              ? 'Berabere!'
              : won
              ? 'Bağlantı ustası!'
              : 'Bu kez bot kazandı.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text('Beş tur tamamlandı. Her bağlantı toplam puanına eklendi.'),
        const SizedBox(height: 20),
        _scores(),
        const SizedBox(height: 20),
        PitchAction(
          label: 'Yeniden oyna',
          icon: Icons.replay_rounded,
          onPressed: _c.newMatch,
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
        _history(),
      ],
    );
  }
}
