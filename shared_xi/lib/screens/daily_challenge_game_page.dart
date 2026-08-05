import 'package:flutter/material.dart';

import '../controllers/daily_challenge_controller.dart';
import '../models/daily_challenge_state.dart';
import '../models/match_entity.dart';

class DailyChallengeGamePage extends StatefulWidget {
  const DailyChallengeGamePage({super.key});

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
    _controller = DailyChallengeController()
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

    return Scaffold(
      appBar: AppBar(title: Text(state.label), centerTitle: true),
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
              if (state.feedback != null) _buildFeedbackCard(state),
              const SizedBox(height: 16),
              _buildFoundPlayersCard(state),
            ],
          ),
        ),
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Expanded(child: _EntityTile(entity: state.entity2!)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(DailyChallengeState state) {
    final total = state.matchingPlayers.length;
    final progress = total == 0
        ? 0.0
        : (state.foundPlayers.length / total).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Skor: ${state.score}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
                Text('Süre: ${state.secondsLeft}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: progress),
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

  Widget _buildFeedbackCard(DailyChallengeState state) {
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

  Widget _buildFoundPlayersCard(DailyChallengeState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bulunan Oyuncular (${state.foundPlayers.length})',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
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

  Widget _buildFinished(DailyChallengeState state) {
  return Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('Günün Mücadelesi'),
      centerTitle: true,
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.calendar_today,
                      size: 48, color: Colors.amber),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Bugünkü mücadeleyi tamamladın!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Text(
                  'Skorun: ${state.score}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  '${state.streak} günlük seri 🔥',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Yarın yeni bir mücadele seni bekliyor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('TAMAM'),
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