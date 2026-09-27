import 'package:flutter/material.dart';

/// Shared visual language for every player; independent of club or artwork.
abstract final class PlayerKitIdentity {
  static String initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    final first = words.first.characters.first;
    final last = words.length > 1 ? words.last.characters.first : '';
    return '$first$last'.toUpperCase();
  }

  static (Color, String, String) position(String value) {
    switch (value.trim().toLowerCase()) {
      case 'goalkeeper':
        return (const Color(0xFFFFC857), 'KL', 'Kaleci');
      case 'defender':
        return (const Color(0xFF53D8FB), 'SV', 'Savunma');
      case 'midfield':
        return (const Color(0xFF76E4A6), 'OS', 'Orta saha');
      case 'attack':
        return (const Color(0xFFC3A0FF), 'HC', 'Hücum');
      default:
        return (const Color(0xFFA7B6C8), 'F', 'Futbolcu');
    }
  }
}
