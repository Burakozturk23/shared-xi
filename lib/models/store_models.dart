import 'package:flutter/material.dart';

import 'economy_models.dart';

/// Player-facing names for every mode a support can be used in. Covers the
/// paid-support modes (functions/boosts.js) and the legacy letter-support
/// flows (functions/store_collection.js); a test keeps both lists in sync.
const boostModeNames = <String, String>{
  'squad_vault': 'Kadro Kasası', 'letter11': 'Harf 11',
  'career': 'Kariyer Bulmacası', 'transfer': 'Transfer Dedektifi', 'mystery': 'Gizemli Futbolcu',
  'mastermind': 'Kariyer Zinciri', 'fake_endless': 'Sahte Kulüp Sonsuz',
  'burst_survival': 'Burst Dayanıklılık', 'pyramid': 'Pyramid', 'matching': 'Kart Eşleştirme',
  'daily_lingo': 'Günün Lingo’su', 'daily_anagram': 'Günün Anagramı', 'anagram_practice': 'Sekizli Anagram',
  'passa_daily': 'Mini Passaparola', 'passa_weekly': 'Haftalık Passaparola',
  'daily_question': 'Günün Sorusu', 'daily_match': 'Günün Maçları',
  'solo_grid_classic': 'Solo Klasik Grid', 'solo_grid_reverse': 'Solo Tersten Grid',
  'solo_grid_random': 'Solo Rastgele Grid', 'bot_grid_classic': 'Bot Klasik Grid',
  'bot_grid_reverse': 'Bot Tersten Grid', 'bot_grid_random': 'Bot Rastgele Grid',
  'bot_loto': 'Bot Football Loto', 'bot_team_race': 'Bot Takım Yarışı', 'bot_cinko': 'Bot Futbol Çinko',
  'bot_random_five': 'Bot Rastgele Beşler',
  'daily_footballer': 'Günün Futbolcusu', 'squad_challenge': 'Kadro Mücadelesi',
  'higher_lower_training': 'Higher or Lower Antrenman', 'blind_ranking_training': 'Blind Ranking Antrenman',
  'player_journey': 'Oyuncu Yolculuğu', 'what_if': 'What If', 'ucl_moments': 'UCL Moments',
  'nostalgia': 'Türkiye Nostaljisi', 'international_glory': 'International Glory',
  'dynasties': 'Hanedanlar', 'football_docu': 'Futbol Belgeseli', 'derby_day': 'Derbi Günü',
  // Legacy letter-support flows.
  'futbol_lingo': 'Futbol Lingo', 'mystery_player': 'Gizemli Futbolcu (klasik)',
  'transfer_detective': 'Transfer Dedektifi (klasik)',
};

/// Letter supports that are no longer sold; leftover stock converts to Temel bilgi.
const legacyBoostIds = ['boost_last_letter', 'boost_anagram'];

IconData storeBoostIcon(String itemId) => switch (itemId) {
  'boost_basic' => Icons.lightbulb_outline_rounded,
  'boost_eliminate' => Icons.filter_alt_off_outlined,
  'boost_connection' => Icons.link_rounded,
  'boost_strong' => Icons.bolt_rounded,
  'boost_anagram' => Icons.shuffle_rounded,
  'boost_last_letter' => Icons.last_page_rounded,
  _ => Icons.first_page_rounded,
};

/// One game in the store's "Oyuna göre" guide, as the server describes it.
class StoreBoostGuide {
  final String modeId, name, group;
  final List<({String itemId, String title, String effect})> supports;
  const StoreBoostGuide({required this.modeId, required this.name, required this.group, required this.supports});

  static List<StoreBoostGuide> listFrom(Object? raw) => [
    if (raw is List)
      for (final m in raw.whereType<Map>())
        if ((m['modeId']?.toString() ?? '').isNotEmpty && m['supports'] is List)
          StoreBoostGuide(
            modeId: m['modeId'].toString(),
            name: m['name']?.toString() ?? m['modeId'].toString(),
            group: m['group']?.toString() ?? 'Diğer',
            supports: [
              for (final x in (m['supports'] as List).whereType<Map>())
                if ((x['itemId']?.toString() ?? '').isNotEmpty)
                  (itemId: x['itemId'].toString(), title: x['title']?.toString() ?? '',
                    effect: x['effect']?.toString() ?? ''),
            ],
          ),
  ];
}

class StoreOffer {
  final String offerId;
  final String title;
  final String subtitle;
  final String badge;
  final int priceCoins;
  final String itemId;
  final String itemType;
  final bool oneTime;
  final int sortOrder;
  final int version;
  final String category;
  final int units;
  final List<String> modes;
  /// App-bundled artwork without a current server offer. Never purchasable.
  final bool isPreview;

  const StoreOffer({
    required this.offerId,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.priceCoins,
    required this.itemId,
    required this.itemType,
    required this.oneTime,
    required this.sortOrder,
    this.version = 1,
    this.category = 'classic',
    this.units = 1,
    this.modes = const [],
    this.isPreview = false,
  });

  bool get isAvatar => itemType == 'avatar';

  String get boostCategory => switch (itemId) {
    'boost_first_letter' || 'boost_last_letter' || 'boost_basic' => 'Temel',
    'boost_eliminate' || 'boost_connection' => 'Taktiksel',
    'boost_anagram' || 'boost_strong' => 'Güçlü',
    _ => category,
  };

  String get compatibleModes =>
      modes.map((mode) => boostModeNames[mode] ?? mode).join(' · ');

  /// Short icon-friendly kind of a support product.
  IconData get boostIcon => storeBoostIcon(itemId);

  factory StoreOffer.fromMap(Map<String, dynamic> data) {
    return StoreOffer(
      offerId: data['offerId']?.toString() ?? '',
      category: data['category']?.toString() ?? 'classic',
      units: _storeInt(data['units'], fallback: 1),
      modes: data['modes'] is List ? (data['modes'] as List).map((v) => v.toString()).toList() : const [],
      title: data['title']?.toString() ?? '',
      subtitle: data['subtitle']?.toString() ?? '',
      badge: data['badge']?.toString() ?? '',
      priceCoins: _storeInt(data['priceCoins']),
      itemId: data['itemId']?.toString() ?? '',
      itemType: data['itemType']?.toString() ?? '',
      oneTime: data['oneTime'] == true,
      sortOrder: _storeInt(data['sortOrder']),
      version: _storeInt(data['version'], fallback: 1),
    );
  }
}

class StoreCatalogSnapshot {
  final int catalogVersion;
  final EconomyWallet wallet;
  final List<StoreOffer> offers;
  final Map<String, EconomyInventoryItem> inventory;
  final String selectedAvatarId, selectedKitId;
  final List<StoreBoostGuide> boostGuide;

  /// Supports added when this load converted leftover letter stock (item → count).
  final Map<String, int> legacyConverted;

  const StoreCatalogSnapshot({
    required this.catalogVersion,
    required this.wallet,
    required this.offers,
    this.inventory = const {},
    this.selectedAvatarId = 'starter_ball',
    this.selectedKitId = '',
    this.boostGuide = const [],
    this.legacyConverted = const {},
  });

  StoreCatalogSnapshot copyWith({
    EconomyWallet? wallet,
    Map<String, EconomyInventoryItem>? inventory,
    String? selectedAvatarId,
    String? selectedKitId,
  }) => StoreCatalogSnapshot(
    catalogVersion: catalogVersion,
    wallet: wallet ?? this.wallet,
    offers: offers,
    inventory: inventory ?? this.inventory,
    selectedAvatarId: selectedAvatarId ?? this.selectedAvatarId,
    selectedKitId: selectedKitId ?? this.selectedKitId,
    boostGuide: boostGuide,
  );
}

int _storeInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
