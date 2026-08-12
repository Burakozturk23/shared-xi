import 'package:flutter/material.dart';
import '../widgets/network_logo.dart';

import '../widgets/country_badge.dart';

import '../controllers/endless_controller.dart';
import '../models/endless_state.dart';
import '../models/match_entity.dart';
import '../theme/app_theme.dart';

class EndlessPage extends StatefulWidget {
  final EndlessMatchMode matchMode;
  final EndlessGameStyle gameStyle;

  const EndlessPage({
    super.key,
    required this.matchMode,
    required this.gameStyle,
  });

  @override
  State<EndlessPage> createState() => _EndlessPageState();
}

class _EndlessPageState extends State<EndlessPage> {
  late final EndlessController _controller;
  final TextEditingController _answerController = TextEditingController();

  bool get _isBlitz => widget.gameStyle == EndlessGameStyle.blitz;

  @override
  void initState() {
    super.initState();

    _controller = EndlessController(
      matchMode: widget.matchMode,
      gameStyle: widget.gameStyle,
    )..addListener(_onControllerChanged);

    _controller.initialize();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _answerController.dispose();
    super.dispose();
  }

  void _submitAnswer() {
    final input = _answerController.text.trim();
    if (input.isEmpty) return;

    _controller.submitAnswer(input);
    _answerController.clear();
  }

  void _playAgain() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EndlessPage(
          matchMode: widget.matchMode,
          gameStyle: widget.gameStyle,
        ),
      ),
    );
  }

  String get _title => _isBlitz ? 'Blitz Mode' : 'Survival Mode';

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state.isLoading || state.entity1 == null || state.entity2 == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (state.isGameOver) {
      return _buildGameOver(state);
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_title),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMatchHeader(state),
              const SizedBox(height: 14),
              _buildStatsCard(state),
              const SizedBox(height: 14),
              if (state.activeHints.isNotEmpty) ...[
                _buildHintsCard(state),
                const SizedBox(height: 14),
              ],
              _buildInputCard(),
              const SizedBox(height: 14),
              _buildActionsRow(state),
              if (state.feedback != null) ...[
                const SizedBox(height: 14),
                _buildFeedbackCard(state),
              ],
              const SizedBox(height: 14),
              _buildFoundPlayersCard(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchHeader(EndlessState state) {
    return Card(
      color: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: _EntityTile(entity: state.entity1!)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'VS',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.hintColor,
                ),
              ),
            ),
            Expanded(child: _EntityTile(entity: state.entity2!)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(EndlessState state) {
    return Card(
      color: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatChip(
                  label: 'Skor',
                  value: '${state.score.round()}',
                ),
                if (_isBlitz)
                  _StatChip(
                    label: 'Süre',
                    value: '${state.secondsLeft}s',
                    highlight: state.secondsLeft <= 10,
                  )
                else
                  _StatChip(
                    label: 'Can',
                    value: '${state.lives}',
                    highlight: state.lives <= 2,
                  ),
                _StatChip(
                  label: 'Seri',
                  value: '${state.streak}',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Çarpan: x${state.multiplier.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.hintColor),
                ),
                Text(
                  'Rekor: ${state.bestScore}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.hintColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHintsCard(EndlessState state) {
    return Card(
      color: const Color(0xFFFFB300).withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 18, color: Color(0xFFFFB300)),
                SizedBox(width: 6),
                Text(
                  'İpuçları',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFFB300),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: state.activeHints
                  .map(
                    (h) => Chip(
                      label: Text(h, style: const TextStyle(fontSize: 13)),
                      backgroundColor: AppTheme.cardColor,
                      side: BorderSide(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.4),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    final suggestions = _controller.state.suggestions;
    return Card(
      color: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _answerController,
              onChanged: _controller.updateSuggestions,
              onSubmitted: (_) => _submitAnswer(),
              textInputAction: TextInputAction.done,
              style: const TextStyle(color: AppTheme.textColor),
              decoration: const InputDecoration(
                labelText: 'Oyuncu adı',
                hintText: 'Örn. Luis Suarez',
              ),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: suggestions.length,
                  itemBuilder: (context, i) {
                    final p = suggestions[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.name),
                      subtitle: Text('${p.position} • ${p.countryLabel}'),
                      onTap: () {
                        _controller.submitPlayer(p);
                        _answerController.clear();
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitAnswer,
                child: const Text(
                  'GÖNDER',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsRow(EndlessState state) {
    final canHint =
        state.foundPlayerIds.length < state.matchingPlayers.length;

    final hintLabel = _isBlitz ? 'İpucu' : 'İpucu (−1 can)';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canHint ? _controller.useHint : null,
                icon: const Icon(Icons.lightbulb_outline, size: 18),
                label: Text(hintLabel, style: const TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: state.skipsLeft > 0 ? _controller.skipRound : null,
                icon: const Icon(Icons.skip_next, size: 18),
                label: Text(
                  'Pas (${state.skipsLeft})',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
        if (_isBlitz) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Oyunu bitir?'),
                    content: Text(
                      'Skorun kaydedilecek: ${state.score.round()}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Devam et'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Bitir'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await _controller.endGame();
                }
              },
              icon: const Icon(Icons.flag_rounded, size: 18),
              label: const Text('Skoru kaydet & bitir'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFeedbackCard(EndlessState state) {
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

  Widget _buildFoundPlayersCard(EndlessState state) {
    return Card(
      color: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bu turda bulunanlar (${state.foundPlayers.length}/${state.matchingPlayers.length})',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 12),
            if (state.foundPlayers.isEmpty)
              const Text(
                'Henüz oyuncu bulmadın.',
                style: TextStyle(color: AppTheme.hintColor),
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

  Widget _buildGameOver(EndlessState state) {
    final finalScore = state.score.round();
    final isNewRecord = finalScore >= state.bestScore && finalScore > 0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: Text('$_title Bitti')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isBlitz ? Icons.flash_on_rounded : Icons.favorite_rounded,
                size: 64,
                color: _isBlitz ? const Color(0xFFFFB300) : Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                'Skor: $finalScore',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isNewRecord ? 'Yeni rekor! 🎉' : 'Rekor: ${state.bestScore}',
                style: const TextStyle(fontSize: 16, color: AppTheme.hintColor),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _playAgain,
                  child: const Text(
                    'TEKRAR OYNA',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.popUntil(context, (route) => route.isFirst),
                  child: const Text('ANA MENÜ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _StatChip({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? Colors.redAccent : AppTheme.textColor;

    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.hintColor),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
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
          NetworkLogo(
            url: entity.logoUrl,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            circular: true,
            fallback: const Icon(Icons.sports_soccer, size: 52),
          )
        else if (entity.type == MatchEntityType.country)
          CountryBadge(
            country: entity.countryName ?? entity.displayName,
            width: 56,
            height: 40,
          )
        else
          const Icon(Icons.public, size: 52),
        const SizedBox(height: 8),
        Text(
          entity.displayName,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textColor,
          ),
        ),
      ],
    );
  }
}