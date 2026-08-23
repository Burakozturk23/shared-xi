/// Maç öncesi taktik (0.0 – 1.0 kaydırıcılar).
class ManagerTactics {
  /// 0 = alçak blok, 1 = yüksek press
  final double press;
  /// 0 = yavaş kontrol, 1 = tempolu
  final double tempo;
  /// 0 = dar, 1 = geniş kanatlar
  final double width;

  const ManagerTactics({
    this.press = 0.5,
    this.tempo = 0.5,
    this.width = 0.5,
  });

  ManagerTactics copyWith({double? press, double? tempo, double? width}) {
    return ManagerTactics(
      press: press ?? this.press,
      tempo: tempo ?? this.tempo,
      width: width ?? this.width,
    );
  }

  /// Güce çarpan ~0.94 – 1.06 (uçlarda risk/ödül).
  double powerMultiplier() {
    // Dengeli (0.5) ≈ 1.0; uçlar hafif bonus ama rakip tarzına göre match'te işlenir
    final balance =
        1.0 - ((press - 0.5).abs() + (tempo - 0.5).abs() + (width - 0.5).abs()) * 0.04;
    final aggression = 1.0 + (press * 0.03) + (tempo * 0.025);
    return ((balance + aggression) / 2).clamp(0.92, 1.08);
  }

  String get pressLabel {
    if (press < 0.34) return 'Alçak blok';
    if (press < 0.67) return 'Dengeli';
    return 'Yüksek press';
  }

  String get tempoLabel {
    if (tempo < 0.34) return 'Kontrol';
    if (tempo < 0.67) return 'Dengeli';
    return 'Yüksek tempo';
  }

  String get widthLabel {
    if (width < 0.34) return 'Dar';
    if (width < 0.67) return 'Dengeli';
    return 'Geniş';
  }
}

enum OpponentStyle {
  lowBlock,
  balanced,
  highPress,
  possession,
  counter,
}

extension OpponentStyleX on OpponentStyle {
  String get label {
    switch (this) {
      case OpponentStyle.lowBlock:
        return 'Alçak blok';
      case OpponentStyle.balanced:
        return 'Dengeli';
      case OpponentStyle.highPress:
        return 'Yüksek press';
      case OpponentStyle.possession:
        return 'Top hakimiyeti';
      case OpponentStyle.counter:
        return 'Kontra';
    }
  }

  String get blurb {
    switch (this) {
      case OpponentStyle.lowBlock:
        return 'Geride bekler, az yer, set oyunu sever';
      case OpponentStyle.balanced:
        return 'Standart dizilim, belirgin zayıf yok';
      case OpponentStyle.highPress:
        return 'Erken baskı, tempolu, riskli açık';
      case OpponentStyle.possession:
        return 'Pas ile kurar, sabırlı hücum';
      case OpponentStyle.counter:
        return 'Çabuk çıkış, az top, net fırsat';
    }
  }
}

class ManagerOpponent {
  final String name;
  final String leagueHint;
  final OpponentStyle style;
  final double basePower; // 45-95

  const ManagerOpponent({
    required this.name,
    required this.leagueHint,
    required this.style,
    required this.basePower,
  });
}
