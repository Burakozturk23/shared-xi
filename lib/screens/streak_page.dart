import 'package:flutter/material.dart';

import '../controllers/streak_controller.dart';
import '../models/streak_state.dart';
import '../services/high_score_service.dart';
import '../widgets/entity_header_tile.dart';

class StreakPage extends StatefulWidget {
  const StreakPage({super.key});

  @override
  State<StreakPage> createState() => _StreakPageState();
}

class _StreakPageState extends State<StreakPage> {
  late final StreakController _controller;
  final TextEditingController _answerController = TextEditingController();

  int _bestStreak = 0;

  @override
  void initState() {
    super.initState();

    _controller = StreakController()..addListener(_onControllerChanged);
    _controller.initialize();

    _loadBestStreak();
  }

  Future<void> _loadBestStreak() async {
    final best = await HighScoreService.getHighScore(
      key: StreakController.highScoreKey,
    );
    if (!mounted) return;
    setState(() => _bestStreak = best);
  }

  void _onControllerChanged() {
    if (!mounted) return;

    if (_controller.state.isGameOver &&
        _controller.state.streak > _bestStreak) {
      _bestStreak = _controller.state.streak;
    }

    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.disposeController();
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

  void _restart() {
    _answerController.clear();
    _controller.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seri Modu'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.isGameOver
                ? _buildGameOver(state)
                : _buildGame(state),
      ),
    );
  }

  Widget _buildGameOver(StreakState state) {
    final isNewRecord = state.streak > 0 && state.streak >= _bestStreak;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt, size: 80, color: Colors.amber),
            const SizedBox(height: 20),
            const Text(
              'SERİ BİTTİ',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Seri: ${state.streak}', style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 8),
            Text(
              'En İyi: $_bestStreak',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            if (isNewRecord) ...[
              const SizedBox(height: 16),
              const Text(
                '🎉 YENİ REKOR!',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('TEKRAR OYNA'),
                onPressed: _restart,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.home),
                label: const Text('ANA MENÜ'),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGame(StreakState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: EntityHeaderTile(entity: state.entity1!)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'VS',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(child: EntityHeaderTile(entity: state.entity2!)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Seri: ${state.streak}',
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
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _answerController,
                    onChanged: _controller.updateSuggestions,
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
                      child: const Text(
                        'GÖNDER',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (state.suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: state.suggestions
                      .map(
                        (player) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(player.name),
                          subtitle: Text(
                              '${player.position} • ${player.countryLabel}'),
                          onTap: () {
                            _controller.submitAnswer(player.name);
                            _answerController.clear();
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: state.hintsLeft > 0 ? _controller.useHint : null,
            icon: const Icon(Icons.lightbulb_outline),
            label: Text('Hint (${state.hintsLeft})'),
          ),
          if (state.feedback != null) ...[
            const SizedBox(height: 16),
            Card(
              color: (state.feedbackIsSuccess ? Colors.green : Colors.red)
                  .withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  state.feedback!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        state.feedbackIsSuccess ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}