import 'package:flutter/material.dart';

import '../controllers/random_five_controller.dart';
import '../models/random_five_state.dart';

class RandomFivePage extends StatefulWidget {
  const RandomFivePage({super.key});

  @override
  State<RandomFivePage> createState() => _RandomFivePageState();
}

class _RandomFivePageState extends State<RandomFivePage> {
  late final RandomFiveController _controller;
  final TextEditingController _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = RandomFiveController()..addListener(_onChanged);
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

  
  Widget _buildSuggestions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Öneriler',
                style: TextStyle(fontWeight: FontWeight.w600)),
            ..._controller.suggestions.map(
              (p) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(p.name),
                subtitle: Text('${p.position} • ${p.countryLabel}'),
                onTap: () {
                  _controller.submitPlayer(p);
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

  void _submit() {
    final input = _answerController.text.trim();
    if (input.isEmpty) return;

    _controller.submitGuess(input);
    _answerController.clear();
  }

  void _finish() {
    final state = _controller.state;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Özet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Toplam skor: ${state.totalScore}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Bulunan oyuncu sayısı: ${state.history.length}'),
            Text('En iyi tek tahmin: ${state.bestSingleScore} kulüp'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('ANA MENÜ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('DEVAM ET'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rastgele Beşler'),
        centerTitle: true,
        actions: [
          TextButton(onPressed: _finish, child: const Text('Bitir')),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildScoreCard(state),
              const SizedBox(height: 16),
              _buildClubsCard(state),
              const SizedBox(height: 16),
              _buildInputCard(),
              const SizedBox(height: 12),
              if (_controller.suggestions.isNotEmpty) _buildSuggestions(),
              if (state.feedback != null) _buildFeedbackCard(state),
              const SizedBox(height: 16),
              _buildHistoryCard(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard(RandomFiveState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Toplam Skor: ${state.totalScore}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            Text('Oyuncu: ${state.history.length}',
                style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildClubsCard(RandomFiveState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Bu 5 kulüpten kaçında oynamış bir oyuncu biliyorsun?',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: state.clubs
                  .map((c) => Chip(label: Text(c.name)))
                  .toList(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _controller.newRound,
                icon: const Icon(Icons.shuffle),
                label: const Text('YENİ 5 KULÜP'),
              ),
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
              onChanged: _controller.updateSuggestions,
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Oyuncu adı',
                hintText: 'Örn. Burak Yılmaz',
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

  Widget _buildFeedbackCard(RandomFiveState state) {
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

  Widget _buildHistoryCard(RandomFiveState state) {
    final sorted = List.of(state.history)
      ..sort((a, b) => b.score.compareTo(a.score));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bulunan Oyuncular (${state.history.length})',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (sorted.isEmpty)
              const Text('Henüz kimseyi bulmadın.',
                  style: TextStyle(color: Colors.grey))
            else
              ...sorted.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(entry.player.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                          Text('+${entry.score}',
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Text(
                        entry.matchedClubs.map((c) => c.name).join(', '),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}