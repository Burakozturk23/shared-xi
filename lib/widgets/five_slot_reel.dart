import 'package:flutter/material.dart';

import '../theme/ortak_saha_theme.dart';
import 'bot_arena.dart';
import 'grid_criterion_label.dart';

/// Random Five rounds: the five clubs of the current five. A new five spins in
/// like a slot machine: each reel rolls through other clubs and lands on its
/// club, top to bottom. Dots after a club show whose answer covers it.
class FiveSlotReel extends StatefulWidget {
  const FiveSlotReel({
    super.key,
    required this.round,
    required this.clubs,
    this.decoys = const [],
    this.marks = const {},
  });

  /// The five's number; a new number spins the reels.
  final int round;
  final List<Map<String, dynamic>> clubs;

  /// Other clubs the reels roll through before they land.
  final List<Map<String, dynamic>> decoys;

  /// Club id -> the colours of the answers that cover it.
  final Map<String, List<Color>> marks;

  static const rowHeight = 58.0;
  static const spin = Duration(milliseconds: 1500);

  @override
  State<FiveSlotReel> createState() => _FiveSlotReelState();
}

class _FiveSlotReelState extends State<FiveSlotReel>
    with SingleTickerProviderStateMixin {
  late final AnimationController reels = AnimationController(
    vsync: this,
    duration: FiveSlotReel.spin,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!reels.isAnimating && reels.value == 0) _spin();
  }

  @override
  void didUpdateWidget(FiveSlotReel old) {
    super.didUpdateWidget(old);
    if (old.round != widget.round) _spin();
  }

  void _spin() {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      reels.value = 1;
    } else {
      reels.forward(from: 0);
    }
  }

  @override
  void dispose() {
    reels.dispose();
    super.dispose();
  }

  /// What reel [i] rolls through: other clubs, then its own.
  List<Map<String, dynamic>> strip(int i) {
    final target = widget.clubs[i];
    final pool = [
      for (final d in widget.decoys)
        if (!widget.clubs.any((k) => k['id'] == d['id'])) d,
    ];
    final n = 7 + i * 2;
    return [
      for (var k = 0; k < n && pool.isNotEmpty; k++)
        pool[(widget.round * 11 + i * 5 + k * 3) % pool.length],
      target,
    ];
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: reels,
    builder: (context, _) => Column(
      children: [
        for (var i = 0; i < widget.clubs.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _reel(context, i),
          ),
      ],
    ),
  );

  Widget _reel(BuildContext context, int i) {
    final p = PitchColors.of(context);
    // Reels start together and land one after another.
    final end = (.55 + i * .1125).clamp(0.0, 1.0);
    final t = Curves.easeOutCubic.transform(
      (reels.value / end).clamp(0.0, 1.0),
    );
    final items = strip(i);
    final landed = t >= 1;
    final pos = t * (items.length - 1);
    final index = pos.floor().clamp(0, items.length - 1);
    final frac = pos - index;
    const h = FiveSlotReel.rowHeight;
    final id = '${widget.clubs[i]['id']}';
    final dots = landed ? widget.marks[id] ?? const <Color>[] : const <Color>[];
    return Container(
      key: ValueKey('five-reel-$i'),
      height: h,
      decoration: BoxDecoration(
        color: landed ? p.surface : p.raised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dots.isNotEmpty
              ? dots.first.withValues(alpha: .7)
              : landed
              ? p.border
              : Arena.lime.withValues(alpha: .35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: -frac * h,
            height: h,
            child: _club(context, items[index], dots, spinning: !landed),
          ),
          if (!landed && index + 1 < items.length)
            Positioned(
              left: 0,
              right: 0,
              top: (1 - frac) * h,
              height: h,
              child: _club(context, items[index + 1], const [], spinning: true),
            ),
        ],
      ),
    );
  }

  Widget _club(
    BuildContext context,
    Map<String, dynamic> k,
    List<Color> dots, {
    required bool spinning,
  }) {
    final p = PitchColors.of(context);
    final label = GridCriterionLabel.text(k);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Opacity(
            opacity: spinning ? .6 : 1,
            child: CriterionMark(
              ArenaCriterion({...k, 'label': label}),
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: spinning ? p.muted : p.text,
              ),
            ),
          ),
          for (final c in dots)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.check_circle_rounded, size: 18, color: c),
            ),
        ],
      ),
    );
  }
}
