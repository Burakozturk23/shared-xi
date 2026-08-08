import 'dart:math';

import 'package:flutter/material.dart';

import '../controllers/career_puzzle_controller.dart';
import '../models/career_puzzle_state.dart';
import '../models/club.dart';

class CareerPuzzlePage extends StatefulWidget {
  const CareerPuzzlePage({super.key});

  @override
  State<CareerPuzzlePage> createState() => _CareerPuzzlePageState();
}

class _CareerPuzzlePageState extends State<CareerPuzzlePage> {
  late final CareerPuzzleController _controller;
  final TextEditingController _answerController = TextEditingController();

  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _controller = CareerPuzzleController()..addListener(_onChanged);
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

  void _submitGuess() {
    final input = _answerController.text.trim();
    if (input.isEmpty) return;

    final wasGuessing = _controller.state.phase == CareerPuzzlePhase.guessingPlayer;
    _controller.submitPlayerGuess(input);
    _answerController.clear();

    if (wasGuessing && _controller.state.phase == CareerPuzzlePhase.orderingCareer) {
      setState(() => _showConfetti = true);
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _showConfetti = false);
      });
    }
  }

  void _restart() {
    setState(() => _showConfetti = false);
    _controller.restart();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state.isLoading || state.target == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Career Puzzle'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: switch (state.phase) {
                CareerPuzzlePhase.guessingPlayer => _buildGuessPhase(state),
                CareerPuzzlePhase.orderingCareer => _buildOrderingPhase(state),
                CareerPuzzlePhase.result => _buildResultPhase(state),
              },
            ),
            if (_showConfetti) const _ConfettiOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildGuessPhase(CareerPuzzleState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Bu 5 kulüpte oynamış oyuncu kim?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            itemCount: state.displayClubs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, index) {
              return _ClubLogoTile(club: state.displayClubs[index]);
            },
          ),
        ),
        const SizedBox(height: 16),
        if (state.feedback != null) ...[
          Card(
            color: Colors.red.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                state.feedback!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _answerController,
          onSubmitted: (_) => _submitGuess(),
          decoration: const InputDecoration(
            labelText: 'Oyuncu adı',
            hintText: 'Örn. Ryan Babel',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _submitGuess,
            child: const Text('TAHMİN ET', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderingPhase(CareerPuzzleState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Harika! Şimdi ${state.target!.name}\'in kariyer rotasını doğru sıraya diz.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'En eski kulüp yukarıda, en yeni kulüp aşağıda olacak şekilde sürükle.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: state.displayClubs.length,
            // ignore: deprecated_member_use
            onReorder: _controller.reorder,
            itemBuilder: (context, index) {
              final club = state.displayClubs[index];
              return _OrderableClubRow(
                key: ValueKey(club.id),
                index: index,
                club: club,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _controller.confirmOrder,
            child: const Text('KARİYERİ ONAYLA',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildResultPhase(CareerPuzzleState state) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.emoji_events, size: 56, color: Colors.amber),
                  const SizedBox(height: 12),
                  Text('Skor: ${state.totalScore} / 100',
                      style:
                          const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '(Oyuncu: +${state.guessScore}  •  Sıralama: +${state.orderScore})',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < state.displayClubs.length; i++)
            _ResultRow(
              index: i,
              club: state.displayClubs[i],
              correctStops: state.correctStops,
              isCorrect: state.resultCorrectness![i],
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _restart,
              child: const Text('YENİ BULMACA',
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
    );
  }
}

class _ClubLogoTile extends StatelessWidget {
  final Club club;

  const _ClubLogoTile({required this.club});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white24),
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
                  const Icon(Icons.sports_soccer, size: 36),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(club.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _OrderableClubRow extends StatelessWidget {
  final int index;
  final Club club;

  const _OrderableClubRow({super.key, required this.index, required this.club});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text('${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            width: 36,
            height: 36,
            child: Image.network(
              club.logo,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.sports_soccer, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(club.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const Icon(Icons.drag_handle, color: Colors.grey),
        ],
      ),
    );
  }
}

class _ResultRow extends StatefulWidget {
  final int index;
  final Club club;
  final List correctStops;
  final bool isCorrect;

  const _ResultRow({
    required this.index,
    required this.club,
    required this.correctStops,
    required this.isCorrect,
  });

  @override
  State<_ResultRow> createState() => _ResultRowState();
}

class _ResultRowState extends State<_ResultRow> with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    if (!widget.isCorrect) {
      Future.delayed(Duration(milliseconds: 100 * widget.index), () {
        if (mounted) _shakeController.forward();
      });
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final correctIndex =
        widget.correctStops.indexWhere((s) => s.clubId == widget.club.id);
    final correctStop = correctIndex >= 0 ? widget.correctStops[correctIndex] : null;

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final offset = widget.isCorrect
            ? 0.0
            : sin(_shakeController.value * pi * 6) * 6 * (1 - _shakeController.value);
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: widget.isCorrect
              ? Colors.green.withValues(alpha: 0.12)
              : Colors.red.withValues(alpha: 0.12),
          border: Border.all(color: widget.isCorrect ? Colors.green : Colors.red),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text('${widget.index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              width: 32,
              height: 32,
              child: Image.network(
                widget.club.logo,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.sports_soccer, size: 22),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.club.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (!widget.isCorrect && correctStop != null)
                    Text(
                      'Doğrusu: ${correctIndex + 1}. sıra (${correctStop.yearsLabel})',
                      style: const TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                ],
              ),
            ),
            Icon(
              widget.isCorrect ? Icons.check_circle : Icons.cancel,
              color: widget.isCorrect ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}

/// Harici paket kullanmadan basit bir confetti patlaması.
class _ConfettiOverlay extends StatefulWidget {
  const _ConfettiOverlay();

  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_ConfettiParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    const colors = [
      Colors.amber, Colors.green, Colors.blue, Colors.red, Colors.purple,
    ];

    for (var i = 0; i < 40; i++) {
      _particles.add(_ConfettiParticle(
        x: _random.nextDouble(),
        angle: _random.nextDouble() * pi * 2,
        speed: 0.3 + _random.nextDouble() * 0.7,
        color: colors[_random.nextInt(colors.length)],
        size: 4 + _random.nextDouble() * 5,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _ConfettiPainter(_particles, _controller.value),
          );
        },
      ),
    );
  }
}

class _ConfettiParticle {
  final double x;
  final double angle;
  final double speed;
  final Color color;
  final double size;

  _ConfettiParticle({
    required this.x,
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final dy = progress * size.height * p.speed;
      final dx = sin(p.angle + progress * 4) * 30;
      final opacity = (1 - progress).clamp(0.0, 1.0);

      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(p.x * size.width + dx, dy),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}