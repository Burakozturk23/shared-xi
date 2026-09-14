import 'package:flutter/material.dart';

import '../controllers/daily_challenge_controller.dart';
import '../models/daily_challenge_state.dart';
import '../models/football_calendar_theme.dart';
import '../app/app_feedback.dart';
import '../app/route_appearance.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/entity_header_tile.dart';
import '../widgets/pitch_ui.dart';
import '../services/daily_challenge_service.dart';
import '../services/daily_playable_matches.dart';
import '../widgets/daily_share_card.dart';
import '../widgets/daily_share_sheet.dart';
import 'daily_leaderboard_page.dart';

class DailyChallengeGamePage extends StatefulWidget {
  /// null = bugün
  final DateTime? playDate;
  final PlayableDailyMatch? match;

  /// The page owns and disposes the controller produced by this factory.
  final DailyChallengeController Function()? controllerFactory;
  const DailyChallengeGamePage({
    super.key,
    this.playDate,
    this.match,
    this.controllerFactory,
  });

  @override
  State<DailyChallengeGamePage> createState() => _DailyChallengeGamePageState();
}

class _DailyChallengeGamePageState extends State<DailyChallengeGamePage> {
  late final DailyChallengeController _controller;
  bool _loadError = false;
  final TextEditingController _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controllerFactory?.call() ??
        DailyChallengeController(
          playDate: widget.playDate,
          presetMatch: widget.match,
        );
    _controller.addListener(_onChanged);
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _loadError = false);
    try {
      await _controller.initialize();
    } catch (error, stack) {
      debugPrint('Daily game: $error\n$stack');
      if (mounted) setState(() => _loadError = true);
    }
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _answerController.dispose();
    super.dispose();
  }

  void _submit() {
    final input = _answerController.text.trim();
    if (input.isEmpty) return;
    _acceptAnswer(() => _controller.submitAnswer(input));
  }

  void _acceptAnswer(VoidCallback submit) {
    final before = _controller.state;
    submit();
    final after = _controller.state;
    if (after.foundPlayerIds.length > before.foundPlayerIds.length) {
      _answerController.clear();
      _controller.clearSuggestions();
      AppFeedback.answer(correct: true);
    } else if (after.wrongAttempts.length > before.wrongAttempts.length) {
      // Preserve rejected/ambiguous input so it can be corrected.
      AppFeedback.answer(correct: false);
    }
  }

  Color _accent(DailyChallengeState state) => PitchColors.of(context).accent;

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (_loadError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Günün maçı')),
        body: EmptyState(
          title: 'Oyun hazırlanamadı',
          message: 'Tekrar deneyebilirsin.',
          actionLabel: 'Tekrar dene',
          onAction: _initialize,
        ),
      );
    }
    if (state.isLoading || state.entity1 == null || state.entity2 == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Günün maçı')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (state.isFinished) {
      return _buildFinished(state);
    }

    final accent = _accent(state);

    return Scaffold(
      appBar: AppBar(
        title: Text(state.theme?.badgeLabel ?? 'Günün Mücadelesi'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'İpucu',
            onPressed: _controller.useHint,
            icon: const Icon(Icons.lightbulb_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.theme?.kind == CalendarThemeKind.derbyDay ||
                  state.theme?.kind == CalendarThemeKind.derbyCountdown)
                _derbyBanner(accent),
              _buildMatchHeader(state),
              const SizedBox(height: 12),
              _buildHud(state, accent),
              const SizedBox(height: 16),
              _buildInput(accent),
              const SizedBox(height: 12),
              if (state.suggestions.isNotEmpty) _buildSuggestions(state),
              if (state.feedback != null) ...[
                const SizedBox(height: 12),
                _buildFeedback(state),
              ],
              const SizedBox(height: 16),
              _buildFound(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _derbyBanner(Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: const Text(
        '🔥 Derbi atmosferi — süre ve can sınırlı!',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  Widget _buildMatchHeader(DailyChallengeState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: EntityHeaderTile(entity: state.entity1!)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'VS',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(child: EntityHeaderTile(entity: state.entity2!)),
          ],
        ),
      ),
    );
  }

  Widget _buildHud(DailyChallengeState state, Color accent) {
    final total = state.totalShared.clamp(1, 999);
    final progress = (state.foundPlayers.length / total).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              children: [
                _hudMetric(
                  Icons.timer_outlined,
                  '${state.secondsLeft} sn',
                  'Kalan süre',
                  state.secondsLeft <= 10
                      ? PitchColors.of(context).error
                      : PitchColors.of(context).text,
                ),
                _hudMetric(
                  Icons.favorite_border_rounded,
                  '${state.livesLeft} can',
                  'Kalan can',
                  PitchColors.of(context).text,
                ),
                _hudMetric(
                  Icons.check_circle_outline_rounded,
                  '${state.foundPlayers.length}/$total',
                  'Bulunan oyuncu',
                  PitchColors.of(context).text,
                ),
                _hudMetric(
                  Icons.star_outline_rounded,
                  '${state.score} puan',
                  'Puan',
                  accent,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: accent,
              ),
            ),
            if (state.label.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                state.label,
                style: TextStyle(
                  fontSize: 12,
                  color: PitchColors.of(context).muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hudMetric(IconData icon, String value, String label, Color color) =>
      Semantics(
        label: label,
        value: value,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      );

  Widget _buildInput(Color accent) => PitchPanel(
    child: Column(
      children: [
        TextField(
          controller: _answerController,
          onChanged: _controller.updateSuggestions,
          onSubmitted: (_) => _submit(),
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Oyuncu adı',
            hintText: 'Bir futbolcu yaz',
          ),
        ),
        const SizedBox(height: 16),
        PitchAction(
          label: 'Yanıtı kontrol et',
          onPressed: _submit,
          icon: Icons.check_rounded,
        ),
      ],
    ),
  );

  Widget _buildSuggestions(DailyChallengeState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Öneriler',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            ...state.suggestions.map(
              (p) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p.name),
                subtitle: Text('${p.position} • ${p.countryLabel}'),
                onTap: () {
                  _acceptAnswer(() => _controller.submitPlayer(p));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedback(DailyChallengeState state) {
    final p = PitchColors.of(context);
    final color = state.feedbackIsSuccess ? p.success : p.error;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color),
        ),
        child: Row(
          children: [
            Icon(
              state.feedbackIsSuccess
                  ? Icons.check_circle_outline_rounded
                  : Icons.info_outline_rounded,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                state.feedback ?? '',
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFound(DailyChallengeState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bulunan (${state.foundPlayers.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (state.foundPlayers.isEmpty)
              Text(
                'İlk ortak futbolcuyu yaz.',
                style: TextStyle(color: PitchColors.of(context).muted),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: state.foundPlayers
                    .map((p) => Chip(label: Text(p.name)))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinished(DailyChallengeState state) {
    final pct = (state.successRate * 100).round();
    final derbyBadge = state.earnedDerbyBadge;
    final accent = _accent(state);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Mücadele Sonucu'),
        centerTitle: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '%$pct',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: pct >= 80
                          ? PitchColors.of(context).success
                          : accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    derbyBadge ? 'Derbi Uzmanı Başarısı' : 'Performans',
                    style: TextStyle(color: PitchColors.of(context).muted),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    state.label.isNotEmpty
                        ? state.label
                        : '${state.entity1?.displayName} vs ${state.entity2?.displayName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${state.foundPlayers.length}/${state.totalShared} bulundu · ${state.score} puan',
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${state.streak} günlük seri 🔥',
                    style: TextStyle(
                      fontSize: 14,
                      color: PitchColors.of(context).muted,
                    ),
                  ),
                  if (derbyBadge) ...[
                    const SizedBox(height: 12),
                    const Chip(
                      avatar: Icon(Icons.emoji_events, size: 18),
                      label: Text('Derbi Uzmanı rozeti kazanıldı'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (state.foundPlayers.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: state.foundPlayers
                          .map(
                            (p) => Chip(
                              label: Text(
                                p.name,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 24),
                  if (_controller.lastRank != null) ...[
                    Text(
                      'Sıralama: #${_controller.lastRank}'
                      '${_controller.lastTotalPlayers != null ? ' / ${_controller.lastTotalPlayers}' : ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('Sonucu paylaş'),
                      onPressed: () async {
                        final st = _controller.state;
                        final text = _controller.shareText();
                        final target =
                            st.theme?.targetFinds ?? st.matchingPlayers.length;
                        await showDailyShareSheet(
                          context,
                          shareText: text,
                          card: DailyShareCard(
                            label: st.label.isNotEmpty
                                ? st.label
                                : '${st.entity1?.displayName} vs ${st.entity2?.displayName}',
                            themeBadge: st.theme?.badgeLabel ?? 'GÜNÜN',
                            score: st.score,
                            target: target,
                            successRate: st.successRate,
                            streak: st.streak,
                            rank: _controller.lastRank,
                            totalPlayers: _controller.lastTotalPlayers,
                            dateKey: DailyChallengeService.dateKeyFor(
                              widget.playDate ?? DateTime.now(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        LinkballRoute(
                          modern: false,
                          builder: (_) =>
                              DailyLeaderboardPage(date: widget.playDate),
                        ),
                      );
                    },
                    icon: const Icon(Icons.leaderboard_outlined),
                    label: const Text('Günün sıralaması'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Maçlara dön',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
