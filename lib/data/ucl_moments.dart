class UclMoment {
  final String year;
  final String title;
  final String narrative;
  final String scoreLabel;
  final int clubIdA;
  final int clubIdB;

  const UclMoment({
    required this.year,
    required this.title,
    required this.narrative,
    required this.scoreLabel,
    required this.clubIdA,
    required this.clubIdB,
  });
}

const List<UclMoment> uclMoments = [
  UclMoment(
    year: '2005',
    title: 'İstanbul Finali',
    narrative:
        "Yarı zamanda 3-0 geriye düşen Liverpool, ikinci yarının ilk 6 dakikasında üç gol bularak tarihin en büyük final geri dönüşünü yazdı. Penaltılarda Dudek'in kaleciliği kupayı Anfield'a taşıdı.",
    scoreLabel: 'AC Milan 3-3 Liverpool (Pen. 3-2 Liverpool)',
    clubIdA: 5,
    clubIdB: 31,
  ),
  UclMoment(
    year: '1999',
    title: 'Nou Camp Draması',
    narrative:
        "Bayern Munich 1-0 önde giderken, uzatma dakikalarında Sheringham ve Solskjær'in 2 dakika arayla attığı goller Manchester United'a tarihi bir treble kazandırdı.",
    scoreLabel: 'Manchester United 2-1 Bayern Munich',
    clubIdA: 985,
    clubIdB: 27,
  ),
  UclMoment(
    year: '2008',
    title: 'Moskova Yağmuru',
    narrative:
        "Luzhniki Stadı'nda yağmur altında oynanan final, Terry'nin kayarak kaçırdığı penaltı ve Anelka'nın kararan penaltısıyla İngiliz kulübü tarihine Chelsea aleyhine yazıldı.",
    scoreLabel: 'Manchester United 1-1 Chelsea (Pen. 6-5)',
    clubIdA: 985,
    clubIdB: 631,
  ),
  UclMoment(
    year: '2014',
    title: "Lizbon'da Uzatma Draması",
    narrative:
        "90 dakika 1-1 biten şehir finalinde, uzatmada Real Madrid adeta bir gol yağmuruna tuttu Atlético'yu. La Décima böyle geldi.",
    scoreLabel: 'Real Madrid 4-1 Atlético Madrid (2014 Final)',
    clubIdA: 418,
    clubIdB: 13,
  ),
  UclMoment(
    year: '2013',
    title: "Wembley'de Alman Finali",
    narrative:
        "İlk kez iki Alman takımının karşılaştığı bir finalde, son dakikalarda Robben'ın golü Bayern'e kupayı getirdi.",
    scoreLabel: 'Borussia Dortmund 1-2 Bayern Münih',
    clubIdA: 16,
    clubIdB: 27,
  ),
  UclMoment(
    year: '2017',
    title: 'La Remontada',
    narrative:
        "İlk maçı 4-0 kaybeden Barcelona, Camp Nou'da 6-1 kazanarak futbol tarihinin en büyük geri dönüşlerinden birine imza attı. Son gol, uzatmanın son saniyesinde geldi.",
    scoreLabel: 'FC Barcelona 6-1 Paris Saint-Germain (İlk maç: 0-4)',
    clubIdA: 131,
    clubIdB: 583,
  ),
  UclMoment(
    year: '2022',
    title: 'Bernabéu Büyüsü',
    narrative:
        "İlk maçı 4-3 kaybeden Real Madrid, evinde 89. dakikaya kadar elenirken Rodrygo'nun 2 dakikada attığı iki golle uzatmaya taşıdı, Benzema penaltıdan bitirdi.",
    scoreLabel: 'Real Madrid 3-1 Manchester City (İlk maç: 3-4, Uzatmalarda)',
    clubIdA: 418,
    clubIdB: 281,
  ),
  UclMoment(
    year: '2019',
    title: 'Amsterdam Mucizesi',
    narrative:
        "İlk maçı kaybeden ve deplasmanda 2-0 geriye düşen Tottenham, Lucas Moura'nın 90+6. dakikadaki golüyle averajla finale yükseldi.",
    scoreLabel: 'Ajax 2-3 Tottenham Hotspur (İlk maç: 1-0, Toplam: 3-3)',
    clubIdA: 610,
    clubIdB: 148,
  ),
  UclMoment(
    year: '2019',
    title: 'Corner Taken Quickly... ORIGI!',
    narrative:
        "İlk maçı 3-0 kaybeden Liverpool, Anfield'da eksik kadrosuyla 4-0 kazanarak finale yükseldi. Origi'nin çabuk alınan kornerden attığı son gol tarihe geçti.",
    scoreLabel: 'Liverpool 4-0 FC Barcelona (İlk maç: 0-3)',
    clubIdA: 31,
    clubIdB: 131,
  ),
  UclMoment(
    year: '2004',
    title: "Deportivo'nun Efsane Dönüşü",
    narrative:
        "İlk maçını 4-1 kaybeden Deportivo La Coruña, Riazor'da favori Milan'ı 4-0 mağlup ederek çeyrek finalde tarihi bir eleme gerçekleştirdi.",
    scoreLabel: 'Deportivo La Coruña 4-0 AC Milan (İlk maç: 1-4)',
    clubIdA: 897,
    clubIdB: 5,
  ),
  UclMoment(
    year: '2009',
    title: 'Stamford Bridge Skandalı',
    narrative:
        "Hakem kararlarının uzun süre tartışıldığı yarı final rövanşında Barcelona, uzatmada bulduğu golle finale yükseldi.",
    scoreLabel: 'Chelsea 1-1 FC Barcelona',
    clubIdA: 631,
    clubIdB: 131,
  ),
  UclMoment(
    year: '2010',
    title: "Mourinho'nun Otobüsü",
    narrative:
        "10 kişi kalan Inter, Camp Nou'da inanılmaz bir savunma performansıyla 1-0 mağlubiyeti tolere ederek finale yükseldi. Mourinho'nun sahaya koşusu unutulmadı.",
    scoreLabel: 'FC Barcelona 1-0 Inter Milan (İlk maç: 1-3)',
    clubIdA: 131,
    clubIdB: 46,
  ),
  UclMoment(
    year: '1999',
    title: "Galatasaray'ın Avrupa Sınavı",
    narrative:
        "Galatasaray'ın Avrupa kupalarındaki en unutulmaz gecelerinden birinde İtalyan devi Milan mağlup edildi.",
    scoreLabel: 'Galatasaray 3-2 AC Milan',
    clubIdA: 141,
    clubIdB: 5,
  ),
  UclMoment(
    year: '2008',
    title: "Kadıköy'de Sevilla Destanı",
    narrative:
        "UEFA Kupası şampiyonu Sevilla, Kadıköy'de Fenerbahçe karşısında sürpriz bir mağlubiyet aldı.",
    scoreLabel: 'Fenerbahçe 3-2 Sevilla',
    clubIdA: 36,
    clubIdB: 368,
  ),
  UclMoment(
    year: '2017',
    title: 'Namağlup Lider Beşiktaş',
    narrative:
        "Beşiktaş, grup aşamasında namağlup lider olarak tamamladığı kampanyada Almanya deplasmanında RB Leipzig'i mağlup etti.",
    scoreLabel: 'RB Leipzig 1-2 Beşiktaş',
    clubIdA: 23826,
    clubIdB: 114,
  ),
  UclMoment(
    year: '2012',
    title: 'Schalke Deplasmanı Zaferi',
    narrative:
        "Galatasaray, Almanya deplasmanında Schalke 04 karşısında etkileyici bir galibiyet aldı.",
    scoreLabel: 'Schalke 04 2-3 Galatasaray',
    clubIdA: 33,
    clubIdB: 141,
  ),
  UclMoment(
    year: '2018',
    title: 'Roma\'nın İnanılmaz Yarı Final Dönüşü',
    narrative:
        "İlk maçı 4-1 kaybeden Roma, Olimpico'da Barcelona'yı 3-0 mağlup ederek averaj farkıyla yarı finale yükseldi.",
    scoreLabel: 'Roma 3-0 Barcelona (2018)',
    clubIdA: 12,
    clubIdB: 131,
  ),
  UclMoment(
    year: '2013',
    title: 'Dortmund\'un Yarı Final Fırtınası',
    narrative:
        "Dortmund, yarı final ilk maçında Real Madrid'i sahasında 4-1 mağlup ederek finale güçlü bir adım attı.",
    scoreLabel: 'Dortmund 4-1 Real Madrid (2013)',
    clubIdA: 16,
    clubIdB: 418,
  ),
  UclMoment(
    year: '2003',
    title: 'Ronaldo Şovu',
    narrative:
        "Real Madrid'in eski yıldızı Ronaldo, Old Trafford'da attığı hat-trick ile kendisini alkışlatan Manchester United taraftarlarını büyüledi.",
    scoreLabel: 'Manchester United 4-3 Real Madrid (2003)',
    clubIdA: 985,
    clubIdB: 418,
  ),
  UclMoment(
    year: '',
    title: 'Beşiktaş - Benfica Gol Şöleni',
    narrative:
        "İki takımın karşılaşmasında toplam 6 gol görüldüğü çekişmeli bir maç yaşandı.",
    scoreLabel: 'Beşiktaş 3-3 Benfica',
    clubIdA: 114,
    clubIdB: 294,
  ),
  UclMoment(
    year: '',
    title: 'Fenerbahçe\'nin Old Trafford Sürprizi',
    narrative:
        "Fenerbahçe, İngiliz devi Manchester United'ı deplasmanda mağlup ederek büyük bir sürpriz gerçekleştirdi.",
    scoreLabel: 'Manchester United 0-1 Fenerbahçe',
    clubIdA: 985,
    clubIdB: 36,
  ),
  UclMoment(
    year: '2012',
    title: 'Münih Finali',
    narrative:
        "Bayern Münih, kendi evinde oynanan finalde Chelsea karşısında favori gösterildi ama Drogba'nın son dakika golü ve penaltılardaki soğukkanlılığı kupayı Londra'ya taşıdı.",
    scoreLabel: 'Bayern Munich 1-1 Chelsea (Pen. 3-4)',
    clubIdA: 27,
    clubIdB: 631,
  ),
  UclMoment(
    year: '2020',
    title: 'Barcelona Depremi',
    narrative:
        "Çeyrek finalde Bayern Münih, Barcelona'yı adeta yerle bir ederek Şampiyonlar Ligi tarihinin en unutulmaz skorlarından birini yazdı.",
    scoreLabel: 'Bayern Munich 8-2 FC Barcelona',
    clubIdA: 27,
    clubIdB: 131,
  ),
  UclMoment(
    year: '2018',
    title: "Kiev'de Bale Şovu",
    narrative:
        "Real Madrid'in üst üste 3. Şampiyonlar Ligi zaferinde, Gareth Bale'in müthiş makasla attığı gol finalin unutulmaz anı oldu.",
    scoreLabel: 'Real Madrid 3-1 Liverpool (2018 Final)',
    clubIdA: 418,
    clubIdB: 31,
  ),
];