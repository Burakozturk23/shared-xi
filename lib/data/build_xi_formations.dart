class FormationSlot {
  final String code;
  final String label;
  final List<String> acceptedDetailedPositions;
  final String fallbackBroadPosition;
  final double x;
  final double y;

  const FormationSlot({
    required this.code,
    required this.label,
    required this.acceptedDetailedPositions,
    required this.fallbackBroadPosition,
    required this.x,
    required this.y,
  });
}

class Formation {
  final String id;
  final String name;
  final List<FormationSlot> slots;
  final List<List<int>> adjacency;

  const Formation({
    required this.id,
    required this.name,
    required this.slots,
    required this.adjacency,
  });
}

const _cbPos = ['Defender - Centre-Back', 'Defender - Sweeper', 'Defender'];
const _lbPos = ['Defender - Left-Back', 'Defender'];
const _rbPos = ['Defender - Right-Back', 'Defender'];
const _cdmPos = ['Midfield - Defensive Midfield', 'Midfield'];
const _cmPos = ['Midfield - Central Midfield', 'Midfield'];
const _camPos = ['Midfield - Attacking Midfield', 'Midfield'];
const _lmPos = ['Midfield - Left Midfield', 'Attack - Left Winger', 'Midfield'];
const _rmPos = ['Midfield - Right Midfield', 'Attack - Right Winger', 'Midfield'];
const _lwPos = ['Attack - Left Winger', 'Midfield - Left Midfield', 'Attack'];
const _rwPos = ['Attack - Right Winger', 'Midfield - Right Midfield', 'Attack'];
const _stPos = ['Attack - Centre-Forward', 'Attack - Second Striker', 'Attack'];

// GK üstte → takım aşağı bakıyor → sol = ekranın sağı (x yüksek)

final Formation formation433 = Formation(
  id: '4-3-3',
  name: '4-3-3',
  slots: const [
    FormationSlot(code: 'GK', label: 'Kaleci', acceptedDetailedPositions: ['Goalkeeper'], fallbackBroadPosition: 'Goalkeeper', x: 0.5, y: 0.06),
    FormationSlot(code: 'LB', label: 'Sol Bek', acceptedDetailedPositions: _lbPos, fallbackBroadPosition: 'Defender', x: 0.85, y: 0.25),
    FormationSlot(code: 'CB', label: 'Stoper', acceptedDetailedPositions: _cbPos, fallbackBroadPosition: 'Defender', x: 0.62, y: 0.20),
    FormationSlot(code: 'CB', label: 'Stoper', acceptedDetailedPositions: _cbPos, fallbackBroadPosition: 'Defender', x: 0.38, y: 0.20),
    FormationSlot(code: 'RB', label: 'Sağ Bek', acceptedDetailedPositions: _rbPos, fallbackBroadPosition: 'Defender', x: 0.15, y: 0.25),
    FormationSlot(code: 'CDM', label: 'Ön Libero', acceptedDetailedPositions: _cdmPos, fallbackBroadPosition: 'Midfield', x: 0.5, y: 0.42),
    FormationSlot(code: 'CM', label: 'Orta Saha', acceptedDetailedPositions: _cmPos, fallbackBroadPosition: 'Midfield', x: 0.7, y: 0.55),
    FormationSlot(code: 'CM', label: 'Orta Saha', acceptedDetailedPositions: _cmPos, fallbackBroadPosition: 'Midfield', x: 0.3, y: 0.55),
    FormationSlot(code: 'LW', label: 'Sol Kanat', acceptedDetailedPositions: _lwPos, fallbackBroadPosition: 'Attack', x: 0.85, y: 0.78),
    FormationSlot(code: 'ST', label: 'Forvet', acceptedDetailedPositions: _stPos, fallbackBroadPosition: 'Attack', x: 0.5, y: 0.85),
    FormationSlot(code: 'RW', label: 'Sağ Kanat', acceptedDetailedPositions: _rwPos, fallbackBroadPosition: 'Attack', x: 0.15, y: 0.78),
  ],
  adjacency: const [
    [2, 3], [2], [0, 1, 3, 5], [0, 2, 4, 5], [3],
    [2, 3, 6, 7], [5, 7, 8], [5, 6, 10], [6, 9], [8, 10], [7, 9],
  ],
);

final Formation formation442 = Formation(
  id: '4-4-2',
  name: '4-4-2',
  slots: const [
    FormationSlot(code: 'GK', label: 'Kaleci', acceptedDetailedPositions: ['Goalkeeper'], fallbackBroadPosition: 'Goalkeeper', x: 0.5, y: 0.06),
    FormationSlot(code: 'LB', label: 'Sol Bek', acceptedDetailedPositions: _lbPos, fallbackBroadPosition: 'Defender', x: 0.85, y: 0.25),
    FormationSlot(code: 'CB', label: 'Stoper', acceptedDetailedPositions: _cbPos, fallbackBroadPosition: 'Defender', x: 0.62, y: 0.20),
    FormationSlot(code: 'CB', label: 'Stoper', acceptedDetailedPositions: _cbPos, fallbackBroadPosition: 'Defender', x: 0.38, y: 0.20),
    FormationSlot(code: 'RB', label: 'Sağ Bek', acceptedDetailedPositions: _rbPos, fallbackBroadPosition: 'Defender', x: 0.15, y: 0.25),
    FormationSlot(code: 'LM', label: 'Sol Orta Saha', acceptedDetailedPositions: _lmPos, fallbackBroadPosition: 'Midfield', x: 0.88, y: 0.55),
    FormationSlot(code: 'CM', label: 'Orta Saha', acceptedDetailedPositions: _cmPos, fallbackBroadPosition: 'Midfield', x: 0.62, y: 0.52),
    FormationSlot(code: 'CM', label: 'Orta Saha', acceptedDetailedPositions: _cmPos, fallbackBroadPosition: 'Midfield', x: 0.38, y: 0.52),
    FormationSlot(code: 'RM', label: 'Sağ Orta Saha', acceptedDetailedPositions: _rmPos, fallbackBroadPosition: 'Midfield', x: 0.12, y: 0.55),
    FormationSlot(code: 'ST', label: 'Forvet', acceptedDetailedPositions: _stPos, fallbackBroadPosition: 'Attack', x: 0.62, y: 0.85),
    FormationSlot(code: 'ST', label: 'Forvet', acceptedDetailedPositions: _stPos, fallbackBroadPosition: 'Attack', x: 0.38, y: 0.85),
  ],
  adjacency: const [
    [2, 3], [2, 5], [0, 1, 3, 6], [0, 2, 4, 7], [3, 8],
    [1, 6, 9], [2, 5, 7, 9], [3, 6, 8, 10], [4, 7, 10], [5, 6, 10], [7, 8, 9],
  ],
);

final Formation formation352 = Formation(
  id: '3-5-2',
  name: '3-5-2',
  slots: const [
    FormationSlot(code: 'GK', label: 'Kaleci', acceptedDetailedPositions: ['Goalkeeper'], fallbackBroadPosition: 'Goalkeeper', x: 0.5, y: 0.06),
    FormationSlot(code: 'CB', label: 'Stoper', acceptedDetailedPositions: _cbPos, fallbackBroadPosition: 'Defender', x: 0.75, y: 0.18),
    FormationSlot(code: 'CB', label: 'Stoper', acceptedDetailedPositions: _cbPos, fallbackBroadPosition: 'Defender', x: 0.5, y: 0.15),
    FormationSlot(code: 'CB', label: 'Stoper', acceptedDetailedPositions: _cbPos, fallbackBroadPosition: 'Defender', x: 0.25, y: 0.18),
    FormationSlot(code: 'LWB', label: 'Sol Kanat Bek', acceptedDetailedPositions: _lbPos, fallbackBroadPosition: 'Defender', x: 0.92, y: 0.45),
    FormationSlot(code: 'RWB', label: 'Sağ Kanat Bek', acceptedDetailedPositions: _rbPos, fallbackBroadPosition: 'Defender', x: 0.08, y: 0.45),
    FormationSlot(code: 'CM', label: 'Orta Saha', acceptedDetailedPositions: _cmPos, fallbackBroadPosition: 'Midfield', x: 0.65, y: 0.50),
    FormationSlot(code: 'CM', label: 'Orta Saha', acceptedDetailedPositions: _cmPos, fallbackBroadPosition: 'Midfield', x: 0.35, y: 0.50),
    FormationSlot(code: 'CAM', label: 'On Numara', acceptedDetailedPositions: _camPos, fallbackBroadPosition: 'Midfield', x: 0.5, y: 0.68),
    FormationSlot(code: 'ST', label: 'Forvet', acceptedDetailedPositions: _stPos, fallbackBroadPosition: 'Attack', x: 0.65, y: 0.88),
    FormationSlot(code: 'ST', label: 'Forvet', acceptedDetailedPositions: _stPos, fallbackBroadPosition: 'Attack', x: 0.35, y: 0.88),
  ],
  adjacency: const [
    [1, 2, 3], [0, 2, 4], [0, 1, 3], [0, 2, 5], [1, 6],
    [3, 7], [4, 7, 8], [5, 6, 8], [6, 7, 9, 10], [8, 10], [8, 9],
  ],
);

/// 4-2-3-1
final Formation formation4231 = Formation(
  id: '4-2-3-1',
  name: '4-2-3-1',
  slots: const [
    FormationSlot(code: 'GK', label: 'Kaleci', acceptedDetailedPositions: ['Goalkeeper'], fallbackBroadPosition: 'Goalkeeper', x: 0.5, y: 0.05),
    FormationSlot(code: 'LB', label: 'Sol Bek', acceptedDetailedPositions: _lbPos, fallbackBroadPosition: 'Defender', x: 0.88, y: 0.22),
    FormationSlot(code: 'CB', label: 'Stoper', acceptedDetailedPositions: _cbPos, fallbackBroadPosition: 'Defender', x: 0.65, y: 0.17),
    FormationSlot(code: 'CB', label: 'Stoper', acceptedDetailedPositions: _cbPos, fallbackBroadPosition: 'Defender', x: 0.35, y: 0.17),
    FormationSlot(code: 'RB', label: 'Sağ Bek', acceptedDetailedPositions: _rbPos, fallbackBroadPosition: 'Defender', x: 0.12, y: 0.22),
    FormationSlot(code: 'CDM', label: 'Ön Libero', acceptedDetailedPositions: _cdmPos, fallbackBroadPosition: 'Midfield', x: 0.65, y: 0.40),
    FormationSlot(code: 'CDM', label: 'Ön Libero', acceptedDetailedPositions: _cdmPos, fallbackBroadPosition: 'Midfield', x: 0.35, y: 0.40),
    FormationSlot(code: 'LW', label: 'Sol Kanat', acceptedDetailedPositions: _lwPos, fallbackBroadPosition: 'Attack', x: 0.88, y: 0.62),
    FormationSlot(code: 'CAM', label: 'On Numara', acceptedDetailedPositions: _camPos, fallbackBroadPosition: 'Midfield', x: 0.5, y: 0.60),
    FormationSlot(code: 'RW', label: 'Sağ Kanat', acceptedDetailedPositions: _rwPos, fallbackBroadPosition: 'Attack', x: 0.12, y: 0.62),
    FormationSlot(code: 'ST', label: 'Forvet', acceptedDetailedPositions: _stPos, fallbackBroadPosition: 'Attack', x: 0.5, y: 0.86),
  ],
  adjacency: const [
    [2, 3],
    [2, 5, 7],
    [0, 1, 3, 5],
    [0, 2, 4, 6],
    [3, 6, 9],
    [1, 2, 6, 7, 8],
    [3, 4, 5, 8, 9],
    [1, 5, 8, 10],
    [5, 6, 7, 9, 10],
    [4, 6, 8, 10],
    [7, 8, 9],
  ],
);

/// 3-4-2-1
final Formation formation3421 = Formation(
  id: '3-4-2-1',
  name: '3-4-2-1',
  slots: const [
    FormationSlot(code: 'GK', label: 'Kaleci', acceptedDetailedPositions: ['Goalkeeper'], fallbackBroadPosition: 'Goalkeeper', x: 0.5, y: 0.05),
    FormationSlot(code: 'CB', label: 'Stoper', acceptedDetailedPositions: _cbPos, fallbackBroadPosition: 'Defender', x: 0.78, y: 0.18),
    FormationSlot(code: 'CB', label: 'Stoper', acceptedDetailedPositions: _cbPos, fallbackBroadPosition: 'Defender', x: 0.5, y: 0.14),
    FormationSlot(code: 'CB', label: 'Stoper', acceptedDetailedPositions: _cbPos, fallbackBroadPosition: 'Defender', x: 0.22, y: 0.18),
    FormationSlot(code: 'LM', label: 'Sol Orta Saha', acceptedDetailedPositions: _lmPos, fallbackBroadPosition: 'Midfield', x: 0.90, y: 0.42),
    FormationSlot(code: 'CM', label: 'Orta Saha', acceptedDetailedPositions: _cmPos, fallbackBroadPosition: 'Midfield', x: 0.62, y: 0.40),
    FormationSlot(code: 'CM', label: 'Orta Saha', acceptedDetailedPositions: _cmPos, fallbackBroadPosition: 'Midfield', x: 0.38, y: 0.40),
    FormationSlot(code: 'RM', label: 'Sağ Orta Saha', acceptedDetailedPositions: _rmPos, fallbackBroadPosition: 'Midfield', x: 0.10, y: 0.42),
    FormationSlot(code: 'CAM', label: 'On Numara', acceptedDetailedPositions: _camPos, fallbackBroadPosition: 'Midfield', x: 0.65, y: 0.64),
    FormationSlot(code: 'CAM', label: 'On Numara', acceptedDetailedPositions: _camPos, fallbackBroadPosition: 'Midfield', x: 0.35, y: 0.64),
    FormationSlot(code: 'ST', label: 'Forvet', acceptedDetailedPositions: _stPos, fallbackBroadPosition: 'Attack', x: 0.5, y: 0.88),
  ],
  adjacency: const [
    [1, 2, 3],
    [0, 2, 4, 5],
    [0, 1, 3, 5, 6],
    [0, 2, 6, 7],
    [1, 5, 8],
    [1, 2, 4, 6, 8],
    [2, 3, 5, 7, 9],
    [3, 6, 9],
    [4, 5, 9, 10],
    [6, 7, 8, 10],
    [8, 9],
  ],
);

/// 4-1-4-1
final Formation formation4141 = Formation(
  id: '4-1-4-1',
  name: '4-1-4-1',
  slots: const [
    FormationSlot(code: 'GK', label: 'Kaleci', acceptedDetailedPositions: ['Goalkeeper'], fallbackBroadPosition: 'Goalkeeper', x: 0.5, y: 0.05),
    FormationSlot(code: 'LB', label: 'Sol Bek', acceptedDetailedPositions: _lbPos, fallbackBroadPosition: 'Defender', x: 0.88, y: 0.22),
    FormationSlot(code: 'CB', label: 'Stoper', acceptedDetailedPositions: _cbPos, fallbackBroadPosition: 'Defender', x: 0.65, y: 0.17),
    FormationSlot(code: 'CB', label: 'Stoper', acceptedDetailedPositions: _cbPos, fallbackBroadPosition: 'Defender', x: 0.35, y: 0.17),
    FormationSlot(code: 'RB', label: 'Sağ Bek', acceptedDetailedPositions: _rbPos, fallbackBroadPosition: 'Defender', x: 0.12, y: 0.22),
    FormationSlot(code: 'CDM', label: 'Ön Libero', acceptedDetailedPositions: _cdmPos, fallbackBroadPosition: 'Midfield', x: 0.5, y: 0.38),
    FormationSlot(code: 'LM', label: 'Sol Orta Saha', acceptedDetailedPositions: _lmPos, fallbackBroadPosition: 'Midfield', x: 0.90, y: 0.58),
    FormationSlot(code: 'CM', label: 'Orta Saha', acceptedDetailedPositions: _cmPos, fallbackBroadPosition: 'Midfield', x: 0.62, y: 0.55),
    FormationSlot(code: 'CM', label: 'Orta Saha', acceptedDetailedPositions: _cmPos, fallbackBroadPosition: 'Midfield', x: 0.38, y: 0.55),
    FormationSlot(code: 'RM', label: 'Sağ Orta Saha', acceptedDetailedPositions: _rmPos, fallbackBroadPosition: 'Midfield', x: 0.10, y: 0.58),
    FormationSlot(code: 'ST', label: 'Forvet', acceptedDetailedPositions: _stPos, fallbackBroadPosition: 'Attack', x: 0.5, y: 0.86),
  ],
  adjacency: const [
    [2, 3],
    [2, 5, 6],
    [0, 1, 3, 5],
    [0, 2, 4, 5],
    [3, 5, 9],
    [1, 2, 3, 4, 7, 8],
    [1, 7, 10],
    [5, 6, 8, 10],
    [5, 7, 9, 10],
    [4, 8, 10],
    [6, 7, 8, 9],
  ],
);

/// 3-4-3
final Formation formation343 = Formation(
  id: '3-4-3',
  name: '3-4-3',
  slots: const [
    FormationSlot(code: 'GK', label: 'Kaleci', acceptedDetailedPositions: ['Goalkeeper'], fallbackBroadPosition: 'Goalkeeper', x: 0.5, y: 0.05),
    FormationSlot(code: 'CB', label: 'Stoper', acceptedDetailedPositions: _cbPos, fallbackBroadPosition: 'Defender', x: 0.78, y: 0.18),
    FormationSlot(code: 'CB', label: 'Stoper', acceptedDetailedPositions: _cbPos, fallbackBroadPosition: 'Defender', x: 0.5, y: 0.14),
    FormationSlot(code: 'CB', label: 'Stoper', acceptedDetailedPositions: _cbPos, fallbackBroadPosition: 'Defender', x: 0.22, y: 0.18),
    FormationSlot(code: 'LM', label: 'Sol Orta Saha', acceptedDetailedPositions: _lmPos, fallbackBroadPosition: 'Midfield', x: 0.90, y: 0.45),
    FormationSlot(code: 'CM', label: 'Orta Saha', acceptedDetailedPositions: _cmPos, fallbackBroadPosition: 'Midfield', x: 0.62, y: 0.42),
    FormationSlot(code: 'CM', label: 'Orta Saha', acceptedDetailedPositions: _cmPos, fallbackBroadPosition: 'Midfield', x: 0.38, y: 0.42),
    FormationSlot(code: 'RM', label: 'Sağ Orta Saha', acceptedDetailedPositions: _rmPos, fallbackBroadPosition: 'Midfield', x: 0.10, y: 0.45),
    FormationSlot(code: 'LW', label: 'Sol Kanat', acceptedDetailedPositions: _lwPos, fallbackBroadPosition: 'Attack', x: 0.85, y: 0.75),
    FormationSlot(code: 'ST', label: 'Forvet', acceptedDetailedPositions: _stPos, fallbackBroadPosition: 'Attack', x: 0.5, y: 0.88),
    FormationSlot(code: 'RW', label: 'Sağ Kanat', acceptedDetailedPositions: _rwPos, fallbackBroadPosition: 'Attack', x: 0.15, y: 0.75),
  ],
  adjacency: const [
    [1, 2, 3],
    [0, 2, 4, 5],
    [0, 1, 3, 5, 6],
    [0, 2, 6, 7],
    [1, 5, 8],
    [1, 2, 4, 6, 8, 9],
    [2, 3, 5, 7, 9, 10],
    [3, 6, 10],
    [4, 5, 9],
    [5, 6, 8, 10],
    [6, 7, 9],
  ],
);

List<Formation> allFormations = [
  formation433,
  formation442,
  formation352,
  formation4231,
  formation3421,
  formation4141,
  formation343,
];