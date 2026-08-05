import '../models/story_scene.dart';

final List<StoryChapter> legendsPathPart1Chapters = [
  StoryChapter(
    number: 1,
    title: "Ya Messi 2021'de Barcelona'dan Ayrılıp Manchester City'ye Gitseydi?",
    narrative:
        "Barcelona'nın finansal çöküşü ve La Liga limitleri yüzünden Messi, çocukluğunun kulübüne veda etmek zorunda kaldı. PSG yerine Pep Guardiola ile yeniden buluşacağı Manchester City'yi seçseydi; Premier Lig'in fiziksel temposunda Pep'in kusursuz pas makinesinin merkezine oturacak ve Şampiyonlar Ligi zaferine Paris'te kaybettiği yılları harcamadan çok daha önce ulaşacaktı.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Taraf Kulüpler: FC Barcelona & Manchester City',
        taskDescription: 'Hem Barcelona hem Manchester City formasını giymiş bir ortak oyuncu bul.',
        clubIdA: 131,
        clubIdBOptions: [281],
      ),
    ],
  ),
  StoryChapter(
    number: 2,
    title: "Ya Cristiano Ronaldo Arsenal'e Gitseydi?",
    narrative:
        "2003'te Wenger, 9 numaralı Ronaldo formasını bile bastırmıştı. Ancak Arsenal yeni stadyum inşaatı nedeniyle bonservisi ödeyemeyince Sir Alex Ferguson araya girip oyuncuyu Manchester United'a kaptırdı.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Kaçırılan Yıldız',
        taskDescription:
            "Ronaldo'yu elinden kaçıran Arsenal ve efsane olduğu Manchester United formalarını giymiş ortak oyunculardan birini tahmin et.",
        clubIdA: 11,
        clubIdBOptions: [985],
      ),
    ],
  ),
  StoryChapter(
    number: 3,
    title: "Ya Lewandowski Volkan Patlaması Yüzünden Blackburn'e Gitmeseydi?",
    narrative:
        "2010'da Lewandowski Blackburn Rovers ile anlaştı, biletler alındı. Ancak İzlanda'daki kül bulutu nedeniyle uçuşlar iptal olunca transfer yattı ve oyuncu Dortmund'a imza atıp dünya yıldızı oldu.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Kül Bulutu Krizi',
        taskDescription:
            "Lewandowski'nin kaçırdığı Blackburn Rovers ve parladığı Borussia Dortmund formalarını giymiş ortak oyunculardan birini tahmin et.",
        clubIdA: 164,
        clubIdBOptions: [16],
      ),
    ],
  ),
  StoryChapter(
    number: 4,
    title: "Ya Steven Gerrard 2005'te Chelsea'ye Transfer Olsaydı?",
    narrative:
        "Gerrard, İstanbul'daki Şampiyonlar Ligi zaferinden hemen sonra Chelsea'ye transfer mektubu verdi. Şehirde formaları yakılınca son anda kaldı. Gitseydi, Premier Lig tarihinin en dominant orta saha hattı (Gerrard & Lampard) kurulacaktı.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Transfer Mektubu',
        taskDescription:
            "Gerrard'ın transferin eşiğinden döndüğü Liverpool ve Chelsea kulüplerinin HER İKİSİNDE DE forma giymiş ortak oyunculardan birini tahmin et.",
        clubIdA: 31,
        clubIdBOptions: [631],
      ),
    ],
  ),
  StoryChapter(
    number: 5,
    title: "Ya Neymar 2017'de Barcelona'dan Ayrılmasaydı?",
    narrative:
        "PSG 222 milyon Euro ödeyip Neymar'ı aldı. Neymar gitmeseydi Barça, Coutinho ve Dembélé'ye 300 milyon Euro harcayıp finansal çökmeye girmeyecek, MSN (Messi-Suarez-Neymar) üçlüsü tarihe ambargo koymaya devam edecekti.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Rekor Transfer',
        taskDescription:
            'Bu tarihin en pahalı transferinde karşı karşıya gelen Barcelona ve Paris Saint-Germain (PSG) formalarını giymiş ortak oyunculardan birini tahmin et.',
        clubIdA: 131,
        clubIdBOptions: [583],
      ),
    ],
  ),
  StoryChapter(
    number: 6,
    title: "Ya Zidane Blackburn Rovers'a Transfer Olsaydı?",
    narrative:
        "1995'te Dalglish Zidane'ı istedi ama kulüp başkanı \"Zidane'a ne gerek var, elimizde Tim Sherwood var\" diyerek transferi reddetti. Zidane da Premier Lig yerine Serie A ve La Liga tarihini yazmaya gitti.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Reddedilen Transfer',
        taskDescription:
            "Zidane'ın kapısından döndüğü Blackburn Rovers ve efsaneleştiği Real Madrid formalarını giymiş ortak oyunculardan birini tahmin et.",
        clubIdA: 164,
        clubIdBOptions: [418],
      ),
    ],
  ),
  StoryChapter(
    number: 7,
    title: "Ya Di Stéfano Real Madrid'e Değil Barcelona'ya Gitseydi?",
    narrative:
        "1953'te Di Stéfano Barcelona ile anlaşıp dostluk maçında Barça forması giydi. Ancak siyasi krizler sonrası Real Madrid oyuncuyu kaptı ve üst üste 5 Avrupa Kupası kazanarak \"Yüzyılın Kulübü\" oldu.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'El Clásico Krizi',
        taskDescription:
            'Di Stéfano savaşının yaşandığı Real Madrid ve Barcelona formalarını (El Clásico\'nun iki tarafını da) giymiş ortak efsanelerden birini tahmin et.',
        clubIdA: 418,
        clubIdBOptions: [131],
      ),
    ],
  ),
  StoryChapter(
    number: 8,
    title: "Ya Zlatan Ibrahimović Arsenal'de Seçmeleri Kabul Etseydi?",
    matchLabel: '2000',
    narrative:
        "19 yaşındaki Zlatan Malmö'deyken Arsène Wenger ona 9 numaralı Arsenal formasını giydirip \"Seni bir de deneme antrenmanında görelim\" dedi. Zlatan ise o tarihi cevabı verdi: \"Zlatan denenmez!\" ve transferi reddetti.",
    scenes: [
      StoryScene.commonPlayers(
        title: '"Zlatan Denenmez!"',
        taskDescription:
            "Zlatan'ın reddettiği Arsenal ve efsane olduğu AC Milan formalarını giymiş ortak oyunculardan birini tahmin et.",
        clubIdA: 11,
        clubIdBOptions: [5],
      ),
    ],
  ),
];

final List<StoryChapter> legendsPathPart2Chapters = [
  StoryChapter(
    number: 9,
    title: "Ya Wayne Rooney 2010'da Manchester City'ye Transfer Olsaydı?",
    matchLabel: '2010',
    narrative:
        "Rooney, Sir Alex Ferguson ile tartışıp kulübün hırsını sorguladı ve Man City'ye geçmek istediğini açıkladı. Şehirde taraftarlar evinin önüne dayanınca son anda çark edip rekor bir sözleşmeyle Man United'da kaldı.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Manchester Derbisi Krizi',
        taskDescription:
            'Rooney transfer krizinin tarafları olan Manchester United ve Manchester City formalarını (Manchester Derbisi\'nin iki tarafını) giymiş ortak oyunculardan birini tahmin et.',
        clubIdA: 985,
        clubIdBOptions: [281],
      ),
    ],
  ),
  StoryChapter(
    number: 10,
    title: "Ya Michael Laudrup 1983'te Liverpool'un Sözleşme Teklifini Kabul Etseydi?",
    narrative:
        "19 yaşındaki Danimarkalı dahi Laudrup, Liverpool ile 3 yıllık anlaşmaya vardı. Ancak Liverpool imza aşamasında süreyi 4 yıla çıkarınca tepki gösterip transferi masada bıraktı ve Juventus'a imza attı.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Masadan Kalkan Transfer',
        taskDescription:
            "Laudrup'ın masadan kalktığı Liverpool ve gittiği Juventus formalarını giymiş ortak oyunculardan birini tahmin et.",
        clubIdA: 31,
        clubIdBOptions: [506],
      ),
    ],
  ),
  StoryChapter(
    number: 11,
    title: "Ya Luka Modrić Newcastle United'a Transfer Olsaydı?",
    matchLabel: '2008',
    narrative:
        "Dinamo Zagreb'deyken Newcastle gözlemcileri Modrić'i izledi, ancak menajer Kevin Keegan \"çok fiziksiz ve küçük\" bularak vazgeçti. Modrić hemen ardından Tottenham'a, oradan Real Madrid'e geçerek Ballon d'Or kazandı.",
    scenes: [
      StoryScene.commonPlayers(
        title: '"Çok Fiziksiz" Denilen Dahi',
        taskDescription:
            "Modrić'i fiziksiz bulan Newcastle United ve Ballon d'Or kazandığı Real Madrid formalarını giymiş ortak oyunculardan birini tahmin et.",
        clubIdA: 762,
        clubIdBOptions: [418],
      ),
    ],
  ),
  StoryChapter(
    number: 12,
    title: "Ya Franco Baresi İnter Altyapısına Seçilseydi?",
    matchLabel: '1974',
    narrative:
        "Baresi çocukken Inter seçmelerine girdi ancak \"Çok çelimsiz ve kısa\" denilerek reddedildi. Ağabeyi Beppe Inter'e alındı. Baresi ise AC Milan'a gidip kulüp tarihinin en büyük efsane kaptanı oldu.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Derby della Madonnina',
        taskDescription:
            'Baresi krizinin ve Milano rekabetinin iki tarafı olan AC Milan ve Inter (Derby della Madonnina) formalarını giymiş ortak oyunculardan birini tahmin et.',
        clubIdA: 5,
        clubIdBOptions: [46],
      ),
    ],
  ),
  StoryChapter(
    number: 13,
    title: "Ya David Beckham 2003'te Real Madrid Yerine Barcelona'ya Gitseydi?",
    narrative:
        "Manchester United başkanı Joan Laporta ile Barcelona için el sıkıştı. Ancak Beckham menajeriyle birlikte tepki gösterip \"Ben sadece Real Madrid'e giderim\" dedi. Barcelona da bu kriz üzerine rotayı PSG'den Ronaldinho'ya kırdı!",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Rota Değişikliği',
        taskDescription:
            "Beckham'ın transfer krizinde karşı karşıya gelen Manchester United ve FC Barcelona formalarını giymiş ortak oyunculardan birini tahmin et.",
        clubIdA: 985,
        clubIdBOptions: [131],
      ),
    ],
  ),
  StoryChapter(
    number: 14,
    title: "Ya Didier Drogba 2002'de Arsenal'e Transfer Olsaydı?",
    narrative:
        "Arsène Wenger, Le Mans'da oynayan Drogba'yı yüzlerce kez izletti ancak \"Henüz hazır değil\" diyerek 100 bin sterline transfer etmedi. Drogba Guingamp ve Marsilya üzerinden Chelsea'ye gitti ve Wenger'in Arsenal'ine onlarca gol atıp kabusu oldu.",
    scenes: [
      StoryScene.commonPlayers(
        title: '"Henüz Hazır Değil"',
        taskDescription:
            "Drogba'nın kapısından döndüğü Arsenal ve efsanesi olduğu Chelsea formalarını giymiş ortak oyunculardan birini tahmin et.",
        clubIdA: 11,
        clubIdBOptions: [631],
      ),
    ],
  ),
  StoryChapter(
    number: 15,
    title: "Ya Pirlo 2010'da AC Milan'dan Real Madrid veya Chelsea'ye Gitseydi?",
    narrative:
        "Milan başkanı Galliani \"yaşlandı\" gerekçesiyle Pirlo'ya 1 yıllık sözleşme teklif etti. Pirlo teklifi reddedip bedelsiz Juventus'a gitti ve Juventus'un 9 yıllık şampiyonluk ambargosunu başlatan saha içi lideri oldu.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Bedelsiz Ayrılış',
        taskDescription:
            "Pirlo'nun bedelsiz geçtiği iki Ezeli Rakip olan AC Milan ve Juventus formalarını giymiş ortak oyunculardan birini tahmin et.",
        clubIdA: 5,
        clubIdBOptions: [506],
      ),
    ],
  ),
  StoryChapter(
    number: 16,
    title: "Ya Alan Shearer 1996'da Manchester United'a Transfer Olsaydı?",
    narrative:
        "EURO 96 sonrası Sir Alex Ferguson Shearer için çıldırdı ancak Shearer doğduğu şehrin takımı Newcastle United'ı seçti. Man United Cantona sonrası aradığı 9 numarayı bulmak için Eric Cantona/Ole Gunnar Solskjær ve Dwight Yorke rotasına kaydı.",
    scenes: [
      StoryScene.commonPlayers(
        title: "Şehrin Çocuğu",
        taskDescription:
            "Shearer'ın rekor kırarak gittiği Newcastle United ve reddettiği Manchester United formalarını giymiş ortak oyunculardan birini tahmin et.",
        clubIdA: 762,
        clubIdBOptions: [985],
      ),
    ],
  ),
];

final List<StoryChapter> legendsPathPart3Chapters = [
  StoryChapter(
    number: 17,
    title: 'Ya Marco van Basten Sakatlıklar Yüzünden 28 Yaşında Futbolu Bırakmak Zorunda Kalmasaydı?',
    narrative:
        "3 Ballon d'Or sahibi Hollandalı dahi, bilek sakatlıkları nedeniyle son resmi maçını 1993 Şampiyonlar Ligi Finali'nde oynadı ve 28 yaşında sahalardan uzak kaldı. Sakatlanmasaydı 90'ların sonuna kadar Milan ve Hollanda ambargosu devam edecekti.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Erken Biten Efsane',
        taskDescription:
            "Van Basten'in parladığı Ajax ve efsaneleştiği AC Milan formalarını giymiş ortak oyunculardan birini tahmin et.",
        clubIdA: 610,
        clubIdBOptions: [5],
      ),
    ],
  ),
  StoryChapter(
    number: 18,
    title: "Ya Ronaldo Nazário'nun Dizi Parçalanmasaydı?",
    narrative:
        "1999 ve 2000 yıllarında Inter forması giyerken diz tendonları kopan Ronaldo, kariyerinin en verimli 3 yılını sakatlıklarla geçirdi. O sakatlıklar olmasaydı, patlayıcı gücünü hiç kaybetmeden belki de Messi ve Cristiano seviyesinde kırılmadık rekor, kazanılmadık Ballon d'Or bırakmayacaktı.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Kırılan Diz',
        taskDescription:
            'Fenomen Ronaldo\'nun sakatlıklar öncesi İtalya\'da fırtınalar estirdiği Inter ve sakatlık dönüşü imza atıp "Galácticos" devrini başlattığı Real Madrid formalarını giymiş ortak oyunculardan birini tahmin et.',
        clubIdA: 46,
        clubIdBOptions: [418],
      ),
    ],
  ),
  StoryChapter(
    number: 19,
    title: "Ya Claude Makélélé 2003'te Real Madrid'den Chelsea'ye Satılmasaydı?",
    narrative:
        "Perez'in \"Maaşına zam yapmam, pas bile veremiyor\" diyerek sattığı Makéléle'nin ardından Real Madrid'in orta sahası çöktü. Zidane bu transfer için \"Siyah arabayı sattılar, altın kaplamalı motoru çöpe attılar\" dedi. Chelsea ise Makéléle ile Premier Lig'e ambargo koydu.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Taraf Kulüpler: Real Madrid & Chelsea FC',
        taskDescription: 'Hem Real Madrid hem Chelsea formasını giymiş bir ortak oyuncu bul.',
        clubIdA: 418,
        clubIdBOptions: [631],
      ),
    ],
  ),
  StoryChapter(
    number: 20,
    title: "Ya Chelsea Kevin De Bruyne ve Mohamed Salah'ı Satmasaydı?",
    narrative:
        "Jose Mourinho yönetimindeki Chelsea; yetersiz görüp Wolfsburg'a gönderdiği De Bruyne'ü ve Fiorentina'ya kiralayıp Roma'ya sattığı Salah'ı elden çıkardı. İki oyuncu birkaç yıl sonra Premier Lig'e dönüp Manchester City ve Liverpool formalarıyla lig tarihinin en baskın iki yıldızına dönüştü.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Taraf Kulüpler: Chelsea FC & Manchester City',
        taskDescription: 'Hem Chelsea hem Manchester City formasını giymiş bir ortak oyuncu bul.',
        clubIdA: 631,
        clubIdBOptions: [281],
      ),
    ],
  ),
  StoryChapter(
    number: 21,
    title: "Ya David De Gea 2015'te Bozuk Faks Makinesi Yüzünden Real Madrid'e Transferi Kalmasaydı?",
    narrative:
        "Real Madrid ve Man United, De Gea - Keylor Navas takası için anlaştı. Ancak transfer döneminin son günü evraklar İspanya Futbol Federasyonu'na faks makinesi arızası yüzünden 2 dakika geç ulaştı ve transfer yattı. Navas Madrid'i üst üste 3 kez Şampiyonlar Ligi şampiyonu yaptı.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Taraf Kulüpler: Atlético Madrid & Manchester United',
        taskDescription: 'Hem Atlético Madrid hem Manchester United formasını giymiş bir ortak oyuncu bul.',
        clubIdA: 13,
        clubIdBOptions: [985],
      ),
    ],
  ),
  StoryChapter(
    number: 22,
    title: "Ya Wesley Sneijder 2010'da Ballon d'Or'u Messi'ye Kaptırmasaydı?",
    narrative:
        "Inter ile Treble yapıp Hollanda'yı Dünya Kupası Finali'ne çıkaran Sneijder'ın Ballon d'Or'u alamaması ödül tarihinin en büyük skandalı kabul edilir. O yıl ödülü alsaydı Messi-Ronaldo ambargosunu kıran ilk isim olacaktı.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Taraf Kulüpler: Inter & Galatasaray',
        taskDescription: 'Hem Inter hem Galatasaray formasını giymiş bir ortak oyuncu bul.',
        clubIdA: 46,
        clubIdBOptions: [141],
      ),
    ],
  ),
  StoryChapter(
    number: 23,
    title: "Ya Romelu Lukaku 2021'de Inter'den 115 Milyon Euro'ya Chelsea'ye Dönmeseydi?",
    narrative:
        "Inter'de Conte ile Serie A şampiyonu olup kariyer zirvesini gören Lukaku, \"yarım kalan işim var\" diyerek Chelsea'ye döndü. Birkaç ay sonra İtalya basınına verdiği röportajda \"Inter'i özlüyorum\" deyince Chelsea taraftarı ve Tuchel ile köprüleri yaktı, kariyeri kaosa sürüklendi.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Pişmanlık Röportajı',
        taskDescription:
            "Lukaku'nun efsaneleştiği Inter ve kriz yaşadığı Chelsea formalarını giymiş ortak oyunculardan birini tahmin et.",
        clubIdA: 46,
        clubIdBOptions: [631],
      ),
    ],
  ),
  StoryChapter(
    number: 24,
    title: "Ya Ronaldinho 2003'te Barcelona Yerine Manchester United'a Transfer Olsaydı?",
    narrative:
        "PSG'den ayrılırken Alex Ferguson, Ronaldinho ile her konuda anlaştı. Transfer tamamlanmak üzereyken Joan Laporta yönetimindeki Barcelona araya girdi ve Brezilyalı efsaneyi kaptı. Ronaldinho Katalonya'da Ballon d'Or kazanıp kulübün çehresini değiştirirken; Manchester United bu hamlenin ardından yönünü Sporting CP altyapısındaki Cristiano Ronaldo'ya çevirdi.",
    scenes: [
      StoryScene.commonPlayers(
        title: 'Taraf Kulüpler: Paris Saint-Germain & Manchester United',
        taskDescription: 'Hem PSG hem Manchester United formasını giymiş bir ortak oyuncu bul.',
        clubIdA: 583,
        clubIdBOptions: [985],
      ),
    ],
  ),
];