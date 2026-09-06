import 'package:flutter/material.dart';

import '../models/club.dart';
import '../theme/app_theme.dart';

/// Linkball club mark renderer.
/// It never falls back to a third-party logo URL. If a local badge asset does
/// not exist, an original Linkball shield + monogram is generated.
class ClubBadge extends StatelessWidget {
  final Club club;
  final double size;

  const ClubBadge({super.key, required this.club, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final key = club.badgeKey;
    if (key != null && key.isNotEmpty) {
      return Image.asset(
        'assets/badges/$key.webp',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _generatedBadge(),
      );
    }
    return _generatedBadge();
  }

  Widget _generatedBadge() {
    final base = _clubColor();
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _ClubShieldPainter(baseColor: base),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: size * 0.05),
            child: Text(
              _initials(club.name),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.27,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _clubColor() {
    final raw = club.color;
    if (raw != null) {
      final value = raw <= 0xFFFFFF ? (0xFF000000 | raw) : raw;
      return Color(value);
    }
    const palette = <Color>[
      Color(0xFF2F7BFF),
      Color(0xFF20A86B),
      Color(0xFF7A65D1),
      Color(0xFFD06A3F),
      Color(0xFF268EA3),
      Color(0xFFB14B78),
    ];
    return palette[club.id.abs() % palette.length];
  }

  static String _initials(String name) {
    final parts = name
        .replaceAll(
          RegExp(r'\b(FC|CF|SC|FK|SK|AC|AS|SS|RC|CD)\b', caseSensitive: false),
          '',
        )
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts[0];
      return s.length >= 3 ? s.substring(0, 3).toUpperCase() : s.toUpperCase();
    }
    if (parts.length >= 3) {
      return (parts[0][0] + parts[1][0] + parts[2][0]).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

class _ClubShieldPainter extends CustomPainter {
  final Color baseColor;

  const _ClubShieldPainter({required this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shield = Path()
      ..moveTo(w * 0.50, h * 0.03)
      ..lineTo(w * 0.88, h * 0.16)
      ..lineTo(w * 0.82, h * 0.70)
      ..quadraticBezierTo(w * 0.74, h * 0.90, w * 0.50, h * 0.98)
      ..quadraticBezierTo(w * 0.26, h * 0.90, w * 0.18, h * 0.70)
      ..lineTo(w * 0.12, h * 0.16)
      ..close();

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [baseColor, Color.lerp(baseColor, Colors.black, 0.42)!],
      ).createShader(Offset.zero & size);
    canvas.drawPath(shield, fill);

    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.10);
    final stripePath = Path()
      ..moveTo(w * 0.24, h * 0.22)
      ..lineTo(w * 0.38, h * 0.16)
      ..lineTo(w * 0.64, h * 0.84)
      ..lineTo(w * 0.51, h * 0.91)
      ..close();
    canvas.save();
    canvas.clipPath(shield);
    canvas.drawPath(stripePath, stripe);
    canvas.restore();

    final border = Paint()
      ..color = AppTheme.strongBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.035).clamp(1.0, 2.4).toDouble();
    canvas.drawPath(shield, border);
  }

  @override
  bool shouldRepaint(covariant _ClubShieldPainter oldDelegate) {
    return oldDelegate.baseColor != baseColor;
  }
}
