import 'package:flutter/material.dart';

import '../controllers/harf11_controller.dart';
import '../models/harf11_models.dart';
import '../models/player.dart';
import '../repositories/repository.dart';

class Harf11Page extends StatefulWidget {
  const Harf11Page({super.key});

  @override
  State<Harf11Page> createState() => _Harf11PageState();
}

class _Harf11PageState extends State<Harf11Page> {
  late final Harf11Controller _c;
  final _search = TextEditingController();
  final _focus = FocusNode();
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    _c = Harf11Controller()..addListener(_refresh);
    _boot();
  }

  Future<void> _boot() async {
    try {
      await Repository.instance.initialize();
    } catch (_) {}
    if (mounted) setState(() => _booting = false);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_refresh);
    _c.disposeController();
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _c.state;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1A12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white70,
        title: const Text('Harf 11', style: TextStyle(color: Colors.white)),
        actions: [
          if (s.phase != Harf11Phase.spinning)
            TextButton(
              onPressed: () {
                _search.clear();
                _c.resetToSpin();
              },
              child: const Text(
                'Yeni Oyun',
                style: TextStyle(color: Color(0xFF00E676)),
              ),
            ),
        ],
      ),
      body: _booting
          ? const Center(child: CircularProgressIndicator())
          : s.phase == Harf11Phase.spinning
              ? _spinView(s)
              : _playView(s),
    );
  }

  Widget _spinView(Harf11State s) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Harf seçiliyor...',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Container(
            width: 110,
            height: 110,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF12261C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00E676), width: 2),
            ),
            child: Text(
              s.spinDisplay,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 52,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            onPressed: _c.spinLetter,
            child: const Text(
              'Harf Seç',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playView(Harf11State s) {
    final letter = s.letter ?? '?';
    final form = s.formation;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            children: [
              Text(
                'Adı veya soyadı "$letter" ile başlayan futbolcular yaz.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in Harf11Formations.all)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f.label),
                          selected: s.formationId == f.id,
                          selectedColor: const Color(0xFF00E676),
                          labelStyle: TextStyle(
                            color: s.formationId == f.id
                                ? Colors.black
                                : Colors.white70,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          backgroundColor: const Color(0xFF12261C),
                          onSelected: (_) => _c.setFormation(f.id),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 0.72,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF1B5E20), Color(0xFF0D3B14)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: const Color(0xFF2E7D32), width: 2),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;
                      return Stack(
                        children: [
                          CustomPaint(
                            size: Size(w, h),
                            painter: _PitchPainter(),
                          ),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${form.label} · HARF $letter',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          for (final slot in form.slots)
                            Positioned(
                              left: slot.x * w - 22,
                              top: slot.y * h - 22,
                              child: _PosDot(
                                pick: s.picks[slot.index],
                                selected: s.selectedSlot == slot.index,
                                onTap: () {
                                  _c.selectSlot(slot.index);
                                  _focus.requestFocus();
                                },
                                onLongPress: () => _c.clearSlot(slot.index),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.selectedSlotLabel == null
                    ? '${s.filledCount}/11  ·  Pozisyon seç → ara / yaz'
                    : '${s.filledCount}/11  ·  Seçili: ${s.selectedSlotLabel} (sadece bu mevki)',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (s.feedback != null) ...[
                const SizedBox(height: 6),
                Text(
                  s.feedback!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: s.feedbackOk
                        ? const Color(0xFF00E676)
                        : Colors.orangeAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Arama + autocomplete
        Container(
          color: const Color(0xFF0D1F14),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (s.suggestions.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    itemCount: s.suggestions.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Colors.white12),
                    itemBuilder: (_, i) {
                      final p = s.suggestions[i];
                      return ListTile(
                        dense: true,
                        title: Text(
                          p.name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                        subtitle: Text(
                          p.countries.join(', '),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                        onTap: () {
                          _c.placePlayer(p);
                          _search.clear();
                          _c.updateSuggestions('');
                        },
                      );
                    },
                  ),
                ),
              TextField(
                controller: _search,
                focusNode: _focus,
                style: const TextStyle(color: Colors.white),
                enabled: s.phase == Harf11Phase.playing,
                decoration: InputDecoration(
                  hintText: s.selectedSlot == null
                      ? 'Önce pozisyon seç…'
                      : 'En az 2 harf yaz (${s.selectedSlotLabel ?? ''})',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF12261C),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Color(0xFF00E676)),
                    onPressed: () {
                      _c.placePlayerByName(_search.text);
                      _search.clear();
                      _c.updateSuggestions('');
                    },
                  ),
                ),
                onChanged: _c.updateSuggestions,
                onSubmitted: (v) {
                  _c.placePlayerByName(v);
                  _search.clear();
                  _c.updateSuggestions('');
                },
              ),
              const SizedBox(height: 10),
              if (s.phase == Harf11Phase.finished)
                _greenBtn('Yeni Oyun', () {
                  _search.clear();
                  _c.resetToSpin();
                })
              else
                _greenBtn(
                  s.filledCount >= 11 ? 'Bitir' : 'Bitir (${s.filledCount}/11)',
                  _c.finish,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _greenBtn(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00E676),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _PosDot extends StatelessWidget {
  final Harf11Pick? pick;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PosDot({
    required this.pick,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final filled = pick != null;
    return GestureDetector(
      onTap: onTap,
      onLongPress: filled ? onLongPress : null,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? const Color(0xFF1B5E20) : Colors.black38,
          border: Border.all(
            color: selected
                ? const Color(0xFF00E676)
                : (filled ? const Color(0xFF69F0AE) : Colors.white38),
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: filled
            ? Text(
                pick!.name.split(' ').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              )
            : const Icon(Icons.add, color: Colors.white54, size: 18),
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final midY = size.height / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), paint);
    canvas.drawCircle(Offset(size.width / 2, midY), size.width * 0.12, paint);

    final boxW = size.width * 0.55;
    final boxH = size.height * 0.14;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, boxH / 2),
        width: boxW,
        height: boxH,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height - boxH / 2),
        width: boxW,
        height: boxH,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
