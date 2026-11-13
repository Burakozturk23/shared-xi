import '../models/bracket_candidate.dart';

/// Kulüp vs Kulüp — Bölüm 1
/// Şampiyonlar Ligi Devleri & Avrupa Hanedanlıkları
/// 32 düello → 64 kulüp-sezonu adayı, 63 karar.
class UclDynasties64Data {
  UclDynasties64Data._();

  static const String bracketId = 'ucl_dynasties_64';

  static const BracketDefinition definition = BracketDefinition(
    id: bracketId,
    title: 'Şampiyonlar Ligi Devleri & Avrupa Hanedanlıkları',
    subtitle: 'UCL Dynasties 64',
    description:
        'Treble yapanlar, mucize finalistler, nostaljik hanedanlıklar. Hangi kulüp-sezonu daha büyük?',
    meta: '64 aday · 63 karar · Kulüp zirve sezonları',
    emoji: '🏆',
    seeds: seeds,
  );

  static const List<BracketCandidate> seeds = [
    BracketCandidate(id: 'real_madrid_16_17_a1', name: 'Real Madrid', badge: '16/17', highlight: 'Üst Üste 2. UCL & La Liga Dublesi'),
    BracketCandidate(id: 'barcelona_10_11_b1', name: 'Barcelona', badge: '10/11', highlight: 'Pep\'in Zirve Set Oyunu / UCL Şampiyonu'),
    BracketCandidate(id: 'bayern_munih_12_13_a2', name: 'Bayern Münih', badge: '12/13', highlight: 'Jupp Heynckes Treble'),
    BracketCandidate(id: 'inter_09_10_b2', name: 'Inter', badge: '09/10', highlight: 'Mourinho Treble'),
    BracketCandidate(id: 'manchester_city_22_23_a3', name: 'Manchester City', badge: '22/23', highlight: 'Pep Guardiola Treble'),
    BracketCandidate(id: 'liverpool_19_20_b3', name: 'Liverpool', badge: '19/20', highlight: '99 Puanlı Premier Lig Şampiyonu'),
    BracketCandidate(id: 'ac_milan_06_07_a4', name: 'AC Milan', badge: '06/07', highlight: 'Atina Rövanşı & Kaká Zirvesi'),
    BracketCandidate(id: 'chelsea_04_05_b4', name: 'Chelsea', badge: '04/05', highlight: 'Mourinho\'nun 15 Gol Yiyen Rekor Takımı'),
    BracketCandidate(id: 'paris_saint_germain_19_20_a5', name: 'Paris Saint-Germain', badge: '19/20', highlight: 'UCL Finalisti / Fransa Üçlemesi'),
    BracketCandidate(id: 'atletico_madrid_13_14_b5', name: 'Atlético Madrid', badge: '13/14', highlight: 'Simeone Mucize La Liga & UCL Finalisti'),
    BracketCandidate(id: 'borussia_dortmund_12_13_a6', name: 'Borussia Dortmund', badge: '12/13', highlight: 'Klopp\'un Wembley Finalistleri'),
    BracketCandidate(id: 'monaco_16_17_b6', name: 'Monaco', badge: '16/17', highlight: 'Mbappé & Falcao\'lu Yarı Finalist'),
    BracketCandidate(id: 'ajax_18_19_a7', name: 'Ajax', badge: '18/19', highlight: 'Genç Büyücüler & Bernabéu Baskını'),
    BracketCandidate(id: 'tottenham_18_19_b7', name: 'Tottenham', badge: '18/19', highlight: 'Pochettino UCL Finalisti'),
    BracketCandidate(id: 'juventus_16_17_a8', name: 'Juventus', badge: '16/17', highlight: 'Cardiff Finalisti & İtalya Dominasyonu'),
    BracketCandidate(id: 'arsenal_03_04_b8', name: 'Arsenal', badge: '03/04', highlight: 'Invincibles / Namaglup Şampiyon'),
    BracketCandidate(id: 'manchester_united_07_08_a9', name: 'Manchester United', badge: '07/08', highlight: 'Ronaldo, Tevez, Rooney\'li Moskova Şampiyonu'),
    BracketCandidate(id: 'porto_03_04_b9', name: 'Porto', badge: '03/04', highlight: 'Mourinho ile Avrupa Krallığı'),
    BracketCandidate(id: 'lyon_09_10_a10', name: 'Lyon', badge: '09/10', highlight: 'Bernabéu Zaferi & UCL Yarı Finalisti'),
    BracketCandidate(id: 'villarreal_20_21_b10', name: 'Villarreal', badge: '20/21', highlight: 'Unai Emery UEFA Şampiyonu'),
    BracketCandidate(id: 'roma_17_18_a11', name: 'Roma', badge: '17/18', highlight: 'Barça Mucize Geri Dönüşü & UCL Yarı Finali'),
    BracketCandidate(id: 'atalanta_19_20_b11', name: 'Atalanta', badge: '19/20', highlight: 'Gasperini 98 Gol Makineleri'),
    BracketCandidate(id: 'benfica_13_14_a12', name: 'Benfica', badge: '13/14', highlight: 'Portekiz Üçlemesi & UEFA Finalisti'),
    BracketCandidate(id: 'sevilla_15_16_b12', name: 'Sevilla', badge: '15/16', highlight: 'Üst Üste 3. UEFA Kupası'),
    BracketCandidate(id: 'rb_leipzig_19_20_a13', name: 'RB Leipzig', badge: '19/20', highlight: 'Nagelsmann ile UCL Yarı Finali'),
    BracketCandidate(id: 'eintracht_frankfurt_21_22_b13', name: 'Eintracht Frankfurt', badge: '21/22', highlight: 'Yenilgisiz UEFA Şampiyonluğu'),
    BracketCandidate(id: 'valencia_00_01_a14', name: 'Valencia', badge: '00/01', highlight: 'Cúper ile Üst Üste UCL Finali'),
    BracketCandidate(id: 'bayer_leverkusen_01_02_b14', name: 'Bayer Leverkusen', badge: '01/02', highlight: 'Üç İkincilikli Efsane Kadro'),
    BracketCandidate(id: 'celtic_02_03_a15', name: 'Celtic', badge: '02/03', highlight: 'Seville UEFA Finalisti Kadro'),
    BracketCandidate(id: 'rangers_21_22_b15', name: 'Rangers', badge: '21/22', highlight: 'Avrupa Ligi Finalisti'),
    BracketCandidate(id: 'shakhtar_donetsk_08_09_a16', name: 'Shakhtar Donetsk', badge: '08/09', highlight: 'Son UEFA Kupası Şampiyonu'),
    BracketCandidate(id: 'zenit_07_08_b16', name: 'Zenit', badge: '07/08', highlight: 'UEFA & Süper Kupa Zaferi'),
    BracketCandidate(id: 'ajax_94_95_a17', name: 'Ajax', badge: '94/95', highlight: 'Van Gaal\'in Yenilgisiz Genç UCL Şampiyonu'),
    BracketCandidate(id: 'ac_milan_88_89_b17', name: 'AC Milan', badge: '88/89', highlight: 'Sacchi\'nin Efsane Rüya Takımı'),
    BracketCandidate(id: 'manchester_united_98_99_a18', name: 'Manchester United', badge: '98/99', highlight: 'Camp Nou Treble Mucizesi'),
    BracketCandidate(id: 'bayern_munih_00_01_b18', name: 'Bayern Münih', badge: '00/01', highlight: 'Kahn\'lı UCL Şampiyonluğu'),
    BracketCandidate(id: 'liverpool_04_05_a19', name: 'Liverpool', badge: '04/05', highlight: 'İstanbul Mucizesi Şampiyonu'),
    BracketCandidate(id: 'chelsea_11_12_b19', name: 'Chelsea', badge: '11/12', highlight: 'Allianz Arena Mucize UCL Şampiyonu'),
    BracketCandidate(id: 'barcelona_08_09_a20', name: 'Barcelona', badge: '08/09', highlight: 'Pep\'in 6 Kupalı Tarihi Sezonu'),
    BracketCandidate(id: 'real_madrid_13_14_b20', name: 'Real Madrid', badge: '13/14', highlight: 'Ancelotti ile La Décima / 10. UCL'),
    BracketCandidate(id: 'inter_97_98_a21', name: 'Inter', badge: '97/98', highlight: 'Ronaldo R9 Sürüklemeli UEFA Şampiyonu'),
    BracketCandidate(id: 'parma_98_99_b21', name: 'Parma', badge: '98/99', highlight: 'UEFA Kupası & İtalya Kupası Zaferi'),
    BracketCandidate(id: 'marseille_92_93_a22', name: 'Marseille', badge: '92/93', highlight: 'İlk UCL Şampiyonu Fransız Dev'),
    BracketCandidate(id: 'red_star_belgrade_90_91_b22', name: 'Red Star Belgrade', badge: '90/91', highlight: 'Şampiyon Kulüpler Kupası Şampiyonu'),
    BracketCandidate(id: 'borussia_dortmund_96_97_a23', name: 'Borussia Dortmund', badge: '96/97', highlight: 'Hitzfeld ile UCL Şampiyonu'),
    BracketCandidate(id: 'juventus_95_96_b23', name: 'Juventus', badge: '95/96', highlight: 'Lippi ile UCL Şampiyonluğu'),
    BracketCandidate(id: 'lazio_98_99_a24', name: 'Lazio', badge: '98/99', highlight: 'Kupa Galipleri Kupası Son Şampiyonu'),
    BracketCandidate(id: 'deportivo_la_coruna_03_04_b24', name: 'Deportivo La Coruña', badge: '03/04', highlight: 'Milan\'ı Eleyen UCL Yarı Finalisti'),
    BracketCandidate(id: 'leeds_united_00_01_a25', name: 'Leeds United', badge: '00/01', highlight: 'Genç Sürpriz UCL Yarı Finalisti'),
    BracketCandidate(id: 'dynamo_kyiv_98_99_b25', name: 'Dynamo Kyiv', badge: '98/99', highlight: 'Shevchenko & Rebrov\'lu UCL Yarı Finalisti'),
    BracketCandidate(id: 'galatasaray_99_00_a26', name: 'Galatasaray', badge: '99/00', highlight: 'Yenilgisiz UEFA Kupası Şampiyonu'),
    BracketCandidate(id: 'cska_moskova_04_05_b26', name: 'CSKA Moskova', badge: '04/05', highlight: 'UEFA Kupası Şampiyonu'),
    BracketCandidate(id: 'schalke_04_10_11_a27', name: 'Schalke 04', badge: '10/11', highlight: 'Raúl\'lü UCL Yarı Finalisti'),
    BracketCandidate(id: 'wolfsburg_15_16_b27', name: 'Wolfsburg', badge: '15/16', highlight: 'Real Madrid\'i Deviren UCL Çeyrek Finalisti'),
    BracketCandidate(id: 'bayer_leverkusen_23_24_a28', name: 'Bayer Leverkusen', badge: '23/24', highlight: 'Xabi Alonso ile Yenilgisiz UEFA Finalisti'),
    BracketCandidate(id: 'atalanta_23_24_b28', name: 'Atalanta', badge: '23/24', highlight: 'Gasperini ile UEFA Kupası Şampiyonu'),
    BracketCandidate(id: 'feyenoord_01_02_a29', name: 'Feyenoord', badge: '01/02', highlight: 'Van Hooijdonk ile UEFA Kupası Şampiyonu'),
    BracketCandidate(id: 'sporting_cp_04_05_b29', name: 'Sporting CP', badge: '04/05', highlight: 'Kendi Evinde UEFA Finalisti'),
    BracketCandidate(id: 'nottingham_forest_78_79_a30', name: 'Nottingham Forest', badge: '78/79', highlight: 'Brian Clough Mucize Avrupa Şampiyonu'),
    BracketCandidate(id: 'aston_villa_81_82_b30', name: 'Aston Villa', badge: '81/82', highlight: 'Rotterdam Avrupa Kupası Şampiyonu'),
    BracketCandidate(id: 'fenerbahce_07_08_a31', name: 'Fenerbahçe', badge: '07/08', highlight: 'Zico ile UCL Çeyrek Finalisti'),
    BracketCandidate(id: 'besiktas_17_18_b31', name: 'Beşiktaş', badge: '17/18', highlight: 'Namaglup UCL Grup Lideri'),
    BracketCandidate(id: 'olympiacos_23_24_a32', name: 'Olympiacos', badge: '23/24', highlight: 'Konferans Ligi Şampiyonu'),
    BracketCandidate(id: 'panathinaikos_95_96_b32', name: 'Panathinaikos', badge: '95/96', highlight: 'Ajax\'ı Yenen UCL Yarı Finalisti'),
  ];
}