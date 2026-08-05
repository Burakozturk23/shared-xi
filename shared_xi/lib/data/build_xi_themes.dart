enum BuildXiPoolType { league, region, all, clubPair }

class BuildXiTheme {
  final String id;
  final String name;
  final String description;
  final BuildXiPoolType poolType;
  final String? leagueName;
  final List<String>? countries;
  final List<int>? clubPairIds;
  final bool uniqueNationalityRule;

  const BuildXiTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.poolType,
    this.leagueName,
    this.countries,
    this.clubPairIds,
    this.uniqueNationalityRule = false,
  });
}

const List<String> southAmericaCountries = [
  'Brazil', 'Argentina', 'Uruguay', 'Colombia', 'Chile',
  'Paraguay', 'Peru', 'Ecuador', 'Venezuela', 'Bolivia',
];

const List<String> balkanCountries = [
  'Serbia', 'Croatia', 'Bosnia-Herzegovina', 'Albania',
  'North Macedonia', 'Montenegro', 'Slovenia', 'Kosovo',
  'Bulgaria', 'Romania',
];

const List<BuildXiTheme> buildXiThemes = [
  BuildXiTheme(
    id: 'premier_league',
    name: 'Premier League',
    description: 'Sadece Premier League geçmişi olan oyuncular',
    poolType: BuildXiPoolType.league,
    leagueName: 'Premier League',
  ),
  BuildXiTheme(
    id: 'laliga',
    name: 'LaLiga',
    description: 'Sadece LaLiga geçmişi olan oyuncular',
    poolType: BuildXiPoolType.league,
    leagueName: 'LaLiga',
  ),
  BuildXiTheme(
    id: 'serie_a',
    name: 'Serie A',
    description: 'Sadece Serie A geçmişi olan oyuncular',
    poolType: BuildXiPoolType.league,
    leagueName: 'Serie A',
  ),
  BuildXiTheme(
    id: 'bundesliga',
    name: 'Bundesliga',
    description: 'Sadece Bundesliga geçmişi olan oyuncular',
    poolType: BuildXiPoolType.league,
    leagueName: 'Bundesliga',
  ),
  BuildXiTheme(
    id: 'ligue_1',
    name: 'Ligue 1',
    description: 'Sadece Ligue 1 geçmişi olan oyuncular',
    poolType: BuildXiPoolType.league,
    leagueName: 'Ligue 1',
  ),
  BuildXiTheme(
    id: 'south_america',
    name: 'Güney Amerika',
    description: 'Sadece Güney Amerikalı oyuncular',
    poolType: BuildXiPoolType.region,
    countries: southAmericaCountries,
  ),
  BuildXiTheme(
    id: 'balkan_power',
    name: 'Balkan Gücü',
    description: 'Sadece Balkan ülkelerinden oyuncular',
    poolType: BuildXiPoolType.region,
    countries: balkanCountries,
  ),
  BuildXiTheme(
    id: 'passportless',
    name: 'Pasaportsuzlar',
    description: 'Aynı ülkeden iki oyuncu olamaz — tüm dünyadan seç',
    poolType: BuildXiPoolType.all,
    uniqueNationalityRule: true,
  ),
  BuildXiTheme(
    id: 'milan_derby',
    name: 'Milano: Milan - Inter',
    description: 'Bu iki kulüpte oynamış oyunculardan kur',
    poolType: BuildXiPoolType.clubPair,
    clubPairIds: [5, 46],
  ),
  BuildXiTheme(
    id: 'istanbul_derby',
    name: 'İstanbul: Fenerbahçe - Beşiktaş',
    description: 'Bu iki kulüpte oynamış oyunculardan kur',
    poolType: BuildXiPoolType.clubPair,
    clubPairIds: [36, 114],
  ),
  BuildXiTheme(
    id: 'karadeniz_derby',
    name: 'Trabzonspor - Beşiktaş',
    description: 'Bu iki kulüpte oynamış oyunculardan kur',
    poolType: BuildXiPoolType.clubPair,
    clubPairIds: [449, 114],
  ),
  BuildXiTheme(
    id: 'napoli_juve',
    name: 'Napoli - Juventus',
    description: 'Bu iki kulüpte oynamış oyunculardan kur',
    poolType: BuildXiPoolType.clubPair,
    clubPairIds: [6195, 506],
  ),
];