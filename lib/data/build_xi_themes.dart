enum BuildXiPoolType { league, region, all, clubPair, clubUnion }

enum BuildXiCategory { leagues, regions, rivalries, special }

class BuildXiTheme {
  final String id;
  final String name;
  final String description;
  final BuildXiPoolType poolType;
  final BuildXiCategory category;
  final String? leagueName;
  final List<String>? countries;
  final List<int>? clubPairIds;
  final bool uniqueNationalityRule;
  final int? minClubs; // Wanderers için
  final int unlockStars; // 0 = başlangıçta açık

  const BuildXiTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.poolType,
    required this.category,
    this.leagueName,
    this.countries,
    this.clubPairIds,
    this.uniqueNationalityRule = false,
    this.minClubs,
    this.unlockStars = 0,
  });
}

// ─── Ülke listeleri ───────────────────────────────────────────────

const List<String> southAmericaCountries = [
  'Brazil', 'Argentina', 'Uruguay', 'Colombia', 'Chile',
  'Paraguay', 'Peru', 'Ecuador', 'Venezuela', 'Bolivia',
];

const List<String> balkanCountries = [
  'Serbia', 'Croatia', 'Bosnia-Herzegovina', 'Albania',
  'North Macedonia', 'Montenegro', 'Slovenia', 'Kosovo',
  'Bulgaria', 'Romania',
];

const List<String> scandinaviaCountries = [
  'Denmark', 'Sweden', 'Norway', 'Finland', 'Iceland',
];

const List<String> africanCountries = [
  'Senegal', 'Nigeria', 'Morocco', 'Cameroon', 'Ivory Coast',
  'Ghana', 'Egypt', 'Mali', 'Algeria', 'Tunisia',
];

const List<String> easternEuropeCountries = [
  'Poland', 'Czech Republic', 'Ukraine', 'Hungary', 'Romania',
  'Slovakia', 'Belarus', 'Moldova', 'Lithuania', 'Latvia', 'Estonia',
];

// ─── Temalar ──────────────────────────────────────────────────────

const List<BuildXiTheme> buildXiThemes = [
  // ═══════════════════════════════════════════════
  // LIGLER
  // ═══════════════════════════════════════════════
  BuildXiTheme(
    id: 'premier_league',
    name: 'Premier League',
    description: 'Sadece Premier League geçmişi olan oyuncular',
    poolType: BuildXiPoolType.league,
    category: BuildXiCategory.leagues,
    leagueName: 'Premier League',
    unlockStars: 0,
  ),
  BuildXiTheme(
    id: 'super_lig',
    name: 'Türkiye Süper Lig',
    description: 'Süper Lig\'de oynamış oyunculardan 11 kur',
    poolType: BuildXiPoolType.league,
    category: BuildXiCategory.leagues,
    leagueName: 'Süper Lig',
    unlockStars: 0,
  ),
  BuildXiTheme(
    id: 'laliga',
    name: 'LaLiga',
    description: 'Sadece LaLiga geçmişi olan oyuncular',
    poolType: BuildXiPoolType.league,
    category: BuildXiCategory.leagues,
    leagueName: 'LaLiga',
    unlockStars: 5,
  ),
  BuildXiTheme(
    id: 'serie_a',
    name: 'Serie A',
    description: 'Sadece Serie A geçmişi olan oyuncular',
    poolType: BuildXiPoolType.league,
    category: BuildXiCategory.leagues,
    leagueName: 'Serie A',
    unlockStars: 5,
  ),
  BuildXiTheme(
    id: 'bundesliga',
    name: 'Bundesliga',
    description: 'Sadece Bundesliga geçmişi olan oyuncular',
    poolType: BuildXiPoolType.league,
    category: BuildXiCategory.leagues,
    leagueName: 'Bundesliga',
    unlockStars: 12,
  ),
  BuildXiTheme(
    id: 'ligue_1',
    name: 'Ligue 1',
    description: 'Sadece Ligue 1 geçmişi olan oyuncular',
    poolType: BuildXiPoolType.league,
    category: BuildXiCategory.leagues,
    leagueName: 'Ligue 1',
    unlockStars: 12,
  ),
  BuildXiTheme(
    id: 'eredivisie',
    name: 'Eredivisie',
    description: 'Eredivisie\'de oynamış oyunculardan 11 kur',
    poolType: BuildXiPoolType.league,
    category: BuildXiCategory.leagues,
    leagueName: 'Eredivisie',
    unlockStars: 12,
  ),
  BuildXiTheme(
    id: 'liga_portugal',
    name: 'Liga Portugal',
    description: 'Portekiz liginde oynamış oyunculardan 11 kur',
    poolType: BuildXiPoolType.league,
    category: BuildXiCategory.leagues,
    leagueName: 'Liga Portugal',
    unlockStars: 12,
  ),

  // ═══════════════════════════════════════════════
  // BÖLGELER
  // ═══════════════════════════════════════════════
  BuildXiTheme(
    id: 'south_america',
    name: 'Güney Amerika',
    description: 'Sadece Güney Amerikalı oyuncular',
    poolType: BuildXiPoolType.region,
    category: BuildXiCategory.regions,
    countries: southAmericaCountries,
    unlockStars: 0,
  ),
  BuildXiTheme(
    id: 'balkan_power',
    name: 'Balkan Gücü',
    description: 'Sadece Balkan ülkelerinden oyuncular',
    poolType: BuildXiPoolType.region,
    category: BuildXiCategory.regions,
    countries: balkanCountries,
    unlockStars: 5,
  ),
  BuildXiTheme(
    id: 'africa',
    name: 'Afrika Gücü',
    description: 'Sadece Afrikalı oyunculardan 11 kur',
    poolType: BuildXiPoolType.region,
    category: BuildXiCategory.regions,
    countries: africanCountries,
    unlockStars: 5,
  ),
  BuildXiTheme(
    id: 'scandinavia',
    name: 'İskandinav Rüzgarı',
    description: 'Sadece İskandinav ülkelerinden oyuncular',
    poolType: BuildXiPoolType.region,
    category: BuildXiCategory.regions,
    countries: scandinaviaCountries,
    unlockStars: 12,
  ),
  BuildXiTheme(
    id: 'eastern_europe',
    name: 'Doğu Avrupa',
    description: 'Polonya, Çekya, Ukrayna, Macaristan ve çevresi',
    poolType: BuildXiPoolType.region,
    category: BuildXiCategory.regions,
    countries: easternEuropeCountries,
    unlockStars: 12,
  ),

  // ═══════════════════════════════════════════════
  // RIVALRIES (clubUnion = A veya B)
  // ═══════════════════════════════════════════════
  BuildXiTheme(
    id: 'el_clasico',
    name: 'El Clásico',
    description: 'Real Madrid veya Barcelona geçmişi olanlar',
    poolType: BuildXiPoolType.clubUnion,
    category: BuildXiCategory.rivalries,
    clubPairIds: [418, 131], // Real Madrid, Barcelona
    unlockStars: 20,
  ),
  BuildXiTheme(
    id: 'manchester_derby',
    name: 'Manchester Derbisi',
    description: 'United veya City geçmişi olanlar',
    poolType: BuildXiPoolType.clubUnion,
    category: BuildXiCategory.rivalries,
    clubPairIds: [985, 281], // United, City
    unlockStars: 20,
  ),
  BuildXiTheme(
    id: 'north_london',
    name: 'Kuzey Londra',
    description: 'Arsenal veya Tottenham geçmişi olanlar',
    poolType: BuildXiPoolType.clubUnion,
    category: BuildXiCategory.rivalries,
    clubPairIds: [11, 148], // Arsenal, Tottenham
    unlockStars: 20,
  ),
  BuildXiTheme(
    id: 'milan_derby',
    name: 'Milano Derbisi',
    description: 'Milan veya Inter geçmişi olanlar',
    poolType: BuildXiPoolType.clubUnion,
    category: BuildXiCategory.rivalries,
    clubPairIds: [5, 46], // Milan, Inter
    unlockStars: 20,
  ),
  BuildXiTheme(
    id: 'der_klassiker',
    name: 'Der Klassiker',
    description: 'Bayern veya Dortmund geçmişi olanlar',
    poolType: BuildXiPoolType.clubUnion,
    category: BuildXiCategory.rivalries,
    clubPairIds: [27, 16], // Bayern, Dortmund
    unlockStars: 20,
  ),
  BuildXiTheme(
    id: 'le_classique',
    name: 'Le Classique',
    description: 'PSG veya Marseille geçmişi olanlar',
    poolType: BuildXiPoolType.clubUnion,
    category: BuildXiCategory.rivalries,
    clubPairIds: [583, 244], // PSG, Marseille
    unlockStars: 20,
  ),
  BuildXiTheme(
    id: 'roma_lazio',
    name: 'Derby della Capitale',
    description: 'Roma veya Lazio geçmişi olanlar',
    poolType: BuildXiPoolType.clubUnion,
    category: BuildXiCategory.rivalries,
    clubPairIds: [12, 398], // Roma, Lazio
    unlockStars: 20,
  ),
  BuildXiTheme(
    id: 'napoli_juve',
    name: 'Napoli – Juventus',
    description: 'Napoli veya Juventus geçmişi olanlar',
    poolType: BuildXiPoolType.clubUnion,
    category: BuildXiCategory.rivalries,
    clubPairIds: [6195, 506], // Napoli, Juventus
    unlockStars: 20,
  ),
  BuildXiTheme(
    id: 'old_firm',
    name: 'Old Firm',
    description: 'Celtic veya Rangers geçmişi olanlar',
    poolType: BuildXiPoolType.clubUnion,
    category: BuildXiCategory.rivalries,
    clubPairIds: [371, 124], // Celtic, Rangers
    unlockStars: 20,
  ),
  BuildXiTheme(
    id: 'superclasico',
    name: 'Superclásico',
    description: 'Boca Juniors veya River Plate geçmişi olanlar',
    poolType: BuildXiPoolType.clubUnion,
    category: BuildXiCategory.rivalries,
    clubPairIds: [189, 209], // Boca, River
    unlockStars: 20,
  ),
  BuildXiTheme(
    id: 'merseyside',
    name: 'Merseyside',
    description: 'Liverpool veya Everton geçmişi olanlar',
    poolType: BuildXiPoolType.clubUnion,
    category: BuildXiCategory.rivalries,
    clubPairIds: [31, 29], // Liverpool, Everton
    unlockStars: 20,
  ),

  // Türk Derbileri
  BuildXiTheme(
    id: 'gs_fb',
    name: 'Galatasaray – Fenerbahçe',
    description: 'GS veya FB geçmişi olanlar',
    poolType: BuildXiPoolType.clubUnion,
    category: BuildXiCategory.rivalries,
    clubPairIds: [141, 36], // Galatasaray, Fenerbahce
    unlockStars: 20,
  ),
  BuildXiTheme(
    id: 'bjk_gs',
    name: 'Beşiktaş – Galatasaray',
    description: 'BJK veya GS geçmişi olanlar',
    poolType: BuildXiPoolType.clubUnion,
    category: BuildXiCategory.rivalries,
    clubPairIds: [114, 141], // Besiktas, Galatasaray
    unlockStars: 20,
  ),
  BuildXiTheme(
    id: 'bjk_fb',
    name: 'Beşiktaş – Fenerbahçe',
    description: 'BJK veya FB geçmişi olanlar',
    poolType: BuildXiPoolType.clubUnion,
    category: BuildXiCategory.rivalries,
    clubPairIds: [114, 36], // Besiktas, Fenerbahce
    unlockStars: 20,
  ),
  BuildXiTheme(
    id: 'ts_gs',
    name: 'Trabzonspor – Galatasaray',
    description: 'Trabzonspor veya GS geçmişi olanlar',
    poolType: BuildXiPoolType.clubUnion,
    category: BuildXiCategory.rivalries,
    clubPairIds: [449, 141], // Trabzonspor, Galatasaray
    unlockStars: 20,
  ),
  BuildXiTheme(
    id: 'ts_fb',
    name: 'Trabzonspor – Fenerbahçe',
    description: 'Trabzonspor veya FB geçmişi olanlar',
    poolType: BuildXiPoolType.clubUnion,
    category: BuildXiCategory.rivalries,
    clubPairIds: [449, 36], // Trabzonspor, Fenerbahce
    unlockStars: 20,
  ),
  BuildXiTheme(
    id: 'ts_bjk',
    name: 'Trabzonspor – Beşiktaş',
    description: 'Trabzonspor veya BJK geçmişi olanlar',
    poolType: BuildXiPoolType.clubUnion,
    category: BuildXiCategory.rivalries,
    clubPairIds: [449, 114], // Trabzonspor, Besiktas
    unlockStars: 20,
  ),

  // ═══════════════════════════════════════════════
  // ÖZEL / HARD
  // ═══════════════════════════════════════════════
  BuildXiTheme(
    id: 'passportless',
    name: 'Pasaportsuzlar',
    description: 'Aynı ülkeden iki oyuncu olamaz — tüm dünyadan seç',
    poolType: BuildXiPoolType.all,
    category: BuildXiCategory.special,
    uniqueNationalityRule: true,
    unlockStars: 0,
  ),
  BuildXiTheme(
    id: 'wanderers',
    name: 'Wanderers',
    description: 'Kariyerinde 5 veya daha fazla kulüpte oynamış oyuncular',
    poolType: BuildXiPoolType.all,
    category: BuildXiCategory.special,
    minClubs: 5,
    unlockStars: 30,
  ),
];

// Yardımcı
List<BuildXiTheme> themesByCategory(BuildXiCategory cat) =>
    buildXiThemes.where((t) => t.category == cat).toList();
