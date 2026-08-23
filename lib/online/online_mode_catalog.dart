import 'package:flutter/material.dart';

import '../models/grid_sub_type.dart';

/// Online’da seçilebilir oyun modları.
enum OnlinePlayMode {
  sharedXi,
  clubCountry,
  gridClassic,
  gridRandom,
  gridReverse,
  randomFive,
  cinko,
  loto,
  clubManager,
}

extension OnlinePlayModeX on OnlinePlayMode {
  String get title {
    switch (this) {
      case OnlinePlayMode.sharedXi:
        return 'Kulüp × Kulüp';
      case OnlinePlayMode.clubCountry:
        return 'Kulüp × Ülke';
      case OnlinePlayMode.gridClassic:
        return 'Grid · Klasik';
      case OnlinePlayMode.gridRandom:
        return 'Grid · Rastgele';
      case OnlinePlayMode.gridReverse:
        return 'Grid · Ters';
      case OnlinePlayMode.randomFive:
        return 'Rastgele Beş';
      case OnlinePlayMode.cinko:
        return 'Çinko';
      case OnlinePlayMode.loto:
        return 'Football Loto';
      case OnlinePlayMode.clubManager:
        return 'Club Manager';
    }
  }

  String get subtitle {
    switch (this) {
      case OnlinePlayMode.sharedXi:
        return 'İki takımın ortak oyuncularını bul';
      case OnlinePlayMode.clubCountry:
        return 'Kulüp + milliyet kesişimindeki oyuncuları bul';
      case OnlinePlayMode.gridClassic:
        return '3×3 kriter · üçlü';
      case OnlinePlayMode.gridRandom:
        return 'Kulüp çifti · ortak oyuncu';
      case OnlinePlayMode.gridReverse:
        return 'Oyuncular hazır · ortak nokta';
      case OnlinePlayMode.randomFive:
        return '5 kulüp · 90 sn puan yarışı';
      case OnlinePlayMode.cinko:
        return '5×5 · satır/sütun çinko';
      case OnlinePlayMode.loto:
        return '4×4 kriter · 16 oyuncu · 3 dk maç';
      case OnlinePlayMode.clubManager:
        return 'Bütçe · 11 kur · kafa kafaya simülasyon';
    }
  }

  IconData get icon {
    switch (this) {
      case OnlinePlayMode.sharedXi:
        return Icons.shield_outlined;
      case OnlinePlayMode.clubCountry:
        return Icons.public;
      case OnlinePlayMode.gridClassic:
        return Icons.grid_3x3;
      case OnlinePlayMode.gridRandom:
        return Icons.shuffle;
      case OnlinePlayMode.gridReverse:
        return Icons.swap_vert;
      case OnlinePlayMode.randomFive:
        return Icons.filter_5;
      case OnlinePlayMode.cinko:
        return Icons.grid_on;
      case OnlinePlayMode.loto:
        return Icons.grid_view;
      case OnlinePlayMode.clubManager:
        return Icons.emoji_events_rounded;
    }
  }

  Color get color {
    switch (this) {
      case OnlinePlayMode.sharedXi:
        return const Color(0xFFFFB300);
      case OnlinePlayMode.clubCountry:
        return const Color(0xFF5C6BC0);
      case OnlinePlayMode.gridClassic:
        return const Color(0xFF66BB6A);
      case OnlinePlayMode.gridRandom:
        return const Color(0xFFAB47BC);
      case OnlinePlayMode.gridReverse:
        return const Color(0xFF26A69A);
      case OnlinePlayMode.randomFive:
        return const Color(0xFF42A5F5);
      case OnlinePlayMode.cinko:
        return const Color(0xFFEF5350);
      case OnlinePlayMode.loto:
        return const Color(0xFF26A69A);
      case OnlinePlayMode.clubManager:
        return const Color(0xFF00E676);
    }
  }

  /// Matchmaking / oda RTDB alanı için kısa kod.
  String get wireName {
    switch (this) {
      case OnlinePlayMode.sharedXi:
        return 'club_club';
      case OnlinePlayMode.clubCountry:
        return 'club_country';
      case OnlinePlayMode.gridClassic:
        return 'grid_classic';
      case OnlinePlayMode.gridRandom:
        return 'grid_random';
      case OnlinePlayMode.gridReverse:
        return 'grid_reverse';
      case OnlinePlayMode.randomFive:
        return 'random_five';
      case OnlinePlayMode.cinko:
        return 'cinko';
      case OnlinePlayMode.loto:
        return 'loto';
      case OnlinePlayMode.clubManager:
        return 'club_manager';
    }
  }

  static OnlinePlayMode? fromWire(String? value) {
    switch (value) {
      case 'club_club':
      case 'shared_xi':
      case 'sharedXi':
        return OnlinePlayMode.sharedXi;
      case 'club_country':
      case 'clubCountry':
        return OnlinePlayMode.clubCountry;
      case 'grid_classic':
        return OnlinePlayMode.gridClassic;
      case 'grid_random':
        return OnlinePlayMode.gridRandom;
      case 'grid_reverse':
        return OnlinePlayMode.gridReverse;
      case 'random_five':
        return OnlinePlayMode.randomFive;
      case 'cinko':
        return OnlinePlayMode.cinko;
      case 'loto':
        return OnlinePlayMode.loto;
      case 'club_manager':
      case 'clubManager':
        return OnlinePlayMode.clubManager;
      default:
        return null;
    }
  }

  GridSubType? get gridSubType {
    switch (this) {
      case OnlinePlayMode.gridClassic:
        return GridSubType.classic;
      case OnlinePlayMode.gridRandom:
        return GridSubType.random;
      case OnlinePlayMode.gridReverse:
        return GridSubType.reverse;
      default:
        return null;
    }
  }
}
