import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/daily_challenge_controller.dart';
import '../models/daily_challenge_state.dart';
import '../models/football_calendar_theme.dart';
import '../models/match_entity.dart';

class DailyChallengeGamePage extends StatefulWidget {
  /// null = bugün
  final DateTime? playDate;

  const DailyChallengeGamePage({super.key, this.playDate});

  @override
  State<DailyChallengeGamePage> createState() =>
      _DailyChallengeGamePageState();
}

class _DailyChallengeGamePageState extends State<DailyChallengeGamePage> {
  late final DailyChallengeController _controller;
  final TextEditingController _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller =
        DailyChallengeController(playDate: widget.playDate)
          ..addListener(_onChanged);
    _controller.initialize();
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
    _controller.submitAnswer(input);
    _answerController.clear();
  }

  Color _accent(DailyChallengeState state) {
    switch (state.theme?.kind) {
      case CalendarThemeKind.europeNight:
        return Colors.amber;
      case CalendarThemeKind.derbyDay:
      case CalendarThemeKind.derbyCountdown:
        return Colors.redAccent;
      case CalendarThemeKind.weekSummary:
        return Colors.lightBlueAccent;
      case null:
        return Colors.lightBlueAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state.isLoading || state.entity1 == null || state.entity2 == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.isFinished) {
      return _buildFinished(state);
    }

    final accent = _accent(state);

    return Scaffold(
      appBar: AppBar(
        title: Text(state.theme?.badgeLabel ?? 'Günün Mücadelesi'),
        centerTitle: true,
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
          padding: const EdgeInsets.all(16),
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
            Expanded(child: _EntityTile(entity: state.entity1!)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('VS',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(child: _EntityTile(entity: state.entity2!)),
          ],
        ),
      ),
    );
  }

  Widget _buildHud(DailyChallengeState state, Color accent) {
    final target =
        state.theme?.targetFinds ?? state.matchingPlayers.length;
    final progress =
        (state.foundPlayers.length / target.clamp(1, 999)).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('⏱ ${state.secondsLeft}s',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: state.secondsLeft <= 10
                            ? Colors.redAccent
                            : null)),
                Text('❤️ ${state.livesLeft}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                Text('${state.foundPlayers.length}/$target',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
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
              Text(state.label,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInput(Color accent) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _answerController,
              onChanged: _controller.updateSuggestions,
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Oyuncu adı',
                hintText: 'Örn. Luis Suarez',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent.withValues(alpha: 0.85),
                ),
                onPressed: _submit,
                child: const Text('GÖNDER',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions(DailyChallengeState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Öneriler',
                style: TextStyle(fontWeight: FontWeight.w600)),
            ...state.suggestions.map(
              (p) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(p.name),
                subtitle: Text('${p.position} • ${p.countryLabel}'),
                onTap: () {
                  _controller.submitPlayer(p);
                  _answerController.clear();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedback(DailyChallengeState state) {
    final color = state.feedbackIsSuccess ? Colors.green : Colors.red;
    return Card(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          state.feedback ?? '',
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
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
            Text('Bulunan (${state.foundPlayers.length})',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (state.foundPlayers.isEmpty)
              const Text('Henüz yok.', style: TextStyle(color: Colors.grey))
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
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '%$pct',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: pct >= 80 ? Colors.greenAccent : accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    derbyBadge ? 'Derbi Uzmanı Başarısı' : 'Performans',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    state.label.isNotEmpty
                        ? state.label
                        : '${state.entity1?.displayName} vs ${state.entity2?.displayName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${state.score} doğru · ${state.streak} günlük seri 🔥',
                    style: const TextStyle(fontSize: 15),
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
                          .map((p) => Chip(
                                label: Text(p.name,
                                    style: const TextStyle(fontSize: 12)),
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('SONUCU PAYLAŞ'),
                      onPressed: () async {
                        final text = _controller.shareText();
                        await Clipboard.setData(ClipboardData(text: text));
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Paylaşım metni panoya kopyalandı.'),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('TAMAM',
                          style: TextStyle(fontWeight: FontWeight.bold)),
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

class _EntityTile extends StatelessWidget {
  final MatchEntity entity;
  const _EntityTile({required this.entity});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (entity.type == MatchEntityType.club)
          ClipOval(
            child: Image.network(
              entity.logoUrl ?? '',
              height: 48,
              width: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.sports_soccer, size: 48),
            ),
          )
        else
          const Icon(Icons.public, size: 48),
        const SizedBox(height: 6),
        Text(
          entity.displayName,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ],
    );
  }
}