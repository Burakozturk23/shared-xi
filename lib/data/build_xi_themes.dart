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
const List<String> scandinaviaCountries = [
  'Denmark', 'Sweden', 'Norway', 'Finland', 'Iceland',
];

const List<String> africanCountries = [
  'Senegal', 'Nigeria', 'Morocco', 'Cameroon', 'Ivory Coast',
  'Ghana', 'Egypt', 'Mali', 'Algeria', 'Tunisia',
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
    id: 'super_lig',
    name: 'Türkiye Süper Lig',
    description: 'Süper Lig\'de oynamış oyunculardan 11\'ini kur',
    poolType: BuildXiPoolType.league,
    leagueName: 'Süper Lig',
  ),
  BuildXiTheme(
  id: 'eredivisie',
  name: 'Eredivisie',
  description: 'Eredivisie\'de oynamış oyunculardan 11 kur',
  poolType: BuildXiPoolType.league,
  leagueName: 'Eredivisie',
),
BuildXiTheme(
  id: 'liga_portugal',
  name: 'Liga Portugal',
  description: 'Portekiz liginde oynamış oyunculardan 11 kur',
  poolType: BuildXiPoolType.league,
  leagueName: 'Liga Portugal', // veya 'Primeira Liga' – veride hangisi varsa
),
BuildXiTheme(
  id: 'scandinavia',
  name: 'İskandinav Rüzgarı',
  description: 'Sadece İskandinav ülkelerinden oyuncular',
  poolType: BuildXiPoolType.region,
  countries: scandinaviaCountries,
),
BuildXiTheme(
  id: 'africa',
  name: 'Afrika Gücü',
  description: 'Sadece Afrikalı oyunculardan 11 kur',
  poolType: BuildXiPoolType.region,
  countries: africanCountries,
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
  id: 'el_clasico',
  name: 'El Clásico: Real Madrid – Barcelona',
  description: 'Bu iki kulüpte oynamış oyunculardan kur',
  poolType: BuildXiPoolType.clubPair,
  clubPairIds: [418, 131],
),
BuildXiTheme(
  id: 'manchester_derby',
  name: 'Manchester Derbisi: United – City',
  description: 'Bu iki kulüpte oynamış oyunculardan kur',
  poolType: BuildXiPoolType.clubPair,
  clubPairIds: [985, 281],
),
BuildXiTheme(
  id: 'north_london',
  name: 'Kuzey Londra: Arsenal – Tottenham',
  description: 'Bu iki kulüpte oynamış oyunculardan kur',
  poolType: BuildXiPoolType.clubPair,
  clubPairIds: [11, 148],
),
BuildXiTheme(
  id: 'le_classique',
  name: 'Le Classique: PSG – Marseille',
  description: 'Bu iki kulüpte oynamış oyunculardan kur',
  poolType: BuildXiPoolType.clubPair,
  clubPairIds: [583, 244],
),
BuildXiTheme(
  id: 'der_klassiker',
  name: 'Der Klassiker: Bayern – Dortmund',
  description: 'Bu iki kulüpte oynamış oyunculardan kur',
  poolType: BuildXiPoolType.clubPair,
  clubPairIds: [27, 16],
),
BuildXiTheme(
  id: 'roma_lazio',
  name: 'Derby della Capitale: Roma – Lazio',
  description: 'Bu iki kulüpte oynamış oyunculardan kur',
  poolType: BuildXiPoolType.clubPair,
  clubPairIds: [12, 398],
),
  BuildXiTheme(
    id: 'milan_derby',
    name: 'Milano: Milan - Inter',
    description: 'Bu iki kulüpte oynamış oyunculardan kur',
    poolType: BuildXiPoolType.clubPair,
    clubPairIds: [5, 46],
  ),
  BuildXiTheme(
    id: 'napoli_juve',
    name: 'Napoli - Juventus',
    description: 'Bu iki kulüpte oynamış oyunculardan kur',
    poolType: BuildXiPoolType.clubPair,
    clubPairIds: [6195, 506],
  ),
];