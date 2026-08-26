import 'package:flutter/material.dart';

import '../models/player.dart';

/// Foto URL kullanmaz. avatarKey asset varsa gosterir; yoksa bas harf siluet.
class PlayerAvatar extends StatelessWidget {
  final Player player;
  final double size;

  const PlayerAvatar({super.key, required this.player, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final key = player.avatarKey;
    if (key != null && key.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: Image.asset(
          'assets/avatars/$key.webp',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final letter = player.name.trim().isNotEmpty
        ? player.name.trim()[0].toUpperCase()
        : '?';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(size * 0.2),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}
