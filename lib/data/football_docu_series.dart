import '../models/story_scene.dart';

final List<StoryChapter> footballDocuSeriesPart1Chapters = [
  StoryChapter(
    number: 1,
    title: "1'e 5000: Peri Masalı",
    matchLabel: 'Leicester City | 2015-2016 Premier Lig',
    narrative:
        "Bir önceki sezon kümede kalma mücadelesi veren, bahis şirketlerinin şampiyonluğuna 1'e 5000 oran verdiği Claudio Ranieri'li Leicester City'nin Premier Lig devlerini darmadağın ederek şampiyon olması. Futbol tarihinin en büyük spor mucizesi.",
    scenes: [
      StoryScene.namedAnswer(
        title: 'Yılın Oyuncusu ve Rekor Golcü',
        taskDescription:
            'O sezon Premier Lig\'de Yılın Oyuncusu seçilen Cezayirli kanat yıldızını ve rekor kıran golcü santrforu tahmin et.',
        correctAnswers: ['Riyad Mahrez', 'Jamie Vardy'],
      ),
      StoryScene.commonPlayers(
        title: 'Ortak İsimler',
        taskDescription:
            'Hem Chelsea hem de Leicester City formasını giymiş ortak oyuncuları bul.',
        clubIdA: 631,
        clubIdBOptions: [1003],
        requiredFinds: 2,
      ),
    ],
  ),
  StoryChapter(
    number: 2,
    title: 'Bir Şehrin Dirilişi',
    matchLabel: 'Napoli | 1986-1987 Serie A',
    narrative:
        "İtalya'nın zengin kuzey takımlarına (Juventus, Milan, Inter) karşı fakir güneyin isyanı.",
    scenes: [
      StoryScene.namedAnswer(
        title: '10 Numara',
        taskDescription:
            "Napoli'ye tarihinin ilk lig şampiyonluğunu kazandıran Arjantinli 10 numarayı tahmin et.",
        correctAnswers: ['Diego Maradona'],
      ),
      StoryScene.commonPlayers(
        title: 'Kuzey-Güney Bağı',
        taskDescription:
            'Napoli ile Juventus, Milan veya Inter\'den herhangi birinde birlikte oynamış ortak oyuncuları bul.',
        clubIdA: 6195,
        clubIdBOptions: [506, 5, 46],
        requiredFinds: 3,
      ),
    ],
  ),
  StoryChapter(
    number: 3,
    title: 'AGÜEROOOOOO!',
    matchLabel: '2012 Premier Lig Son Hafta | Manchester City 3-2 QPR',
    narrative:
        "Manchester City'nin 44 yıl sonra lig şampiyonu olması için galibiyet gerekiyordu. Maç 91. dakikaya 2-1 geride girildi. 91+2'de Džeko eşitledi, 93+2'de Sergio Agüero attı ve spikerin \"AGÜEROOOOO\" haykırışıyla kupa Manchester United'ın elinden sökülüp alındı.",
    scenes: [
      StoryScene.namedAnswer(
        title: 'Asist ve Eşitlik Golü',
        taskDescription:
            "Agüero'ya o efsanevi 93+2. dakika golünde asisti yapan ve uzatmalarda 2-2'yi getiren kafa golünü atan futbolcuları tahmin et.",
        correctAnswers: ['Mario Balotelli', 'Edin Džeko'],
      ),
      StoryScene.commonPlayers(
        title: 'City & QPR',
        taskDescription:
            'O tarihi maçta karşı karşıya gelen Manchester City ve QPR (Queens Park Rangers) kulüplerinin her ikisinde de forma giymiş bir ortak oyuncu bul.',
        clubIdA: 281,
        clubIdBOptions: [1039],
        requiredFinds: 1,
      ),
    ],
  ),
  StoryChapter(
    number: 4,
    title: "Sınıfın En İyileri: Class of '92",
    matchLabel: 'Manchester United | 1992-1999',
    narrative:
        "Sir Alex Ferguson'un 'Çocuklarla hiçbir şey kazanamazsınız' eleştirilerine aldırış etmeden kulüp altyapısından yetiştirip sahaya sürdüğü efsanevi jenerasyon. 1999'da Camp Nou'da Bayern Münih'e karşı uzatmalarda gelen 2 golle Treble (3 Kupa) yapan Manchester United mucizesi.",
    scenes: [
      StoryScene.namedAnswer(
        title: 'Korner Asistleri',
        taskDescription:
            'O efsanevi 1999 Şampiyonlar Ligi finalinde 90+1 ve 90+3. dakikalarda gelen korner gollerinde asistleri/pasları veren "Class of \'92" üyesi sağ ayaklı efsanevi kanat oyuncusunu tahmin et.',
        correctAnswers: ['David Beckham'],
      ),
    ],
  ),
  StoryChapter(
    number: 5,
    title: 'Yenilgisizler: The Invincibles',
    matchLabel: 'Arsenal | 2003-2004 Premier Lig',
    narrative:
        "İngiltere Premier Lig tarihinde bir sezonda oynadığı 38 maçın hiçbirini kaybetmeden (26 Galibiyet, 12 Beraberlik) Altın Kupa'yı müzesine götüren tek takım. Arsène Wenger'in kusursuz işleyen hücum makinesi.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Invincibles & Barcelona',
        taskDescription:
            'Hem Arsenal "Invincibles" kadrosunda yer almış hem de kariyerinde FC Barcelona forması giymiş ortak oyunculardan birini tahmin et.',
        clubIdA: 11,
        clubIdBOptions: [131],
        requiredFinds: 1,
      ),
    ],
  ),
  StoryChapter(
    number: 6,
    title: 'Şüphelenden İnanana (From Skeptics to Believers)',
    matchLabel: "Klopp'un Liverpool'u | 2018-2020",
    narrative:
        "30 yıllık Premier Lig şampiyonluk hasretine son veren, 2019'da Camp Nou'daki 3-0'ın rövanşında Barcelona'yı Anfield'da 4-0 devirerek Şampiyonlar Ligi'ni kazanan Jürgen Klopp'un tutku dolu Heavy-Metal futbolu.",
    scenes: [
      StoryScene.namedAnswer(
        title: 'Çabuk Alınan Korner',
        taskDescription:
            "Barcelona karşısındaki 4-0'lık efsanevi rövanş maçında, korneri hızlıca kullanarak Origi'ye o unutulmaz asisti yapan İngiliz sağ beki tahmin et.",
        correctAnswers: ['Trent Alexander-Arnold'],
      ),
    ],
  ),
  StoryChapter(
    number: 7,
    title: 'Gençlik Aşısı ve Total Futbol',
    matchLabel: "Louis van Gaal'ın Ajax'ı | 1994-1995",
    narrative:
        "Altyapı akademisinden çıkan çocukların dünya futbolunu fethettiği an! Seedorf, Kluivert, Davids, Litmanen ve De Boer kardeşli Ajax; Şampiyonlar Ligi Finali'nde Capello'nun rüya takımı AC Milan'ı devirerek Avrupa'nın zirvesine çıktı.",
    scenes: [
      StoryScene.namedAnswer(
        title: '18 Yaşında Şampiyon',
        taskDescription:
            '1995 Şampiyonlar Ligi Finali\'nde 85. dakikada maça girip AC Milan\'a galibiyet golünü atan ve kupa kazandığında henüz 18 yaşında olan Hollandalı santrforu tahmin et.',
        correctAnswers: ['Patrick Kluivert'],
      ),
    ],
  ),
  StoryChapter(
    number: 8,
    title: "Avrupa'yı Titreten Kent Kulübü",
    matchLabel: 'Nottingham Forest | 1978-1980',
    narrative:
        "İngiltere 2. Ligi'nden çıkıp önce Premier Lig şampiyonu olan, ardından ÜST ÜSTE İKİ KEZ Şampiyon Kulüpler Kupası'nı (Şampiyonlar Ligi) kazanan futbol tarihinin en büyük kulüp mucizesi.",
    scenes: [
      StoryScene.namedAnswer(
        title: 'Aykırı Dahi',
        taskDescription:
            "Nottingham Forest'ı 2. Lig'den alıp üst üste 2 kez Avrupa Şampiyonu yapan, futbol dünyasının en renkli ve aykırı teknik direktörünü tahmin et.",
        correctAnswers: ['Brian Clough'],
      ),
    ],
  ),
];

final List<StoryChapter> footballDocuSeriesPart2Chapters = [
  StoryChapter(
    number: 9,
    title: 'Özel Biri ve Porto Rüyası',
    matchLabel: "José Mourinho'nun Porto'su | 2002-2004",
    narrative:
        "Bir teknik adamın doğuşu! José Mourinho yönetimindeki Porto'nun kısıtlı bütçeyle önce UEFA Kupası'nı (2003), hemen ardından Old Trafford devrimiyle Şampiyonlar Ligi'ni (2004) kazanarak Avrupa devlerine diz çöktürmesi.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Porto & Chelsea',
        taskDescription:
            'O efsanevi Porto kadrosunda yer alıp Şampiyonlar Ligi zaferinden sonra Mourinho ile birlikte Chelsea\'ye transfer olan ortak oyunculardan birini tahmin et.',
        clubIdA: 720,
        clubIdBOptions: [631],
        requiredFinds: 1,
      ),
    ],
  ),
  StoryChapter(
    number: 10,
    title: 'Beton Prensip ve Üçlü Kupa',
    matchLabel: "José Mourinho'nun Inter'i | 2009-2010",
    narrative:
        "Camp Nou'da 10 kişi kalıp Guardiola'nın Barcelona'sına karşı tarihin en ikonik savunma performansını sergileyen ve İtalyan futbol tarihinde 'Treble' (Serie A, İtalya Kupası, Şampiyonlar Ligi) yapan tek takım.",
    scenes: [
      StoryScene.namedAnswer(
        title: "Treble'ın Mimarı",
        taskDescription:
            "O sezon hem Barcelona'ya karşı yarı finalde hem de Bayern Münih'e karşı finalde hayati goller atarak Treble'ın mimarı olan Arjantinli santrforu tahmin et.",
        correctAnswers: ['Diego Milito'],
      ),
    ],
  ),
  StoryChapter(
    number: 11,
    title: 'Sözleşmeyi Bozan Duygu',
    matchLabel: "Diego Simeone'nin Atletico Madrid'i | 2013-2014 La Liga",
    narrative:
        "Real Madrid ve Barcelona'nın 10 yıllık ambargosunu kıran Çolchonerolar! Diego Simeone'nin 'Cholismo' felsefesiyle Camp Nou'da son hafta Godín'in kafa golüyle La Liga Şampiyonu olan ve Şampiyonlar Ligi Finali'ne yükselen çelik savunmalı takım.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Atletico & Barcelona',
        taskDescription:
            'O sezon Atletico Madrid ile La Liga şampiyonu olup ertesi yıllarda FC Barcelona forması da giyen ortak oyuncuları tahmin et.',
        clubIdA: 13,
        clubIdBOptions: [131],
        requiredFinds: 2,
      ),
    ],
  ),
  StoryChapter(
    number: 12,
    title: 'Çelik Perde ve Peri Masalı',
    matchLabel: 'Kaiserslautern | 1997-1998',
    narrative:
        "Dünya futbol tarihinde eşi benzeri görülmemiş bir başarı: Almanya 2. Ligi'nden şampiyon olarak Bundesliga'ya çıktığı İLK SEZONDA Bayern Münih'in önünde Bundesliga Şampiyonu olan Kaiserslautern.",
    scenes: [
      StoryScene.namedAnswer(
        title: 'İleride EURO Kazanacak Hoca',
        taskDescription:
            'Bu peri masalını yazan ve 6 yıl sonra Yunanistan Milli Takımı ile EURO 2004 mucizesini gerçekleştirecek olan efsanevi teknik direktörü tahmin et.',
        correctAnswers: ['Otto Rehhagel'],
      ),
    ],
  ),
  StoryChapter(
    number: 13,
    title: 'Mucizeler Ligi ve Bir Şehrin İsyanı',
    matchLabel: 'Montpellier | 2011-2012 Ligue 1',
    narrative:
        "Katar sermayesinin PSG'ye aktığı ve Ancelotti, Pastore gibi yıldızların transfer edildiği ilk sezonda; mütevazı bütçeli Montpellier'nin dev bütçeli PSG'yi geride bırakarak kulüp tarihinin ilk ve tek Ligue 1 şampiyonluğunu kazanması.",
    scenes: [
      StoryScene.namedAnswer(
        title: 'Gol Kralı',
        taskDescription:
            "O sezon Montpellier formasıyla 21 gol atarak gol kralı olan ve ertesi sezon Arsenal'a transfer olan Fransız santrforu tahmin et.",
        correctAnswers: ['Olivier Giroud'],
      ),
    ],
  ),
  StoryChapter(
    number: 14,
    title: 'La Fabrica vs La Masia: 5-0\'lık El Clásico',
    matchLabel: '2010 | Barcelona 5-0 Real Madrid',
    narrative:
        "Mourinho'nun Real Madrid'inin Camp Nou'da Guardiola'nın Barcelona'sına karşı ağır hezimete uğradığı gece. Futbol sahasında bir takımın pas trafiği ve dominantlıkla rakibini çaresiz bıraktığı en ikonik 90 dakika.",
    scenes: [
      StoryScene.namedAnswer(
        title: 'Manita',
        taskDescription:
            'O tarihi maçta gol atıp ardından "Manita" (5 parmak) hareketiyle galibiyeti kutlayan İspanyol defans oyuncusunu tahmin et.',
        correctAnswers: ['Gerard Piqué'],
      ),
    ],
  ),
  StoryChapter(
    number: 15,
    title: "Wembley'de Bir Masal",
    matchLabel: "1976 | Trabzonspor 1-0 Liverpool",
    narrative:
        "Anadolu'dan çıkan bir devin Avrupa Şampiyonu Liverpool'a diz çöktürdüğü gece. Trabzon'da Hüseyin Avni Aker Stadı'nda Kevin Keegan'lı Liverpool'u 1-0 mağlup eden Trabzonspor'un tarihe geçen ilk büyük Avrupa zaferi.",
    scenes: [
      StoryScene.namedAnswer(
        title: 'Penaltı Golü',
        taskDescription:
            'O maçta penaltıdan attığı golle tarihi galibiyeti getiren Trabzonspor efsanesini tahmin et.',
        correctAnswers: ['Kadir Özcan'],
      ),
    ],
  ),
  StoryChapter(
    number: 16,
    title: "İtalya'nın Çelik Duvarı ve Mucize",
    matchLabel: 'Sampdoria | 1990-1991 Serie A',
    narrative:
        "I Gemelli del Gol, Maradona'lı Napoli'yi, Van Basten'li Milan'ı ve Matthäus'lu Inter'i geride bırakarak kulüp tarihinin ilk ve tek Serie A Şampiyonluğunu kazandığı efsanevi sezon.",
    scenes: [
      StoryScene.namedAnswer(
        title: 'Gol İkizleri',
        taskDescription:
            'O Sampdoria kadrosunun efsanevi hücum ikilisini oluşturan ve ilerleyen yıllarda İtalya Milli Takımı\'nı teknik heyette EURO 2020 şampiyonu yapacak olan ikiliden birini tahmin et.',
        correctAnswers: ['Roberto Mancini'],
      ),
    ],
  ),
];