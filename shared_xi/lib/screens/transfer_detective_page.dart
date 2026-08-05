import 'package:flutter/material.dart';

import '../controllers/transfer_detective_controller.dart';
import '../data/country_flags.dart';
import '../models/transfer_detective_state.dart';

class TransferDetectivePage extends StatefulWidget {
  const TransferDetectivePage({super.key});

  @override
  State<TransferDetectivePage> createState() => _TransferDetectivePageState();
}

class _TransferDetectivePageState extends State<TransferDetectivePage> {
  late final TransferDetectiveController _controller;
  final TextEditingController _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = TransferDetectiveController()..addListener(_onChanged);
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

  String _feeLabel(double fee) => '€${(fee / 1000000).toStringAsFixed(0)}M';

  List<String> _cluesFor(TransferDetectiveState state) {
    final t = state.transfer!;
    final from = state.fromClub!;
    final to = state.toClub!;
    final target = state.target!;

    return [
      '📅 Yıl: ${t.year}',
      '💰 Bonservis Bedeli: ${_feeLabel(t.fee)}',
      '🌍 Lig Geçişi: ${from.league} ➔ ${to.league}',
      '🛡️ Gittiği Kulüp: ${to.name}',
      '${flagFor(target.countries.isNotEmpty ? target.countries.first : "")} Uyruğu: ${target.countryLabel}',
    ];
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

    final clues = _cluesFor(state);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Detective'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'İpucu: ${state.cluesRevealed}/${TransferDetectiveState.maxClues}  •  Şu an bilirsen: ${125 - state.cluesRevealed * 25} puan',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildCluesCard(state, clues),
              const SizedBox(height: 16),
              _buildInputCard(state),
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

  Widget _buildCluesCard(TransferDetectiveState state, List<String> clues) {
    final canRevealMore = state.cluesRevealed < TransferDetectiveState.maxClues;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bu oyuncu kim?', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            for (var i = 0; i < state.cluesRevealed; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(clues[i], style: const TextStyle(fontSize: 15)),
              ),
            if (canRevealMore) ...[
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _controller.revealNextClue,
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('Sonraki İpucunu Aç (puan düşer)'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard(TransferDetectiveState state) {
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
                child: const Text('TAHMİN ET', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWrongGuessesCard(TransferDetectiveState state) {
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

  Widget _buildResult(TransferDetectiveState state) {
    final success = state.isSolved;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(success ? 'Buldun!' : 'Bulunamadı'),
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
                  Text(
                    '${state.fromClub!.name} ➔ ${state.toClub!.name} (${state.transfer!.year})',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  if (success)
                    Text('Skor: ${state.score}',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold))
                  else
                    const Text('5 ipucu da tükendi.',
                        style: TextStyle(fontSize: 15, color: Colors.grey)),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        _controller.restart();
                      },
                      child: const Text('YENİ TRANSFER', style: TextStyle(fontWeight: FontWeight.bold)),
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