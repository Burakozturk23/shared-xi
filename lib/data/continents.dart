enum Continent { europe, southAmerica, northAmerica, africa, asia, oceania }

const Map<String, Continent> countryContinents = {
  'England': Continent.europe, 'France': Continent.europe, 'Germany': Continent.europe,
  'Spain': Continent.europe, 'Italy': Continent.europe, 'Portugal': Continent.europe,
  'Netherlands': Continent.europe, 'Belgium': Continent.europe, 'Croatia': Continent.europe,
  'Serbia': Continent.europe, 'Poland': Continent.europe, 'Sweden': Continent.europe,
  'Denmark': Continent.europe, 'Switzerland': Continent.europe, 'Austria': Continent.europe,
  'Wales': Continent.europe, 'Scotland': Continent.europe, 'Türkiye': Continent.europe,
  'Ukraine': Continent.europe, 'Russia': Continent.europe, 'Norway': Continent.europe,
  'Bosnia-Herzegovina': Continent.europe, 'Albania': Continent.europe,
  'North Macedonia': Continent.europe, 'Montenegro': Continent.europe,
  'Slovenia': Continent.europe, 'Kosovo': Continent.europe, 'Bulgaria': Continent.europe,
  'Romania': Continent.europe, 'Greece': Continent.europe, 'Hungary': Continent.europe,
  'Czech Republic': Continent.europe, 'Slovakia': Continent.europe, 'Ireland': Continent.europe,
  'Finland': Continent.europe, 'Iceland': Continent.europe,

  'Brazil': Continent.southAmerica, 'Argentina': Continent.southAmerica,
  'Uruguay': Continent.southAmerica, 'Colombia': Continent.southAmerica,
  'Chile': Continent.southAmerica, 'Paraguay': Continent.southAmerica,
  'Peru': Continent.southAmerica, 'Ecuador': Continent.southAmerica,
  'Venezuela': Continent.southAmerica, 'Bolivia': Continent.southAmerica,

  'United States': Continent.northAmerica, 'Mexico': Continent.northAmerica,
  'Canada': Continent.northAmerica, 'Jamaica': Continent.northAmerica,
  'Costa Rica': Continent.northAmerica,

  'Nigeria': Continent.africa, 'Senegal': Continent.africa, 'Morocco': Continent.africa,
  'Egypt': Continent.africa, 'Ghana': Continent.africa, 'Algeria': Continent.africa,
  'Ivory Coast': Continent.africa, 'Cameroon': Continent.africa, 'Tunisia': Continent.africa,
  'South Africa': Continent.africa, 'Mali': Continent.africa,

  'Japan': Continent.asia, 'South Korea': Continent.asia, 'Saudi Arabia': Continent.asia,
  'Iran': Continent.asia, 'Qatar': Continent.asia, 'China': Continent.asia,

  'Australia': Continent.oceania,
};

Continent? continentOf(String country) => countryContinents[country];