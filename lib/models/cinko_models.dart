enum CinkoCellType { club, country, league }

enum CinkoCellStatus {
  open, // henüz boyanmamış
  selected, // bu turda kullanıcı seçti (onay öncesi)
  correct, // kalıcı boyalı
  wrongFlash, // geçici kırmızı
}

/// correct iken kim boyadı: 0 = (solo / bilinmiyor), 1 = kullanıcı, 2 = bot
class CinkoCell {
  final String id;
  final CinkoCellType type;
  final String label;
  final String? logoUrl;
  final int? clubId;
  final CinkoCellStatus status;
  final int owner;

  const CinkoCell({
    required this.id,
    required this.type,
    required this.label,
    this.logoUrl,
    this.clubId,
    this.status = CinkoCellStatus.open,
    this.owner = 0,
  });

  CinkoCell copyWith({
    CinkoCellStatus? status,
    int? owner,
  }) {
    return CinkoCell(
      id: id,
      type: type,
      label: label,
      logoUrl: logoUrl,
      clubId: clubId,
      status: status ?? this.status,
      owner: owner ?? this.owner,
    );
  }
}

enum CinkoPhase {
  enterPlayer,
  selecting,
  revealing,
  gameOver,
}
