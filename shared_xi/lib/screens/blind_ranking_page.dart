import 'package:flutter/material.dart';

import '../controllers/blind_ranking_controller.dart';
import '../models/blind_ranking_state.dart';


class BlindRankingPage extends StatefulWidget {
  const BlindRankingPage({super.key});

  @override
  State<BlindRankingPage> createState() => _BlindRankingPageState();
}

class _BlindRankingPageState extends State<BlindRankingPage> {
  late final BlindRankingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BlindRankingController()..addListener(_onChanged);
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

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state.isLoading || state.players.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.isFinished) {
      return _buildResult(state);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Körlemesine Kariyer Sıralama'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Oyuncu: ${state.currentIndex + 1}/${BlindRankingState.slotCount}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              _buildCurrentPlayerCard(state),
              const SizedBox(height: 8),
              const Text(
             'Genel kariyer başarısına göre (en iyiden en zayıfa) sırala — gol sayısı da hesaba katılıyor. Yerleştirince değiştiremezsin!',
             textAlign: TextAlign.center,
             style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
              const SizedBox(height: 16),
              Expanded(child: _buildSlots(state)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPlayerCard(BlindRankingState state) {
    final player = state.currentPlayer!;

    return Card(
      color: Colors.amber.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              player.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '${player.position} • ${player.countryLabel}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlots(BlindRankingState state) {
    return ListView.separated(
      itemCount: BlindRankingState.slotCount,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final player = state.slots[index];
        final filled = player != null;

        return GestureDetector(
          onTap: filled
              ? null
              : () => _controller.placeCurrentPlayerAt(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: filled
                  ? Colors.blue.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                color: filled ? Colors.blue : Colors.white24,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Expanded(
                  child: Text(
                    filled ? player.name : 'Boş - dokun ve yerleştir',
                    style: TextStyle(
                      fontWeight: filled ? FontWeight.w600 : FontWeight.normal,
                      color: filled ? null : Colors.white38,
                    ),
                  ),
                ),
                if (filled) const Icon(Icons.lock, size: 16, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResult(BlindRankingState state) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Sıralama Tamamlandı'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.leaderboard, size: 56, color: Colors.amber),
                      const SizedBox(height: 12),
                      Text('Skor: ${state.totalScore} / 100',
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('${state.exactMatches} oyuncu tam yerinde',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Senin sıralaman vs Gerçek sıralama',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      for (var i = 0; i < state.slots.length; i++)
                        _buildComparisonRow(state, i),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _controller.restart,
                  child: const Text('YENİ SIRALAMA',
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
    );
  }

  Widget _buildComparisonRow(BlindRankingState state, int index) {
  final player = state.slots[index]!;
  final trueRank = state.trueRankOf(player);
  final correct = trueRank == index + 1;

  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(
          width: 24,
          child: Text('${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Text(player.name,
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Text('${player.careerGoals} gol',
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(width: 6),
        Icon(
          correct ? Icons.check_circle : Icons.swap_vert,
          size: 16,
          color: correct ? Colors.green : Colors.orange,
        ),
        const SizedBox(width: 4),
        Text('Gerçek: $trueRank',
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    ),
  );
}
}