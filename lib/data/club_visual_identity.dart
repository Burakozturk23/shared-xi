import 'package:flutter/material.dart';

import '../models/club.dart';

/// Original app marks, not reproductions of official club crests.
/// IDs belong to the bundled V4 catalog; never infer identity from a substring.
enum ClubMarkShape { shield, round, pennant }

class ClubVisualIdentity {
  const ClubVisualIdentity(
    this.label,
    this.primary,
    this.secondary, {
    this.shape = ClubMarkShape.shield,
  });

  final String label;
  final Color primary;
  final Color secondary;
  final ClubMarkShape shape;

  static ClubVisualIdentity forClub(Club club) {
    final known = catalog[club.id];
    if (known != null) return known;
    final raw = club.color;
    final primary = raw == null
        ? const Color(0xFF246B72)
        : Color(raw <= 0xFFFFFF ? 0xFF000000 | raw : raw);
    return ClubVisualIdentity(
      initials(club.name),
      primary,
      const Color(0xFFE0E8DF),
    );
  }

  static String initials(String name) {
    final parts = name
        .replaceAll(
          RegExp(r'\b(FC|CF|SC|FK|SK|AC|AS|SS|RC|CD)\b', caseSensitive: false),
          '',
        )
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return String.fromCharCodes(parts.first.runes.take(3)).toUpperCase();
    }
    return parts.take(3).map((part) => String.fromCharCode(part.runes.first))
        .join().toUpperCase();
  }

  static const catalog = <int, ClubVisualIdentity>{
    418: ClubVisualIdentity('RMA', Color(0xFFF7F5EC), Color(0xFFC9A453), shape: ClubMarkShape.round),
    131: ClubVisualIdentity('BAR', Color(0xFFA32042), Color(0xFF17488F), shape: ClubMarkShape.shield),
    13: ClubVisualIdentity('ATM', Color(0xFFD62D38), Color(0xFFF8F5EC), shape: ClubMarkShape.pennant),
    36: ClubVisualIdentity('FB', Color(0xFF142744), Color(0xFFF4CD35), shape: ClubMarkShape.round),
    141: ClubVisualIdentity('GS', Color(0xFFA91E32), Color(0xFFF7B52C), shape: ClubMarkShape.shield),
    114: ClubVisualIdentity('BJK', Color(0xFF181E24), Color(0xFFF6F5EE), shape: ClubMarkShape.pennant),
    449: ClubVisualIdentity('TS', Color(0xFF7B294B), Color(0xFF61BBD3), shape: ClubMarkShape.shield),
    11: ClubVisualIdentity('ARS', Color(0xFFC92435), Color(0xFFF7F3E8), shape: ClubMarkShape.shield),
    631: ClubVisualIdentity('CHE', Color(0xFF174BA6), Color(0xFFF1F2EC), shape: ClubMarkShape.round),
    31: ClubVisualIdentity('LIV', Color(0xFFBA2438), Color(0xFFF5EDE0), shape: ClubMarkShape.pennant),
    985: ClubVisualIdentity('MUN', Color(0xFFCF293B), Color(0xFFF4CE45), shape: ClubMarkShape.shield),
    281: ClubVisualIdentity('MCI', Color(0xFF78BCE1), Color(0xFFF7F5EB), shape: ClubMarkShape.round),
    148: ClubVisualIdentity('TOT', Color(0xFFF7F6EF), Color(0xFF172946), shape: ClubMarkShape.pennant),
    762: ClubVisualIdentity('NEW', Color(0xFF20252B), Color(0xFFF4F4EE), shape: ClubMarkShape.shield),
    405: ClubVisualIdentity('AVL', Color(0xFF79334D), Color(0xFF8BCBE7), shape: ClubMarkShape.shield),
    379: ClubVisualIdentity('WHU', Color(0xFF753048), Color(0xFF8CC8E1), shape: ClubMarkShape.pennant),
    29: ClubVisualIdentity('EVE', Color(0xFF2354B5), Color(0xFFF4F5ED), shape: ClubMarkShape.shield),
    1237: ClubVisualIdentity('BHA', Color(0xFF2265B7), Color(0xFFF7F5EE), shape: ClubMarkShape.round),
    873: ClubVisualIdentity('CRY', Color(0xFF2253A1), Color(0xFFC32F42), shape: ClubMarkShape.shield),
    543: ClubVisualIdentity('WOL', Color(0xFFE5AE31), Color(0xFF25282A), shape: ClubMarkShape.pennant),
    399: ClubVisualIdentity('LEE', Color(0xFFF5F4E8), Color(0xFFE6C73A), shape: ClubMarkShape.shield),
    1003: ClubVisualIdentity('LEI', Color(0xFF295BAC), Color(0xFFF6F5ED), shape: ClubMarkShape.round),
    703: ClubVisualIdentity('NFO', Color(0xFFC9313D), Color(0xFFF6F5EF), shape: ClubMarkShape.pennant),
    931: ClubVisualIdentity('FUL', Color(0xFFF5F4EA), Color(0xFF26282C), shape: ClubMarkShape.shield),
    180: ClubVisualIdentity('SOU', Color(0xFFD42F3C), Color(0xFFF5F3E8), shape: ClubMarkShape.pennant),
    1148: ClubVisualIdentity('BRE', Color(0xFFD2323D), Color(0xFFF6F4E9), shape: ClubMarkShape.round),
    989: ClubVisualIdentity('BOU', Color(0xFFB92335), Color(0xFF21262C), shape: ClubMarkShape.shield),
    27: ClubVisualIdentity('BAY', Color(0xFFC9273F), Color(0xFFF5F3EC), shape: ClubMarkShape.round),
    16: ClubVisualIdentity('BVB', Color(0xFFF2D432), Color(0xFF242626), shape: ClubMarkShape.pennant),
    15: ClubVisualIdentity('B04', Color(0xFFCE2936), Color(0xFF20262C), shape: ClubMarkShape.shield),
    23826: ClubVisualIdentity('RBL', Color(0xFFF5F4EB), Color(0xFFD83246), shape: ClubMarkShape.pennant),
    24: ClubVisualIdentity('SGE', Color(0xFF24292D), Color(0xFFD4353D), shape: ClubMarkShape.round),
    79: ClubVisualIdentity('VFB', Color(0xFFF7F4E9), Color(0xFFCF3342), shape: ClubMarkShape.shield),
    18: ClubVisualIdentity('BMG', Color(0xFFF4F4EB), Color(0xFF27734B), shape: ClubMarkShape.pennant),
    82: ClubVisualIdentity('WOB', Color(0xFF73B84A), Color(0xFFF4F5EC), shape: ClubMarkShape.round),
    86: ClubVisualIdentity('SVW', Color(0xFF249663), Color(0xFFF4F4E9), shape: ClubMarkShape.shield),
    33: ClubVisualIdentity('S04', Color(0xFF2452B1), Color(0xFFF5F5EC), shape: ClubMarkShape.round),
    41: ClubVisualIdentity('HSV', Color(0xFF2157A0), Color(0xFFF5F3E8), shape: ClubMarkShape.pennant),
    5: ClubVisualIdentity('MIL', Color(0xFFC42A39), Color(0xFF20252A), shape: ClubMarkShape.pennant),
    46: ClubVisualIdentity('INT', Color(0xFF2262B7), Color(0xFF20262B), shape: ClubMarkShape.round),
    506: ClubVisualIdentity('JUV', Color(0xFFF5F4EC), Color(0xFF20252B), shape: ClubMarkShape.pennant),
    15795: ClubVisualIdentity('NAP', Color(0xFF40A8D8), Color(0xFFF5F5EE), shape: ClubMarkShape.round),
    12: ClubVisualIdentity('ROM', Color(0xFF9C2E38), Color(0xFFEBB444), shape: ClubMarkShape.shield),
    398: ClubVisualIdentity('LAZ', Color(0xFF8FC8E0), Color(0xFFF7F5EE), shape: ClubMarkShape.pennant),
    430: ClubVisualIdentity('FIO', Color(0xFF713D9D), Color(0xFFF5F3ED), shape: ClubMarkShape.shield),
    800: ClubVisualIdentity('ATA', Color(0xFF2260AA), Color(0xFF24282E), shape: ClubMarkShape.pennant),
    1025: ClubVisualIdentity('BOL', Color(0xFFB02A3F), Color(0xFF203966), shape: ClubMarkShape.shield),
    416: ClubVisualIdentity('TOR', Color(0xFF812C3A), Color(0xFFF5EEDD), shape: ClubMarkShape.round),
    130: ClubVisualIdentity('PAR', Color(0xFFF4CE3C), Color(0xFF234983), shape: ClubMarkShape.shield),
    252: ClubVisualIdentity('GEN', Color(0xFFAB2B3F), Color(0xFF233854), shape: ClubMarkShape.pennant),
    583: ClubVisualIdentity('PSG', Color(0xFF183D69), Color(0xFFD23347), shape: ClubMarkShape.round),
    244: ClubVisualIdentity('OM', Color(0xFFF5F4ED), Color(0xFF3FA8D6), shape: ClubMarkShape.pennant),
    1041: ClubVisualIdentity('OL', Color(0xFFF5F4ED), Color(0xFFD62E45), shape: ClubMarkShape.shield),
    162: ClubVisualIdentity('ASM', Color(0xFFD23541), Color(0xFFF5F2E9), shape: ClubMarkShape.pennant),
    1082: ClubVisualIdentity('LIL', Color(0xFFC62D46), Color(0xFF253F64), shape: ClubMarkShape.shield),
    417: ClubVisualIdentity('NIC', Color(0xFFC32A37), Color(0xFF24282C), shape: ClubMarkShape.pennant),
    368: ClubVisualIdentity('SEV', Color(0xFFF5F4ED), Color(0xFFCE3041), shape: ClubMarkShape.shield),
    150: ClubVisualIdentity('BET', Color(0xFF258F56), Color(0xFFF6F5EB), shape: ClubMarkShape.pennant),
    621: ClubVisualIdentity('ATH', Color(0xFFC73540), Color(0xFFF5F4EB), shape: ClubMarkShape.shield),
    681: ClubVisualIdentity('RSO', Color(0xFF2F77B9), Color(0xFFF4F4EB), shape: ClubMarkShape.pennant),
    1049: ClubVisualIdentity('VAL', Color(0xFFF3F1E8), Color(0xFF24272B), shape: ClubMarkShape.shield),
    1050: ClubVisualIdentity('VIL', Color(0xFFF1D63C), Color(0xFF244582), shape: ClubMarkShape.round),
    720: ClubVisualIdentity('POR', Color(0xFF255AAA), Color(0xFFF6F4ED), shape: ClubMarkShape.round),
    294: ClubVisualIdentity('BEN', Color(0xFFD3303E), Color(0xFFF5F2E9), shape: ClubMarkShape.pennant),
    336: ClubVisualIdentity('SCP', Color(0xFF238052), Color(0xFFF4F4E9), shape: ClubMarkShape.shield),
    610: ClubVisualIdentity('AJA', Color(0xFFF4F3EA), Color(0xFFCC3040), shape: ClubMarkShape.pennant),
    234: ClubVisualIdentity('FEY', Color(0xFFC5303D), Color(0xFFF5F3E9), shape: ClubMarkShape.round),
    371: ClubVisualIdentity('CEL', Color(0xFF26894F), Color(0xFFF5F4E9), shape: ClubMarkShape.round),
    124: ClubVisualIdentity('RAN', Color(0xFF2456AA), Color(0xFFF4F4E9), shape: ClubMarkShape.shield),
    189: ClubVisualIdentity('BOC', Color(0xFF224C96), Color(0xFFF2C43A), shape: ClubMarkShape.shield),
    209: ClubVisualIdentity('RIV', Color(0xFFF5F3E9), Color(0xFFCC3042), shape: ClubMarkShape.pennant),
    614: ClubVisualIdentity('FLA', Color(0xFFC12C3B), Color(0xFF23262A), shape: ClubMarkShape.shield),
    221: ClubVisualIdentity('SAN', Color(0xFFF5F4ED), Color(0xFF24282C), shape: ClubMarkShape.pennant),
    199: ClubVisualIdentity('COR', Color(0xFFF4F3EC), Color(0xFF24282C), shape: ClubMarkShape.shield),
    1023: ClubVisualIdentity('PAL', Color(0xFF267A4C), Color(0xFFF4F4E9), shape: ClubMarkShape.round),
    23287: ClubVisualIdentity('MIA', Color(0xFFEDA7BF), Color(0xFF252A30), shape: ClubMarkShape.shield),
    69261: ClubVisualIdentity('MIA', Color(0xFFEDA7BF), Color(0xFF252A30), shape: ClubMarkShape.shield),
    1114: ClubVisualIdentity('HIL', Color(0xFF225DB3), Color(0xFFF5F4EA), shape: ClubMarkShape.round),
    18544: ClubVisualIdentity('NAS', Color(0xFFF2D43E), Color(0xFF2451A0), shape: ClubMarkShape.shield),
  };
}
