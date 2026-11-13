import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_feedback.dart';
import '../app/game_audio.dart';
import '../theme/ortak_saha_theme.dart';

/// Harf 11's letter, drawn like a slot machine: the Turkish alphabet rolls
/// through a three-row window, slows down, runs a quarter letter past and
/// settles on the letter the server chose. Ticks as letters pass, locks with a
/// clunk, then shows the rule. A tap skips the spin; reduced motion shows the
/// landed letter at once. The server has already chosen; the reel only shows it.
class LetterSlotReveal extends StatefulWidget {
  const LetterSlotReveal({
    super.key,
    required this.letter,
    this.difficulty,
    this.daily = false,
    this.onDone,
  });

  final String letter;

  /// easy / medium / hard, when known.
  final String? difficulty;
  final bool daily;
  final VoidCallback? onDone;

  static const alphabet = [
    'A', 'B', 'C', 'Ç', 'D', 'E', 'F', 'G', 'Ğ', 'H', 'I', 'İ', 'J', 'K', 'L',
    'M', 'N', 'O', 'Ö', 'P', 'R', 'S', 'Ş', 'T', 'U', 'Ü', 'V', 'Y', 'Z',
  ];
  static const spin = Duration(milliseconds: 2600);
  static const rowHeight = 80.0;

  /// Shows the reel over the game and completes when the player closes it.
  static Future<void> show(
    BuildContext context, {
    required String letter,
    String? difficulty,
    bool daily = false,
  }) => showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: .78),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, _) => LetterSlotReveal(
      letter: letter,
      difficulty: difficulty,
      daily: daily,
      onDone: () => Navigator.of(ctx).pop(),
    ),
    transitionBuilder: (ctx, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: .92, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    ),
  );

  @override
  State<LetterSlotReveal> createState() => _LetterSlotRevealState();
}

class _LetterSlotRevealState extends State<LetterSlotReveal>
    with TickerProviderStateMixin {
  late final AnimationController _reel = AnimationController(
    vsync: this,
    duration: LetterSlotReveal.spin,
  )..addListener(_tick)..addStatusListener(_landed);
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late Animation<double> _position;
  late final int _target;
  int _lastIndex = -1;
  DateTime _lastTick = DateTime.fromMillisecondsSinceEpoch(0);
  bool _started = false;

  static const _letters = LetterSlotReveal.alphabet;
  int get _n => _letters.length;

  @override
  void initState() {
    super.initState();
    final i = _letters.indexOf(widget.letter.toUpperCase());
    _target = i < 0 ? 0 : i;
    // Three full turns and a different start each time, ending on the target.
    final start = (_target + 7 + widget.letter.codeUnitAt(0) % 11) % _n;
    final end = (3 * _n + _target - start).toDouble() + start;
    _position = TweenSequence<double>([
      // Fast roll, slowing down, a quarter letter past the target...
      TweenSequenceItem(
        tween: Tween(begin: start.toDouble(), end: end + .28)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 86,
      ),
      // ...then back into the slot.
      TweenSequenceItem(
        tween: Tween(begin: end + .28, end: end)
            .chain(CurveTween(curve: Curves.easeInOutBack)),
        weight: 14,
      ),
    ]).animate(_reel);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _reel.value = 1;
      _pop.value = 1;
    } else {
      AppFeedback.sfx(Sfx.coachRoulette);
      _reel.forward();
    }
  }

  /// A click for each letter through the window, at most every 70 ms.
  void _tick() {
    final index = _position.value.round();
    if (index == _lastIndex) return;
    _lastIndex = index;
    final now = DateTime.now();
    if (_reel.isAnimating && now.difference(_lastTick).inMilliseconds >= 70) {
      _lastTick = now;
      HapticFeedback.selectionClick();
    }
  }

  void _landed(AnimationStatus status) {
    if (status != AnimationStatus.completed || _pop.isAnimating || _pop.value == 1) return;
    AppFeedback.sfx(Sfx.slotLock);
    HapticFeedback.mediumImpact();
    _pop.forward(from: 0);
  }

  void _skip() {
    if (_reel.isAnimating) {
      _reel.value = 1;
      _landed(AnimationStatus.completed);
    }
  }

  @override
  void dispose() {
    _reel.dispose();
    _pop.dispose();
    super.dispose();
  }

  String get _level => switch (widget.difficulty) {
    'easy' => 'Kolay harf',
    'medium' => 'Orta harf',
    'hard' => 'Zor harf',
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
                BoxShadow(color: palette.accent.withValues(alpha: .25), blurRadius: 32, spreadRadius: 1),
              ],
            ),
            child: AnimatedBuilder(
              animation: Listenable.merge([_reel, _pop]),
              builder: (context, _) {
                final landed = _pop.value > 0 || !_reel.isAnimating && _reel.value == 1;
                return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.daily ? 'GÜNÜN HARFİ' : 'HARF RULETİ',
                    style: text.labelLarge?.copyWith(
                      letterSpacing: 3,
                      fontWeight: FontWeight.w900,
                      color: palette.accent,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _window(palette, text),
                  const SizedBox(height: 16),
                  AnimatedOpacity(
                    opacity: landed ? 1 : 0,
                    duration: const Duration(milliseconds: 260),
                    child: Column(
                      children: [
                        Text(
                          '${widget.letter} harfi',
                          key: const Key('letter-slot-result'),
                          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        if (_level.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: palette.tint,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(_level, style: text.labelMedium?.copyWith(color: palette.accent)),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          'Adı, soyadı ya da bilinen lakabı ${widget.letter} ile başlayan 11 oyuncuyla kadronu kur.',
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(color: palette.muted),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: landed ? widget.onDone : null,
                            icon: const Icon(Icons.sports_soccer_rounded),
                            label: const Text('Kadroyu kur'),
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
                  if (!landed)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Dokun: hemen göster', style: text.labelSmall?.copyWith(color: palette.muted)),
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

  /// Three rows of the reel: the middle row is the pick, the outer ones fade.
  Widget _window(PitchColors palette, TextTheme text) {
    const h = LetterSlotReveal.rowHeight;
    final pos = _position.value;
    final base = pos.floor();
    final frac = pos - base;
    // The landed letter swells once and glows.
    final pop = Curves.easeOutBack.transform(_pop.value);
    final swell = _pop.value == 0 ? 1.0 : 1 + .22 * math.sin(math.pi * math.min(1, pop));
    // Motion blur while the drum is fast, clearing as it slows (the roll eases out cubically).
    final t = _reel.value;
    final blur = _reel.isAnimating && t < .86 ? 6 * math.pow(1 - t / .86, 2).toDouble() : 0.0;
    return Semantics(
      label: _pop.value > 0 ? '${widget.letter} harfi seçildi' : 'Harf ruleti dönüyor',
      liveRegion: true,
      child: Container(
        height: h * 3,
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Stack(
            children: [
              // The pay line.
              Positioned(
                left: 0,
                right: 0,
                top: h,
                height: h,
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.limeTint.withValues(alpha: .55 + .45 * _pop.value),
                    border: Border.symmetric(
                      horizontal: BorderSide(color: PitchColors.lime.withValues(alpha: .7), width: 2),
                    ),
                  ),
                ),
              ),
              for (var k = -2; k <= 2; k++)
                if (blur > .2)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: h + (k - frac) * h,
                    height: h,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 0, sigmaY: blur),
                      child: Center(
                        child: Text(
                          _letters[((base + k) % _n + _n) % _n],
                          style: text.displayMedium?.copyWith(fontWeight: FontWeight.w900, height: 1),
                        ),
                      ),
                    ),
                  )
                else
                Positioned(
                  left: 0,
                  right: 0,
                  top: h + (k - frac) * h,
                  height: h,
                  child: Center(
                    child: Transform.scale(
                      scale: k == 0 && frac < .5 || k == 1 && frac >= .5 ? swell : 1,
                      child: Text(
                        _letters[((base + k) % _n + _n) % _n],
                        style: text.displayMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1,
                          color: (k == 0 && frac < .5 || k == 1 && frac >= .5)
                              ? Color.lerp(palette.text, PitchColors.lime, _pop.value)
                              : palette.text,
                          shadows: _pop.value > 0 && (k == 0 && frac < .5 || k == 1 && frac >= .5)
                              ? [Shadow(color: PitchColors.lime.withValues(alpha: .8 * _pop.value), blurRadius: 24)]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              // Fade the outer rows like a drum turning away.
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        palette.background,
                        palette.background.withValues(alpha: 0),
                        palette.background.withValues(alpha: 0),
                        palette.background,
                      ],
                      stops: const [0, .3, .7, 1],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
