
import '../models/player.dart';

/// Position groups of the Club Manager pool; the weekly pool itself is dealt by
/// ManagerRoster.poolFor (3 GK + 7 DEF + 8 MID + 7 ATT).
class ManagerPoolService {
  ManagerPoolService._();
  static final ManagerPoolService instance = ManagerPoolService._();

  static const posTargets = {'GK': 3, 'DEF': 7, 'MID': 8, 'ATT': 7};

  /// Pozisyon grubu. "Defensive Midfield" MID olmalı (defen tuzak).
  String positionGroup(Player p) {
    final pos = p.position.trim().toLowerCase();
    final det = p.detailedPosition.trim().toLowerCase();
    final raw = '$pos $det';

    // 1) Kaleci
    if (raw.contains('goal') ||
        raw.contains('keeper') ||
        raw.contains('kaleci') ||
        pos == 'g' ||
        pos == 'gk') {
      return 'GK';
    }

    // 2) Orta saha ÖNCE (defensive/attacking midfield, CM, CDM, CAM…)
    if (raw.contains('midfield') ||
        raw.contains('midfielder') ||
        raw.contains('orta saha') ||
        raw.contains('orta-saha') ||
        det.contains('cdm') ||
        det.contains('cam') ||
        det.contains('cm') ||
        det.contains('dm') ||
        det.contains('am') ||
        pos == 'm' ||
        pos == 'mf' ||
        pos == 'mid') {
      return 'MID';
    }
    // "mid" tek başına (ama "middle" vs. nadir)
    if (raw.contains(' mid') || raw.startsWith('mid') || raw.contains('orta')) {
      return 'MID';
    }

    // 3) Forvet / kanat hücum
    if (raw.contains('strik') ||
        raw.contains('forw') ||
        raw.contains('forvet') ||
        raw.contains('second striker') ||
        det.contains('cf') ||
        det.contains('st') ||
        pos == 'f' ||
        pos == 'fw' ||
        pos == 'a' ||
        pos == 'att') {
      return 'ATT';
    }
    // Wing: "left wing" / "right wing" — not wing-back
    if ((raw.contains('wing') && !raw.contains('back') && !raw.contains('wingback') && !raw.contains('wing-back')) ||
        raw.contains('winger') ||
        det == 'lw' ||
        det == 'rw') {
      return 'ATT';
    }
    if (raw.contains('attack') && !raw.contains('midfield')) {
      return 'ATT';
    }

    // 4) Defans (full-back, centre-back, wing-back, stoper…)
    if (raw.contains('defen') ||
        raw.contains('centre-back') ||
        raw.contains('center-back') ||
        raw.contains('center back') ||
        raw.contains('centre back') ||
        raw.contains('full-back') ||
        raw.contains('fullback') ||
        raw.contains('full back') ||
        raw.contains('wing-back') ||
        raw.contains('wingback') ||
        raw.contains('wing back') ||
        raw.contains('stoper') ||
        raw.contains('bek') ||
        raw.contains('stopper') ||
        det.contains('cb') ||
        det.contains('lb') ||
        det.contains('rb') ||
        det.contains('lwb') ||
        det.contains('rwb') ||
        pos == 'd' ||
        pos == 'df' ||
        pos == 'def') {
      return 'DEF';
    }
    // "back" yalnızca defans bağlamında
    if (raw.contains('back') && !raw.contains('mid')) {
      return 'DEF';
    }

    return 'MID';
  }
}
