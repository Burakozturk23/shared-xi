import 'package:flutter/material.dart';

/// İpucu v2: the server's hint menu for one session (`session['hintMenu']`).
/// The bag (how many of each type the player owns) comes from the wallet.
class HintItem {
  const HintItem({
    required this.id,
    required this.label,
    required this.type,
    required this.strong,
    required this.price,
    required this.used,
    this.result,
    this.why,
  });
  final String id, label, type;
  final bool strong, used;
  final int price;
  final String? result, why;

  /// Inventory key of the bag type this item spends.
  String get bagKey => 'hint_$type';

  factory HintItem.fromMap(Map data) => HintItem(
    id: '${data['id']}',
    label: '${data['label'] ?? ''}',
    type: '${data['type'] ?? ''}',
    strong: data['strong'] == true,
    price: (data['price'] as num?)?.toInt() ?? 0,
    used: data['used'] == true,
    result: data['result'] as String?,
    why: data['why'] as String?,
  );
}

class HintMenu {
  const HintMenu({
    required this.board,
    required this.items,
    required this.suggested,
    required this.adsAllowed,
    required this.adsRemaining,
    required this.credits,
    required this.assisted,
    this.byTarget,
  });
  final String board;
  final List<HintItem> items;
  final (String?, String?) suggested;
  final bool adsAllowed, assisted;
  final int adsRemaining;
  final Map<String, int> credits;

  /// Items each target (Grid cell, Çinko cell, axis) can produce; null = every item.
  final Map<String, List<String>>? byTarget;

  static HintMenu? fromSession(Map? session) {
    final raw = session?['hintMenu'];
    if (raw is! Map || raw['version'] != 2) return null;
    final ads = raw['ads'] is Map ? raw['ads'] as Map : const {};
    final s = raw['suggested'] is List ? raw['suggested'] as List : const [];
    final targets = raw['byTarget'];
    return HintMenu(
      board: '${raw['board'] ?? ''}',
      items: [
        for (final i in raw['items'] is List ? raw['items'] as List : const [])
          if (i is Map) HintItem.fromMap(i),
      ],
      suggested: (s.isNotEmpty ? s[0] as String? : null, s.length > 1 ? s[1] as String? : null),
      adsAllowed: ads['allowed'] != false,
      adsRemaining: (ads['remaining'] as num?)?.toInt() ?? 0,
      credits: {
        for (final e in (ads['credits'] is Map ? ads['credits'] as Map : const {}).entries)
          '${e.key}': (e.value as num?)?.toInt() ?? 0,
      },
      assisted: raw['assisted'] == true,
      byTarget: targets is Map
          ? {for (final e in targets.entries) '${e.key}': [for (final x in e.value as List) '$x']}
          : null,
    );
  }

  /// The items the selected target can produce (all items when the mode has no targets).
  List<HintItem> forTarget(Object? target) {
    final allowed = target == null ? null : byTarget?['$target'];
    if (allowed == null) return items;
    return [for (final i in items) if (i.used || allowed.contains(i.id)) i];
  }

  HintItem? item(String? id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }
}

/// Titles and icons of the nine bag types and the Pro Joker.
const hintTypeTitles = <String, String>{
  'milliyet': 'Milliyet', 'mevki': 'Mevki', 'kulup': 'Kulüp', 'donem': 'Dönem', 'harf': 'Harf',
  'ele': 'Ele', 'isim': 'İsim', 'baglanti': 'Bağlantı', 'aday': 'Aday', 'joker': 'Joker',
};
IconData hintTypeIcon(String type) => switch (type) {
  'milliyet' => Icons.flag_outlined,
  'mevki' => Icons.directions_run,
  'kulup' => Icons.shield_outlined,
  'donem' => Icons.calendar_month_outlined,
  'harf' => Icons.text_fields,
  'ele' => Icons.remove_circle_outline,
  'isim' => Icons.badge_outlined,
  'baglanti' => Icons.link,
  'aday' => Icons.person_search_outlined,
  'joker' => Icons.auto_awesome,
  _ => Icons.lightbulb_outline,
};
