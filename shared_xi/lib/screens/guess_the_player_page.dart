import 'package:flutter/material.dart';

import '../controllers/guess_the_player_controller.dart';
import '../models/guess_the_player_state.dart';

class GuessThePlayerPage extends StatefulWidget {
  const GuessThePlayerPage({super.key});

  @override
  State<GuessThePlayerPage> createState() => _GuessThePlayerPageState();
}

class _GuessThePlayerPageState extends State<GuessThePlayerPage> {
  late final GuessThePlayerController _controller;
  final TextEditingController _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = GuessThePlayerController()..addListener(_onChanged);
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
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state.isLoading || state.club == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guess the Player'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bitir'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildClubCard(state),
              const SizedBox(height: 16),
              _buildInputCard(),
              const SizedBox(height: 12),
              if (state.feedback != null) _buildFeedbackCard(state),
              const SizedBox(height: 16),
              _buildFoundCard(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClubCard(GuessThePlayerState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('Bu kulüpte oynamış bir oyuncu yaz',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              state.club!.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('Skor: ${state.totalScore}',
                style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _controller.newClub,
                icon: const Icon(Icons.shuffle),
                label: const Text('YENİ KULÜP'),
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
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Oyuncu adı',
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

  Widget _buildFeedbackCard(GuessThePlayerState state) {
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

  Widget _buildFoundCard(GuessThePlayerState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bulunan Oyuncular (${state.foundPlayers.length})',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (state.foundPlayers.isEmpty)
              const Text('Henüz kimse bulmadın.',
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
}