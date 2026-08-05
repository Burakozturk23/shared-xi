import 'package:flutter/material.dart';

import '../controllers/odd_club_controller.dart';
import '../models/club.dart';
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
    _controller = OddClubController(timed: widget.timed)
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

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state.isLoading || state.player == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.isGameOver) {
      return _buildResult(state);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.timed ? 'Sahte Kulüp - Süreli' : 'Sahte Kulüp - Sonsuz Seri'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              if (widget.timed) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: state.secondsLeft / 5,
                    minHeight: 8,
                    color: state.secondsLeft <= 2 ? Colors.red : Colors.amber,
                  ),
                ),
                const SizedBox(height: 4),
                Text('${state.secondsLeft} sn',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey)),
              ],
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text('Bu oyuncunun OYNAMADIĞI kulüp hangisi?',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      Text(
                        state.player!.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${state.player!.position} • ${state.player!.countryLabel}',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(child: _buildOptions(state)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptions(OddClubState state) {
    return GridView.builder(
      itemCount: state.options.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final club = state.options[index];
        return _OptionCard(
          club: club,
          state: state,
          index: index,
          onTap: () => _controller.selectOption(index),
        );
      },
    );
  }

  Widget _buildResult(OddClubState state) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Seri Bitti'),
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
                      child: const Text('TEKRAR DENE',
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

class _OptionCard extends StatelessWidget {
  final Club club;
  final OddClubState state;
  final int index;
  final VoidCallback onTap;

  const _OptionCard({
    required this.club,
    required this.state,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor = Colors.white24;
    Color? bgColor;

    if (state.answered) {
      if (index == state.fakeIndex) {
        borderColor = Colors.green;
        bgColor = Colors.green.withValues(alpha: 0.15);
      } else if (index == state.selectedIndex) {
        borderColor = Colors.red;
        bgColor = Colors.red.withValues(alpha: 0.15);
      }
    }

    return GestureDetector(
      onTap: state.answered ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor ?? Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Image.network(
                club.logo,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.sports_soccer, size: 40),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              club.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}