import 'dart:math';

import '../models/player.dart';
import '../repositories/repository.dart';

class Harf11Letter {
  Harf11Letter._();

  static const letters = [
    'A', 'B', 'C', 'Ç', 'D', 'E', 'F', 'G', 'H', 'I', 'İ', 'J', 'K', 'L', 'M',
    'N', 'O', 'Ö', 'P', 'R', 'S', 'Ş', 'T', 'U', 'Ü', 'V', 'Y', 'Z',
  ];

  static final _rng = Random();

  static String normalizeLetter(String s) {
    if (s.isEmpty) return '';
    final ch = s[0];
    if (ch == 'i' || ch == 'İ') return 'İ';
    if (ch == 'ı' || ch == 'I') return 'I';
    return ch.toUpperCase();
  }

  /// Ad veya soyadın herhangi bir parçası bu letter ile başlıyor mu?
  static bool nameMatchesLetter(String name, String letter) {
    final L = normalizeLetter(letter);
    final parts = name.trim().split(RegExp(r'\s+'));
    for (final p in parts) {
      if (p.isEmpty) continue;
      if (normalizeLetter(p) == L) return true;
    }
    return false;
  }

  /// En az [minPlayers] oyuncu bulunan harfler.
  static List<String> playableLetters({int minPlayers = 11}) {
    final counts = <String, int>{};
    for (final p in Repository.instance.players) {
      final parts = p.name.trim().split(RegExp(r'\s+'));
      final seen = <String>{};
      for (final part in parts) {
        if (part.isEmpty) continue;
        final L = normalizeLetter(part);
        if (!letters.contains(L)) continue;
        if (seen.add(L)) {
          counts[L] = (counts[L] ?? 0) + 1;
        }
      }
    }
    final ok = counts.entries
        .where((e) => e.value >= minPlayers)
        .map((e) => e.key)
        .toList();
    if (ok.isEmpty) return List<String>.from(letters);
    return ok;
  }

  static String pickPlayableLetter() {
    final ok = playableLetters();
    return ok[_rng.nextInt(ok.length)];
  }

  static List<Player> playersForLetter(String letter) {
    final L = normalizeLetter(letter);
    return Repository.instance.players
        .where((p) => nameMatchesLetter(p.name, L))
        .toList();
  }

  static String norm(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Slot etiketi (GK/DEF/MID/FWD) ile oyuncu pozisyonu uyumlu mu?
  static bool fitsPosition(Player player, String slotLabel) {
    final group = positionGroup(player);
    switch (slotLabel.toUpperCase()) {
      case 'GK':
        return group == 'GK';
      case 'DEF':
        return group == 'DEF';
      case 'MID':
        return group == 'MID';
      case 'FWD':
        return group == 'FWD';
      default:
        return true;
    }
  }

  /// Player.position / detailedPosition → GK | DEF | MID | FWD
  static String positionGroup(Player player) {
    final raw =
        '${player.position} ${player.detailedPosition}'.toLowerCase();

    if (raw.contains('goal') ||
        raw.contains('keeper') ||
        raw.contains('kaleci') ||
        raw.contains('gk') ||
        RegExp(r'\bgk\b').hasMatch(raw)) {
      return 'GK';
    }
    if (raw.contains('defen') ||
        raw.contains('back') ||
        raw.contains('stoper') ||
        raw.contains('bek') ||
        raw.contains('cb') ||
        raw.contains('lb') ||
        raw.contains('rb') ||
        raw.contains('wb') ||
        raw.contains('sweeper')) {
      return 'DEF';
    }
    if (raw.contains('mid') ||
        raw.contains('orta') ||
        raw.contains('cm') ||
        raw.contains('cdm') ||
        raw.contains('cam') ||
        raw.contains('dm') ||
        raw.contains('am') ||
        raw.contains('wingback')) {
      return 'MID';
    }
    if (raw.contains('forw') ||
        raw.contains('attack') ||
        raw.contains('strik') ||
        raw.contains('wing') ||
        raw.contains('santra') ||
        raw.contains('forvet') ||
        raw.contains('cf') ||
        raw.contains('st') ||
        raw.contains('lw') ||
        raw.contains('rw') ||
        raw.contains('ss')) {
      return 'FWD';
    }

    final p = player.position.trim().toUpperCase();
    if (p == 'G' || p == 'GK') return 'GK';
    if (p == 'D' || p == 'DF' || p == 'DEF') return 'DEF';
    if (p == 'M' || p == 'MF' || p == 'MID') return 'MID';
    if (p == 'F' || p == 'FW' || p == 'FWD' || p == 'A') return 'FWD';

    return 'MID';
  }
}
