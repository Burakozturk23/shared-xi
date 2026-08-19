/// Online / bot Grid ailesi alt modları.
enum GridSubType {
  classic,
  random,
  reverse;

  String get id => name;

  String get titleTr {
    switch (this) {
      case GridSubType.classic:
        return 'Klasik Grid';
      case GridSubType.random:
        return 'Rastgele Grid';
      case GridSubType.reverse:
        return 'Ters Grid';
    }
  }

  String get subtitleTr {
    switch (this) {
      case GridSubType.classic:
        return '3×3 kriter · oyuncu doldur · üçlü';
      case GridSubType.random:
        return 'Kulüp çifti · ortak oyuncu · puan';
      case GridSubType.reverse:
        return 'Oyuncular hazır · ortak noktayı bul';
    }
  }

  static GridSubType fromId(String? raw) {
    return GridSubType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => GridSubType.classic,
    );
  }
}
