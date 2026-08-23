/// Slot id format: ROLE_index  e.g. LB, CB1, CB2, RB, CM1, ST, GK
class ManagerFormation {
  final String id;
  final String label;
  final String category;
  final String blurb;
  final List<List<String>> rows;

  const ManagerFormation({
    required this.id,
    required this.label,
    required this.category,
    required this.blurb,
    required this.rows,
  });

  List<String> get slots => [for (final r in rows) ...r];

  /// Slot → geniş grup (havuz filtresi)
  static String groupOf(String slot) {
    final r = roleOf(slot);
    if (r == 'GK') return 'GK';
    if (const {'LB', 'RB', 'CB', 'LWB', 'RWB'}.contains(r)) return 'DEF';
    if (const {'CDM', 'CM', 'CAM', 'LM', 'RM', 'LW', 'RW'}.contains(r)) {
      // LW/RW can be ATT in some systems — treat wing as MID if labeled LM/RM/LW/RW in mid row
      if (r == 'LW' || r == 'RW') return 'ATT';
      return 'MID';
    }
    if (const {'ST', 'CF', 'SS'}.contains(r)) return 'ATT';
    // fallback prefix
    if (slot.startsWith('GK')) return 'GK';
    if (slot.startsWith('DEF') || slot.startsWith('CB') || slot.startsWith('LB') || slot.startsWith('RB')) {
      return 'DEF';
    }
    if (slot.startsWith('ATT') || slot.startsWith('ST')) return 'ATT';
    return 'MID';
  }

  /// Slot görünen kısa rol
  static String roleOf(String slot) {
    // strip trailing digits: CB1 -> CB, CM2 -> CM
    final m = RegExp(r'^([A-Z]+)').firstMatch(slot);
    return m?.group(1) ?? slot;
  }

  static String labelOf(String slot) {
    final role = roleOf(slot);
    switch (role) {
      case 'GK':
        return 'GK';
      case 'LB':
        return 'SOL B';
      case 'RB':
        return 'SAĞ B';
      case 'CB':
        return 'STP';
      case 'LWB':
        return 'LWB';
      case 'RWB':
        return 'RWB';
      case 'CDM':
        return 'CDM';
      case 'CM':
        return 'CM';
      case 'CAM':
        return 'CAM';
      case 'LM':
        return 'LM';
      case 'RM':
        return 'RM';
      case 'LW':
        return 'SOL K';
      case 'RW':
        return 'SAĞ K';
      case 'ST':
        return 'ST';
      case 'CF':
        return 'CF';
      default:
        return role;
    }
  }

  int countGroup(String g) => slots.where((s) => groupOf(s) == g).length;
}

class ManagerFormations {
  ManagerFormations._();

  static final List<ManagerFormation> all = [
    const ManagerFormation(
      id: '433',
      label: '4-3-3',
      category: 'Dörtlü savunma',
      blurb: 'Kanat hücumu · dengeli',
      rows: [
        ['LW', 'ST', 'RW'],
        ['CM1', 'CM2', 'CM3'],
        ['LB', 'CB1', 'CB2', 'RB'],
        ['GK'],
      ],
    ),
    const ManagerFormation(
      id: '4231',
      label: '4-2-3-1',
      category: 'Dörtlü savunma',
      blurb: 'Kontrol · çift pivot',
      rows: [
        ['ST'],
        ['LM', 'CAM', 'RM'],
        ['CDM1', 'CDM2'],
        ['LB', 'CB1', 'CB2', 'RB'],
        ['GK'],
      ],
    ),
    const ManagerFormation(
      id: '442',
      label: '4-4-2',
      category: 'Klasik sistemler',
      blurb: 'Klasik blok · dengeli',
      rows: [
        ['ST1', 'ST2'],
        ['LM', 'CM1', 'CM2', 'RM'],
        ['LB', 'CB1', 'CB2', 'RB'],
        ['GK'],
      ],
    ),
    const ManagerFormation(
      id: '4141',
      label: '4-1-4-1',
      category: 'Klasik sistemler',
      blurb: 'Tek pivot · geçiş',
      rows: [
        ['ST'],
        ['LM', 'CM1', 'CM2', 'RM'],
        ['CDM'],
        ['LB', 'CB1', 'CB2', 'RB'],
        ['GK'],
      ],
    ),
    const ManagerFormation(
      id: '352',
      label: '3-5-2',
      category: 'Üçlü savunma',
      blurb: 'Kanat bek · orta saha',
      rows: [
        ['ST1', 'ST2'],
        ['LWB', 'CM1', 'CM2', 'CM3', 'RWB'],
        ['CB1', 'CB2', 'CB3'],
        ['GK'],
      ],
    ),
    const ManagerFormation(
      id: '3421',
      label: '3-4-2-1',
      category: 'Üçlü savunma',
      blurb: 'Çift 10 · yaratıcı',
      rows: [
        ['ST'],
        ['CAM1', 'CAM2'],
        ['LWB', 'CM1', 'CM2', 'RWB'],
        ['CB1', 'CB2', 'CB3'],
        ['GK'],
      ],
    ),
    const ManagerFormation(
      id: '532',
      label: '5-3-2',
      category: 'Beşli savunma',
      blurb: 'Alçak blok',
      rows: [
        ['ST1', 'ST2'],
        ['CM1', 'CM2', 'CM3'],
        ['LWB', 'CB1', 'CB2', 'CB3', 'RWB'],
        ['GK'],
      ],
    ),
    const ManagerFormation(
      id: '541',
      label: '5-4-1',
      category: 'Beşli savunma',
      blurb: 'Park the bus',
      rows: [
        ['ST'],
        ['LM', 'CM1', 'CM2', 'RM'],
        ['LWB', 'CB1', 'CB2', 'CB3', 'RWB'],
        ['GK'],
      ],
    ),
    const ManagerFormation(
      id: '343',
      label: '3-4-3',
      category: 'Hücum ağırlıklı',
      blurb: 'Geniş hücum',
      rows: [
        ['LW', 'ST', 'RW'],
        ['LWB', 'CM1', 'CM2', 'RWB'],
        ['CB1', 'CB2', 'CB3'],
        ['GK'],
      ],
    ),
    const ManagerFormation(
      id: '424',
      label: '4-2-4',
      category: 'Hücum ağırlıklı',
      blurb: 'Dört forvet baskı',
      rows: [
        ['LW', 'ST1', 'ST2', 'RW'],
        ['CDM1', 'CDM2'],
        ['LB', 'CB1', 'CB2', 'RB'],
        ['GK'],
      ],
    ),
  ];

  static List<String> get categories {
    final seen = <String>[];
    for (final f in all) {
      if (!seen.contains(f.category)) seen.add(f.category);
    }
    return seen;
  }
}
