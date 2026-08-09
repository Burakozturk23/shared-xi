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

const List<DerbyCountry> derbyCountries = [
  DerbyCountry('Türkiye', [
    Derby(114, 141, 'Beşiktaş 🆚 Galatasaray'),
    Derby(36, 141, 'Fenerbahçe 🆚 Galatasaray (Kıtalararası Derbi)'),
    Derby(114, 36, 'Beşiktaş 🆚 Fenerbahçe'),
    Derby(1467, 2375,'Göztepe 🆚 Altay'),
    Derby(1467, 2330,'Göztepe 🆚 Karşıyaka (İzmir Derbisi)'),
    Derby(2375, 2330,'Altay 🆚 Karşıyaka (Cumhuriyet Derbisi)'),
    Derby(868, 820,'Ankaragücü vs Gençlerbirliği (Ankara Derbisi)'),
    Derby(449, 36, 'Trabzonspor 🆚 Fenerbahçe'),
    Derby(449, 141, 'Trabzonspor 🆚 Galatasaray'),
    Derby(449, 114, 'Trabzonspor 🆚 Beşiktaş'),
  ]),
  DerbyCountry('İngiltere', [
    Derby(31, 985, 'Liverpool 🆚 Manchester United'),
    Derby(985, 281, 'Manchester United 🆚 Manchester City (Manchester Derby)'),
    Derby(11, 148, 'Arsenal 🆚 Tottenham (North London Derby)'),
    Derby(31, 29, 'Liverpool 🆚 Everton'),
    Derby(631, 11, 'Chelsea 🆚 Arsenal'),
    Derby(631, 148, 'Chelsea 🆚 Tottenham'),
    Derby(11, 985, 'Arsenal 🆚 Manchester United'),
    Derby(31, 631, 'Liverpool 🆚 Chelsea'),
  ]),
  DerbyCountry('İspanya', [
    Derby(418, 131, 'Real Madrid 🆚 Barcelona (El Clásico)'),
    Derby(13, 418, 'Atlético Madrid 🆚 Real Madrid'),
    Derby(368, 150, 'Sevilla FC 🆚 Real Betis (El Gran Derbi)'),
  ]),
  DerbyCountry('İtalya', [
    Derby(5, 46, 'Milan 🆚 Inter (Derby della Madonnina)'),
    Derby(506, 46, 'Juventus 🆚 Inter (Derby d-italia'),
    Derby(12, 398, 'Roma 🆚 Lazio (Derby della Capitale)'),
    Derby(506, 5, 'Juventus 🆚 Milan'),
    Derby(506, 6195, 'Juventus 🆚 Napoli'),
    Derby(506, 416, 'Juventus 🆚 Torino'),
  ]),
  DerbyCountry('Almanya', [
    Derby(27, 16, 'Bayern Münih 🆚 Borussia Dortmund'),
    Derby(16, 33, 'Borussia Dortmund 🆚 Schalke 04 (Revierderby)'),
  ]),
  DerbyCountry('Fransa', [
    Derby(583, 244, 'PSG 🆚 Marseille (Le Classique)'),
  ]),
  DerbyCountry('Hollanda', [
    Derby(610, 234, 'Ajax 🆚 Feyenoord (De Klassieker)'),
  ]),
  DerbyCountry('Portekiz', [
    Derby(294, 720, 'Benfica 🆚 Porto (O Clássico - Portekiz)'),
    Derby(336, 294, 'Sporting 🆚 Benfica (Derby de Lisboa)'),
    Derby(336, 720, 'Sporting 🆚 Porto'),
  ]),
  DerbyCountry('Yunanistan', [
    Derby(683, 265, 'Olympiakos 🆚 Panathinaikos (Derby of the Eternal Enemies)'),
  ]),
  DerbyCountry('Belçika', [
    Derby(58, 3057, 'Anderlecht vs Standard Liège'),
  ]),
  DerbyCountry('İskoçya', [
    Derby(371, 124, 'Celtic 🆚 Rangers (Old Firm)'),
  ]),
  DerbyCountry('Brezilya', [
    Derby(614, 2462, 'Flamengo 🆚 Fluminense (Fla-Flu)'),
    Derby(199, 1023, 'Corinthians vs Palmeiras (Derbi Paulista)'),
  ]),
  DerbyCountry('Arjantin', [
    Derby(189, 209, 'Boca Juniors vs River Plate (Superclásico)'),
  ]),
];