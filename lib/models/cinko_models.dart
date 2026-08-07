enum CinkoCellType { club, country, league }

enum CinkoCellStatus {
  open,       // henüz boyanmamış
  selected,   // bu turda kullanıcı seçti (onay öncesi)
  correct,    // kalıcı yeşil
  wrongFlash, // geçici kırmızı
}

class CinkoCell {
  final String id;
  final CinkoCellType type;
  final String label;
  final String? logoUrl;
  final int? clubId; // type == club ise
  final CinkoCellStatus status;

  const CinkoCell({
    required this.id,
    required this.type,
    required this.label,
    this.logoUrl,
    this.clubId,
    this.status = CinkoCellStatus.open,
  });

  CinkoCell copyWith({CinkoCellStatus? status}) {
    return CinkoCell(
      id: id,
      type: type,
      label: label,
      logoUrl: logoUrl,
      clubId: clubId,
      status: status ?? this.status,
    );
  }
}

enum CinkoPhase {
  enterPlayer, // isim gir
  selecting,   // kutu seç
  revealing,   // doğru/yanlış göster
  gameOver,
}