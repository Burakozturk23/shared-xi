import 'package:flutter/material.dart';

import '../data/club_visual_identity.dart';
import '../models/club.dart';

/// Local, original club marks. Never downloads third-party crests.
class ClubBadge extends StatelessWidget {
  final Club club;
  final double size;

  const ClubBadge({super.key, required this.club, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final key = club.badgeKey;
    return Semantics(
      image: true,
      label: '${club.name} kulüp simgesi',
      child: ExcludeSemantics(
        child: key != null && key.isNotEmpty
            ? Image.asset(
                'assets/badges/$key.webp',
                width: size,
                height: size,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _generatedBadge(),
              )
            : _generatedBadge(),
      ),
    );
  }

  Widget _generatedBadge() {
    final identity = ClubVisualIdentity.forClub(club);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _ClubMarkPainter(identity),
        child: Center(
          child: Container(
            width: size * .76,
            height: size * .34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF14242B),
              borderRadius: BorderRadius.circular(size * .055),
              border: Border.all(color: Colors.white24, width: size * .012),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: size * .035),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  identity.label,
                  maxLines: 1,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: const Color(0xFFFFFDF5),
                    fontWeight: FontWeight.w900,
                    fontSize: size * .23,
                    letterSpacing: size * .013,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClubMarkPainter extends CustomPainter {
  const _ClubMarkPainter(this.identity);
  final ClubVisualIdentity identity;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final outline = switch (identity.shape) {
      ClubMarkShape.round => Path()..addOval(const Rect.fromLTWH(7, 7, 86, 86)),
      ClubMarkShape.shield => Path()
        ..moveTo(13, 12)..lineTo(87, 12)..lineTo(87, 54)
        ..quadraticBezierTo(86, 79, 50, 95)
        ..quadraticBezierTo(14, 79, 13, 54)..close(),
      ClubMarkShape.pennant => Path()
        ..moveTo(50, 5)..lineTo(88, 20)..lineTo(83, 71)
        ..lineTo(50, 96)..lineTo(17, 71)..lineTo(12, 20)..close(),
    };
    canvas.drawPath(outline, Paint()..color = identity.primary);
    canvas.save();
    canvas.clipPath(outline);
    // Broad original bands remain recognizable even at a 24px rendering.
    canvas.drawRect(const Rect.fromLTWH(58, 0, 21, 100), Paint()..color = identity.secondary);
    canvas.drawRect(const Rect.fromLTWH(22, 0, 7, 100), Paint()..color = identity.secondary);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 100, 100),
      Paint()..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x22FFFFFF), Color(0x00000000), Color(0x33000000)],
      ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),
    );
    canvas.restore();
    canvas.drawPath(outline, Paint()
      ..color = const Color(0xFF8FABA8)
      ..style = PaintingStyle.stroke..strokeWidth = 2.2);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ClubMarkPainter oldDelegate) =>
      oldDelegate.identity.primary != identity.primary ||
      oldDelegate.identity.secondary != identity.secondary ||
      oldDelegate.identity.shape != identity.shape;
}
