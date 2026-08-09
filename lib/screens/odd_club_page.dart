import 'package:flutter/material.dart';

import '../controllers/odd_club_controller.dart';
import '../models/odd_club_state.dart';

class OddClubPage extends StatefulWidget {
  final bool timed;

  const OddClubPage({super.key, required this.timed});

  @override
  State<OddClubPage> createState() => _OddClubPageState();
}

class _OddClubPageState extends State<OddClubPage> {
  late final OddClubController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OddClubController(timed: widget.timed)..addListener(_onChanged);
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
    final s = _controller.state;

    if (s.isLoading || s.player == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (s.isGameOver) return _result(s);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Imposter'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _topBar(s),
              const SizedBox(height: 12),
              if (widget.timed)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: s.secondsLeft / OddClubState.questionSeconds,
                    minHeight: 8,
                    color: s.secondsLeft <= 3 ? Colors.redAccent : Colors.amber,
                  ),
                ),
              const SizedBox(height: 12),
              _playerCard(s),
              const SizedBox(height: 12),
              const Text(
                'Hangi kulüpte HİÇ oynamadı?',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 10),
              Expanded(child: _grid(s)),
              if (s.feedback != null) ...[
                Text(
                  s.feedback!,
                  style: TextStyle(
                    color: s.wasCorrect ? Colors.greenAccent : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              if (s.factLine != null) ...[
                const SizedBox(height: 4),
                Text(
                  s.factLine!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
              const SizedBox(height: 8),
              _jokers(s),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(OddClubState s) {
    final hearts = List.generate(
      OddClubState.maxLives,
      (i) => Icon(
        i < s.lives ? Icons.favorite : Icons.favorite_border,
        color: Colors.redAccent,
        size: 18,
      ),
    );
    return Row(
      children: [
        Row(children: hearts),
        const Spacer(),
        if (widget.timed) Text('⏱️ ${s.secondsLeft}s'),
        const SizedBox(width: 10),
        Text('⭐ ${s.score}'),
        const SizedBox(width: 8),
        Text('Seri ${s.streak} (${s.streakMultiplier}x)',
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _playerCard(OddClubState s) {
    final p = s.player!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            const Icon(Icons.person, size: 40, color: Colors.white70),
            const SizedBox(height: 6),
            Text(
              p.name.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              '${p.countryLabel.isEmpty ? "?" : p.countryLabel}  •  ${_controller.positionLabel()}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Color? _tileColor(OddClubState s, int i) {
    if (!s.answered) return null;
    if (i == s.fakeIndex) return Colors.green.withValues(alpha: 0.35);
    if (i == s.selectedIndex && i != s.fakeIndex) {
      return Colors.red.withValues(alpha: 0.35);
    }
    return null;
  }

  Widget _grid(OddClubState s) {
    return GridView.builder(
      itemCount: s.options.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, i) {
        final club = s.options[i];
        final eliminated = s.eliminatedIndex == i;
        final crowd = s.crowdPercents;

        return Opacity(
          opacity: eliminated ? 0.25 : 1,
          child: Material(
            color: _tileColor(s, i) ?? Colors.white10,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: eliminated || s.answered
                  ? null
                  : () => _controller.selectOption(i),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (club.logo.isNotEmpty)
                      Image.network(
                        club.logo,
                        height: 40,
                        errorBuilder: (c, e, st) =>
                            const Icon(Icons.shield, size: 36),
                      )
                    else
                      const Icon(Icons.shield, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      club.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    if (crowd != null && !eliminated)
                      Text('%${crowd[i]}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.amber)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _jokers(OddClubState s) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: s.jokers5050Left > 0 && !s.answered
                ? _controller.use5050
                : null,
            child: Text('50% (${s.jokers5050Left})'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: s.jokersCrowdLeft > 0 && !s.answered
                ? _controller.useCrowd
                : null,
            child: Text('İpucu % (${s.jokersCrowdLeft})'),
          ),
        ),
      ],
    );
  }

  Widget _result(OddClubState s) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find Imposter')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag, size: 56, color: Colors.amber),
              const SizedBox(height: 12),
              Text('Skor: ${s.score}',
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold)),
              Text('En iyi seri: ${s.bestStreak}'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _controller.restart,
                child: const Text('TEKRAR DENE'),
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