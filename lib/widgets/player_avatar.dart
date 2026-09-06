import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/player.dart';
import '../theme/app_theme.dart';

/// Linkball portrait renderer.
/// Uses a local illustrated asset when avatarKey exists. Otherwise renders a
/// deterministic generic portrait; it is intentionally NOT a likeness.
class PlayerAvatar extends StatelessWidget {
  final Player player;
  final double size;

  const PlayerAvatar({super.key, required this.player, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final key = player.avatarKey;
    if (key != null && key.isNotEmpty) {
      return _frame(
        Image.asset(
          'assets/avatars/$key.webp',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _frame(Widget child) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.20),
        border: Border.all(color: AppTheme.strongBorderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _fallback() {
    final accent = _accentFor(player.id);
    return _frame(
      CustomPaint(
        size: Size.square(size),
        painter: _GenericPortraitPainter(seed: player.id, accent: accent),
      ),
    );
  }

  static Color _accentFor(int id) {
    const palette = <Color>[
      Color(0xFF2F7BFF),
      Color(0xFF20D47B),
      Color(0xFF8B72FF),
      Color(0xFFFF8A4C),
      Color(0xFF22B8CF),
      Color(0xFFE35D9A),
    ];
    return palette[id.abs() % palette.length];
  }
}

class _GenericPortraitPainter extends CustomPainter {
  final int seed;
  final Color accent;

  const _GenericPortraitPainter({required this.seed, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final random = math.Random(seed);

    final background = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent.withValues(alpha: 0.52), AppTheme.mutedSurfaceColor],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    // Abstract pitch/card detail.
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = math.max(1, w * 0.012)
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(w * 0.82, h * 0.18), w * 0.30, linePaint);

    // Shoulders / shirt.
    final shirtPaint = Paint()
      ..color = Color.lerp(accent, const Color(0xFF081012), 0.45)!;
    final shoulders = Path()
      ..moveTo(w * 0.10, h)
      ..quadraticBezierTo(w * 0.18, h * 0.72, w * 0.40, h * 0.69)
      ..lineTo(w * 0.60, h * 0.69)
      ..quadraticBezierTo(w * 0.82, h * 0.72, w * 0.90, h)
      ..close();
    canvas.drawPath(shoulders, shirtPaint);

    // Neutral stylized face. This is a generic placeholder, not a likeness.
    final facePaint = Paint()..color = const Color(0xFFD0D6DA);
    final faceRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.43),
        width: w * 0.43,
        height: h * 0.49,
      ),
      Radius.circular(w * 0.19),
    );
    canvas.drawRRect(faceRect, facePaint);

    // Hair silhouette gets small deterministic variation for visual variety.
    final hairPaint = Paint()..color = const Color(0xFF20272C);
    final hairHeight = h * (0.12 + random.nextDouble() * 0.06);
    final hair = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.285, h * 0.175, w * 0.43, hairHeight),
      Radius.circular(w * 0.14),
    );
    canvas.drawRRect(hair, hairPaint);

    final featurePaint = Paint()
      ..color = const Color(0xFF485158)
      ..strokeWidth = math.max(1.2, w * 0.024)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.39, h * 0.43),
      Offset(w * 0.43, h * 0.43),
      featurePaint,
    );
    canvas.drawLine(
      Offset(w * 0.57, h * 0.43),
      Offset(w * 0.61, h * 0.43),
      featurePaint,
    );
    canvas.drawLine(
      Offset(w * 0.46, h * 0.58),
      Offset(w * 0.54, h * 0.58),
      featurePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GenericPortraitPainter oldDelegate) {
    return oldDelegate.seed != seed || oldDelegate.accent != accent;
  }
}
