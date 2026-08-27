import 'package:flutter/material.dart';

import '../models/club.dart';

/// Logo URL kullanmaz. badgeKey asset varsa gosterir; yoksa monogram.
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
        errorBuilder: (_, __, ___) => _monogram(),
      );
    }
    return _monogram();
  }

  Widget _monogram() {
    final letters = _initials(club.name);
    final bg =
        club.color != null ? Color(club.color!) : const Color(0xFF30363D);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        letters,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.32,
        ),
      ),
    );
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
      return s.length >= 2 ? s.substring(0, 2).toUpperCase() : s.toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
