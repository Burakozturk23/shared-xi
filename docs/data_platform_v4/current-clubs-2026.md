# 2026 yazı kulüp değişiklikleri (v4-2026-11-11.1)

Kariyer ve transfer verisi 2026 yaz dönemi öncesinde bitiyordu; kulüp kadroları ise güncel kulübü biliyordu
(Grid gibi modlar Dumfries'i Real Madrid'de görüyor, Kariyer Yarışı / Gizem / Transfer Düellosu görmüyordu).
Bu sürüm her taşınmayı kariyere son durak, kesin olduğunda da transfer olarak ekler.

## Kaynaklar

- **Kadrolar:** worldcup26.ir kulüp kadroları, 29 Eylül 2026 (`tools/data_platform_v4/patches/roster*-2026-09-29-*.json`).
- **Sporx:** "Dünyada biten transferler (2026 yaz transfer dönemi)" galerisi, 334 giriş (`patches/sporx-transfers-2026-summer.json`, `fetch_sporx_transfers.py` ile alındı).

Kaynaklar transferin gününü vermez: yeni durak ve transfer **2026-07-01, sezon hassasiyetinde** saklanır
(`career_spells.confidence` ve `transfers.trust` = `REVIEWED_SEASON`). Transfer Düellosu bu soruları ay yerine
"2026 · Yaz transferi" diye gösterir.

## Kurallar

- Kadrodaki kulüp kariyerde yoksa yeni son durak eklenir. Kulüp ayrılışı (transfer) yalnız son durak 2026'da bittiyse
  ya da Sporx aynı kulübü yazıyorsa eklenir; daha eski bitiş arada eksik bir kulüp olabilir demektir (Tadić:
  Fenerbahçe 2025, Al-Wahda, sonra NEC; kariyerine NEC eklendi, Fenerbahçe → NEC transferi eklenmedi).
- Sporx'ta olup kadrolarda olmayan taşınmalar (Portekiz, Yunanistan, Bulgaristan, BAE… ve kadrosu eşleşmeyenler):
  futbolcu adla tek kişiye eşleşmeli, ayrıldığı kulüp kariyerindeki son durak olmalı, gittiği kulüp tek bir A takımına
  çözülmeli (eşit uyan iki kulüp, ör. Vitória Setúbal / Guimarães, çözülmüş sayılmaz).
- Son durağı açık (bitişsiz) olan futbolcunun durağı yalnız kaynak onu o kulüpten ayrılmış gösteriyorsa 2026-07-01'de kapanır.
- Kadro ile Sporx çelişirse futbolcu eklenmez.

## Sonuç

- 492 futbolcuya yeni son durak (87 bilinen isim), 455 transfer, 33 açık durak kapandı.
- Kaynak: yalnız kadro 308, kadro + Sporx 148, yalnız Sporx 36.
- Eklenmeyenler: kariyeri olmayan 6145 kadro futbolcusu, açık son durağı Sporx'la doğrulanmayan 94, Sporx'ta adı veritabanında bulunmayan 134 giriş.
- Çelişki nedeniyle dışarıda bırakılanlar: Thilo Kehrer (kadro: Ajax Amsterdam, Sporx: Ajax -> Monaco); Danilho Doekhi (kadro: SS Lazio, Sporx: Union Berlin -> Aston Villa).

Veritabanını okuyan bütün kataloglar yeniden üretildi: Kariyer/Transfer, Gizem, Sahte Kulüp, PvP (tüm online
modlar ve botlar), Hangisi, Arcade (Burst / Piramit; `tools/arcade/build_vectors.js` ile çevrimdışı Burst test
vektörleri de), Günlük Kelime ve Üç Mod. Hangisi ve Günlük Kelime'nin sürümü değiştiği için o günün içeriği
yeni sürümle değişir. Diğer katalog üreticileri veritabanını kullanmaz.

## Wikipedia doğrulaması (v4-2026-11-12.1)

Yukarıdaki 492 taşınmanın her biri ve Sporx'ta eşleşmeyen isimler İngilizce Wikipedia'daki oyuncu kutusunun
(infobox) A takım kariyeriyle karşılaştırıldı (`fetch_wikipedia_careers.py` → `patches/wikipedia-careers-2026-11-12.json`,
her oyuncu için sayfa adı ve revizyon numarası saklı). Düzeltmeler `build_wikipedia_moves.py` ile
`patches/wikipedia-moves-2026-11-12.json` dosyasına yazılır, `apply_reviewed_corrections.py` ile uygulanır.

- **Sporx'ta eşleşmeyen, Wikipedia'nın doğruladığı taşınmalar:** Ceballos → Betis, Kehrer → Ajax (kiralık; Sporx yönü
  ters yazmış), Doekhi → Lazio (Sporx'taki Aston Villa yanlış), Mudryk → Tottenham, Kolo Muani → Juventus,
  ter Stegen → Ajax, Openda → Lyon, Digne → PSG, Guessand → Crystal Palace, Seko Fofana → Porto,
  Morata Como → Leganés, Florentino Burnley → Ipswich, Maffeo Mallorca → Olympiacos → Valencia (kiralık).
  Morata ve Florentino'daki 2026-06-30 "kiralıktan dönüş" durağı (Milan / Benfica) Wikipedia'ya göre hiç
  olmadı (Como ve Burnley oyuncuyu satın aldı); durak ve dönüş transferi kaldırıldı.
- **Başka bir futbolcuya ait kadro satırları** (aynı ad): Murillo (Riestra), Rafael (Real Salt Lake),
  Liam Henderson (Falkirk), Eduardo (V-Varen Nagasaki), Córdoba (Instituto), Brian Mansilla (Arouca),
  Zé Carlos (Rio Ave). Durak, transfer ve kadro bağlantısı geri alındı; Wikipedia'daki gerçek kulüp biliniyorsa
  eklendi (Murillo Al-Shamal, Henderson Sampdoria, Rafael Botafogo 2021-2024).
- **Aynı kulübün iki satırı taşınma sanılmış:** Union Saint-Gilloise (3948 / 6571) ve Antwerp (1096 / 10625);
  6 Union SG oyuncusu ve Foulon geri alındı.
- **Aradaki kulüpler:** son kayıtlı kulüp ile yeni kulüp arasındaki, kariyerde olmayan dönemler (Ziyech ve Amrabat
  Wydad, Cuisance Osnabrück + Hertha, Padt Ludogorets, Coucke Al-Orobah + Sampdoria, Vidigal Stoke + Wycombe,
  Dani Gómez Zaragoza, Diallo Al-Arabi / Al-Duhail / Umm Salal, Gaari Al-Hazem) yıl hassasiyetinde eklendi
  (`REVIEWED_YEAR`, `YYYY-07-01` ya da önceki durağın bittiği gün olarak saklanır, modlar yalnız yılı gösterir).
- **Körfez kulüpleri:** veritabanındaki transferler `1000002524`'ün Abu Dabi'nin Al Jazira'sı (Lanzini, Kosanović),
  `1000000161`'in Abu Dabi'nin Al Wahda'sı (Pizzi, Allan, Matheus Pereira) olduğunu gösterir. Talisca
  Fenerbahçe → Al Jazira, Tadić Fenerbahçe → Al Wahda (2025-08-08) → NEC, Fekir Betis → Al Jazira → Abha eklendi;
  Fekir'in Al Jazira bağlantısı Universitatea Craiova (id 2524, kaydırma çakışması) olarak saklanmıştı, düzeltildi.
  Al-Diriyah (Suudi Arabistan) veritabanında yoktu: yeni kulüp `5000000024` olarak eklendi (`addClub`), Darwin Núñez
  Al-Hilal → Al-Diriyah (kiralık) ve Colley'nin 2025-2026 dönemi ona bağlandı. Bu kulüpler oyun havuzunda değil
  (`gameplay_eligible=0`, Abha gibi): veri doğru, ancak Kariyer Yarışı ve Transfer Düellosu bu durakları göstermez.
  Eklenmeyen: Al-Ula, Al-Nasr (Dubai), Mağusa Türk Gücü.
- **Grid bağlantıları:** yalnız Sporx'tan gelen yeni kulüpler (ör. Gabriel Jesus → Barcelona) `player_clubs`'a da
  eklendi; Grid modları artık bu kulüpleri de tanır.
- **Eklenmeyenler:** Sporx'ta adı geçen ama veritabanında kariyeri olmayan 68 oyuncu (Baleba, Mastantuono,
  Kang-in Lee, Trafford…) seçim sırası 55.000'in altında olduğu için (modlar ilk 5.000'i kullanır) oyunda
  görünmez; bu oyuncular için kariyer eklenmedi. Veritabanında hiç olmayan isimler de eklenmedi.

`build_wikipedia_moves.py` düzeltme öncesi veritabanından üretilir (uygulandıktan sonra yeniden üretilirse
eklenen dönemler zaten var sayılır).

## Sonraki dönem (ör. Ocak 2027)

1. Yeni kadro anlık görüntüsünü ve Sporx galerisini kaydet: `py -3 tools/data_platform_v4/fetch_sporx_transfers.py --gallery <id> --page <url> --out tools/data_platform_v4/patches/sporx-transfers-<dönem>.json`.
2. `build_current_club_review.py` ve `apply_current_clubs.py` içindeki tarih, revizyon ve dosya adlarını yeni döneme göre değiştir; listeyi üret, sahibine onaylat (`excludedPlayerIds`).
3. Uygula; sonra listedeki oyuncuları `fetch_wikipedia_careers.py` ile Wikipedia'dan çekip `build_wikipedia_moves.py`
   (yeni revizyon ve dosya adıyla) ve `apply_reviewed_corrections.py` ile düzelt. Wikipedia'ya saniyede bir istek
   gönderilir; 429 yanıtında araç bekleyip yeniden dener.
4. Kariyer/Transfer, Gizem, Sahte Kulüp ve PvP kataloglarını yeniden üret.

## Liste

| Sıra | Futbolcu | Eski kulüp (son kayıt) | Yeni kulüp | Transfer | Kaynak | Sporx bonservis |
|---|---|---|---|---|---|---|
| 1 | Robert Lewandowski | FC Barcelona (2026-07-01) | Chicago Fire FC | evet | roster+sporx | - |
| 2 | Mohamed Salah | Liverpool FC (2026-07-01) | Trabzonspor | evet | roster |  |
| 10 | Alexis Sánchez | Sevilla FC (2026-05-23) | CF Montréal | evet | roster |  |
| 13 | Romelu Lukaku | Napoli (2026-03-06) | Fenerbahce | evet | roster |  |
| 20 | Dušan Tadić | Fenerbahce (2025-08-08) | NEC Nijmegen | hayır | roster |  |
| 22 | Pierre-Emerick Aubameyang | Olympique Marseille (2026-05-17) | Deportivo de La Coruña | evet | roster+sporx | 1.5 milyon euro |
| 28 | Bernardo Silva | Manchester City (2026-07-01) | Real Madrid | evet | roster+sporx | Bedelsiz |
| 41 | David Alaba | Real Madrid (2026-07-01) | Udinese Calcio | evet | roster |  |
| 61 | Daley Blind | Girona FC (2026-05-01) | Ajax Amsterdam | evet | sporx | - |
| 62 | Jordan Henderson | Brentford FC (2026-05-24) | Chelsea FC | evet | roster+sporx | Bedelsiz |
| 75 | Casemiro | Manchester United (2026-07-01) | Inter Miami CF | evet | roster+sporx | - |
| 85 | Leon Goretzka | Bayern Munich (2026-07-01) | Aston Villa | evet | roster+sporx | - |
| 86 | Youri Tielemans | Aston Villa (2026-05-24) | Manchester United | evet | roster+sporx | 41 milyon Euro |
| 97 | Hakim Ziyech | Al-Duhail SC (2025-07-01) | Botafogo FC | hayır | roster |  |
| 98 | Georginio Wijnaldum | Al-Ettifaq Football Club (2026-07-01) | Al-Ittihad Football Club | evet | roster |  |
| 123 | Filip Kostić | Juventus FC (2026-07-01) | PSV Eindhoven | evet | roster+sporx | Bedelsiz |
| 129 | João Cancelo | Al-Hilal Saudi Football Club (açık) | FC Barcelona | evet | sporx | - |
| 145 | Yann Sommer | Inter Milan (2026-07-01) | Club Brugge KV | evet | roster+sporx |  |
| 168 | Marten de Roon | Atalanta BC (2026-05-22) | AS Roma | evet | roster |  |
| 174 | Michy Batshuayi | Eintracht Frankfurt (2025-12-06) | Abha | evet | roster+sporx | - |
| 179 | Wout Weghorst | Ajax Amsterdam (2026-05-17) | Twente Enschede FC | evet | roster+sporx | -  Twente, Ajax'tan ayrılan 33 yaşındaki Hollandalı golcü Wo |
| 187 | Thomas Partey | Villarreal CF (2026-07-01) | Al-Shabab Club | evet | roster+sporx | - |
| 191 | Nemanja Gudelj | Sevilla FC (2026-07-01) | Getafe CF | evet | roster |  |
| 194 | Leandro Trossard | Arsenal FC (2026-05-18) | Besiktas JK | evet | roster |  |
| 206 | Thomas Meunier | LOSC Lille (2026-07-01) | Sunderland AFC | evet | roster+sporx | - |
| 230 | Denzel Dumfries | Inter Milan (2026-05-09) | Real Madrid | evet | roster+sporx | 20 milyon euro  Real Madrid, Inter'den Hollandalı sağ bek De |
| 234 | Julian Brandt | Borussia Dortmund (2026-07-01) | Ajax Amsterdam | evet | roster+sporx | Bedelsiz |
| 237 | Rodri | Manchester City (2026-05-19) | FC Barcelona | evet | roster+sporx | 60+15 milyon Euro |
| 247 | John Stones | Manchester City (2026-07-01) | Inter Milan | evet | roster+sporx | - |
| 256 | Ferran Torres | FC Barcelona (2026-05-23) | Paris Saint-Germain | evet | roster+sporx | 50 Milyon Euro |
| 265 | Aïssa Mandi | LOSC Lille (2026-05-17) | Levante UD | evet | roster |  |
| 274 | Gabriel Jesus | Arsenal FC (2026-05-24) | FC Barcelona | evet | sporx | 10 + 4 milyon Euro, sonraki satıştan yüzde 20 pay |
| 277 | Jonathan David | Juventus FC (2026-05-24) | Atlético de Madrid | evet | roster+sporx | Kiralık |
| 287 | Danny Welbeck | Brighton & Hove Albion (2026-05-24) | Chelsea FC | evet | roster+sporx | - |
| 297 | Breel Embolo | Stade Rennais FC (2026-05-17) | Atlanta United FC | evet | roster |  |
| 407 | Alireza Jahanbakhsh | FCV Dender EH (2026-07-01) | Excelsior Rotterdam | evet | roster |  |
| 449 | Nathan Aké | Manchester City (2026-05-24) | Fenerbahce | evet | roster |  |
| 540 | Robin Gosens | ACF Fiorentina (2026-05-22) | FC Schalke 04 | evet | roster+sporx | Satın alma opsiyonlu kiralık |
| 545 | Franck Kessié | Al-Ahli Saudi Football Club (açık) | Atalanta BC | evet | sporx | - |
| 618 | Sofyan Amrabat | Fenerbahce (açık) | Ajax Amsterdam | evet | roster+sporx | -  Ajax, Fenerbahçe'nin sözleşmesini feshettiğini Faslı orta |
| 623 | Fred | Fenerbahce (2026-05-17) | Clube Atlético Mineiro | evet | roster+sporx | 2 milyon euro |
| 646 | Jeison Murillo | Celta de Vigo (2022-05-21) | Club Deportivo Riestra | hayır | roster |  |
| 761 | Rafael Leão | AC Milan (2026-05-24) | Galatasaray | evet | roster |  |
| 789 | Clément Lenglet | Atlético de Madrid (2026-05-24) | SL Benfica | evet | roster+sporx | - |
| 790 | Nordin Amrabat | Hull City (2025-06-01) | FC Utrecht | hayır | roster |  |
| 914 | José María Giménez | Atlético de Madrid (2026-05-09) | Deportivo de La Coruña | evet | roster |  |
| 926 | Christopher Nkunku | AC Milan (2026-05-24) | RB Leipzig | evet | sporx | 3 milyon euro kiralama bedeli, 28 milyon euro satın alma ops |
| 929 | Cédric Bakambu | Real Betis Balompié (2026-05-17) | San Diego FC | evet | roster |  |
| 936 | Péter Gulácsi | RB Leipzig (2026-05-16) | Villarreal CF | evet | roster+sporx | 2 milyon euro |
| 937 | João Palhinha | Bayern Munich (açık) | SL Benfica | evet | roster+sporx | 14+5 milyon euro |
| 947 | Alejandro Grimaldo | Bayer 04 Leverkusen (2026-05-16) | Atlético de Madrid | evet | roster+sporx | 20 milyon euro |
| 1111 | Viktor Tsygankov | Girona FC (2026-05-23) | Ajax Amsterdam | evet | roster+sporx | 4 milyon euro |
| 1115 | Sergi Roberto | Como 1907 (2026-05-24) | LA Galaxy | evet | roster |  |
| 1118 | Djibril Sidibé | FC Toulouse (2026-05-10) | Le Mans FC | evet | roster |  |
| 1122 | Florian Grillitsch | SC Braga (2026-04-26) | Frosinone Calcio | evet | roster |  |
| 1352 | Dennis Praet | Royal Antwerp FC (2026-07-01) | KV Mechelen | evet | roster |  |
| 1536 | Moise Kean | ACF Fiorentina (2026-04-04) | Como 1907 | evet | roster |  |
| 1542 | Jack Grealish | Manchester City (açık) | Everton FC | evet | sporx | Kiralık |
| 1544 | Théo Bongonda | Spartak Moscow (2026-07-01) | Al-Faisaly | evet | roster |  |
| 1550 | Nico Elvedi | Borussia Mönchengladbach (2026-05-16) | Leeds United | evet | roster |  |
| 1784 | Tijjani Reijnders | Manchester City (2026-05-24) | Al-Qadsiah Saudi Football Club | evet | roster+sporx | 61 milyon euro |
| 1806 | Anthony Lopes | FC Nantes (2026-05-08) | Angers SCO | evet | roster |  |
| 2117 | Enes Ünal | AFC Bournemouth (2026-05-24) | Getafe CF | evet | sporx | Yok |
| 2137 | Marc Cucurella | Chelsea FC (2026-05-24) | Real Madrid | evet | roster+sporx | 55+5 |
| 2142 | Nahuel Molina | Atlético de Madrid (2026-05-09) | AS Roma | evet | roster+sporx | 13 Milyon euro |
| 2458 | Emiliano Martínez | Aston Villa (2026-05-15) | Chelsea FC | evet | roster+sporx | 8.7 milyon euro |
| 2814 | Angeliño | AS Roma (2026-04-10) | Deportivo de La Coruña | evet | roster |  |
| 2817 | Ander Herrera | CA Boca Juniors (2025-06-16) | Real Zaragoza | evet | sporx | Bedelsiz |
| 3233 | Enner Valencia | CF Pachuca (açık) | CA Boca Juniors | evet | roster+sporx | Bedelsiz |
| 3240 | Mërgim Vojvoda | Como 1907 (2026-05-24) | Udinese Calcio | evet | roster |  |
| 3247 | Antonio Sanabria | US Cremonese (2026-05-10) | Sport Club Internacional | evet | roster |  |
| 3249 | Nick Viergever | FC Utrecht (2026-07-01) | PEC Zwolle | evet | roster |  |
| 3256 | Cristian Romero | Tottenham Hotspur (2026-04-12) | Atlético de Madrid | evet | roster+sporx | 40 Milyon Euro |
| 3592 | Carlos Álvarez | Levante UD (2026-05-02) | CF América | evet | roster |  |
| 3723 | Sandro Tonali | Newcastle United (2026-05-17) | Tottenham Hotspur | evet | roster+sporx | 115 milyon euro |
| 3730 | Zeki Çelik | AS Roma (2026-05-24) | Juventus FC | evet | roster |  |
| 3750 | Vincent Janssen | Royal Antwerp FC (2026-07-01) | Portland Timbers | evet | roster |  |
| 3769 | Gabriel Martinelli | Arsenal FC (2026-05-24) | Al-Hilal Saudi Football Club | evet | roster+sporx | 70 milyon euro |
| 3778 | Ollie Watkins | Aston Villa (2026-05-24) | Al-Hilal Saudi Football Club | evet | roster |  |
| 4128 | Christian Nørgaard | Arsenal FC (2026-05-24) | Everton FC | evet | roster |  |
| 4140 | Djibril Sow | Sevilla FC (2026-05-23) | Genoa CFC | evet | roster |  |
| 4146 | Joey Veerman | PSV Eindhoven (2026-05-17) | Borussia Dortmund | evet | roster+sporx | 22 milyon euro |
| 4150 | Omar Marmoush | Manchester City (2026-05-19) | Tottenham Hotspur | evet | roster+sporx | Zorunlu satın alma opsiyonu ile kiralık. Opsiyon bonuslar da |
| 4632 | Niclas Füllkrug | West Ham United (açık) | SV Werder Bremen | evet | sporx | Kiralık |
| 4645 | Bruno Guimarães | Newcastle United (2026-05-24) | Arsenal FC | evet | roster+sporx | 87 milyon euro bonservis |
| 4654 | Jhon Córdoba | FC Krasnodar (2026-05-17) | Instituto ACC | evet | roster |  |
| 4661 | Davide Frattesi | Inter Milan (2026-05-09) | SS Lazio | evet | roster+sporx | Kiralık |
| 5363 | Gonçalo Ramos | PSG (2026-05-17) | AC Milan | evet | roster+sporx | 74 milyon euro + bonuslar |
| 5382 | Gyrano Kerk | Royal Antwerp FC (2026-07-01) | Erzurumspor FK | evet | roster |  |
| 5402 | Ibrahima Konaté | Liverpool FC (2026-07-01) | Real Madrid | evet | roster+sporx | -  Real Madrid, Liverpool'dan ayrılan Ibrahima Konate ile 20 |
| 5407 | Johan Mojica | RCD Mallorca (2026-05-17) | Getafe CF | evet | roster |  |
| 5418 | Roberto Gagliardini | Hellas Verona (2026-07-01) | Cagliari Calcio | evet | roster |  |
| 5979 | Daizen Maeda | Celtic FC (2026-04-19) | Ipswich Town | evet | roster |  |
| 5984 | Gerónimo Rulli | Olympique Marseille (2026-05-17) | Manchester City | evet | sporx | 3.5 milyon euro |
| 6006 | Youssouf Fofana | AC Milan (2026-05-24) | Sevilla FC | evet | roster+sporx | Kiralık |
| 6014 | Martin Dúbravka | Burnley FC (2026-07-01) | Tottenham Hotspur | evet | roster |  |
| 6051 | Victor Nelsson | Galatasaray (açık) | FC Nordsjaelland | evet | sporx | - |
| 6055 | Juan Jesus | Napoli (2026-07-01) | Venezia FC | evet | roster |  |
| 6058 | Saša Lukić | Fulham FC (2026-05-17) | Ipswich Town | evet | roster |  |
| 6060 | Moussa Diaby | Al-Ittihad Football Club (açık) | Bayer 04 Leverkusen | evet | sporx | 30 milyon Euro |
| 6515 | Michaël Cuisance | UC Sampdoria (2023-05-08) | RC Lens | hayır | roster |  |
| 6527 | Jhon Lucumí | Bologna FC 1909 (2026-05-23) | Juventus FC | evet | roster+sporx | 20 milyon euro ve bonuslar |
| 6532 | Adama Traoré | West Ham United (2026-07-01) | Deportivo de La Coruña | evet | roster |  |
| 6567 | Diego Carlos | Fenerbahce (açık) | Parma Calcio 1913 | evet | roster+sporx | Kiralık |
| 6574 | Hidemasa Morita | Sporting CP (2026-07-01) | Hull City | evet | roster+sporx | Bedelsiz |
| 6583 | Nabil Fekir | Real Betis Balompié (2024-08-25) | Abha | hayır | roster |  |
| 6584 | Eric Bailly | Real Oviedo (2026-07-01) | Columbus Crew | evet | roster+sporx | - |
| 6993 | Guillermo Maripán | Torino FC (2026-07-01) | Sport Club Internacional | evet | roster |  |
| 7009 | Çağlar Söyüncü | Fenerbahce (2026-05-17) | Corum FK | evet | roster |  |
| 7031 | Salih Özcan | Borussia Dortmund (2026-07-01) | Besiktas JK | evet | roster |  |
| 7037 | Enzo Fernández | Chelsea FC (2026-05-24) | Manchester City | evet | roster+sporx | 125 Milyon Sterlin (Yaklaşık 145 milyon euro) |
| 7040 | Bradley Barcola | PSG (2026-05-17) | Liverpool FC | evet | roster+sporx | 125 milyon euro bonservis, 20 milyon euro bonus, 5 yıllık sö |
| 7047 | Kevin Danso | Tottenham Hotspur (2026-05-24) | Sunderland AFC | evet | roster+sporx | Kiralık (2.90 milyon euro) |
| 7051 | Xaver Schlager | RB Leipzig (2026-07-01) | Nottingham Forest | evet | roster |  |
| 7053 | Omar Mascarell | RCD Mallorca (2026-05-23) | Al-Khaleej Club (Saihat) | evet | roster |  |
| 7064 | Harry Wilson | Fulham FC (2026-05-24) | Leeds United | evet | roster |  |
| 7650 | Jackson Irvine | FC St. Pauli (2026-05-16) | Cerezo Osaka | evet | roster |  |
| 7692 | Brais Méndez | Real Sociedad (2026-05-17) | Columbus Crew | evet | roster |  |
| 7704 | Pedro Gonçalves | Sporting CP (2026-05-16) | ACF Fiorentina | evet | roster |  |
| 7721 | Arthur Theate | Eintracht Frankfurt (2026-05-08) | Bologna FC 1909 | evet | sporx | - |
| 7744 | Ezri Konsa | Aston Villa (2026-05-15) | Arsenal FC | evet | roster+sporx | 60 milyon euro + 6 milyon euro bonus |
| 8307 | Frank Onyeka | Brentford FC (açık) | Coventry City | evet | sporx | 7 milyon euro |
| 8311 | Tin Jedvaj | Panathinaikos FC (2026-03-08) | Al-Shabab Club | evet | roster |  |
| 8330 | Ronald Araujo | FC Barcelona (2026-05-23) | Liverpool FC | evet | roster+sporx | Kiralık |
| 8362 | Callum Wilson | West Ham United (2026-05-24) | Brentford FC | evet | roster+sporx | Bedelsiz |
| 8371 | Nicolas Jackson | Chelsea FC (açık) | Aston Villa | evet | roster+sporx | 75 milyon euo |
| 8372 | Romain Del Castillo | Stade Brestois 29 (2026-05-17) | CA Osasuna | evet | roster |  |
| 8375 | Aaron Wan-Bissaka | West Ham United (2026-05-17) | Aston Villa | evet | roster+sporx | Kiralık |
| 8391 | Paulo Oliveira | SC Braga (2026-05-16) | Al-Fayha FC | evet | roster |  |
| 8963 | Duje Caleta-Car | Olympique Lyon (açık) | US Sassuolo | evet | roster+sporx | 2 milyon Euro |
| 8964 | Abdou Diallo | RB Leipzig (2023-05-20) | Abha | hayır | roster |  |
| 8970 | Santiago Gimenez | AC Milan (2026-05-24) | FC Porto | evet | roster+sporx | Satın alma opsiyonlu kiralık, opsiyon 18 milyon euro ve bonu |
| 8971 | Salih Uçan | Besiktas JK (2026-05-15) | Genclerbirligi Ankara | evet | roster |  |
| 8972 | Allan Saint-Maximin | RC Lens (2026-07-01) | Charlotte FC | evet | roster+sporx | - |
| 8980 | Kyogo Furuhashi | Birmingham City (2026-01-10) | LA Galaxy | evet | roster |  |
| 9014 | Artem Dovbyk | AS Roma (2026-05-17) | Bologna FC 1909 | evet | roster+sporx | Kiralık |
| 9026 | Takehiro Tomiyasu | Ajax Amsterdam (2026-07-01) | Crystal Palace | evet | roster+sporx | Bedelsiz |
| 9056 | Lutsharel Geertruida | RB Leipzig (açık) | PSV Eindhoven | evet | roster+sporx | 7 milyon euro |
| 9617 | Fábio Vieira | Arsenal FC (açık) | Hamburger SV | evet | sporx | 9 milyon euro |
| 9647 | Amir Hadziahmetovic | Besiktas JK (açık) | Ludogorets | evet | sporx | Bedelsiz |
| 9675 | Emre Mor | Fenerbahce (2026-07-01) | NEC Nijmegen | evet | roster+sporx | Bedelsiz |
| 9710 | Mostafa Mohamed | FC Nantes (2026-05-08) | Konyaspor | evet | roster |  |
| 10342 | Kristjan Asllani | Inter Milan (açık) | Al-Jazira | evet | sporx | - |
| 10357 | Taiwo Awoniyi | Nottingham Forest (2026-05-24) | Coventry City | evet | roster+sporx | 10.50 milyon euro |
| 10384 | Rob Schoofs | Union Saint-Gilloise (2026-05-17) | Union St. Gilloise | evet | roster |  |
| 10387 | Ayase Ueda | Feyenoord Rotterdam (2026-05-10) | LOSC Lille | evet | roster+sporx | 15 milyon euro  Ueda, Lille tarihinin ilk Japon futbolcusu o |
| 10389 | Chidozie Awaziem | FC Nantes (2026-05-08) | Konyaspor | evet | roster |  |
| 10392 | Pape Matar Sarr | Tottenham Hotspur (2026-05-24) | Juventus FC | evet | roster+sporx | Kiralık |
| 11040 | Nico González | Manchester City (2026-05-24) | Newcastle United | evet | roster+sporx | 55 milyon euro + 3.5 milyon euro bonus |
| 11067 | Omar Colley | PAOK Thessaloniki (2025-07-23) | Al-Fayha FC | hayır | roster |  |
| 11079 | Rafa Soares | FC Famalicão (2026-05-16) | CF Estrela Amadora | evet | roster |  |
| 11083 | Joan Jordán | Sevilla FC (2026-01-24) | CF Estrela Amadora | evet | roster |  |
| 11095 | Orbelín Pineda | AEK Athens (2026-03-22) | CF Monterrey | evet | roster |  |
| 11101 | Caio Henrique | Monaco (2026-05-02) | Ajax Amsterdam | evet | roster |  |
| 11103 | Curtis Jones | Liverpool FC (2026-05-24) | Inter Milan | evet | roster+sporx | 30 milyon euro + 5 milyon euro bonus, Sonraki satıştan %10 p |
| 11121 | Albert Gudmundsson | ACF Fiorentina (2026-05-22) | SS Lazio | evet | roster |  |
| 11124 | Raphael Onyedika | Club Brugge KV (2026-05-17) | Eintracht Frankfurt | evet | roster+sporx | 9 milyon euro |
| 11164 | Isaac Kiese Thelin | Urawa Red Diamonds (2026-07-01) | SV Ried | evet | roster |  |
| 11755 | Brennan Johnson | Crystal Palace (2026-05-17) | Everton FC | evet | roster |  |
| 11766 | Daniel Muñoz | Crystal Palace (2026-05-24) | Nottingham Forest | evet | roster+sporx | 25 milyon euro |
| 11796 | Jonas Wind | VfL Wolfsburg (2026-07-01) | SC Braga | evet | roster |  |
| 11813 | Habib Diallo | FC Metz (2026-05-10) | Le Mans FC | evet | roster |  |
| 11824 | Mason Greenwood | Olympique Marseille (2026-05-17) | Fenerbahce | evet | roster |  |
| 11849 | El Bilal Touré | Atalanta BC (açık) | Parma Calcio 1913 | evet | roster+sporx | 1.5 milyon euro kiralama bedeli, 10 milyon euroluk şartlara  |
| 12497 | Terem Moffi | OGC Nice (açık) | Hamburger SV | evet | roster+sporx | 2 milyon Euro |
| 12577 | Axel Disasi | Chelsea FC (açık) | Crystal Palace | evet | roster+sporx | Kiralık |
| 12591 | Malang Sarr | RC Lens (2026-05-17) | Neom Sports Club | evet | roster+sporx | Bedelsiz |
| 12604 | Morgan Rogers | Aston Villa (2026-05-15) | Chelsea FC | evet | roster+sporx | 138 Milyon Euro |
| 12610 | Ainsley Maitland-Niles | Olympique Lyon (2026-05-17) | Everton FC | evet | roster |  |
| 12617 | Aarón Martín | Genoa CFC (2026-05-24) | Racing Santander | evet | roster |  |
| 12625 | Dwight McNeil | Everton FC (2026-05-17) | Crystal Palace | evet | roster |  |
| 13209 | Kingsley Ehizibue | Udinese Calcio (2026-05-24) | Genoa CFC | evet | roster |  |
| 13220 | Nikola Storm | Antalyaspor (2026-05-17) | KVC Westerlo | evet | roster |  |
| 13250 | Jovane Cabral | CF Estrela Amadora (2026-07-01) | Grêmio Foot-Ball Porto Alegrense | evet | roster |  |
| 13252 | Mauro Arambarri | Getafe CF (2026-05-23) | CA River Plate | evet | roster |  |
| 13277 | Jordan Larsson | FC Copenhagen (2026-03-07) | Al-Ettifaq Football Club | evet | roster |  |
| 13303 | Andrea Pinamonti | US Sassuolo (2026-05-24) | SS Lazio | evet | roster |  |
| 13358 | Azzedine Ounahi | Girona FC (2026-05-23) | Panathinaikos FC | evet | sporx | 14 milyon euro + 2 milyon euro bonuslar |
| 13364 | Jamiro Monteiro | PEC Zwolle (2026-07-01) | NEC Nijmegen | evet | roster |  |
| 13929 | Attila Szalai | TSG 1899 Hoffenheim (açık) | Pogon Szczecin | evet | sporx |  |
| 13936 | Ørjan Nyland | Sevilla FC (2026-07-01) | RB Leipzig | evet | sporx | - |
| 13940 | Cherif Ndiaye | Samsunspor (2026-05-09) | PAOK Thessaloniki | evet | sporx | Satın alma opsiyonlu kiralık |
| 13945 | Miguel Cardoso | Kayserispor (2026-05-09) | Erzurumspor FK | evet | roster |  |
| 14017 | Nedim Bajrami | Rangers FC (2026-03-08) | Al-Taawoun Football Club | evet | roster |  |
| 14023 | Guglielmo Vicario | Tottenham Hotspur (2026-03-22) | Juventus FC | evet | roster+sporx | Kiralık |
| 14028 | Matt Targett | Middlesbrough FC (2026-05-31) | Hull City | evet | roster |  |
| 14621 | Rafael | Basaksehir FK (2021-05-08) | Real Salt Lake City | hayır | roster |  |
| 14641 | Romano Schmid | SV Werder Bremen (2026-05-16) | Frosinone Calcio | evet | roster |  |
| 14656 | Elias Achouri | FC Copenhagen (2026-02-14) | San Diego FC | evet | roster |  |
| 14660 | Domingos Duarte | Getafe CF (2026-05-23) | São Paulo Futebol Clube | evet | roster |  |
| 14662 | Quinten Timber | Olympique Marseille (2026-05-17) | Crystal Palace | evet | roster+sporx | - |
| 14663 | Ylber Ramadani | US Lecce (2026-05-24) | Corum FK | evet | roster |  |
| 14716 | Sergio Padt | FC Groningen (2021-05-16) | FC Utrecht | hayır | roster |  |
| 14719 | Gideon Mensah | AJ Auxerre (2026-05-17) | 1.FC Köln | evet | roster |  |
| 14721 | Alejandro Garnacho | Chelsea FC (2026-05-19) | Aston Villa | evet | roster+sporx | - Şartlı satın alma |
| 14736 | Beto | Everton FC (2026-05-24) | ACF Fiorentina | evet | roster |  |
| 14743 | Óscar Mingueza | Celta de Vigo (2026-05-23) | Crystal Palace | evet | roster+sporx | Bedelsiz |
| 14744 | Trevoh Chalobah | Chelsea FC (2026-05-24) | Como 1907 | evet | roster |  |
| 14748 | Lazare Amani | AE Kifisias (2026-03-22) | Cercle Brugge | evet | roster |  |
| 15356 | Borna Sosa | Crystal Palace (2026-04-25) | 1.FC Köln | evet | roster |  |
| 15357 | Berkan Kutlu | Konyaspor (2026-04-27) | Kocaelispor | evet | roster |  |
| 15359 | Kaj Sierhuis | Fortuna Sittard (2026-07-01) | NEC Nijmegen | evet | roster |  |
| 15373 | Oliver Antman | Rangers FC (2026-04-12) | RSC Anderlecht | evet | roster |  |
| 15391 | Yves Bissouma | Tottenham Hotspur (2026-07-01) | Ajax Amsterdam | evet | roster |  |
| 15413 | Giovanni Reyna | Borussia Mönchengladbach (2026-05-16) | RC Strasbourg Alsace | evet | roster |  |
| 15455 | Oleg Reabciuk | Spartak Moscow (2026-07-01) | RSC Anderlecht | evet | roster |  |
| 15482 | Morten Hjulmand | Sporting CP (2026-05-16) | Atlético de Madrid | evet | roster+sporx |  |
| 16059 | Jorge Sánchez | PAOK Thessaloniki (2026-03-22) | Atlas Guadalajara | evet | roster |  |
| 16061 | Karim Adeyemi | Borussia Dortmund (2026-05-16) | FC Barcelona | evet | roster+sporx | 22+ 7 |
| 16063 | Yan Couto | Borussia Dortmund (2026-05-16) | Como 1907 | evet | roster |  |
| 16094 | Christos Tzolis | Club Brugge KV (2026-05-24) | Arsenal FC | evet | roster+sporx | 40 Milyon Euro |
| 16100 | Ertuğrul Taşkıran | Alanyaspor (2026-01-31) | Erzurumspor FK | evet | roster |  |
| 16112 | Thijs Dallinga | Bologna FC 1909 (2026-05-23) | 1.FC Köln | evet | roster |  |
| 16125 | Fran García | Real Madrid (2026-05-17) | Real Betis Balompié | evet | roster |  |
| 16137 | Alexander Schwolow | Heart of Midlothian FC (2026-04-11) | 1.FSV Mainz 05 | evet | roster |  |
| 16140 | Jack Butland | Rangers FC (2026-04-12) | Hull City | evet | roster+sporx | - |
| 16170 | Yann Gboho | FC Toulouse (2026-05-10) | Coventry City | evet | roster |  |
| 16175 | Liam Henderson | FC Empoli (2025-05-25) | Falkirk FC | hayır | roster |  |
| 16196 | Savinho | Manchester City (2026-05-24) | Tottenham Hotspur | evet | sporx | 87.5 milyon Euro + 11 milyon euro (bonus) |
| 16197 | Sebastiaan Bornauw | Leeds United (2026-05-24) | Hamburger SV | evet | roster |  |
| 16704 | Arno Verschueren | Twente Enschede FC (2026-05-17) | SK Beveren | evet | roster |  |
| 16711 | Orel Mangala | Olympique Lyon (2026-05-17) | Getafe CF | evet | roster |  |
| 16721 | Danilo Barbosa | Botafogo FC (2025-06-28) | Grêmio Foot-Ball Porto Alegrense | hayır | roster |  |
| 16732 | Troy Parrott | AZ Alkmaar (2026-05-17) | Real Betis Balompié | evet | roster+sporx | 16 milyon euro |
| 16755 | Maxence Lacroix | Crystal Palace (2026-05-17) | Chelsea FC | evet | roster+sporx | 60.7 milyon euro |
| 16759 | Thomas Ouwejan | NEC Nijmegen (2026-02-04) | Machida Zelvia | evet | roster |  |
| 16768 | Ivan Ilić | Torino FC (2026-03-01) | US Lecce | evet | roster |  |
| 16772 | Miguel Gutiérrez | Napoli (2026-05-24) | Bayer 04 Leverkusen | evet | roster+sporx | 26 milyon euro |
| 16773 | Nick Woltemade | Newcastle United (2026-05-24) | Juventus FC | evet | roster+sporx | Kiralık (3.60 milyon euro) |
| 16775 | Ricardo Mangas | Sporting CP (2026-05-16) | AC Monza | evet | roster |  |
| 16780 | Rochinha | FC Famalicão (2025-10-05) | Casa Pia AC | hayır | roster |  |
| 16788 | Kévin Rodrigues | Gaziantep FK (2026-07-01) | Genclerbirligi Ankara | evet | roster |  |
| 16789 | Daniel Bragança | Sporting CP (2026-05-16) | Torino FC | evet | roster |  |
| 16799 | Pablo Maffeo | RCD Mallorca (2026-05-23) | Valencia CF | evet | roster |  |
| 16800 | Andoni Gorosabel | Athletic Bilbao (2026-05-23) | RCD Espanyol Barcelona | evet | roster |  |
| 17456 | Michel-Ange Balikwisha | Celtic FC (2026-01-18) | KAA Gent | evet | roster |  |
| 17467 | Maghnes Akliouche | Monaco (2026-05-17) | Paris Saint-Germain | evet | roster |  |
| 17536 | Pelle Clement | Sparta Rotterdam (2026-07-01) | FC Groningen | evet | roster |  |
| 17549 | Furkan Soyalp | Kayserispor (2026-05-17) | Amed SK | evet | roster |  |
| 17550 | Mohamed-Ali Cho | OGC Nice (2026-05-17) | Hull City | evet | roster+sporx | 13 milyon euro + bonuslar |
| 17551 | Jean-Luc Dompé | Hamburger SV (2026-03-21) | Konyaspor | evet | roster |  |
| 17560 | Ahmed Touba | Panathinaikos FC (2026-03-22) | Le Havre AC | evet | roster+sporx | Kiralık |
| 17573 | Exequiel Palacios | Bayer 04 Leverkusen (2026-05-16) | Ipswich Town | evet | roster |  |
| 17598 | Diego Rico | Getafe CF (2026-05-03) | CA Osasuna | evet | roster |  |
| 17615 | Ousmane Diomande | Sporting CP (2026-05-11) | Nottingham Forest | evet | roster+sporx | 40 Milyon Euro |
| 17617 | Robert Sánchez | Chelsea FC (2026-05-24) | Como 1907 | evet | roster |  |
| 18303 | Roberto Piccoli | ACF Fiorentina (2026-05-22) | Bologna FC 1909 | evet | roster |  |
| 18323 | Ernest Poku | Bayer 04 Leverkusen (2026-05-09) | Besiktas JK | evet | roster |  |
| 18331 | Rick van Drongelen | Samsunspor (2026-05-16) | Panathinaikos FC | evet | sporx | 6,5 milyon euro |
| 18333 | Jean-Clair Todibo | West Ham United (2026-05-17) | RC Lens | evet | roster |  |
| 18344 | Mohamed Amoura | VfL Wolfsburg (2026-05-16) | OGC Nice | evet | roster |  |
| 18367 | Umut Bozok | Eyüpspor (2026-07-01) | Basaksehir FK | evet | roster |  |
| 18379 | Ivan Provedel | SS Lazio (2026-03-04) | Inter Milan | evet | roster |  |
| 18385 | Diogo Leite | 1.FC Union Berlin (2026-07-01) | SS Lazio | evet | roster |  |
| 18387 | Lyle Foster | Burnley FC (2026-05-10) | Houston Dynamo FC | evet | roster |  |
| 18391 | Félix Correia | LOSC Lille (2026-05-17) | Sevilla FC | evet | roster |  |
| 18397 | Samet Akaydin | Caykur Rizespor (2026-05-09) | Trabzonspor | evet | roster |  |
| 18414 | Niklas Dorsch | 1.FC Heidenheim 1846 (2026-05-16) | Toronto FC | evet | roster |  |
| 18935 | Giulian Biancone | Olympiacos Piraeus (2026-03-22) | RSC Anderlecht | evet | roster |  |
| 18937 | André Almeida | Valencia CF (2026-05-23) | Racing Santander | evet | roster |  |
| 18950 | Kevin Akpoguma | TSG 1899 Hoffenheim (2026-07-01) | Frosinone Calcio | evet | roster |  |
| 18956 | Jhon Durán | Al-Nassr Football Club (açık) | SL Benfica | evet | roster+sporx | Satın alma opsiyonlu kiralık |
| 18962 | Marvin Peersman | FC Groningen (2026-05-17) | SC Telstar | evet | roster |  |
| 18965 | Ismael Saibari | PSV Eindhoven (2026-05-17) | Bayern Munich | evet | roster+sporx | 50 milyon euro |
| 18972 | Sven Mijnans | AZ Alkmaar (2026-05-17) | PSV Eindhoven | evet | roster |  |
| 18977 | Samuele Ricci | AC Milan (2026-05-17) | Como 1907 | evet | roster |  |
| 18987 | Kamil Grabara | VfL Wolfsburg (2026-05-16) | Juventus FC | evet | roster+sporx | Kiralık |
| 19042 | Youssoufa Moukoko | FC Copenhagen (2026-03-07) | Corum FK | evet | roster |  |
| 19043 | Umut Meraş | Eyüpspor (2026-05-17) | Amed SK | evet | roster |  |
| 19050 | Iván Martín | Girona FC (2026-05-23) | Racing Santander | evet | roster |  |
| 19051 | Couhaib Driouech | PSV Eindhoven (2026-05-17) | Celta de Vigo | evet | roster |  |
| 19066 | Marash Kumbulla | AS Roma (açık) | Rayo Vallecano | evet | roster+sporx | Kiralık |
| 19098 | Brian Mansilla | Akhmat Grozny (2026-05-10) | FC Arouca | evet | roster |  |
| 19702 | Iliman Ndiaye | Everton FC (2026-05-24) | Manchester City | evet | roster+sporx | 70 Milyon Euro |
| 19725 | Serdar Dursun | Kocaelispor (2026-07-01) | Gaziantep FK | evet | roster |  |
| 19744 | Güven Yalçın | Alanyaspor (2026-05-16) | Kasimpasa | evet | roster |  |
| 19750 | Bruno Duarte | Red Star Belgrade (2026-02-26) | Clube de Regatas Vasco da Gama | evet | roster |  |
| 19854 | Bersant Celina | AIK (2025-08-14) | Al-Ettifaq Football Club | hayır | roster |  |
| 19857 | Benoît Badiashile | Chelsea FC (2026-03-07) | SSC Napoli | evet | roster+sporx | Kiralik + (27 milyon euro satın alma opsiyonu var) |
| 19859 | Harry Winks | Leicester City (2025-03-16) | Cagliari Calcio | evet | roster+sporx | - |
| 19906 | Elisha Owusu | AJ Auxerre (2026-05-17) | Erzurumspor FK | evet | roster |  |
| 19920 | Arnau Martínez | Girona FC (2026-05-23) | Valencia CF | evet | roster |  |
| 20432 | Juriën Gaari | RKC Waalwijk (2024-07-01) | Abha | hayır | roster |  |
| 20444 | Lorenzo Montipò | Hellas Verona (2026-05-24) | Venezia FC | evet | roster |  |
| 20452 | Djed Spence | Tottenham Hotspur (2026-05-24) | Inter Milan | evet | roster+sporx | 35 Milyon Euro |
| 20460 | Matthis Abline | FC Nantes (2026-05-08) | AS Monaco | evet | roster+sporx | 25+5 milyon euro |
| 20474 | Juanlu Sánchez | Sevilla FC (2026-05-17) | AFC Bournemouth | evet | roster+sporx | 11 milyon euro |
| 20478 | Jan Paul van Hecke | Brighton & Hove Albion (2026-05-24) | Tottenham Hotspur | evet | roster+sporx | 60 milyon euro |
| 20482 | Jordan Lotomba | Feyenoord Rotterdam (2026-05-10) | Celtic FC | evet | roster |  |
| 20485 | Berat Özdemir | Basaksehir FK (2026-03-07) | Corum FK | evet | roster |  |
| 20495 | Lesley Ugochukwu | Burnley FC (2026-05-24) | Galatasaray | evet | roster |  |
| 20500 | Kevin Rodríguez | Union Saint-Gilloise (2026-05-24) | Union St. Gilloise | evet | roster |  |
| 20585 | Casper Tengstedt | Feyenoord Rotterdam (2026-05-17) | FC Toulouse | evet | roster |  |
| 20586 | Axel Tuanzebe | Burnley FC (2026-05-24) | AJ Auxerre | evet | roster |  |
| 20606 | Christian Burgess | Union Saint-Gilloise (2026-07-01) | KAA Gent | evet | roster |  |
| 20611 | Dominik Livakovic | Fenerbahce (açık) | FC Barcelona | evet | sporx | - |
| 20612 | Eray Cömert | Valencia CF (2026-05-17) | Torino FC | evet | roster |  |
| 20630 | Josip Sutalo | Ajax Amsterdam (2026-05-10) | SS Lazio | evet | roster |  |
| 20654 | Michele Di Gregorio | Juventus FC (2026-05-17) | AFC Bournemouth | evet | roster+sporx | Kiralık |
| 20681 | Eduard Spertsyan | FC Krasnodar (2026-05-17) | Al-Ahli Saudi Football Club | evet | roster+sporx | 21.9 milyon Euro |
| 21234 | Liam Delap | Chelsea FC (2026-05-24) | Nottingham Forest | evet | roster+sporx | 52 milyon sterlin |
| 21248 | Alexandre Penetra | AZ Alkmaar (2026-05-17) | Corum FK | evet | roster |  |
| 21262 | Ahmed Kutucu | Galatasaray (2026-05-17) | Caykur Rizespor | evet | roster |  |
| 21272 | Eduardo | AO Xanthi (2020-03-01) | V-Varen Nagasaki | hayır | roster |  |
| 21289 | David Bates | Standard Liège (2026-05-23) | Amed SK | evet | roster |  |
| 21474 | Toni Borevković | Samsunspor (2026-05-09) | Vitória Guimarães SC | evet | sporx | Satın alma opsiyonlu kiralık |
| 21497 | Oliver Sørensen | Parma Calcio 1913 (2026-05-24) | Celtic FC | evet | roster |  |
| 21506 | Mateus Fernandes | West Ham United (2026-05-24) | Tottenham Hotspur | evet | roster+sporx | 100 milyon euro |
| 21519 | Anouar Ait El Hadj | Union Saint-Gilloise (2026-05-24) | Union St. Gilloise | evet | roster |  |
| 21530 | Wilfried Kanga | KAA Gent (2026-05-24) | Al-Fateh | evet | roster |  |
| 21540 | Conrad Harder | RB Leipzig (2026-05-16) | RC Strasbourg Alsace | evet | roster+sporx | Kiralık |
| 21550 | Niclas Eliasson | AEK Athens (2026-03-22) | Sport Club Internacional | evet | roster |  |
| 21556 | Ethan Pinnock | Brentford FC (2026-03-21) | Coventry City | evet | roster |  |
| 21561 | Luis Milla | Getafe CF (2026-05-23) | Como 1907 | evet | roster |  |
| 21562 | Keito Nakamura | Stade Reims (2025-05-10) | Olympique Lyon | hayır | roster |  |
| 22042 | Radu Drăgușin | Tottenham Hotspur (2026-05-24) | ACF Fiorentina | evet | roster |  |
| 22047 | Tosin Adarabioyo | Chelsea FC (2026-05-04) | Tottenham Hotspur | evet | roster |  |
| 22059 | Bryan Reynolds | KVC Westerlo (2026-05-23) | Stade Rennais FC | evet | roster |  |
| 22065 | Chimy Ávila | Real Betis Balompié (2026-05-23) | Independiente | evet | roster |  |
| 22067 | Henrique Araújo | SL Benfica (2025-11-09) | Casa Pia AC | hayır | roster |  |
| 22075 | Cedric Itten | Fortuna Düsseldorf (2025-10-29) | SV Werder Bremen | hayır | roster |  |
| 22216 | Thierry Correia | Valencia CF (2026-05-23) | Venezia FC | evet | roster+sporx | Bedelsiz |
| 22240 | Giannis Konstantelias | PAOK Thessaloniki (2026-04-25) | Borussia Dortmund | evet | roster+sporx | 26 milyon euro |
| 22258 | Andreas Hanche-Olsen | 1.FSV Mainz 05 (2025-12-21) | Chicago Fire FC | hayır | roster |  |
| 22266 | Samú Costa | RCD Mallorca (2026-05-23) | Al-Nassr Football Club | evet | roster |  |
| 22283 | Erencan Yardımcı | TSG 1899 Hoffenheim (açık) | 1.FC Kaiserslautern | evet | sporx | Kiralık |
| 22288 | Lassine Sinayoko | AJ Auxerre (2026-05-17) | Paris FC | evet | roster+sporx | 8 Milyon Euro |
| 22309 | Sydney van Hooijdonk | CF Estrela Amadora (2026-05-16) | PEC Zwolle | evet | roster |  |
| 22313 | António Silva | SL Benfica (2026-05-11) | AFC Bournemouth | evet | roster+sporx | 25+5 milyon euro |
| 22724 | Tolu Arokodare | Wolverhampton Wanderers (2026-05-24) | Ajax Amsterdam | evet | roster |  |
| 22757 | Nicolas Kühn | Como 1907 (2026-04-26) | Borussia Mönchengladbach | evet | roster |  |
| 22781 | Carlo Holse | Samsunspor (2026-05-16) | St. Louis CITY SC | evet | roster+sporx | 6 milyon dolar |
| 22944 | Louis Patris | Union Saint-Gilloise (2026-05-21) | Union St. Gilloise | evet | roster |  |
| 22945 | Fabio Miretti | Juventus FC (2026-05-24) | Besiktas JK | evet | roster |  |
| 22948 | Amar Dedić | SL Benfica (2026-05-16) | Newcastle United | evet | roster+sporx | 34.5 milyon euro |
| 22977 | Elye Wahi | Eintracht Frankfurt (açık) | OGC Nice | evet | sporx | Kiralık |
| 22996 | Felix Uduokhai | Besiktas JK (2026-05-01) | 1.FC Union Berlin | evet | roster+sporx | 1.5 milyon euro |
| 23012 | Anel Ahmedhodzic | Feyenoord Rotterdam (2026-03-22) | Burnley FC | evet | sporx | 7 milyon euro |
| 23015 | Leonardo Balerdi | Olympique Marseille (2026-05-17) | AS Roma | evet | roster+sporx | 1 milyon euro kiralama bedeli, 20 milyon euro satın alma ops |
| 23019 | David Møller Wolfe | Wolverhampton Wanderers (2026-05-24) | Hamburger SV | evet | roster |  |
| 23026 | Michal Skoras | KAA Gent (2026-05-21) | RC Lens | evet | roster+sporx | 6 milyon euro |
| 23029 | Adem Zorgane | Union Saint-Gilloise (2026-05-24) | Union St. Gilloise | evet | roster |  |
| 23043 | Lilian Brassier | Stade Rennais FC (2026-05-03) | Eintracht Frankfurt | evet | roster |  |
| 23430 | Anthony Musaba | Fenerbahce (2026-05-17) | Norwich City | evet | sporx | Kiralık |
| 23432 | Charles Vanhoutte | OGC Nice (2026-05-17) | Feyenoord Rotterdam | evet | roster |  |
| 23437 | Tanguy Nianzou | Sevilla FC (2026-04-05) | LOSC Lille | evet | roster |  |
| 23463 | Artem Bondarenko | Shakhtar Donetsk (2026-05-21) | Al-Ahli Saudi Football Club | evet | roster |  |
| 23475 | Thomas Kristensen | Udinese Calcio (2026-05-24) | Atalanta BC | evet | roster |  |
| 23476 | Can Bozdogan | FC Utrecht (2026-05-02) | Caykur Rizespor | evet | roster |  |
| 23487 | Dirk Proper | NEC Nijmegen (2026-05-17) | SC Heerenveen | evet | roster |  |
| 23566 | Elliot Anderson | Nottingham Forest (2026-05-24) | Manchester City | evet | roster+sporx | 135 Milyon Euro |
| 23591 | Youssef Maziz | Oud-Heverlee Leuven (2026-07-01) | Colorado Rapids | evet | roster |  |
| 23598 | Costinha | Olympiacos Piraeus (2026-03-22) | Brighton & Hove Albion | evet | roster |  |
| 23610 | Loum Tchaouna | Burnley FC (2026-05-24) | Coventry City | evet | roster |  |
| 23642 | Ebrima Colley | BSC Young Boys (2025-11-06) | Konyaspor | hayır | roster |  |
| 23650 | Altay Bayındır | Manchester United (2025-09-27) | Celta de Vigo | evet | roster+sporx | Kiralık |
| 23664 | Akor Adams | Sevilla FC (2026-05-23) | Venezia FC | evet | roster |  |
| 24135 | Koki Ogawa | NEC Nijmegen (2026-05-17) | Machida Zelvia | evet | roster |  |
| 24137 | Allahyar Sayyadmanesh | KVC Westerlo (2026-05-19) | Lech Poznan | evet | sporx | Bedelsiz |
| 24150 | Perr Schuurs | Torino FC (2023-10-21) | NEC Nijmegen | hayır | roster |  |
| 24173 | Gianluca Gaetano | Cagliari Calcio (2026-05-24) | Atalanta BC | evet | roster |  |
| 24334 | Lukas Haraslin | AC Sparta Prague (2025-08-27) | Al-Fateh | hayır | roster |  |
| 24351 | Thiago Almada | Atlético de Madrid (2026-05-17) | CA River Plate | evet | roster+sporx | 20 Milyon Euro |
| 24368 | David Datro Fofana | Chelsea FC (açık) | Servette FC | evet | sporx | - |
| 24371 | Nathan Patterson | Everton FC (2026-05-04) | Torino FC | evet | roster |  |
| 24396 | Konrad Michalak | Panetolikos GFS (2026-03-22) | Eyüpspor | evet | roster |  |
| 24790 | Samuel Mbangula | SV Werder Bremen (2026-05-16) | Bologna FC 1909 | evet | roster |  |
| 24810 | Andrey Santos | Chelsea FC (2026-05-19) | Manchester United | evet | roster+sporx | - 55 milyon euro bonservis  - 2.5 milyon euro bonus  - Sonra |
| 24812 | Mory Konaté | KV Mechelen (2026-07-01) | Al-Hazem Sport Club | evet | roster |  |
| 24823 | Konstantinos Koulierakis | VfL Wolfsburg (2026-05-16) | AS Roma | evet | roster+sporx | 16,5 milyon euro |
| 24837 | Jawad El Yamiq | Real Zaragoza (2026-07-01) | Eyüpspor | evet | roster |  |
| 25101 | Quilindschy Hartman | Burnley FC (2026-05-01) | RCD Espanyol Barcelona | evet | roster |  |
| 25103 | Alidu Seidu | Stade Rennais FC (2026-05-10) | OGC Nice | evet | roster |  |
| 25110 | Rayan Raveloson | BSC Young Boys (2026-01-22) | Amed SK | evet | roster |  |
| 25151 | Guéla Doué | RC Strasbourg Alsace (2026-05-17) | Bayer 04 Leverkusen | evet | roster |  |
| 25180 | Dani Gómez | Valencia CF (2025-01-03) | FC Tokyo | hayır | roster |  |
| 25210 | Jan Zamburek | Heracles Almelo (2026-05-17) | ADO Den Haag | evet | roster |  |
| 25211 | Alan Forrest | Heart of Midlothian FC (2026-07-01) | Dundee FC | evet | roster |  |
| 25580 | Darío Osorio | FC Midtjylland (2026-03-19) | Crystal Palace | evet | roster |  |
| 25584 | Franjo Ivanović | SL Benfica (2026-05-11) | RC Lens | evet | roster+sporx | Kiralık (2.5 milyon euro) |
| 25600 | Isak Jensen | AZ Alkmaar (2026-05-17) | FC Lorient | evet | roster |  |
| 25605 | Roberts Uldrikis | Arminia Bielefeld (2025-02-25) | SC Heerenveen | hayır | roster |  |
| 25639 | Michael Zetterer | Eintracht Frankfurt (2026-05-16) | Leeds United | evet | roster |  |
| 25846 | Richard Ríos | SL Benfica (2026-05-16) | Al-Ittihad Football Club | evet | roster+sporx | Kiralık |
| 25854 | Jota Silva | Nottingham Forest (açık) | Olympiacos Piraeus | evet | sporx | -  Olympiacos, Nottingham Forest'tan Jota Silva'yı satın alm |
| 25867 | Miguel Crespo | Basaksehir FK (2026-05-16) | Al-Khaleej Club (Saihat) | evet | sporx | - |
| 25873 | Matias Fernandez-Pardo | LOSC Lille (2026-05-17) | Newcastle United | evet | roster+sporx | 60 milyon euro |
| 25879 | Emin Bayram | KVC Westerlo (2026-05-23) | Basaksehir FK | evet | roster |  |
| 25897 | Ole Romeny | Oxford United (2026-02-15) | Fortuna Sittard | evet | roster |  |
| 25903 | Mory Diaw | Le Havre AC (2026-05-17) | Al-Shabab Club | evet | roster |  |
| 25912 | Duk | CD Leganés (2025-12-04) | Atlas Guadalajara | hayır | roster |  |
| 25925 | Josh Campbell | Hibernian FC (2026-04-04) | St. Johnstone FC | evet | roster |  |
| 25952 | Cameron Archer | Southampton FC (2025-05-25) | AJ Auxerre | hayır | roster |  |
| 26309 | Zé Carlos | Gil Vicente FC (2026-07-01) | Rio Ave FC | evet | roster |  |
| 26317 | Yusuf Barası | Kasimpasa (2025-12-21) | Eyüpspor | hayır | roster |  |
| 26347 | Daam Foulon | Royal Antwerp FC (2026-05-23) | Antwerp | evet | roster |  |
| 26352 | Nathaniel Brown | Eintracht Frankfurt (2026-05-16) | Bayern Munich | evet | roster+sporx | 50 milyon euro |
| 26719 | Makana Baku | Atromitos Athens (2026-03-22) | Kocaelispor | evet | roster |  |
| 26722 | Gökdeniz Bayrakdar | Bodrum FK (2025-06-01) | Göztepe | hayır | roster |  |
| 26731 | Malick Fofana | Olympique Lyon (2026-05-17) | Sunderland AFC | evet | roster+sporx | 30 Milyon Euro |
| 26732 | Serdar Saatçı | Trabzonspor (2025-12-22) | Corum FK | hayır | roster |  |
| 26751 | Jean-Mattéo Bahoya | Eintracht Frankfurt (2026-05-16) | Leeds United | evet | roster |  |
| 26765 | Ethan Nwaneri | Arsenal FC (açık) | Borussia Dortmund | evet | roster+sporx | Kiralık |
| 26766 | Benjamin Tahirović | Bröndby IF (2026-03-01) | KRC Genk | evet | roster |  |
| 26786 | Gaëtan Coucke | KV Mechelen (2024-07-01) | Cercle Brugge | hayır | roster |  |
| 26787 | Gökhan Sazdağı | Besiktas JK (2026-04-05) | Corum FK | evet | roster |  |
| 26832 | Crysencio Summerville | West Ham United (2026-05-24) | Al-Hilal Saudi Football Club | evet | roster+sporx | 65 milyon euro + 12 milyon euro |
| 26845 | Ibrahim Salah | FC Basel 1893 (2026-01-29) | Antwerp | evet | roster |  |
| 26866 | Laurent Abergel | FC Lorient (2026-05-17) | OGC Nice | evet | roster |  |
| 27136 | James Penrice | AEK Athens (2026-03-15) | Rangers FC | evet | roster |  |
| 27140 | Arnaud Bodart | LOSC Lille (2026-03-22) | Le Havre AC | evet | roster |  |
| 27193 | Tyrell Malacia | Manchester United (2026-07-01) | FC Cincinnati | evet | roster |  |
| 27211 | Vanja Drkusic | Zenit S-Pb (2026-05-17) | RCD Espanyol Barcelona | evet | roster |  |
| 27215 | Ryan Strain | Dundee United FC (2026-07-01) | Falkirk FC | evet | roster |  |
| 27224 | Festy Ebosele | Basaksehir FK (2026-03-14) | Erzurumspor FK | evet | roster |  |
| 27225 | Badredine Bouanani | VfB Stuttgart (2026-04-26) | Rangers FC | evet | roster |  |
| 27418 | Dejan Ljubicic | GNK Dinamo Zagreb (2026-01-22) | FC Schalke 04 | evet | roster |  |
| 27427 | Adil Aouchiche | Aberdeen FC (2026-01-18) | FC Schalke 04 | evet | roster |  |
| 27430 | Rodinei | Olympiacos Piraeus (2026-03-22) | Santos FC | evet | roster |  |
| 27436 | Santiago Castro | Bologna FC 1909 (2026-05-23) | AS Roma | evet | roster+sporx | 35 milyon euro |
| 27446 | Kjell Scherpen | Union Saint-Gilloise (2026-05-24) | Ipswich Town | evet | roster |  |
| 27462 | Abdoulaye Seck | Maccabi Haifa (2026-07-01) | Al-Faisaly | evet | roster |  |
| 27469 | Alan | Moreirense FC (2026-07-01) | Vitória Guimarães SC | evet | roster |  |
| 27474 | Dário Essugo | Chelsea FC (2026-05-19) | RC Strasbourg Alsace | evet | roster |  |
| 27510 | Zeno Van Den Bosch | Royal Antwerp FC (2026-07-01) | 1.FC Union Berlin | evet | roster |  |
| 27537 | Charlie Cresswell | FC Toulouse (2026-05-10) | Stade Rennais FC | evet | roster |  |
| 27542 | Gabriel Pereira | FC Copenhagen (2026-03-07) | Clube de Regatas Vasco da Gama | evet | roster |  |
| 27545 | Filip Krovinovic | HNK Hajduk Split (2025-08-14) | Grêmio Foot-Ball Porto Alegrense | hayır | roster |  |
| 27547 | Nazinho | Cercle Brugge (2026-05-09) | AS Monaco | evet | roster |  |
| 27548 | Shawn Adewoye | Fortuna Sittard (2026-04-25) | Lommel SK | evet | roster |  |
| 27795 | Rafik Belghali | Hellas Verona (2026-05-24) | Torino FC | evet | roster |  |
| 27801 | Armel Bella-Kotchap | Hellas Verona (2026-05-24) | Venezia FC | evet | roster+sporx | 7 milyon euro |
| 27813 | Sam Johnstone | Wolverhampton Wanderers (2026-03-06) | Celtic FC | evet | roster |  |
| 27820 | Abdelhamid Sabiri | ACF Fiorentina (2026-07-01) | Eyüpspor | evet | roster |  |
| 27828 | Leo Sauer | Feyenoord Rotterdam (2026-03-22) | VfB Stuttgart | evet | roster |  |
| 27842 | André Vidigal | CS Marítimo (2023-05-27) | FC Alverca | hayır | roster |  |
| 27860 | Santiago Bueno | Wolverhampton Wanderers (2026-05-24) | CF América | evet | roster |  |
| 28132 | Cisse Sandra | Club Brugge KV (2026-05-24) | KVC Westerlo | evet | roster |  |
| 28138 | Everton | CR Flamengo (2025-06-25) | Santos FC | hayır | roster |  |
| 28153 | Zian Flemming | Burnley FC (2026-05-24) | Ipswich Town | evet | roster |  |
| 28163 | Aleksa Terzic | Red Bull Salzburg (2025-12-11) | Frosinone Calcio | hayır | roster |  |
| 28164 | Elias Jelert | Southampton FC (2026-02-14) | Le Havre AC | evet | roster+sporx | 1 yıllık kiralık |
| 28166 | Gabriel Silva | CD Santa Clara (2026-05-16) | SC Braga | evet | roster |  |
| 28197 | Zion Suzuki | Parma Calcio 1913 (2026-05-17) | Aston Villa | evet | roster+sporx | 30+5 milyon euro |
| 28198 | Álvaro Rodríguez | Elche CF (2026-05-23) | AFC Bournemouth | evet | roster+sporx | 25 milyon euro |
| 28203 | Matteo Ruggeri | Atlético de Madrid (2026-05-24) | Aston Villa | evet | roster+sporx | 25 milyon euro + 1.5 milyon euro bonus |
| 28209 | Miguel Rodríguez | FC Utrecht (2026-03-06) | Deportivo Alavés | evet | roster |  |
| 28211 | Arthur Atta | Udinese Calcio (2026-05-24) | ACF Fiorentina | evet | roster |  |
| 28232 | Aral Şimşir | FC Midtjylland (2026-03-19) | Trabzonspor | evet | roster |  |
| 28511 | Mathieu Maertens | Oud-Heverlee Leuven (2026-07-01) | SC Cambuur Leeuwarden | evet | roster |  |
| 28515 | Lucas Gourna-Douath | Red Bull Salzburg (açık) | Hull City | evet | roster+sporx | 4 Milyon Euro |
| 28517 | Unai Gómez | Athletic Bilbao (2026-05-23) | Udinese Calcio | evet | roster |  |
| 28554 | Donovan Léon | AJ Auxerre (2026-05-17) | Abha | evet | roster |  |
| 28578 | Illan Meslier | Leeds United (2026-07-01) | Arsenal FC | evet | roster+sporx | Bedelsiz |
| 28586 | Kasper Høgh | FK Bodø/Glimt (2026-03-17) | Celtic FC | evet | roster+sporx | 13 milyon euro |
| 28930 | Kevin Mac Allister | Union Saint-Gilloise (2026-05-24) | Union St. Gilloise | evet | roster |  |
| 28938 | Anthony Valencia | Royal Antwerp FC (2026-05-19) | CR Flamengo | evet | roster |  |
| 28958 | Jaouen Hadjam | BSC Young Boys (2025-12-11) | Brighton & Hove Albion | evet | roster+sporx | 13 milyon euro |
| 29035 | Sontje Hansen | Middlesbrough FC (2026-01-10) | Gaziantep FK | evet | roster |  |
| 29295 | Gautier Lloris | Le Havre AC (2026-05-17) | Stade Brestois 29 | evet | roster |  |
| 29341 | Ibrahim Sadiq | AZ Alkmaar (2026-03-22) | Colorado Rapids | evet | roster |  |
| 29642 | Jacopo Fazzini | ACF Fiorentina (2026-05-04) | Cagliari Calcio | evet | roster |  |
| 29644 | Dion Lopy | UD Almería (2025-10-29) | Al-Ittihad Football Club | hayır | roster |  |
| 29647 | Kennedy Boateng | FC Dinamo 1948 (2026-07-01) | Al-Fateh | evet | roster |  |
| 29648 | Rodrigo Mora | FC Porto (2026-05-16) | AS Roma | evet | roster+sporx | 25 M€ bonservis, Sonraki satıştan %50 pay, Satış payını kapa |
| 29649 | Fernando Calero | RCD Espanyol Barcelona (2026-07-01) | Málaga CF | evet | roster |  |
| 29656 | Karl Darlow | Leeds United (2026-05-24) | Manchester United | evet | roster+sporx | Bedelsiz |
| 29675 | Johan Manzambi | SC Freiburg (2026-05-16) | Aston Villa | evet | roster+sporx | 60 milyon euro  Aston Villa, Manzambi için bonuslarla 70 mil |
| 29678 | Aske Adelgaard | Go Ahead Eagles (2026-05-10) | Twente Enschede FC | evet | roster |  |
| 29701 | Rodrigo Abascal | Vitória Guimarães SC (2026-05-16) | Al-Riyadh Saudi Club | evet | roster |  |
| 29712 | Promise David | Union Saint-Gilloise (2026-02-21) | Brighton & Hove Albion | evet | roster+sporx | - |
| 29724 | André Luiz | Olympiacos Piraeus (2026-03-01) | Sporting Kansas City | evet | roster |  |
| 29730 | Mamadou Sangaré | RC Lens (2026-05-13) | Brentford FC | evet | roster+sporx | 48 milyon euro  - Mamadou Sangare, Brentford'un bir futbolcu |
| 29744 | Amine El Ouazzani | SC Braga (2026-05-03) | Angers SCO | evet | roster |  |
| 30046 | Willem Geubbels | Paris FC (2026-05-17) | US Lecce | evet | roster |  |
| 31322 | Angus Gunn | Nottingham Forest (2026-07-01) | San Jose Earthquakes | evet | roster |  |
| 32117 | Tim Iroegbunam | Everton FC (2026-05-24) | Hull City | evet | roster+sporx | 15.15 Milyon Euro |
| 32438 | Taylor Harwood-Bellis | Southampton FC (2025-05-18) | Aston Villa | evet | roster+sporx | 29 + 5.8 milyon Euro |
| 34553 | Marc Guiu | Chelsea FC (2026-04-21) | RB Leipzig | evet | roster |  |
| 35270 | El Chadaille Bitshiabu | RB Leipzig (2026-05-02) | Galatasaray | evet | roster |  |
| 36345 | Ahmetcan Kaplan | Ajax Amsterdam (açık) | NEC Nijmegen | evet | sporx | - |
| 39167 | Adam Aznou | Everton FC (2026-01-10) | Málaga CF | evet | roster+sporx | Kiralık |
| 46663 | David Odogu | AC Milan (2026-03-21) | FC Toulouse | evet | roster |  |
| 48453 | Robinio Vaz | AS Roma (2026-05-24) | Hull City | evet | roster+sporx | Kiralık |
| 50089 | Renato Marin | PSG (2026-05-10) | CD Nacional | evet | roster |  |
| - | Axel Witsel | Girona FC (2026-05-23) | OGC Nice | evet | roster |  |
| - | João Mário | Besiktas JK (açık) | AEK Athens | evet | sporx |  |
| - | Trezeguet | Al Ahly (2025-06-24) | Al-Riyadh Saudi Club | hayır | roster |  |
| - | Malcom | Al-Hilal Saudi Football Club (2025-07-04) | Al-Jazira | evet | sporx | - |
| - | Eljif Elmas | RB Leipzig (açık) | Atalanta BC | evet | roster+sporx | Satın alma opsiyonlu kiralık |
| - | Francisco Trincão | Sporting CP (2026-05-16) | Al-Ahli Saudi Football Club | evet | roster+sporx | 39.35 milyon euro |
| - | Abdul Fatawu | Leicester City (2024-11-10) | Ipswich Town | evet | roster+sporx | 23.4 Milyon Euro |
