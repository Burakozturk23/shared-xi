class Derby {
  final int clubIdA;
  final int clubIdB;
  final String label;

  const Derby(this.clubIdA, this.clubIdB, this.label);
}

class DerbyCountry {
  final String name;
  final List<Derby> derbies;

  const DerbyCountry(this.name, this.derbies);
}

// IDs are shared with the V2 catalog; questions live in the redacted asset.
const List<DerbyCountry> derbyCountries = [
  DerbyCountry('Türkiye', [
    Derby(114, 141, 'Beşiktaş – Galatasaray'),
    Derby(36, 141, 'Fenerbahçe – Galatasaray'),
    Derby(114, 36, 'Beşiktaş – Fenerbahçe'),
    Derby(1467, 2375, 'Göztepe – Altay'),
    Derby(1467, 2330, 'Göztepe – Karşıyaka'),
    Derby(2375, 2330, 'Altay – Karşıyaka'),
    Derby(868, 820, 'Ankaragücü – Gençlerbirliği'),
    Derby(449, 36, 'Trabzonspor – Fenerbahçe'),
    Derby(449, 141, 'Trabzonspor – Galatasaray'),
    Derby(449, 114, 'Trabzonspor – Beşiktaş'),
    Derby(3840, 6, 'Adana Demirspor – Adanaspor'),
    Derby(120, 2463, 'Kocaelispor – Sakaryaspor'),
  ]),
  DerbyCountry('İngiltere', [
    Derby(31, 985, 'Liverpool – Manchester United'),
    Derby(985, 281, 'Manchester United – Manchester City'),
    Derby(11, 148, 'Arsenal – Tottenham'),
    Derby(31, 29, 'Liverpool – Everton'),
    Derby(631, 11, 'Chelsea – Arsenal'),
    Derby(631, 148, 'Chelsea – Tottenham'),
    Derby(11, 985, 'Arsenal – Manchester United'),
    Derby(31, 631, 'Liverpool – Chelsea'),
  ]),
  DerbyCountry('İspanya', [
    Derby(418, 131, 'Real Madrid – Barcelona'),
    Derby(13, 418, 'Atlético Madrid – Real Madrid'),
    Derby(368, 150, 'Sevilla – Real Betis'),
  ]),
  DerbyCountry('İtalya', [
    Derby(5, 46, 'Milan – Inter'),
    Derby(506, 46, 'Juventus – Inter'),
    Derby(12, 398, 'Roma – Lazio'),
    Derby(506, 5, 'Juventus – Milan'),
    Derby(506, 6195, 'Juventus – Napoli'),
    Derby(506, 416, 'Juventus – Torino'),
    Derby(252, 1038, 'Genoa – Sampdoria'),
  ]),
  DerbyCountry('Almanya', [
    Derby(27, 16, 'Bayern Münih – Borussia Dortmund'),
    Derby(16, 33, 'Borussia Dortmund – Schalke 04'),
  ]),
  DerbyCountry('Fransa', [
    Derby(583, 244, 'Paris Saint-Germain – Marseille'),
  ]),
  DerbyCountry('Hollanda', [
    Derby(610, 234, 'Ajax – Feyenoord'),
  ]),
  DerbyCountry('Portekiz', [
    Derby(294, 720, 'Benfica – Porto'),
    Derby(336, 294, 'Sporting – Benfica'),
    Derby(336, 720, 'Sporting – Porto'),
  ]),
  DerbyCountry('Yunanistan', [
    Derby(683, 265, 'Olympiacos – Panathinaikos'),
  ]),
  DerbyCountry('Belçika', [
    Derby(58, 3057, 'Anderlecht – Standard Liège'),
  ]),
  DerbyCountry('İskoçya', [
    Derby(371, 124, 'Celtic – Rangers'),
  ]),
  DerbyCountry('Brezilya', [
    Derby(614, 2462, 'Flamengo – Fluminense'),
    Derby(199, 1023, 'Corinthians – Palmeiras'),
    Derby(210, 6600, 'Grêmio – Internacional'),
  ]),
  DerbyCountry('Arjantin', [
    Derby(189, 209, 'Boca Juniors – River Plate'),
    Derby(1418, 1286, 'Rosario Central – Newell’s Old Boys'),
  ]),
  DerbyCountry('Sırbistan', [
    Derby(159, 669, 'Kızılyıldız – Partizan'),
  ]),
  DerbyCountry('Uruguay', [
    Derby(1000000861, 1000000866, 'Peñarol – Nacional'),
  ]),
  DerbyCountry('Meksika', [
    Derby(3631, 6711, 'Club América – Chivas'),
  ]),
];
