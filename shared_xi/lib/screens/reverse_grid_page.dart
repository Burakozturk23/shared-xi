import 'package:flutter/material.dart';

import '../controllers/reverse_grid_controller.dart';
import '../models/player.dart';
import '../models/reverse_grid_state.dart';

class ReverseGridPage extends StatefulWidget {
  const ReverseGridPage({super.key});

  @override
  State<ReverseGridPage> createState() => _ReverseGridPageState();
}

class _ReverseGridPageState extends State<ReverseGridPage> {
  late final ReverseGridController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ReverseGridController()..addListener(_onChanged);
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

  void _restart() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ReverseGridPage()),
    );
  }

  void _openRowGuess(int row) {
    _showGuessSheet(
      title: 'Bu satırdaki 3 oyuncunun ortak noktası ne?',
      initialText: _controller.state.rowGuessText[row] ?? '',
      onSubmit: (text) => _controller.submitRowGuess(row, text),
    );
  }

  void _openColGuess(int col) {
    _showGuessSheet(
      title: 'Bu sütundaki 3 oyuncunun ortak noktası ne?',
      initialText: _controller.state.colGuessText[col] ?? '',
      onSubmit: (text) => _controller.submitColGuess(col, text),
    );
  }

  void _showGuessSheet({
    required String title,
    required String initialText,
    required void Function(String) onSubmit,
  }) {
    final controller = TextEditingController(text: initialText);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Kulüp, ülke, pozisyon (Kaleci/Defans/Orta Saha/Forvet) ya da "100 gol" gibi bir sayı yazabilirsin.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                onSubmitted: (v) {
                  onSubmit(v);
                  Navigator.pop(context);
                },
                decoration: const InputDecoration(
                  hintText: 'Ortak noktayı yaz...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    onSubmit(controller.text);
                    Navigator.pop(context);
                  },
                  child: const Text('ONAYLA'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.cellPlayers.length < 9) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tersten Grid')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Uygun bir grid oluşturulamadı, tekrar dene.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (state.isFinished) {
      return _buildResult(state);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grid Modu - Tersten'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _controller.finishManually,
            child: const Text('Bitir'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Doğru: ${state.correctCount}/6',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildGrid(state)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(ReverseGridState state) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(flex: 2, child: SizedBox()),
            for (var col = 0; col < 3; col++)
              Expanded(
                flex: 3,
                child: _GuessHeaderCell(
                  guess: state.colGuessText[col],
                  isCorrect: state.colCorrect[col],
                  onTap: () => _openColGuess(col),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < 3; row++)
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _GuessHeaderCell(
                    guess: state.rowGuessText[row],
                    isCorrect: state.rowCorrect[row],
                    onTap: () => _openRowGuess(row),
                  ),
                ),
                for (var col = 0; col < 3; col++)
                  Expanded(
                    flex: 3,
                    child: _PlayerCell(
                      player: state.cellPlayers[row * 3 + col],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildResult(ReverseGridState state) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Tersten Grid Bitti'),
        centerTitle: true,
      ),
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
                  const Icon(Icons.grid_view, size: 64, color: Colors.amber),
                  const SizedBox(height: 16),
                  Text('${state.correctCount} / 6 doğru',
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(
                    'Skor: ${state.totalScore}',
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Text(
                            'Satır ${i + 1} cevabı: ${state.rowCriteria[i].label}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        const SizedBox(height: 4),
                        for (var i = 0; i < 3; i++)
                          Text(
                            'Sütun ${i + 1} cevabı: ${state.colCriteria[i].label}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _restart,
                      child: const Text('YENİ GRID',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.popUntil(context, (r) => r.isFirst),
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

class _GuessHeaderCell extends StatelessWidget {
  final String? guess;
  final bool isCorrect;
  final VoidCallback onTap;

  const _GuessHeaderCell({
    required this.guess,
    required this.isCorrect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final answered = guess != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: !answered
              ? Colors.white.withValues(alpha: 0.05)
              : (isCorrect
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.red.withValues(alpha: 0.15)),
          border: Border.all(
            color: !answered
                ? Colors.white24
                : (isCorrect ? Colors.green : Colors.red),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: answered
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCorrect ? Icons.check_circle : Icons.cancel,
                    size: 16,
                    color: isCorrect ? Colors.green : Colors.red,
                  ),
                  Text(
                    guess!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              )
            : const Icon(Icons.help_outline, color: Colors.white38),
      ),
    );
  }
}

class _PlayerCell extends StatelessWidget {
  final Player player;

  const _PlayerCell({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4),
      child: Text(
        player.name,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}