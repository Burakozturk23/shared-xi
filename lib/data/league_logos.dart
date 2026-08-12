/// Lig adı → asset. Eşleşme normalize + alias ile yapılır.
const Map<String, String> _leagueLogoByKey = {
  'premier league': 'assets/logos/leagues/premier_league.png',
  'epl': 'assets/logos/leagues/premier_league.png',
  'laliga': 'assets/logos/leagues/laliga.png',
  'la liga': 'assets/logos/leagues/laliga.png',
  'serie a': 'assets/logos/leagues/serie_a.png',
  'bundesliga': 'assets/logos/leagues/bundesliga.png',
  'ligue 1': 'assets/logos/leagues/ligue_1.png',
  'süper lig': 'assets/logos/leagues/super_lig.png',
  'super lig': 'assets/logos/leagues/super_lig.png',
  'trendyol süper lig': 'assets/logos/leagues/super_lig.png',
  'eredivisie': 'assets/logos/leagues/eredivisie.png',
  'liga portugal': 'assets/logos/leagues/liga_portugal.png',
  'liga portugal 2': 'assets/logos/leagues/liga_portugal.png',
  'primeira liga': 'assets/logos/leagues/liga_portugal.png',
  'liga nos': 'assets/logos/leagues/liga_portugal.png',
  'scottish premiership': 'assets/logos/leagues/scottish_premiership.png',
  'belgian pro league': 'assets/logos/leagues/belgian_pro_league.png',
  'jupiler pro league': 'assets/logos/leagues/belgian_pro_league.png',
  'championship': 'assets/logos/leagues/championship.png',
  'efl championship': 'assets/logos/leagues/championship.png',
  'serie b': 'assets/logos/leagues/serie_b.png',
  '2. bundesliga': 'assets/logos/leagues/2_bundesliga.png',
  '2 bundesliga': 'assets/logos/leagues/2_bundesliga.png',
  'ligue 2': 'assets/logos/leagues/ligue_2.png',
  'laliga2': 'assets/logos/leagues/laliga2.png',
  'la liga 2': 'assets/logos/leagues/laliga2.png',
  'laliga hypermotion': 'assets/logos/leagues/laliga2.png',
  'mls': 'assets/logos/leagues/mls.png',
  'major league soccer': 'assets/logos/leagues/mls.png',
  'saudi pro league': 'assets/logos/leagues/saudi_pro_league.png',
  'uefa champions league': 'assets/logos/leagues/ucl.png',
  'champions league': 'assets/logos/leagues/ucl.png',
  'uefa europa league': 'assets/logos/leagues/uel.png',
  'europa league': 'assets/logos/leagues/uel.png',
};

String _normLeague(String s) {
  var t = s.trim().toLowerCase();
  t = t.replaceAll('ü', 'u').replaceAll('ı', 'i').replaceAll('ş', 's');
  t = t.replaceAll(RegExp(r'\s+'), ' ');
  return t;
}

String? leagueLogoAsset(String league) {
  final key = _normLeague(league);
  if (_leagueLogoByKey.containsKey(key)) return _leagueLogoByKey[key];

  // Kısmi eşleşme: "Premier League 2024" vb.
  for (final e in _leagueLogoByKey.entries) {
    if (key.contains(e.key) || e.key.contains(key)) return e.value;
  }
  return null;
}

String leagueShortName(String league) {
  final key = _normLeague(league);
  const shorts = {
    'premier league': 'EPL',
    'laliga': 'LaLiga',
    'la liga': 'LaLiga',
    'serie a': 'Serie A',
    'bundesliga': 'BL',
    'ligue 1': 'L1',
    'süper lig': 'SL',
    'super lig': 'SL',
    'eredivisie': 'Ered',
    'liga portugal': 'Liga PT',
    'liga portugal 2': 'Liga PT2',
    'primeira liga': 'Liga PT',
    'championship': 'Champ',
    'ligue 2': 'L2',
    'serie b': 'SB',
  };
  return shorts[key] ?? league.trim();
}