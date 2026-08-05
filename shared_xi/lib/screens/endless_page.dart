import 'package:flutter/material.dart';

import '../controllers/endless_controller.dart';
import '../models/endless_state.dart';
import '../models/match_entity.dart';

class EndlessPage extends StatefulWidget {
  final EndlessMatchMode matchMode;

  const EndlessPage({super.key, required this.matchMode});

  @override
  State<EndlessPage> createState() => _EndlessPageState();
}

class _EndlessPageState extends State<EndlessPage> {
  late final EndlessController _controller;
  final TextEditingController _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _controller = EndlessController(matchMode: widget.matchMode)
      ..addListener(_onControllerChanged);
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
        builder: (_) => EndlessPage(matchMode: widget.matchMode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state.isLoading || state.entity1 == null || state.entity2 == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.isGameOver) {
      return _buildGameOver(state);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seri Modu'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMatchHeader(state),
              const SizedBox(height: 16),
              _buildStatsCard(state),
              const SizedBox(height: 16),
              _buildInputCard(),             
              const SizedBox(height: 16),
              _buildActionsRow(state),
              const SizedBox(height: 16),
              if (state.feedback != null) _buildFeedbackCard(state),
              const SizedBox(height: 16),
              _buildFoundPlayersCard(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchHeader(EndlessState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: _EntityTile(entity: state.entity1!)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('VS',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Expanded(child: _EntityTile(entity: state.entity2!)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(EndlessState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Skor: ${state.score.round()}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
                Text('Can: ${state.lives}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
                Text('Süre: ${state.secondsLeft}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Seri: ${state.streak}  •  Çarpan: x${state.multiplier.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                Text('Rekor: ${state.bestScore}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _answerController,             
              onSubmitted: (_) => _submitAnswer(),
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
                onPressed: _submitAnswer,
                child: const Text('GÖNDER',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  

  Widget _buildActionsRow(EndlessState state) {
    final canHint = state.foundPlayerIds.length < state.matchingPlayers.length;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: canHint ? _controller.useHint : null,
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('İpucu (-1 can)'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: state.skipsLeft > 0 ? _controller.skipRound : null,
            icon: const Icon(Icons.skip_next),
            label: Text('Pas (${state.skipsLeft})'),
          ),
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bu turda bulunanlar (${state.foundPlayers.length}/${state.matchingPlayers.length})',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (state.foundPlayers.isEmpty)
              const Text('Henüz oyuncu bulmadın.',
                  style: TextStyle(color: Colors.grey))
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
      appBar: AppBar(title: const Text('Seri Bitti')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, size: 64, color: Colors.amber),
              const SizedBox(height: 16),
              Text(
                'Skor: $finalScore',
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                isNewRecord ? 'Yeni rekor! 🎉' : 'Rekor: ${state.bestScore}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _playAgain,
                  child: const Text('TEKRAR OYNA',
                      style: TextStyle(fontWeight: FontWeight.bold)),
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
              height: 52,
              width: 52,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const SizedBox(
                  height: 52,
                  width: 52,
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.sports_soccer, size: 52);
              },
            ),
          )
        else
          const Icon(Icons.public, size: 52),
        const SizedBox(height: 8),
        Text(
          entity.displayName,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}