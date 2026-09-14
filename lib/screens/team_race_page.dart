import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/team_race_controller.dart';
import '../controllers/vs_bot_controller.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/club_badge.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/player_avatar.dart';

class TeamRacePage extends StatefulWidget {
  const TeamRacePage({
    super.key,
    required this.userClub,
    this.difficulty = VsBotDifficulty.medium,
    this.controllerFactory,
  });

  final Club userClub;
  final VsBotDifficulty difficulty;
  final TeamRaceController Function()? controllerFactory;

  @override
  State<TeamRacePage> createState() => _TeamRacePageState();
}

class _TeamRacePageState extends State<TeamRacePage>
    with WidgetsBindingObserver {
  late final TeamRaceController _c;
  final TextEditingController _answerController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _foreground = true;
  bool _allowExit = false;
  bool _exitDialog = false;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null ||
        (lifecycle != AppLifecycleState.paused &&
            lifecycle != AppLifecycleState.inactive &&
            lifecycle != AppLifecycleState.hidden);
    WidgetsBinding.instance.addObserver(this);
    _c = (widget.controllerFactory?.call() ??
        TeamRaceController(
          userClub: widget.userClub,
          difficulty: widget.difficulty,
        ))
      ..addListener(_changed);
    unawaited(_c.prepare());
  }

  void _changed() {
    if (!mounted) return;
    if (_c.phase != TeamRacePhase.racing && _answerController.text.isNotEmpty) {
      _answerController.clear();
      _c.clearSuggestions();
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _c.pause();
    } else if (_c.phase == TeamRacePhase.paused && !_exitDialog) {
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
    final wasPlaying = _c.isInRound;
    _c.pause();
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Maçtan çıkılsın mı?'),
        content: const Text('Bu turun ilerlemesi kaybolur.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Maça dön'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Maçtan çık'),
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
    } else if (wasPlaying && _foreground && _c.phase == TeamRacePhase.paused) {
      _c.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final inRound = _c.isInRound;
    return PopScope(
      canPop: _allowExit || !inRound,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_requestExit());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Takım Yarışı'),
          actions: [
            if (_c.phase == TeamRacePhase.racing)
              IconButton(
                tooltip: 'Maçı duraklat',
                onPressed: _c.pause,
                icon: const Icon(Icons.pause_rounded),
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: switch (_c.phase) {
            TeamRacePhase.loading => _message(
                Icons.sports_soccer,
                'Rakip hazırlanıyor',
                'V4 ortak oyuncu havuzundan uygun bir takım seçiliyor. Süren henüz başlamadı.',
                loading: true,
              ),
            TeamRacePhase.error => _message(
                Icons.cloud_off_outlined,
                'Maç hazırlanamadı',
                _c.errorMessage ?? 'Bu seçim için uygun bir rakip bulunamadı.',
                actions: [
                  PitchAction(label: 'Yeniden dene', onPressed: _c.retry),
                  const SizedBox(height: 12),
                  PitchAction(
                    label: 'Takım değiştir',
                    secondary: true,
                    neutral: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            TeamRacePhase.countdown => _countdown(),
            TeamRacePhase.paused => _message(
                Icons.pause_circle_outline_rounded,
                'Maç duraklatıldı',
                'Senin ve botun sırası bekliyor. Kaldığın yerden devam edebilirsin.',
                actions: [
                  PitchAction(
                    label: 'Devam et',
                    icon: Icons.play_arrow_rounded,
                    onPressed: _foreground ? _c.resume : null,
                  ),
                ],
              ),
            TeamRacePhase.racing => _game(),
            TeamRacePhase.roundOver || TeamRacePhase.finished => _result(),
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
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 32),
        Icon(icon, size: 42, color: PitchColors.of(context).accent),
        const SizedBox(height: 20),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(text),
        if (loading) ...[
          const SizedBox(height: 24),
          const LinearProgressIndicator(minHeight: 4),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 28),
          ...actions,
        ],
      ],
    );
  }

  Widget _countdown() {
    final session = _c.session;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: PitchPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (session != null)
                Row(
                  children: [
                    Expanded(child: _clubLabel(session.userClub)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('VS', style: Theme.of(context).textTheme.titleSmall),
                    ),
                    Expanded(child: _clubLabel(session.opponentClub, end: true)),
                  ],
                ),
              const SizedBox(height: 28),
              Text(
                '${_c.countdownLeft}',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: PitchColors.of(context).accent,
                      fontSize: 64,
                    ),
              ),
              const SizedBox(height: 4),
              Text('Hazır ol!', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }

  Widget _game() {
    final session = _c.session;
    if (session == null) return _message(Icons.error_outline, 'Maç bulunamadı', 'Tekrar dene.');
    final p = PitchColors.of(context);
    final compact = MediaQuery.textScalerOf(context).scale(14) / 14 > 1.35;
    return ListView(
      key: const PageStorageKey('team-race-game'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _scoreStrip(p),
        const SizedBox(height: 12),
        PitchPanel(
          child: Row(
            children: [
              Expanded(child: _clubLabel(session.userClub)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: p.tint, borderRadius: BorderRadius.circular(10)),
                child: Text('VS', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: p.accent)),
              ),
              Expanded(child: _clubLabel(session.opponentClub, end: true)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${_c.remainingCount} ortak oyuncu kaldı · Bu turda daha çok bulan kazanır.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_c.feedback != null) ...[
          const SizedBox(height: 10),
          _feedbackBanner(p),
        ],
        const SizedBox(height: 12),
        _answerPanel(p),
        const SizedBox(height: 16),
        if (compact) ...[
          _foundPanel('Senin buldukların', _c.userFound, p.accent),
          const SizedBox(height: 12),
          _foundPanel('Botun buldukları', _c.botFound, p.error),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _foundPanel('Senin buldukların', _c.userFound, p.accent)),
              const SizedBox(width: 12),
              Expanded(child: _foundPanel('Botun buldukları', _c.botFound, p.error)),
            ],
          ),
      ],
    );
  }

  Widget _scoreStrip(PitchColors p) => Row(
        children: [
          Expanded(child: _scoreCard('Sen', _c.userScore, _c.userRoundWins, p.accent)),
          const SizedBox(width: 12),
          Expanded(child: _scoreCard('Bot', _c.botScore, _c.botRoundWins, p.error)),
        ],
      );

  Widget _scoreCard(String title, int score, int rounds, Color color) =>
      PitchPanel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 34,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color)),
                  Text('$score', style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
            Text('$rounds / 3 tur', style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      );

  Widget _answerPanel(PitchColors p) => PitchPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ortak oyuncuyu bul', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('İki takımda da oynamış bir futbolcu yaz.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _answerController,
              focusNode: _focusNode,
              autofocus: true,
              onChanged: _c.updateSuggestions,
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'Oyuncu adı',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            if (_c.suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 190),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _c.suggestions.length,
                  separatorBuilder: (_, _) => Divider(color: p.border, height: 1),
                  itemBuilder: (context, index) {
                    final player = _c.suggestions[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: PlayerAvatar(player: player, size: 34),
                      title: Text(player.name),
                      subtitle: Text('${player.position} · ${player.countryLabel}'),
                      onTap: () {
                        if (_c.submitPlayer(player)) {
                          _answerController.clear();
                          _focusNode.requestFocus();
                        }
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            PitchAction(label: 'Cevabı gönder', onPressed: _submit),
          ],
        ),
      );

  void _submit() {
    if (_c.submitAnswer(_answerController.text)) {
      _answerController.clear();
      _focusNode.requestFocus();
    }
  }

  Widget _feedbackBanner(PitchColors p) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: (_c.feedbackOk ? p.success : p.error).withValues(alpha: .12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: (_c.feedbackOk ? p.success : p.error).withValues(alpha: .35)),
        ),
        child: Row(
          children: [
            Icon(
              _c.feedbackOk ? Icons.check_circle_outline : Icons.info_outline,
              color: _c.feedbackOk ? p.success : p.error,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(_c.feedback!)),
          ],
        ),
      );

  Widget _foundPanel(String title, List<Player> players, Color color) => PitchPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
                Text('${players.length}', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color)),
              ],
            ),
            const SizedBox(height: 10),
            if (players.isEmpty)
              Text('Henüz cevap yok.', style: Theme.of(context).textTheme.bodySmall)
            else
              for (final player in players.take(8)) ...[
                Row(
                  children: [
                    PlayerAvatar(player: player, size: 28),
                    const SizedBox(width: 8),
                    Expanded(child: Text(player.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Icon(Icons.check_rounded, color: color, size: 18),
                  ],
                ),
                if (player != players.take(8).last) const SizedBox(height: 8),
              ],
          ],
        ),
      );

  Widget _result() {
    final finished = _c.phase == TeamRacePhase.finished;
    final userWon = _c.userRoundWins > _c.botRoundWins ||
        (!finished && _c.userScore > _c.botScore);
    final draw = !finished && _c.userScore == _c.botScore;
    final p = PitchColors.of(context);
    final title = draw
        ? 'Tur berabere'
        : userWon
        ? (finished ? 'Maçı kazandın!' : 'Turu kazandın!')
        : (finished ? 'Bot maçı kazandı' : 'Bot turu kazandı');
    return ListView(
      key: const PageStorageKey('team-race-result'),
      padding: const EdgeInsets.all(16),
      children: [
        PitchPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                userWon ? Icons.emoji_events_outlined : Icons.sports_soccer,
                color: userWon ? p.success : p.accent,
                size: 42,
              ),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Tur skoru  ${_c.userScore} – ${_c.botScore}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Seri  ${_c.userRoundWins} – ${_c.botRoundWins}  ·  İlk 3 turu alan kazanır.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PitchAction(
          label: finished ? 'Yeni maç' : 'Sonraki tur',
          icon: finished ? Icons.replay_rounded : Icons.arrow_forward_rounded,
          onPressed: finished ? _c.rematch : _c.nextRound,
        ),
        const SizedBox(height: 12),
        PitchAction(
          label: 'Takımı değiştir',
          secondary: true,
          neutral: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const PitchSectionTitle('Bu turdaki cevaplar'),
        if (_c.userFound.isEmpty && _c.botFound.isEmpty)
          Text('Bu turda cevap bulunamadı.', style: Theme.of(context).textTheme.bodySmall)
        else ...[
          _foundPanel('Sen', _c.userFound, p.accent),
          const SizedBox(height: 12),
          _foundPanel('Bot', _c.botFound, p.error),
        ],
      ],
    );
  }

  Widget _clubLabel(Club club, {bool end = false}) => Row(
        mainAxisAlignment: end ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!end) ...[
            ClubBadge(club: club, size: 34),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              club.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: end ? TextAlign.end : TextAlign.start,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (end) ...[
            const SizedBox(width: 8),
            ClubBadge(club: club, size: 34),
          ],
        ],
      );
}
