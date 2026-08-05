class PopularClubClubMatchup {
  final int clubId1;
  final int clubId2;
  final String label;

  const PopularClubClubMatchup(this.clubId1, this.clubId2, this.label);
}

class PopularClubCountryMatchup {
  final int clubId;
  final String country;
  final String label;

  const PopularClubCountryMatchup(this.clubId, this.country, this.label);
}

const List<PopularClubClubMatchup> popularClubClubMatchups = [
  PopularClubClubMatchup(418, 131, 'El Clásico'),
  PopularClubClubMatchup(985, 31, 'Man United - Liverpool'),
  PopularClubClubMatchup(27, 506, 'Bayern - Juventus'),
  PopularClubClubMatchup(583, 281, 'PSG - Man City'),
  PopularClubClubMatchup(631, 11, 'Chelsea - Arsenal'),
  PopularClubClubMatchup(5, 46, 'Milano Derbisi'),
  PopularClubClubMatchup(13, 418, 'Madrid Derbisi'),
  PopularClubClubMatchup(16, 27, 'Der Klassiker'),
];

const List<PopularClubCountryMatchup> popularClubCountryMatchups = [
  PopularClubCountryMatchup(131, 'Brazil', 'Barcelona - Brezilya'),
  PopularClubCountryMatchup(418, 'France', 'Real Madrid - Fransa'),
  PopularClubCountryMatchup(985, 'England', 'Man United - İngiltere'),
  PopularClubCountryMatchup(27, 'Germany', 'Bayern - Almanya'),
  PopularClubCountryMatchup(506, 'Italy', 'Juventus - İtalya'),
  PopularClubCountryMatchup(583, 'Argentina', 'PSG - Arjantin'),
  PopularClubCountryMatchup(31, 'Portugal', 'Liverpool - Portekiz'),
  PopularClubCountryMatchup(281, 'Uruguay', 'Man City - Uruguay'),
];