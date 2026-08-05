import '../models/player_journey.dart';
import '../repositories/repository.dart';
import '../utils/career_overlap.dart';

Set<int> _premierLeagueClubIds() {
  return Repository.instance.clubs
      .where((c) => c.league == 'Premier League')
      .map((c) => c.id)
      .toSet();
}

final PlayerJourneyDefinition ronaldoJourney = PlayerJourneyDefinition(
  id: 'ronaldo',
  subjectName: 'Cristiano Ronaldo',
  subjectPlayerId: 8198,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: "Lizbon'dan Manchester'a",
      subtitle: '2002 - 2006',
      narrative:
          "Genç bir yetenek Madeira'dan çıktı, Sporting CP'de parladı ve Sir Alex Ferguson'ın dikkatini çekti...",
      taskDescription:
          "Ronaldo'nun Sporting CP ve Manchester United'daki ilk yıllarında birlikte oynadığı oyuncuları bul. ",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 336, 2002, 2003) ||
          playedAtClubDuring(p, 985, 2003, 2006),
    ),
    PlayerJourneyStage(
      title: "Rüyalar Tiyatrosu ve İlk Ballon d'Or",
      subtitle: '2006 - 2009',
      narrative:
          "Premier Lig'i sallayan, 7 numarayı efsaneleştiren ve ilk Şampiyonlar Ligi zaferini yaşayan dönem...",
      taskDescription:
          "2008 Moskova finalindeki Manchester United kadrosundan ya da o dönem Premier Lig'de oynayıp aynı zamanda Portekiz Milli Takımı'nda forma giyen oyunculardan bul.",
      requiredFinds: 3,
      isValidTeammate: (p) {
        final playedManUtd = playedAtClubDuring(p, 985, 2006, 2009);
        final playedPLAndPortugal = p.primaryNationalTeamId == 3300 &&
            playedInClubSetDuring(p, _premierLeagueClubIds(), 2006, 2009);
        return playedManUtd || playedPLAndPortugal;
      },
    ),
    PlayerJourneyStage(
      title: 'Galáctico ve Şampiyonlar Ligi Ambargosu',
      subtitle: '2009 - 2018',
      narrative:
          "Santiago Bernabéu'da 80 bin kişinin karşıladığı, rekorları altüst eden ve 4 Şampiyonlar Ligi kaldıran Real Madrid dönemi...",
      taskDescription:
          "Real Madrid'in o efsanevi dönemindeki (2009-2018) takım arkadaşlarını bul.",
      requiredFinds: 4,
      isValidTeammate: (p) => playedAtClubDuring(p, 418, 2009, 2018),
    ),
    PlayerJourneyStage(
      title: 'İtalya, Milli Gurur ve Son Dans',
      subtitle: '2018 - Günümüz',
      narrative:
          "Juventus zaferleri, Portekiz ile Euro 2016 kupası ve tarihin en çok gol atan oyuncusu unvanı...",
      taskDescription:
          "Ronaldo'nun Juventus'taki ya da Portekiz Milli Takımı'ndaki takım arkadaşlarını bularak hikayeyi %100 tamamla!",
      requiredFinds: 4,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 506, 2018, 2021) ||
          p.primaryNationalTeamId == 3300,
    ),
  ],
);

final PlayerJourneyDefinition ibrahimovicJourney = PlayerJourneyDefinition(
  id: 'ibrahimovic',
  subjectName: 'Zlatan Ibrahimović',
  subjectPlayerId: 3455,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: "İskandinavya'dan Amsterdam'a",
      subtitle: '1999 - 2004',
      narrative:
          "Malmö sokaklarında tekniğiyle yetişen kibirli genç adam, Ajax formasıyla NAC Breda'ya attığı o efsanevi 'çalım golü' ile tüm dünyaya adını duyuruyor...",
      taskDescription:
          "Zlatan'ın Ajax'taki ilk yıllarında soyunma odasını paylaştığı ve kariyerinin ilerleyen dönemlerinde başka kulüplerde de karşısına çıkan ortak arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 496, 1999, 2001) ||
          playedAtClubDuring(p, 610, 2001, 2004),
    ),
    PlayerJourneyStage(
      title: 'İtalya Sahnesinde Hükümranlık',
      subtitle: '2004 - 2012',
      narrative:
          "İtalya Serie A'yı domine eden adam. Juventus, Inter ve AC Milan formalarıyla İtalya'da şampiyonluk yaşayıp, arada Barcelona'da Guardiola ile kısa bir hesaplaşma kapatıyor...",
      taskDescription:
          "Zlatan'ın İtalya'daki dev kulüplerde aynı anda oynadığı dünya yıldızları ve Barcelona'daki kısa döneminde  kesişen ortak bağlarını çöz.",
      requiredFinds: 4,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 506, 2004, 2006) ||
          playedAtClubDuring(p, 46, 2006, 2009) ||
          playedAtClubDuring(p, 131, 2009, 2010) ||
          playedAtClubDuring(p, 5, 2010, 2012),
    ),
    PlayerJourneyStage(
      title: "Paris'in Kralı",
      subtitle: '2012 - 2016',
      narrative:
          "'Kral gibi geldim, efsane gibi gidiyorum.' Zlatan, PSG projesinin vitrin yüzü oluyor ve Fransa futbolunu tek başına baştan yazıyor...",
      taskDescription:
          "Zlatan'ın PSG'deki en parlak döneminde birlikte oynadığı oyuncuları ya da İsveç Milli Takımı'ndaki ortak takım arkadaşlarını tespit et.",
      requiredFinds: 4,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 583, 2012, 2016) ||
          p.primaryNationalTeamId == 3557,
    ),
    PlayerJourneyStage(
      title: 'Rüyalar Tiyatrosu ve Kapanış',
      subtitle: '2016 - 2023',
      narrative:
          "35 yaşında Premier Lig'e geçip Manchester United ile kupa kaldırdı, Amerika'yı (LA Galaxy) fethetti ve geri dönüp AC Milan'ı 11 yıl sonra tekrar şampiyon yaparak jübilesini yaptı...",
      taskDescription:
          "Zlatan'ın kariyerinin bu son döneminde genç yıldızlarla ve eski dostlarıyla kurduğu son ortak oyuncu ağını tamamla!",
      requiredFinds: 4,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 985, 2016, 2018) ||
          playedAtClubDuring(p, 1061, 2018, 2020) ||
          playedAtClubDuring(p, 5, 2020, 2023),
    ),
  ],
);

final PlayerJourneyDefinition ardaTuranJourney = PlayerJourneyDefinition(
  id: 'arda_turan',
  subjectName: 'Arda Turan',
  subjectPlayerId: 21369,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: "Ali Sami Yen'in Çocuğu",
      subtitle: '2004 - 2008',
      narrative:
          "Bayrampaşa sokaklarında başlayan bir rüya... Galatasaray altyapısından çıkıp, Manisaspor'daki kısa kiralık dönemi sonrası Florya'ya dönen ve henüz 21 yaşında Galatasaray kaptanı olan o genç yetenek...",
      taskDescription:
          "Arda'nın Manisaspor'da birlikte kiralık oynadığı ya da Galatasaray'a dönüp şampiyonluk yaşarken soyunma odasını paylaştığı efsanevi isimlerle ortak bağlantıları kur.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 141, 2004, 2008) ||
          playedAtClubDuring(p, 1267, 2004, 2008),
    ),
    PlayerJourneyStage(
      title: 'Euro 2008 Mucizesi ve Liderlik',
      subtitle: '2008 - 2011',
      narrative:
          "İsviçre'ye son dakikada atılan gol, Yağmur altındaki Cenevre mucizeleri... Arda Turan, Türkiye'yi Avrupa 3.'sü yapan jenerasyonun kalbi ve Türk futbolunun Avrupa'ya ihraç edeceği en büyük değer haline geliyor...",
      taskDescription:
          "Arda'nın 2008 Milli Takımı'ndaki efsanevi kadro arkadaşları ile aynı dönemde Galatasaray'da beraber forma giydiği yabancı yıldızların ortak ağlarını çöz.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 141, 2008, 2011) ||
          p.primaryNationalTeamId == 3381,
    ),
    PlayerJourneyStage(
      title: "Vicente Calderón'un 10 Numarası",
      subtitle: '2011 - 2015',
      narrative:
          "Simeone'nin Atletico Madrid'inde savaşçı bir 10 numara. Real Madrid ve Barcelona hegemonyasını yıkarak kazanılan La Liga şampiyonluğu, UEFA Kupası ve Şampiyonlar Ligi Finali...",
      taskDescription:
          "Arda Turan'ın Atletico Madrid'de birlikte tarih yazdığı dünya yıldızlarını ve onlarla aynı kulüpte oynamış ortak oyuncuları bağla.",
      requiredFinds: 4,
      isValidTeammate: (p) => playedAtClubDuring(p, 13, 2011, 2015),
    ),
    PlayerJourneyStage(
      title: 'Camp Nou Rüyası ve Yuvaya Dönüş',
      subtitle: '2015 - 2022',
      narrative:
          "41 milyon Euro bonservis bedeliyle Barcelona'ya transfer olan ilk Türk futbolcu! Messi, Iniesta ve Neymar ile aynı sahada kupalar kaldırdıktan sonra, hikaye başladığı yerde, Ali Sami Yen'de kapanıyor...",
      taskDescription:
          "Arda'nın Barcelona'daki rüya kadro arkadaşlarını ya da kariyerinin son döneminde Galatasaray ve Milli Takım'da beraber oynadığı oyuncuları bularak hikayeyi %100 tamamla!",
      requiredFinds: 4,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 131, 2015, 2018) ||
          playedAtClubDuring(p, 6890, 2018, 2020) ||
          playedAtClubDuring(p, 141, 2020, 2022) ||
          p.primaryNationalTeamId == 3381,
    ),
  ],
);

final PlayerJourneyDefinition messiJourney = PlayerJourneyDefinition(
  id: 'messi',
  subjectName: 'Lionel Messi',
  subjectPlayerId: 28003,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: 'Peçetedeki İmza ve La Masia',
      subtitle: '2000 - 2008',
      narrative:
          "Büyüme hormonu tedavisi için Arjantin'den Barcelona'ya uzanan çileli yol... Bir peçeteye atılan ilk imza, La Masia eğitimi ve Ronaldinho'nun sırtında Camp Nou'da atılan o ilk gol...",
      taskDescription:
          "Messi'nin Barcelona'daki ilk günlerinde ona abilik yapan yıldızları ya da Arjantin Genç Milli Takımı'nda birlikte şampiyonluk yaşadığı ortak arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) {
        final playedBarca =
            playedAtClubDuring(p, 2464, 2004, 2005) ||
            playedAtClubDuring(p, 131, 2005, 2008);
        final youthTeammate = p.nationalTeams
            .toSet()
            .intersection({11940, 53819})
            .isNotEmpty;
        return playedBarca || youthTeammate;
      },
    ),
    PlayerJourneyStage(
      title: 'Pep Guardiola ve Altın Çağ',
      subtitle: '2008 - 2015',
      narrative:
          "Futbol tarihinin gördüğü en dominant takım! Pep Guardiola yönetimindeki 10 numara Messi; 91 gollü akılalmaz sezon, 4 Ballon d'Or ve Şampiyonlar Ligi zaferleri...",
      taskDescription:
          "Barça'nın o efsanevi tiki-taka kadrosundaki ortak isimleri ve 2015'teki dönemindeki ortak takım arkadaşlarını bağla.",
      requiredFinds: 4,
      isValidTeammate: (p) => playedAtClubDuring(p, 131, 2008, 2015),
    ),
    PlayerJourneyStage(
      title: 'Milli Takım Çilesi ve Büyük Baskı',
      subtitle: '2014 - 2019',
      narrative:
          "Kulüp seviyesinde kazanılmadık kupa kalmazken Arjantin formasıyla gelen ardı ardına final mağlubiyetleri... 2014 Dünya Kupası Finali, üst üste kaybedilen Copa América'lar ve geçici milli takım veda kararı...",
      taskDescription:
          "Messi'nin o sancılı milli takım finallerinde birlikte forma giydiği Arjantin'li isimleri çöz.",
      requiredFinds: 4,
      isValidTeammate: (p) => p.primaryNationalTeamId == 3437,
    ),
    PlayerJourneyStage(
      title: "Katar'da Peri Masalı ve Son Dans",
      subtitle: '2021 - Günümüz',
      narrative:
          "Önce 2021 Copa América, ardından 2022 Katar Dünya Kupası! Futbolun, borçlu olduğu kupayı en büyük efsanesine teslim ettiği o an... PSG serüveni ve Miami'deki veda dansı...",
      taskDescription:
          "Messi'nin 2022 Dünya Kupası'nı kaldıran yeni jenerasyon arkadaşlarını ya da PSG/Inter Miami'deki ortak oyuncularını bularak hikayeyi %100 tamamla!",
      requiredFinds: 4,
      isValidTeammate: (p) =>
          p.primaryNationalTeamId == 3437 ||
          playedAtClubDuring(p, 583, 2021, 2023) ||
          playedAtClubDuring(p, 69261, 2023, 2025),
    ),
  ],
);

final PlayerJourneyDefinition drogbaJourney = PlayerJourneyDefinition(
  id: 'drogba',
  subjectName: 'Didier Drogba',
  subjectPlayerId: 3924,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: 'Fransa Alt Ligleri ve Geç Parlama',
      subtitle: '1998 - 2003',
      narrative:
          "Birçok yıldızın aksine genç yaşta değil, tırnaklarıyla kazıyarak yükselen bir hikaye... Fransa alt liglerinde başlayan, fiziki gücü ve hırsıyla basamakları adım adım tırmanan dirençli bir santrforun ilk adımları...",
      taskDescription:
          "Drogba'nın Fransa'daki ilk takımlarında (Le Mans, Guingamp) birlikte sahaya çıktığı ilk ortak arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 1164, 1998, 2003) ||
          playedAtClubDuring(p, 855, 1998, 2003),
    ),
    PlayerJourneyStage(
      title: 'Marseille Parlaması ve Londra Transferi',
      subtitle: '2003 - 2006',
      narrative:
          "Velodrome Stadyumu'nda yazılan tek sezonluk destan! Fransa'yı sallayıp UEFA Kupası'nda finale çıkan, ardından Portekizli teknik adamın ısrarıyla İngiltere'ye dev bir bonservisle adım atan bir güç abidesi...",
      taskDescription:
          "Drogba'nın Marsilya'daki o efsanevi sezonunda ve Chelsea'deki ilk şampiyonluklarında soyunma odasını paylaştığı ortak isimleri bağla.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 244, 2003, 2004) ||
          playedAtClubDuring(p, 631, 2004, 2006),
    ),
    PlayerJourneyStage(
      title: 'Münih Mucizesi ve Devler Ligi Zaferi',
      subtitle: '2006 - 2012',
      narrative:
          "Final maçlarının adamı! Çıktığı hemen hemen her kupa finalinde gol atan, Wembley'in kralı olan ve en sonunda Alman devinin kendi evindeki Şampiyonlar Ligi finalinde son dakika golü ve son penaltıyla kulübüne tarihinin ilk Devler Ligi kupasını getiren unutulmaz gece...",
      taskDescription:
          "Şampiyonlar Ligi zaferini kazanan o ikonik Chelsea kadrosundaki oyuncuları ya da Fildişi Sahili Milli Takımı'ndaki ortak yıldızları tespit et.",
      requiredFinds: 4,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 631, 2006, 2012) ||
          p.primaryNationalTeamId == 3591,
    ),
    PlayerJourneyStage(
      title: 'Kıtalararası Rekabet ve Jübile',
      subtitle: '2013 - 2018',
      narrative:
          "Çin macerasının ardından Türk futbolunun kalbine uzanan yolculuk... Real Madrid ve Juventus ağlarına bırakılan unutulmaz goller, ezeli rekabetlerde kaldırılan kupalar ve Amerika'da noktalanan efsanevi bir kariyer...",
      taskDescription:
          "Drogba'nın İstanbul'da (Galatasaray) geçirdiği şampiyonluk dolu dönemde birlikte oynadığı dünya yıldızlarını ya da kariyerinin son durağı Amerika'daki (CF Montréal) oyuncuları bularak son ortak ağı tamamla!",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 141, 2013, 2014) ||
          playedAtClubDuring(p, 4078, 2015, 2018),
    ),
  ],
);

final PlayerJourneyDefinition ronaldinhoJourney = PlayerJourneyDefinition(
  id: 'ronaldinho',
  subjectName: 'Ronaldinho',
  subjectPlayerId: 3373,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: 'Porto Alegre Sokakları ve Dünya Şampiyonluğu',
      subtitle: '1998 - 2002',
      narrative:
          "Salon futbolunda ve plajlarda top sektirerek başlayan, tekniğiyle Brezilya'yı kendine hayran bırakan bir gençlik... 2002 yılında Asya'da düzenlenen Dünya Kupası'nda İngiltere'ye attığı o akılalmaz uzak mesafe serbest vuruş golüyle dünya sahnesine çıkan bir efsanenin doğuşu...",
      taskDescription:
          "Ronaldinho'nun Brezilya'daki ilk kulübünde (Grêmio) birlikte forma giydiği isimleri ya da 2002 Dünya Kupası'nı kazanan efsanevi Samba kadrosundaki ortak arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 210, 1998, 2001) ||
          p.primaryNationalTeamId == 3439,
    ),
    PlayerJourneyStage(
      title: 'Avrupa\'ya İlk Adım ve Eyfel Kulesi',
      subtitle: '2001 - 2003',
      narrative:
          "Avrupa devlerinin radarına girip Fransa'nın yolunu tuttuğu dönem... Çalımları, elastik hareketleri ve Eyfel Kulesi gölgesindeki şovlarıyla Avrupa futboluna 'Joga Bonito' felsefesini tanıttığı ilk yıllar...",
      taskDescription:
          "Ronaldinho'nun Paris'teki (PSG) dönemi boyunca aynı soyunma odasını paylaştığı ortak oyuncuları bağla.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 583, 2001, 2003),
    ),
    PlayerJourneyStage(
      title: 'Bernabéu Alkışları ve Dünya Zirvesi',
      subtitle: '2003 - 2008',
      narrative:
          "Futbol tarihinin en ikonik dönemi! Katalan devini ayağa kaldıran, Santiago Bernabéu'da rakip taraftarlarına kendisini ayakta alkışlatan, Ballon d'Or kazanan ve genç bir Arjantinli yeteneğe ilk golünün asistini yapan o büyülü yıllar...",
      taskDescription:
          "Ronaldinho'nun Şampiyonlar Ligi'ni kaldırdığı o rüya Barcelona kadrosundaki takım arkadaşlarıyla ortak bağlantıları çöz.",
      requiredFinds: 4,
      isValidTeammate: (p) => playedAtClubDuring(p, 131, 2003, 2008),
    ),
    PlayerJourneyStage(
      title: 'İtalya Sahnesi ve Yuvada Son Samba',
      subtitle: '2008 - 2015',
      narrative:
          "İtalya'nın devinde diğer efsanelerle kurulan hücum hattı, ardından Brezilya'ya dönüş ve Libertadores Kupası zaferi... Sahadaki gülümsemesini hiç kaybetmeden, şovunu kupa ve jübileyle taçlandıran bir veda...",
      taskDescription:
          "Ronaldinho'nun Milano'daki (AC Milan) döneminde ya da kariyerinin son yıllarında Brezilya'ya dönüp kupa kaldırırken yanında olan son ortak oyuncu ağını tamamla.",
      requiredFinds: 4,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 5, 2008, 2011) ||
          playedAtClubDuring(p, 614, 2011, 2015) ||
          playedAtClubDuring(p, 330, 2011, 2015),
    ),
  ],
);

final PlayerJourneyDefinition modricJourney = PlayerJourneyDefinition(
  id: 'modric',
  subjectName: 'Luka Modrić',
  subjectPlayerId: 27992,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: 'Zor Zamanlar ve Dinamo Zagreb',
      subtitle: '2001 - 2008',
      narrative:
          "Savaşın gölgesinde geçen bir çocukluk, 'fiziksel olarak çok cılız' denilerek reddedilen ilk kulüpler... Kiralık günlerinden sonra Dinamo Zagreb'de oyun zekasıyla bir ülkenin en büyük yeteneğine dönüşen bir gencin direnç dolu ilk adımları...",
      taskDescription:
          "Modrić'in ilk yıllarında Dinamo Zagreb'de ya da kiralık gittiği kulüpte birlikte oynadığı ve kariyerinin ilerleyen yıllarında Avrupa'nın dev liglerinde de yolları kesişen ilk ortak arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 419, 2001, 2008) ||
          playedAtClubDuring(p, 918, 2001, 2008),
    ),
    PlayerJourneyStage(
      title: 'Kuzey Londra Sınavı ve Premier Lig Temposu',
      subtitle: '2008 - 2012',
      narrative:
          "İngiltere Premier Ligi'nin fiziksel sertliğine uyum sağlayamayacağı iddia edilen ama oyun zekası, pas açısı ve pres gücüyle Kuzey Londra ekibini Şampiyonlar Ligi sahnesine taşıyan orta saha orkestra şefliği dönemi...",
      taskDescription:
          "Modrić'in Tottenham'daki döneminde aynı soyunma odasını paylaştığı ve sonrasında dev kulüplere transfer olan ortak takım arkadaşlarını bağla.",
      requiredFinds: 3,
      isValidTeammate: (p) => playedAtClubDuring(p, 148, 2008, 2012),
    ),
    PlayerJourneyStage(
      title: 'Bernabéu Hanedanı ve 5 Devler Ligi Kupası',
      subtitle: '2012 - 2018',
      narrative:
          "Kötü başlayan ilk sezondan sonra kulüp tarihinin en başarılı dönemine damga vuran orta saha üçlüsünün beyni! Üst üste 3 kez, toplamda 5 kez Şampiyonlar Ligi kupasını kaldıran, 'La Décima' korner asistini yapan o efsanevi yıllar...",
      taskDescription:
          "Modrić'in Real Madrid'deki altın çağında birlikte tarih yazdığı efsanevi orta saha partnerlerini ve hücum hattındaki ortak oyuncularla bağları çöz.",
      requiredFinds: 4,
      isValidTeammate: (p) => playedAtClubDuring(p, 418, 2012, 2018),
    ),
    PlayerJourneyStage(
      title: 'Hırvatistan Mucizesi ve Ballon d\'Or Zaferi',
      subtitle: '2018 - Günümüz',
      narrative:
          "Küçük bir ülkenin kaptanı olarak 2018 Dünya Kupası'nda finale uzanan peri masalı... Messi ve Ronaldo dominasyonunu kırarak kazandığı Ballon d'Or ve 38 yaşında bile gençlere taş çıkartan efsanevi jübile adımları...",
      taskDescription:
          "Modrić'in Hırvatistan Milli Takımı ile Dünya Kupası finali/üçüncülüğü yaşarken yanında olan milli arkadaşlarını ya da son dönemdeki Real Madrid takım arkadaşlarını bularak hikayeyi %100 tamamla!",
      requiredFinds: 4,
      isValidTeammate: (p) =>
          p.primaryNationalTeamId == 3556 ||
          playedAtClubDuring(p, 418, 2018, 2025),
    ),
  ],
);

final PlayerJourneyDefinition henryJourney = PlayerJourneyDefinition(
  id: 'henry',
  subjectName: 'Thierry Henry',
  subjectPlayerId: 3207,
  available: true,
  stages: [
    PlayerJourneyStage(
      title: 'Monaco\'da Keşif ve Dünya Kupası Zaferi',
      subtitle: '1994 - 1998',
      narrative:
          "Fransız teknik adamın kanatta keşfettiği fırtına gibi hızlı bir genç... Monaco formasıyla sergilediği performansla dikkatleri çekip, henüz 20 yaşında kendi evlerindeki 1998 Dünya Kupası'nı kazanan Fransa kadrosunun en golcü ismi olan o ilk adımlar...",
      taskDescription:
          "Henry'nin Fransa'daki ilk kulübünde (Monaco) birlikte forma giydiği isimleri ya da 1998 Dünya Kupası'nı kazanan efsanevi Horozlar jenerasyonundaki ortak arkadaşlarını bul.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 162, 1994, 1998) ||
          p.primaryNationalTeamId == 3377,
    ),
    PlayerJourneyStage(
      title: 'İtalya Sınavı ve Londra\'da Santrfor Doğuşu',
      subtitle: '1999 - 2002',
      narrative:
          "Juventus'ta kanatta sıkışıp kalan kısa bir hayal kırıklığı... Ardından kendisini çok iyi tanıyan Fransız hocasıyla Kuzey Londra'da buluşma ve kanattan tarihin en zarif 9 numarasına dönüştürüldüğü o efsanevi değişim yılları...",
      taskDescription:
          "Henry'nin İtalya'daki (Juventus) kısa döneminde aynı soyunma odasını paylaştığı dünya yıldızlarını ya da Arsenal'e geldikten sonra birlikte kupa kaldırdığı ilk ortak oyuncuları bağla.",
      requiredFinds: 3,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 506, 1999, 2002) ||
          playedAtClubDuring(p, 11, 1999, 2002),
    ),
    PlayerJourneyStage(
      title: 'Kuzey Londra Yenilmezleri ve Krallık Tacı',
      subtitle: '2002 - 2007',
      narrative:
          "Premier Lig tarihinin en büyük efsanesi! Ligde namağlup şampiyon olan 'Yenilmezler' kadrosunun lideri, üst üste Gol Krallıkları, ceza sahası dışından attığı plase goller ve heykeli dikilen bir Kuzey Londra efsanesi...",
      taskDescription:
          "Henry'nin namağlup şampiyon olan o efsanevi Arsenal kadrosundaki takım arkadaşlarını ya da 2006 Şampiyonlar Ligi finaline yükselen ortak oyuncularla bağları çöz.",
      requiredFinds: 4,
      isValidTeammate: (p) => playedAtClubDuring(p, 11, 2002, 2007),
    ),
    PlayerJourneyStage(
      title: 'Camp Nou Zaferleri ve MLS Jübilesi',
      subtitle: '2007 - 2014',
      narrative:
          "Eksik kalan tek kupayı tamamlamak için Katalan devine transfer...Ölümcül hücum hattıyla gelen Şampiyonlar Ligi kupası, 6 kupalı sezon ve Amerika'da (New York) alkışlarla noktalanan bir jübile...",
      taskDescription:
          "Henry'nin Barcelona'daki 6 kupalı rüya sezonda birlikte oynadığı isimleri ya da kariyerinin son durağında (New York Red Bulls) soyunma odasını paylaştığı son ortak oyuncu ağını tamamla!",
      requiredFinds: 4,
      isValidTeammate: (p) =>
          playedAtClubDuring(p, 131, 2007, 2010) ||
          playedAtClubDuring(p, 623, 2010, 2014),
    ),
  ],
);

final List<PlayerJourneyDefinition> playerJourneys = [
  ronaldoJourney,
  ibrahimovicJourney,
  ardaTuranJourney,
  messiJourney,
  drogbaJourney,
  ronaldinhoJourney,
  modricJourney,
  henryJourney,
];