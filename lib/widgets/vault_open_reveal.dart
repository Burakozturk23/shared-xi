import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_feedback.dart';
import '../app/game_audio.dart';
import '../data/country_flags.dart';
import '../theme/ortak_saha_theme.dart';

/// One flag the vault opens with: the player's country and position label.
typedef VaultFlag = ({String country, String position});

/// Kadro Kasası opening: a steel door's dial spins, the bolts slide back, the
/// door swings open and the first three flags drop out one by one. Then the
/// rule and "Kasayı çöz". The server has already chosen the club and the flags;
/// this only shows them. A tap skips; reduced motion shows the open vault.
class VaultOpenReveal extends StatefulWidget {
  const VaultOpenReveal({
    super.key,
    required this.flags,
    this.guesses = 5,
    this.difficulty,
    this.daily = false,
    this.onDone,
  });

  final List<VaultFlag> flags;
  final int guesses;
  final String? difficulty;
  final bool daily;
  final VoidCallback? onDone;

  static const duration = Duration(milliseconds: 2900);

  static Future<void> show(
    BuildContext context, {
    required List<VaultFlag> flags,
    int guesses = 5,
    String? difficulty,
    bool daily = false,
  }) => showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: .8),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, _) => VaultOpenReveal(
      flags: flags,
      guesses: guesses,
      difficulty: difficulty,
      daily: daily,
      onDone: () => Navigator.of(ctx).pop(),
    ),
    transitionBuilder: (ctx, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );

  @override
  State<VaultOpenReveal> createState() => _VaultOpenRevealState();
}

class _VaultOpenRevealState extends State<VaultOpenReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: VaultOpenReveal.duration,
  )..addListener(_cues);
  bool _started = false;
  final Set<String> _played = {};

  // Timeline (share of the whole run).
  static const _dialEnd = .30; // dial spins
  static const _boltEnd = .38; // bolts slide back: unlock
  static const _doorEnd = .58; // door swings open
  static double _flagAt(int i) => .60 + i * .10; // each flag drops
  static const _flagLength = .14;

  double _span(double a, double b, [Curve curve = Curves.linear]) =>
      curve.transform(((_run.value - a) / (b - a)).clamp(0.0, 1.0));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _played.addAll(['dial', 'unlock', for (var i = 0; i < 3; i++) 'flag$i']);
      _run.value = 1;
    } else {
      _run.forward();
    }
  }

  /// Sounds and pulses at their moments, once each (also when skipped past).
  void _cues() {
    void once(String key, double at, VoidCallback cue) {
      if (_run.value >= at && _played.add(key)) cue();
    }

    once('dial', 0, () => AppFeedback.sfx(Sfx.coachRoulette));
    once('unlock', _dialEnd, () {
      AppFeedback.sfx(Sfx.slotLock);
      HapticFeedback.mediumImpact();
    });
    for (var i = 0; i < math.min(3, widget.flags.length); i++) {
      once('flag$i', _flagAt(i) + _flagLength * .7, () {
        AppFeedback.sfx(Sfx.cardFlip);
        HapticFeedback.selectionClick();
      });
    }
  }

  void _skip() {
    if (_run.isAnimating) {
      _played.addAll(['dial', 'unlock', for (var i = 0; i < 3; i++) 'flag$i']);
      _run.value = 1;
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  String get _level => switch (widget.difficulty) {
    'easy' => 'Kolay kasa',
    'medium' => 'Orta kasa',
    'hard' => 'Zor kasa',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final palette = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          onTap: _skip,
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Container(
              width: math.min(MediaQuery.sizeOf(context).width - 32, 360),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: palette.accent.withValues(alpha: .55), width: 1.5),
                boxShadow: [
                  BoxShadow(color: palette.accent.withValues(alpha: .22), blurRadius: 32, spreadRadius: 1),
                ],
              ),
              child: AnimatedBuilder(
                animation: _run,
                builder: (context, _) {
                  final done = _run.value >= 1;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.daily ? 'GÜNÜN KASASI' : 'KADRO KASASI',
                        style: text.labelLarge?.copyWith(
                          letterSpacing: 3,
                          fontWeight: FontWeight.w900,
                          color: palette.accent,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(height: 200, child: _vault(palette, text)),
                      const SizedBox(height: 14),
                      _flags(palette, text),
                      const SizedBox(height: 14),
                      AnimatedOpacity(
                        opacity: done ? 1 : 0,
                        duration: const Duration(milliseconds: 260),
                        child: Column(
                          children: [
                            if (_level.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: palette.tint,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(_level, style: text.labelMedium?.copyWith(color: palette.accent)),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              'Bu 11 oyuncu farklı dönemlerde aynı kulüpte oynadı. '
                              'Kulübü bul: ${widget.guesses} tahmin hakkın var, ipucu yıldız düşürür.',
                              key: const Key('vault-open-rule'),
                              textAlign: TextAlign.center,
                              style: text.bodyMedium?.copyWith(color: palette.muted),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: done ? widget.onDone : null,
                                icon: const Icon(Icons.lock_open_rounded),
                                label: const Text('Kasayı çöz'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: PitchColors.lime,
                                  foregroundColor: PitchColors.onAction,
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!done)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Dokun: hemen aç', style: text.labelSmall?.copyWith(color: palette.muted)),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The vault: a dark chamber behind a round steel door. The dial turns, the
  /// bolts slide back and the door swings open on its left hinge.
  Widget _vault(PitchColors palette, TextTheme text) {
    final dial = _span(0, _dialEnd, Curves.easeInOutCubic);
    final bolts = _span(_dialEnd, _boltEnd, Curves.easeOut);
    final door = _span(_boltEnd, _doorEnd, Curves.easeInOutCubic);
    final glow = _span(_boltEnd, _doorEnd);
    const steel = Color(0xFF8C9AA0);
    return Semantics(
      label: door >= 1 ? 'Kasa açıldı' : 'Kasa açılıyor',
      liveRegion: true,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The chamber, lit as the door opens.
          Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                Color.lerp(palette.background, PitchColors.lime.withValues(alpha: .45), glow)!,
                palette.background,
              ]),
              border: Border.all(color: palette.border, width: 6),
            ),
            child: Center(
              child: Opacity(
                opacity: glow,
                child: Icon(Icons.groups_rounded, size: 54, color: PitchColors.lime.withValues(alpha: .9)),
              ),
            ),
          ),
          // The door, hinged on its left edge.
          Transform(
            alignment: Alignment.centerLeft,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .0015)
              ..rotateY(-1.35 * door),
            child: Opacity(
              opacity: 1 - .35 * door,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFB7C3C7), steel, Color(0xFF4E5B60)],
                  ),
                  border: Border.all(color: const Color(0xFF2E373A), width: 5),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 6))],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Four bolts, sliding back into the door.
                    for (var k = 0; k < 4; k++)
                      Transform.rotate(
                        angle: k * math.pi / 2,
                        child: Transform.translate(
                          offset: Offset(0, -80 + 18 * bolts),
                          child: Container(
                            width: 16,
                            height: 26,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B464A),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),
                    // The dial: two and a half turns, then a click.
                    Transform.rotate(
                      angle: dial * math.pi * 5,
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2E373A),
                          border: Border.all(color: const Color(0xFFD7E0E3), width: 3),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            for (var k = 0; k < 12; k++)
                              Transform.rotate(
                                angle: k * math.pi / 6,
                                child: Transform.translate(
                                  offset: const Offset(0, -34),
                                  child: Container(width: 3, height: k % 3 == 0 ? 10 : 6, color: const Color(0xFFD7E0E3)),
                                ),
                              ),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: bolts >= 1 ? PitchColors.lime : const Color(0xFFD7E0E3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The first three flags drop out of the vault, one by one, with a bounce.
  Widget _flags(PitchColors palette, TextTheme text) {
    final shown = widget.flags.take(3).toList();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < shown.length; i++)
          Builder(builder: (context) {
            final drop = _span(_flagAt(i), _flagAt(i) + _flagLength, Curves.easeOutBack);
            final f = shown[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Opacity(
                opacity: drop.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, -46 * (1 - drop)),
                  child: Transform.rotate(
                    angle: (1 - drop) * (i - 1) * .35,
                    child: Container(
                      width: 92,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                      decoration: BoxDecoration(
                        color: palette.raised,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: PitchColors.lime.withValues(alpha: .6)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            label: f.country,
                            child: ExcludeSemantics(
                              child: Text(
                                flagFor(f.country),
                                style: const TextStyle(fontSize: 28, fontFamily: 'Noto Color Emoji'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            f.country,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(f.position, style: text.labelSmall?.copyWith(color: palette.muted)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
