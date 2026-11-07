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

  /// What beats this style, as matchupMultiplier scores it.
  String get advice {
    switch (this) {
      case OpponentStyle.lowBlock:
        return 'Geride kapanan rakibe geniş ve tempolu oyna; aşırı baskı boşa enerji harcatır.';
      case OpponentStyle.balanced:
        return 'Belirgin zayıfı yok; dengeli bir plan ve kadro gücü belirleyici.';
      case OpponentStyle.highPress:
        return 'Önde basan rakibe alçak blok ve kontrollü tempo, arkada boşluk bulur.';
      case OpponentStyle.possession:
        return 'Topu seven rakibi yüksek baskı ve tempo bozar; geride beklersen top hep onda kalır.';
      case OpponentStyle.counter:
        return 'Kontra oynayan rakibe dar ve kontrollü oyna; yüksek tempo arkada alan bırakır.';
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

/// The one in-match decision, taken at half-time.
enum ManagerHalftimePlan { keep, push, protect }

extension ManagerHalftimePlanX on ManagerHalftimePlan {
  String get label => switch (this) {
    ManagerHalftimePlan.keep => 'Planı koru',
    ManagerHalftimePlan.push => 'Öne çık',
    ManagerHalftimePlan.protect => 'Skoru koru',
  };

  String get detail => switch (this) {
    ManagerHalftimePlan.keep => 'İkinci yarı aynı dengeyle sürer.',
    ManagerHalftimePlan.push => 'Daha çok pozisyon bulursun ama arkada boşluk verirsin.',
    ManagerHalftimePlan.protect => 'İki takım da az pozisyon bulur; skoru tutmak kolaylaşır.',
  };

  /// Second-half xG multipliers (yours, theirs).
  (double, double) get xg => switch (this) {
    ManagerHalftimePlan.keep => (1.0, 1.0),
    ManagerHalftimePlan.push => (1.35, 1.25),
    ManagerHalftimePlan.protect => (0.7, 0.65),
  };
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
