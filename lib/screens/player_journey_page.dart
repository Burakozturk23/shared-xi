import 'package:flutter/material.dart';

import '../controllers/player_journey_controller.dart';
import '../models/player.dart';
import '../models/player_journey.dart';
import '../models/player_journey_state.dart';

class PlayerJourneyPage extends StatefulWidget {
  final PlayerJourneyDefinition journey;

  const PlayerJourneyPage({
    super.key,
    required this.journey,
  });

  @override
  State<PlayerJourneyPage> createState() => _PlayerJourneyPageState();
}

class _PlayerJourneyPageState extends State<PlayerJourneyPage> {
  late final PlayerJourneyController _controller;
  final TextEditingController _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _controller = PlayerJourneyController(
      journey: widget.journey,
    )..addListener(_onChanged);

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

    _controller.submitGuess(input);
    _answerController.clear();
    _controller.clearSuggestions();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state.isLoading || state.journey == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (state.isJourneyComplete) {
      return _buildComplete(state);
    }

    final stage = _controller.currentStage;
    final foundThisStage =
        state.foundPerStage[state.currentStageIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.journey.subjectName),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStageProgress(state),

              const SizedBox(height: 16),

              _buildNarrativeCard(
                stage,
                state.currentStageIndex,
              ),

              const SizedBox(height: 16),

              _buildTaskCard(
                stage,
                foundThisStage,
              ),

              const SizedBox(height: 16),

              _buildInputCard(),

              if (state.suggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildSuggestionsCard(state),
              ],

              const SizedBox(height: 12),

              _buildHintsCard(state),

              const SizedBox(height: 12),

              if (state.feedback != null)
                _buildFeedbackCard(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageProgress(PlayerJourneyState state) {
    final stages = widget.journey.stages;

    return Row(
      children: List.generate(stages.length, (i) {
        final isDone = i < state.currentStageIndex;
        final isCurrent = i == state.currentStageIndex;
        final isLocked = i > state.currentStageIndex;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? Colors.green
                        : (isCurrent
                            ? Colors.amber
                            : Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Icon(
                    isDone
                        ? Icons.check
                        : (isLocked
                            ? Icons.lock
                            : Icons.play_arrow),
                    size: 16,
                    color: isLocked ? Colors.white38 : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${i + 1}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNarrativeCard(
    PlayerJourneyStage stage,
    int index,
  ) {
    return Card(
      color: Colors.amber.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📍 ${index + 1}. Aşama: ${stage.title}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              stage.subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '"${stage.narrative}"',
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(
    PlayerJourneyStage stage,
    List<Player> foundThisStage,
  ) {
    final progress = stage.requiredFinds == 0
        ? 0.0
        : (foundThisStage.length / stage.requiredFinds)
            .clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🎯 Görev',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              stage.taskDescription,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              '${foundThisStage.length} / ${stage.requiredFinds} bulundu',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
              ),
            ),
            if (foundThisStage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: foundThisStage
                    .map<Widget>(
                      (p) => Chip(
                        label: Text(p.name),
                        avatar: const Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.green,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
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
              onChanged: _controller.updateSuggestions,
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Oyuncu adı',
                hintText: 'En az 3 harf yaz, listeden seç...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submit,
                child: const Text(
                  'GÖNDER',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsCard(
    PlayerJourneyState state,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Öneriler',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            ...state.suggestions.map(
              (player) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(player.name),
                subtitle: Text(
                  '${player.position} • ${player.countryLabel}',
                ),
                onTap: () {
                  _controller.submitPlayer(player);
                  _answerController.clear();
                  _controller.clearSuggestions();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHintsCard(
    PlayerJourneyState state,
  ) {
    final used = state.hintsUsed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'İpuçları',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            if (used >= 1)
              Text(
                '🏳️ Ülke: ${_controller.hintCountry ?? "—"}',
              ),

            if (used >= 2)
              Text(
                '📍 Mevki: ${_controller.hintPosition ?? "—"}',
              ),

            if (used >= 3)
              Text(
                '🔤 Baş harfler: ${_controller.hintInitials ?? "—"}',
              ),

            if (used > 0)
              const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed:
                  used >= 3 ? null : _controller.useHint,
              icon: const Icon(
                Icons.lightbulb_outline,
              ),
              label: Text(
                used >= 3
                    ? 'İpuçları tükendi'
                    : 'İpucu al ($used/3)',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(
    PlayerJourneyState state,
  ) {
    final color =
        state.feedbackSuccess ? Colors.green : Colors.red;

    return Card(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          state.feedback ?? '',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildComplete(
    PlayerJourneyState state,
  ) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Hikaye Tamamlandı'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 32,
                horizontal: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.emoji_events,
                    size: 64,
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${widget.journey.subjectName}\n'
                    'Hikayesi %100 Tamamlandı! 🎉',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'GERİ DÖN',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
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
