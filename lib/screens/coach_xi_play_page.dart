import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../controllers/coach_xi_controller.dart';
import '../data/build_xi_formations.dart';
import '../models/coach.dart';
import '../theme/app_theme.dart';

class CoachXiPlayPage extends StatefulWidget {
  const CoachXiPlayPage({super.key});

  @override
  State<CoachXiPlayPage> createState() => _CoachXiPlayPageState();
}

class _CoachXiPlayPageState extends State<CoachXiPlayPage> {
  late final CoachXiController _c;
  final _searchCtrl = TextEditingController();
  final _rng = Random();

  String _spinLabel = '…';
  bool _showGame = false;

  @override
  void initState() {
    super.initState();
    _c = CoachXiController()..initialize();
    _c.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSpin());
  }

  @override
  void dispose() {
    _c.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _startSpin() async {
    if (_c.candidates.isEmpty) {
      setState(() => _showGame = true);
      return;
    }
    _c.setSpinning(true);
    final winner = _c.randomCandidate();
    const steps = 28;
    for (var i = 0; i < steps; i++) {
      if (!mounted) return;
      final name = _c.candidates[_rng.nextInt(_c.candidates.length)].name;
      setState(() => _spinLabel = name);
      final delay = 40 + (i * i * 1.2).round();
      await Future<void>.delayed(Duration(milliseconds: delay.clamp(40, 220)));
    }
    if (!mounted) return;
    setState(() => _spinLabel = winner.name);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    _c.applyCoach(winner);
    setState(() => _showGame = true);
  }

  Future<void> _spinAgain() async {
    setState(() {
      _showGame = false;
      _spinLabel = '…';
    });
    await _startSpin();
  }

  @override
  Widget build(BuildContext context) {
    if (_c.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_c.errorMessage != null && _c.candidates.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Teknik Direktör XI')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_c.errorMessage!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    if (!_showGame || _c.coach == null) {
      return _buildSpinScreen();
    }

    return _buildGameScreen(_c.coach!);
  }

  Widget _buildSpinScreen() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text('Teknik Direktör XI'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Teknik direktör seçiliyor…',
              style: TextStyle(
                color: AppTheme.hintColor.withValues(alpha: 0.9),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 28),
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF3DDC84).withValues(alpha: 0.7),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3DDC84).withValues(alpha: 0.15),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor:
                        AppTheme.primaryColor.withValues(alpha: 0.25),
                    child: Icon(Icons.person, size: 36, color: Colors.white70),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 260,
                    child: Text(
                      _spinLabel,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameScreen(Coach coach) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text('Teknik Direktör XI'),
        actions: [
          TextButton(
            onPressed: _spinAgain,
            child: const Text('Yeni TD'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Coach header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor:
                        AppTheme.primaryColor.withValues(alpha: 0.2),
                    child: Text(
                      coach.name.isNotEmpty ? coach.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TEKNİK DİREKTÖR',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            color: AppTheme.hintColor,
                          ),
                        ),
                        Text(
                          coach.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        if (coach.countries.isNotEmpty)
                          Text(
                            coach.countries.join(', '),
                            style: const TextStyle(
                              color: AppTheme.hintColor,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${_c.filledCount}/${_c.totalSlots}',
                    style: const TextStyle(
                      color: Color(0xFF3DDC84),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${coach.name} ile aynı kulüplerde oynamış futbolcuları bul.',
              style: const TextStyle(color: AppTheme.hintColor, fontSize: 12),
            ),
          ),
          const SizedBox(height: 6),
          // Formations
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final f in allFormations)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Text(f.name, style: const TextStyle(fontSize: 12)),
                      selected: _c.formation.id == f.id,
                      onSelected: (_) => _c.setFormation(f),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Pitch
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return _PitchBoard(
                    formation: _c.formation,
                    slots: _c.slots,
                    selectedSlot: _c.selectedSlot,
                    onTapSlot: _c.selectSlot,
                    onClearSlot: _c.clearSlot,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                  );
                },
              ),
            ),
          ),
          // Search panel
          if (_c.selectedSlot != null)
            Container(
              color: const Color(0xFF0D1117),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Oyuncu adı yaz…',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: _c.search,
                  ),
                  if (_c.searchResults.isNotEmpty)
                    SizedBox(
                      height: 140,
                      child: ListView.builder(
                        itemCount: _c.searchResults.length,
                        itemBuilder: (context, i) {
                          final p = _c.searchResults[i];
                          return ListTile(
                            dense: true,
                            title: Text(p.name),
                            subtitle: Text(p.position),
                            onTap: () {
                              final err = _c.tryPlace(p);
                              if (err != null && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(err)),
                                );
                              } else {
                                _searchCtrl.clear();
                              }
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          if (_c.isComplete)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3DDC84),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('11 tamam!'),
                        content: Text('${coach.name} kadrosu dolduruldu.'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _spinAgain();
                            },
                            child: const Text('Yeni TD'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.pop(context);
                            },
                            child: const Text('Bitir'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Kadro tamam'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PitchBoard extends StatelessWidget {
  final Formation formation;
  final List slots;
  final int? selectedSlot;
  final ValueChanged<int> onTapSlot;
  final ValueChanged<int> onClearSlot;
  final double width;
  final double height;

  const _PitchBoard({
    required this.formation,
    required this.slots,
    required this.selectedSlot,
    required this.onTapSlot,
    required this.onClearSlot,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final h = height.clamp(280.0, 520.0);
    return Center(
      child: Container(
        width: width,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B5E3B), Color(0xFF0D3B24)],
          ),
          border: Border.all(color: Colors.white24),
        ),
        child: Stack(
          children: [
            // basit saha çizgileri
            Positioned.fill(
              child: CustomPaint(painter: _PitchLinesPainter()),
            ),
            for (var i = 0; i < formation.slots.length; i++)
              _slotBubble(i, h),
          ],
        ),
      ),
    );
  }

  Widget _slotBubble(int i, double h) {
    final slot = formation.slots[i];
    final player = i < slots.length ? slots[i] : null;
    final selected = selectedSlot == i;
    // x,y 0-1 — formasyon verisinde GK üstte
    final left = slot.x * width - 28;
    final top = slot.y * h - 28;

    return Positioned(
      left: left.clamp(4.0, width - 60),
      top: top.clamp(4.0, h - 60),
      child: GestureDetector(
        onTap: () => onTapSlot(i),
        onLongPress: player != null ? () => onClearSlot(i) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: player != null
                ? const Color(0xFF161B22)
                : Colors.black.withValues(alpha: 0.35),
            border: Border.all(
              color: selected
                  ? const Color(0xFF3DDC84)
                  : (player != null ? Colors.white54 : Colors.white30),
              width: selected ? 2.5 : 1.5,
              strokeAlign: BorderSide.strokeAlignOutside,
            ),
          ),
          child: player != null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      player.name.split(' ').last,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      slot.code,
                      style: const TextStyle(fontSize: 8, color: Colors.white54),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, size: 18, color: Colors.white54),
                    Text(
                      slot.code,
                      style: const TextStyle(fontSize: 9, color: Colors.white54),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PitchLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
      const Radius.circular(8),
    );
    canvas.drawRRect(r, paint);

    // orta çizgi
    canvas.drawLine(
      Offset(8, size.height / 2),
      Offset(size.width - 8, size.height / 2),
      paint,
    );
    // orta daire
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.12,
      paint,
    );
    // ceza sahaları (üst/alt)
    final boxW = size.width * 0.55;
    final boxH = size.height * 0.16;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, 8 + boxH / 2),
        width: boxW,
        height: boxH,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height - 8 - boxH / 2),
        width: boxW,
        height: boxH,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
