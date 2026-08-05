import 'package:flutter/material.dart';

import '../controllers/higher_lower_controller.dart';
import '../models/higher_lower_state.dart';
import '../models/player.dart';

class HigherLowerPage extends StatefulWidget {
  final HigherLowerCriterion criterion;

  const HigherLowerPage({super.key, required this.criterion});

  @override
  State<HigherLowerPage> createState() => _HigherLowerPageState();
}

class _HigherLowerPageState extends State<HigherLowerPage> {
  late final HigherLowerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HigherLowerController(criterion: widget.criterion)
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
    super.dispose();
  }

  String _formatValue(HigherLowerState state, Player p) {
    final v = state.valueOf(p);
    if (state.criterion == HigherLowerCriterion.marketValue) {
      if (v >= 1000000) return '€${(v / 1000000).toStringAsFixed(1)}M';
      return '€${(v / 1000).toStringAsFixed(0)}K';
    }
    return '${v.toInt()} gol';
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state.isLoading || state.currentPlayer == null || state.nextPlayer == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.isGameOver) {
      return _buildResult(state);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Higher or Lower - ${state.criterionLabel}'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Seri: ${state.streak}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  Text('Rekor: ${state.bestStreak}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildPlayerCard(state, state.currentPlayer!, revealed: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildPlayerCard(state, state.nextPlayer!, revealed: state.answered)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!state.answered)
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: () => _controller.guess(false),
                          icon: const Icon(Icons.arrow_downward),
                          label: const Text('DAHA DÜŞÜK'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: () => _controller.guess(true),
                          icon: const Icon(Icons.arrow_upward),
                          label: const Text('DAHA YÜKSEK'),
                        ),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  height: 54,
                  child: Center(
                    child: Text(
                      state.wasCorrect == true ? 'Doğru! 🎉' : 'Yanlış! ❌',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: state.wasCorrect == true ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerCard(HigherLowerState state, Player player, {required bool revealed}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              player.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '${player.position} • ${player.countryLabel}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (revealed)
              Text(
                _formatValue(state, player),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber),
              )
            else
              const Icon(Icons.question_mark, size: 36, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(HigherLowerState state) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Seri Bitti'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt, size: 64, color: Colors.amber),
                  const SizedBox(height: 16),
                  Text('Seri: ${state.streak}',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    state.streak >= state.bestStreak && state.streak > 0
                        ? 'Yeni rekor! 🎉'
                        : 'Rekor: ${state.bestStreak}',
                    style: const TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _controller.restart,
                      child: const Text('TEKRAR DENE', style: TextStyle(fontWeight: FontWeight.bold)),
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