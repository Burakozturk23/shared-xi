import 'package:flutter/material.dart';

import '../controllers/mystery_player_controller.dart';
import '../models/mystery_player_state.dart';

class MysteryPlayerPage extends StatefulWidget {
  const MysteryPlayerPage({super.key});

  @override
  State<MysteryPlayerPage> createState() => _MysteryPlayerPageState();
}

class _MysteryPlayerPageState extends State<MysteryPlayerPage> {
  late final MysteryPlayerController _controller;
  final TextEditingController _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = MysteryPlayerController()..addListener(_onChanged);
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

  void _restart() {
    _answerController.clear();
    _controller.newRound();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state.isLoading || state.target == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.isSolved || state.isFailed) {
      return _buildResult(state);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mystery Player'),
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
              Text(
                'Tahmin hakkı: ${MysteryPlayerState.maxGuesses - state.guessesUsed}/${MysteryPlayerState.maxGuesses}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              _buildCluesCard(state),
              const SizedBox(height: 16),
              _buildInputCard(),
              if (state.wrongGuesses.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildWrongGuessesCard(state),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCluesCard(MysteryPlayerState state) {
    final canRevealMore = state.cluesRevealed < state.allClues.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('İpuçları', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            for (var i = 0; i < state.cluesRevealed; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.allClues[i])),
                  ],
                ),
              ),
            if (canRevealMore) ...[
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _controller.revealNextClue,
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('Sonraki İpucunu Aç (-1 hak)'),
                ),
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
                child: const Text('TAHMİN ET',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWrongGuessesCard(MysteryPlayerState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Yanlış Tahminler', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.wrongGuesses
                  .map((g) => Chip(
                        label: Text(g),
                        avatar: const Icon(Icons.close, size: 16, color: Colors.red),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(MysteryPlayerState state) {
    final success = state.isSolved;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(success ? 'Bildin!' : 'Bilemedin'),
        centerTitle: true,
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
                  Icon(
                    success ? Icons.emoji_events : Icons.close,
                    size: 64,
                    color: success ? Colors.amber : Colors.redAccent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.target!.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (success) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (i) {
                        return Icon(
                          i < state.stars ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 30,
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text('${state.guessesUsed + 1} tahminde bildin',
                        style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text('Skor: ${state.score}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ] else
                    const Text(
                      '6 tahmin hakkın doldu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Colors.grey),
                    ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _restart,
                      child: const Text('YENİ OYUNCU',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ANA MENÜ'),
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