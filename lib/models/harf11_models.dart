/// Formasyon slotu.
class FormationSlot {
  final int index;
  final String positionLabel; // GK, DEF, MID, FWD
  final double x; // 0–1 saha oranı (sol-sağ)
  final double y; // 0–1 (üst hücum → alt kaleci)

  const FormationSlot({
    required this.index,
    required this.positionLabel,
    required this.x,
    required this.y,
  });
}

class FormationDef {
  final String id;
  final String label;
  final List<FormationSlot> slots;

  const FormationDef({
    required this.id,
    required this.label,
    required this.slots,
  });
}

/// Yerleştirilen oyuncu.
class Harf11Pick {
  final int playerId;
  final String name;

  const Harf11Pick({required this.playerId, required this.name});
}

class Harf11Formations {
  Harf11Formations._();

  /// y: 0 tepe (hücum), 1 dip (kaleci) — dikey saha.
  static final List<FormationDef> all = [
    FormationDef(
      id: '433',
      label: '4-3-3',
      slots: const [
        // FWD
        FormationSlot(index: 0, positionLabel: 'FWD', x: 0.20, y: 0.12),
        FormationSlot(index: 1, positionLabel: 'FWD', x: 0.50, y: 0.08),
        FormationSlot(index: 2, positionLabel: 'FWD', x: 0.80, y: 0.12),
        // MID
        FormationSlot(index: 3, positionLabel: 'MID', x: 0.25, y: 0.38),
        FormationSlot(index: 4, positionLabel: 'MID', x: 0.50, y: 0.42),
        FormationSlot(index: 5, positionLabel: 'MID', x: 0.75, y: 0.38),
        // DEF
        FormationSlot(index: 6, positionLabel: 'DEF', x: 0.15, y: 0.68),
        FormationSlot(index: 7, positionLabel: 'DEF', x: 0.38, y: 0.72),
        FormationSlot(index: 8, positionLabel: 'DEF', x: 0.62, y: 0.72),
        FormationSlot(index: 9, positionLabel: 'DEF', x: 0.85, y: 0.68),
        // GK
        FormationSlot(index: 10, positionLabel: 'GK', x: 0.50, y: 0.92),
      ],
    ),
    FormationDef(
      id: '442',
      label: '4-4-2',
      slots: const [
        FormationSlot(index: 0, positionLabel: 'FWD', x: 0.35, y: 0.10),
        FormationSlot(index: 1, positionLabel: 'FWD', x: 0.65, y: 0.10),
        FormationSlot(index: 2, positionLabel: 'MID', x: 0.15, y: 0.36),
        FormationSlot(index: 3, positionLabel: 'MID', x: 0.38, y: 0.40),
        FormationSlot(index: 4, positionLabel: 'MID', x: 0.62, y: 0.40),
        FormationSlot(index: 5, positionLabel: 'MID', x: 0.85, y: 0.36),
        FormationSlot(index: 6, positionLabel: 'DEF', x: 0.15, y: 0.68),
        FormationSlot(index: 7, positionLabel: 'DEF', x: 0.38, y: 0.72),
        FormationSlot(index: 8, positionLabel: 'DEF', x: 0.62, y: 0.72),
        FormationSlot(index: 9, positionLabel: 'DEF', x: 0.85, y: 0.68),
        FormationSlot(index: 10, positionLabel: 'GK', x: 0.50, y: 0.92),
      ],
    ),
    FormationDef(
      id: '352',
      label: '3-5-2',
      slots: const [
        FormationSlot(index: 0, positionLabel: 'FWD', x: 0.35, y: 0.10),
        FormationSlot(index: 1, positionLabel: 'FWD', x: 0.65, y: 0.10),
        FormationSlot(index: 2, positionLabel: 'MID', x: 0.12, y: 0.34),
        FormationSlot(index: 3, positionLabel: 'MID', x: 0.32, y: 0.40),
        FormationSlot(index: 4, positionLabel: 'MID', x: 0.50, y: 0.36),
        FormationSlot(index: 5, positionLabel: 'MID', x: 0.68, y: 0.40),
        FormationSlot(index: 6, positionLabel: 'MID', x: 0.88, y: 0.34),
        FormationSlot(index: 7, positionLabel: 'DEF', x: 0.25, y: 0.70),
        FormationSlot(index: 8, positionLabel: 'DEF', x: 0.50, y: 0.74),
        FormationSlot(index: 9, positionLabel: 'DEF', x: 0.75, y: 0.70),
        FormationSlot(index: 10, positionLabel: 'GK', x: 0.50, y: 0.92),
      ],
    ),
    FormationDef(
      id: '4231',
      label: '4-2-3-1',
      slots: const [
        FormationSlot(index: 0, positionLabel: 'FWD', x: 0.50, y: 0.08),
        FormationSlot(index: 1, positionLabel: 'MID', x: 0.20, y: 0.28),
        FormationSlot(index: 2, positionLabel: 'MID', x: 0.50, y: 0.30),
        FormationSlot(index: 3, positionLabel: 'MID', x: 0.80, y: 0.28),
        FormationSlot(index: 4, positionLabel: 'MID', x: 0.35, y: 0.48),
        FormationSlot(index: 5, positionLabel: 'MID', x: 0.65, y: 0.48),
        FormationSlot(index: 6, positionLabel: 'DEF', x: 0.15, y: 0.70),
        FormationSlot(index: 7, positionLabel: 'DEF', x: 0.38, y: 0.74),
        FormationSlot(index: 8, positionLabel: 'DEF', x: 0.62, y: 0.74),
        FormationSlot(index: 9, positionLabel: 'DEF', x: 0.85, y: 0.70),
        FormationSlot(index: 10, positionLabel: 'GK', x: 0.50, y: 0.92),
      ],
    ),
    FormationDef(
      id: '451',
      label: '4-5-1',
      slots: const [
        FormationSlot(index: 0, positionLabel: 'FWD', x: 0.50, y: 0.10),
        FormationSlot(index: 1, positionLabel: 'MID', x: 0.12, y: 0.34),
        FormationSlot(index: 2, positionLabel: 'MID', x: 0.32, y: 0.38),
        FormationSlot(index: 3, positionLabel: 'MID', x: 0.50, y: 0.36),
        FormationSlot(index: 4, positionLabel: 'MID', x: 0.68, y: 0.38),
        FormationSlot(index: 5, positionLabel: 'MID', x: 0.88, y: 0.34),
        FormationSlot(index: 6, positionLabel: 'DEF', x: 0.15, y: 0.70),
        FormationSlot(index: 7, positionLabel: 'DEF', x: 0.38, y: 0.74),
        FormationSlot(index: 8, positionLabel: 'DEF', x: 0.62, y: 0.74),
        FormationSlot(index: 9, positionLabel: 'DEF', x: 0.85, y: 0.70),
        FormationSlot(index: 10, positionLabel: 'GK', x: 0.50, y: 0.92),
      ],
    ),
  ];

  static FormationDef byId(String id) =>
      all.firstWhere((f) => f.id == id, orElse: () => all.first);
}
