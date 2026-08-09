import 'package:flutter/material.dart';

import '../controllers/transfer_detective_controller.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../models/transfer_detective_state.dart';

class TransferDetectivePage extends StatefulWidget {
  const TransferDetectivePage({super.key});

  @override
  State<TransferDetectivePage> createState() => _TransferDetectivePageState();
}

class _TransferDetectivePageState extends State<TransferDetectivePage> {
  late final TransferDetectiveController _controller;
  final TextEditingController _answerController = TextEditingController();
  List<Player> _suggestions = const [];

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

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state.isLoading ||
        state.target == null ||
        state.transfer == null ||
        state.fromClub == null ||
        state.toClub == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.isSolved || state.isFailed) {
      return _buildResult(state);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Detective'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _topBar(state),
            const SizedBox(height: 12),
            _transferCard(state),
            const SizedBox(height: 12),
            _hintsSection(state),
            const SizedBox(height: 12),
            Text(
              'Potansiyel kazanç: ${state.potentialPoints} puan',
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
            _inputSection(state),
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
              const SizedBox(height: 8),
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

  Widget _topBar(TransferDetectiveState state) {
    final hearts = List.generate(
      TransferDetectiveState.maxLives,
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
                '🏆 ${state.sessionScore}  •  Seri ${state.streakMultiplierLabel}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Row(children: hearts),
            const SizedBox(width: 8),
            Text('🪙 ${state.coins}'),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _clubLogo(Club club, {double size = 36}) {
    if (club.logo.isEmpty) {
      return Icon(Icons.shield, size: size);
    }
    return Image.network(
      club.logo,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.shield, size: size),
    );
  }

  Widget _transferCard(TransferDetectiveState state) {
    final t = state.transfer!;
    final from = state.fromClub!;
    final to = state.toClub!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip(Icons.calendar_today, '${t.year}'),
                _chip(Icons.payments, _controller.formatFee()),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _clubLogo(from, size: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${from.league.isNotEmpty ? from.league : from.country}'
                    '  →  '
                    '${to.league.isNotEmpty ? to.league : to.country}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _clubLogo(to, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Gittiği kulüp', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(to.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _hintsSection(TransferDetectiveState state) {
    final next = state.nextLockedHintIndex;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('İpuçları', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final hint in state.hints)
              if (hint.unlocked)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      if (hint.logoUrl != null) ...[
                        Image.network(
                          hint.logoUrl!,
                          width: 24,
                          height: 24,
                          errorBuilder: (c, e, s) => const Icon(Icons.shield, size: 20),
                        ),
                        const SizedBox(width: 8),
                      ] else ...[
                        const Icon(Icons.lightbulb, size: 18, color: Colors.amber),
                        const SizedBox(width: 8),
                      ],
                      Expanded(child: Text('${hint.title}: ${hint.text}')),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.lock, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: Text(hint.title, style: const TextStyle(color: Colors.grey))),
                      Text('-${hint.cost}', style: const TextStyle(color: Colors.orange)),
                    ],
                  ),
                ),
            if (next != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _controller.unlockNextHint,
                icon: const Icon(Icons.add),
                label: Text(
                  'İpucu aç (−${state.hints[next].cost} puan): ${state.hints[next].title}',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _inputSection(TransferDetectiveState state) {
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
                onPressed: _controller.revealFirstLetter,
                child: Text('İlk harf (${TransferDetectiveState.letterRevealCost}🪙)'),
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

  Widget _buildResult(TransferDetectiveState state) {
    final ok = state.isSolved;
    return Scaffold(
      appBar: AppBar(title: Text(ok ? 'Buldun!' : 'Bulunamadı')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                ok ? Icons.emoji_events : Icons.close,
                size: 64,
                color: ok ? Colors.amber : Colors.redAccent,
              ),
              const SizedBox(height: 12),
              Text(
                state.target?.name ?? '',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text(
                '${state.fromClub?.name} → ${state.toClub?.name} (${state.transfer?.year})',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              if (state.feedback != null) Text(state.feedback!),
              Text('Oturum puanı: ${state.sessionScore}'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _answerController.clear();
                  setState(() => _suggestions = const []);
                  _controller.restart();
                },
                child: const Text('YENİ TRANSFER'),
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