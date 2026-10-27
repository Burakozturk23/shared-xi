import 'economy_models.dart';

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

  String get compatibleModes => modes.map((mode) => const {
    'coach_xi': 'Hoca 11', 'squad_vault': 'Kadro Kasası', 'letter11': 'Harf 11',
    'career': 'Kariyer', 'transfer': 'Transfer Detective', 'mystery': 'Gizemli Futbolcu',
    'mastermind': 'Zincir', 'fake_endless': 'Sahte Kulüp Sonsuz',
    'burst_survival': 'Burst Dayanıklılık', 'pyramid': 'Pyramid', 'matching': 'Kart Eşleştirme',
    'daily_lingo': 'Günün Lingo’su', 'daily_anagram': 'Günün Anagramı', 'anagram_practice': 'Sekizli Anagram',
    'passa_daily': 'Mini Passaparola', 'passa_weekly': 'Haftalık Passaparola',
    'daily_question': 'Günün Sorusu', 'daily_match': 'Günün Maçları', 'solo_grid_classic': 'Solo Klasik Grid', 'solo_grid_reverse': 'Solo Tersten Grid',
  'solo_grid_random': 'Solo Rastgele Grid', 'bot_grid_classic': 'Bot Klasik Grid',
  'bot_grid_reverse': 'Bot Tersten Grid', 'bot_grid_random': 'Bot Rastgele Grid',
  'bot_loto': 'Bot Football Loto', 'bot_team_race': 'Bot Takım Yarışı', 'bot_cinko': 'Bot Futbol Çinko',
  'bot_random_five': 'Bot Rastgele Beşler',
  'daily_footballer': 'Günün Futbolcusu', 'squad_challenge': 'Kadro Mücadelesi',
    'higher_lower_training': 'Higher or Lower Antrenman', 'blind_ranking_training': 'Blind Ranking Antrenman',
    'player_journey': 'Oyuncu Yolculuğu', 'what_if': 'What If', 'ucl_moments': 'UCL Moments',
    'nostalgia': 'Türkiye Nostaljisi', 'international_glory': 'International Glory',
    'dynasties': 'Hanedanlar', 'football_docu': 'Futbol Belgeseli', 'derby_day': 'Derbi Günü',
  }[mode] ?? mode).join(' · ');

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

  const StoreCatalogSnapshot({
    required this.catalogVersion,
    required this.wallet,
    required this.offers,
    this.inventory = const {},
    this.selectedAvatarId = 'starter_ball',
    this.selectedKitId = '',
  });
}

int _storeInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
