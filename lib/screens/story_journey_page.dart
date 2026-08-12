import 'package:flutter/material.dart';

import '../controllers/story_journey_controller.dart';
import '../models/story_journey_state.dart';
import '../models/story_scene.dart';

class StoryJourneyPage extends StatefulWidget {
  final String appBarTitle;
  final List<StoryChapter> chapters;
  final String completionText;

  const StoryJourneyPage({
    super.key,
    required this.appBarTitle,
    required this.chapters,
    required this.completionText,
  });

  @override
  State<StoryJourneyPage> createState() => _StoryJourneyPageState();
}

class _StoryJourneyPageState extends State<StoryJourneyPage> {
  late final StoryJourneyController _controller;
  final TextEditingController _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = StoryJourneyController(chapters: widget.chapters)
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

    _controller.submitGuess(input);
    _answerController.clear();
    _controller.clearSuggestions();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.isComplete) {
      return _buildComplete();
    }

    final chapter = _controller.currentChapter;
    final scene = _controller.currentScene;

    return Scaffold(
      appBar: AppBar(title: Text(widget.appBarTitle), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildChapterProgress(state),
              const SizedBox(height: 16),
              _buildNarrativeCard(chapter),
              const SizedBox(height: 16),
              _buildSceneCard(state, scene),
              const SizedBox(height: 16),
              _buildInputCard(),
              const SizedBox(height: 12),
              if (state.suggestions.isNotEmpty) _buildSuggestionsCard(state),
              const SizedBox(height: 12),
              if (state.feedback != null) _buildFeedbackCard(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChapterProgress(StoryJourneyState state) {
    return Row(
      children: List.generate(widget.chapters.length, (i) {
        final isDone = i < state.currentChapterIndex;
        final isCurrent = i == state.currentChapterIndex;
        final isLocked = i > state.currentChapterIndex;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
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
                        : (isLocked ? Icons.lock : Icons.play_arrow),
                    size: 13,
                    color: isLocked ? Colors.white38 : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text('${i + 1}',
                    style: const TextStyle(fontSize: 9, color: Colors.grey)),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNarrativeCard(StoryChapter chapter) {
    return Card(
      color: Colors.amber.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📌 BÖLÜM ${chapter.number}: ${chapter.title}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            if (chapter.matchLabel != null) ...[
              const SizedBox(height: 4),
              Text(chapter.matchLabel!,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 10),
            Text('"${chapter.narrative}"',
                style:
                    const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildSceneCard(StoryJourneyState state, StoryScene scene) {
    final isCommon = scene.type == StorySceneType.commonPlayers;
    final progress = isCommon
        ? state.foundThisScene.length
        : state.matchedAnswersThisScene.length;
    final total =
        isCommon ? scene.requiredFinds : scene.correctAnswers.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🎮 ${scene.title}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (scene.matchLabel != null) ...[
              const SizedBox(height: 4),
              Text(scene.matchLabel!,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600)),
            ],
            if (scene.sceneNarrative != null) ...[
              const SizedBox(height: 8),
              Text('"${scene.sceneNarrative!}"',
                  style: const TextStyle(
                      fontSize: 12, fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 10),
            Text(scene.taskDescription, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            Text('$progress / $total bulundu',
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                  value: total == 0 ? 0 : progress / total, minHeight: 8),
            ),
            if (isCommon && state.foundThisScene.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: state.foundThisScene
                    .map((p) => Chip(
                          label: Text(p.name),
                          avatar: const Icon(Icons.check,
                              size: 16, color: Colors.green),
                        ))
                    .toList(),
              ),
            ],
            if (!isCommon && state.matchedAnswersThisScene.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: state.matchedAnswersThisScene
                    .map((name) => Chip(
                          label: Text(name),
                          avatar: const Icon(Icons.check,
                              size: 16, color: Colors.green),
                        ))
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
                hintText: 'Örn. Luis Suarez',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
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

  Widget _buildSuggestionsCard(StoryJourneyState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Öneriler',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...state.suggestions.map(
              (player) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(player.name),
                subtitle: Text('${player.position} • ${player.countryLabel}'),
                onTap: () {
                  _controller.submitPlayer(player);
                  _answerController.clear();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(StoryJourneyState state) {
    final color = state.feedbackSuccess ? Colors.green : Colors.red;

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

  Widget _buildComplete() {
    return Scaffold(
      appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Hikaye Tamamlandı'),
          centerTitle: true),
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
                  const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
                  const SizedBox(height: 16),
                  Text(
                    widget.completionText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('GERİ DÖN',
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