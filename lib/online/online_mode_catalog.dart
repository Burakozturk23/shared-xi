import 'package:flutter/material.dart';

import '../models/grid_sub_type.dart';

/// Online’da seçilebilir oyun modları.
enum OnlinePlayMode {
  sharedXi,
  gridClassic,
  gridRandom,
  gridReverse,
  randomFive,
  cinko,
}

extension OnlinePlayModeX on OnlinePlayMode {
  String get title {
    switch (this) {
      case OnlinePlayMode.sharedXi:
        return 'Shared XI';
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
    }
  }

  String get subtitle {
    switch (this) {
      case OnlinePlayMode.sharedXi:
        return 'İki takımın ortak oyuncularını bul';
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
    }
  }

  IconData get icon {
    switch (this) {
      case OnlinePlayMode.sharedXi:
        return Icons.people_alt_outlined;
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
    }
  }

  Color get color {
    switch (this) {
      case OnlinePlayMode.sharedXi:
        return const Color(0xFFFFB300);
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
    }
  }
}
