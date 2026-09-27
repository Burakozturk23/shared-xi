import 'package:flutter/material.dart';
import '../models/store_collection.dart';

/// Original club-neutral jersey artwork; no logos, sponsors or external images.
class ProfileKitView extends StatelessWidget {
  const ProfileKitView({super.key, required this.kit, this.size = 88});
  final ProfileKit kit;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${kit.title} profil forması',
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _KitPainter(kit)),
    ),
  );
}

class _KitPainter extends CustomPainter {
  const _KitPainter(this.kit);
  final ProfileKit kit;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final shape = Path()
      ..moveTo(30, 14)
      ..lineTo(10, 27)
      ..lineTo(3, 48)
      ..lineTo(23, 57)
      ..lineTo(26, 47)
      ..lineTo(26, 92)
      ..lineTo(74, 92)
      ..lineTo(74, 47)
      ..lineTo(77, 57)
      ..lineTo(97, 48)
      ..lineTo(90, 27)
      ..lineTo(70, 14)
      ..quadraticBezierTo(50, 26, 30, 14)
      ..close();
    canvas.drawShadow(shape, Colors.black.withValues(alpha: .2), 4, false);
    canvas.drawPath(shape, Paint()..color = Color(kit.primary));
    canvas.save();
    canvas.clipPath(shape);
    final accent = Paint()..color = Color(kit.secondary);
    switch (kit.pattern) {
      case 'half':
        canvas.drawRect(const Rect.fromLTWH(50, 0, 50, 100), accent);
      case 'stripes':
        for (var x = 27.0; x < 80; x += 18) {
          canvas.drawRect(Rect.fromLTWH(x, 0, 9, 100), accent);
        }
      case 'hoops':
        for (var y = 35.0; y < 90; y += 22) {
          canvas.drawRect(Rect.fromLTWH(0, y, 100, 7), accent);
        }
      case 'sleeves':
        canvas.drawRect(const Rect.fromLTWH(0, 0, 26, 100), accent);
        canvas.drawRect(const Rect.fromLTWH(74, 0, 26, 100), accent);
      case 'plain':
        canvas.drawRect(const Rect.fromLTWH(0, 49, 24, 5), accent);
        canvas.drawRect(const Rect.fromLTWH(76, 49, 24, 5), accent);
      default:
        canvas.drawRect(const Rect.fromLTWH(44, 22, 12, 70), accent);
    }
    canvas.restore();
    canvas.drawPath(
      Path()
        ..moveTo(32, 16)
        ..quadraticBezierTo(50, 37, 68, 16),
      Paint()
        ..color = Color(kit.secondary)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawCircle(
      const Offset(65, 37),
      4,
      Paint()..color = Color(kit.secondary),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_KitPainter old) => old.kit != kit;
}
