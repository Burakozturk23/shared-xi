import 'package:flutter/material.dart';

import '../controllers/mystery_player_controller.dart';
import '../models/mystery_player_state.dart';
import '../models/player.dart';

class MysteryPlayerPage extends StatefulWidget {
  const MysteryPlayerPage({super.key});

  @override
  State<MysteryPlayerPage> createState() => _MysteryPlayerPageState();
}

class _MysteryPlayerPageState extends State<MysteryPlayerPage> {
  late final MysteryPlayerController _controller;
  final TextEditingController _answerController = TextEditingController();
  List<Player> _suggestions = const [];

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
    _controller.disposeController();
    _answerController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    setState(() {
      _suggestions = q.trim().length >= 3 ? _controller.suggestions(q) : const [];
    });
  }

  void _submit([String? forced]) {
    final input = (forced ?? _answerController.text).trim();
    if (input.isEmpty) return;
    _controller.submitGuess(input);
    _answerController.clear();
    setState(() => _suggestions = const []);
  }

  void _restart() {
    _answerController.clear();
    setState(() => _suggestions = const []);
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
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTopBar(state),
            const SizedBox(height: 12),
            _buildHints(state),
            const SizedBox(height: 12),
            Text(
              'Mevcut kazanılacak: ${state.potentialPoints} puan'
              '${state.speedBonusActive ? "  •  ⚡ Hız x1.5 aktif" : ""}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _controller.maskedName(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInput(state),
            if (state.feedback != null) ...[
              const SizedBox(height: 8),
              Text(
                state.feedback!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: state.feedbackSuccess ? Colors.greenAccent : Colors.orange,
                ),
              ),
            ],
            if (state.wrongGuesses.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Yanlışlar: ${state.wrongGuesses.join(", ")}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(MysteryPlayerState state) {
    final hearts = List.generate(
      MysteryPlayerState.maxLives,
      (i) => Icon(
        i < state.lives ? Icons.favorite : Icons.favorite_border,
        color: Colors.redAccent,
        size: 20,
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '🏆 Seri: x${state.streak} (${state.streakMultiplierLabel})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Row(children: hearts),
            const SizedBox(width: 10),
            Text('🪙 ${state.coins}', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildHints(MysteryPlayerState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('İpuçları', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (var i = 0; i < state.hints.length; i++)
              _hintRow(state, i, state.hints[i]),
          ],
        ),
      ),
    );
  }

  Widget _hintRow(MysteryPlayerState state, int index, MysteryHint hint) {
    if (hint.unlocked) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.lightbulb, size: 18, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${hint.title}: ${hint.text}'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.lock, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text('İpucu: ${hint.title}')),
          Text('-${hint.cost} puan', style: const TextStyle(color: Colors.orange)),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _controller.unlockHint(index),
            child: const Text('Aç'),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(MysteryPlayerState state) {
    return Column(
      children: [
        TextField(
          controller: _answerController,
          textInputAction: TextInputAction.done,
          onChanged: _onQueryChanged,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            labelText: 'Oyuncu adı',
            border: OutlineInputBorder(),
          ),
        ),
        if (_suggestions.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 6),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = _suggestions[i];
                return ListTile(
                  dense: true,
                  title: Text(p.name),
                  onTap: () {
                    _answerController.text = p.name;
                    _submit(p.name);
                  },
                );
              },
            ),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _submit(),
                child: const Text('TAHMİN ET'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _controller.revealLetter,
                child: Text('Harf Al (${MysteryPlayerState.letterRevealCost}🪙)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _controller.skip,
          child: const Text('PAS GEÇ (seri sıfırlanır)'),
        ),
      ],
    );
  }

  Widget _buildResult(MysteryPlayerState state) {
    final ok = state.isSolved;
    return Scaffold(
      appBar: AppBar(title: const Text('Mystery Player')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                ok ? Icons.check_circle : Icons.cancel,
                size: 64,
                color: ok ? Colors.green : Colors.redAccent,
              ),
              const SizedBox(height: 12),
              Text(
                ok ? 'Doğru!' : 'Bilemedin',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(state.target?.name ?? ''),
              const SizedBox(height: 8),
              if (state.feedback != null) Text(state.feedback!),
              Text('Oturum puanı: ${state.sessionScore}'),
              Text('Seri: ${state.streak}'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _restart,
                child: Text(ok ? 'SONRAKİ' : 'TEKRAR DENE'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ANA MENÜ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}