import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/loto_bot_page.dart';
import '../screens/classic_grid_page.dart';
import '../screens/vs_bot_cinko_page.dart';
import '../screens/vs_bot_club_selection_page.dart';
import '../screens/vs_bot_random_five_page.dart';
import '../screens/vs_bot_random_grid_page.dart';
import '../screens/vs_bot_reverse_grid_page.dart';
import 'game_audio.dart';
import 'game_catalog.dart';

/// Browsing needs no game data. Migrated modes prepare their own V4 session.
@immutable
class BotGameDefinition {
  const BotGameDefinition({
    required this.entry,
    required this.tags,
    required this.goal,
    required this.steps,
    required this.scoring,
    this.action = 'Oyuna başla',
  });

  final GameEntry entry;
  final List<String> tags;
  final String goal;
  final List<(String, String)> steps;
  final String scoring;
  final String action;
}

class BotGameCatalog {
  static const loto = BotGameDefinition(
    entry: GameEntry(
      title: 'Football Loto',
      subtitle: 'Gelen futbolcuyu doğru kritere yerleştir.',
      icon: Icons.dashboard_outlined,
      page: LotoBotPage(),
      requiresRepository: false,
      modern: true,
      music: MusicTrack.rush,
    ),
    tags: ['4×4 tahta', '16 oyuncu', 'Süreli', '3 bot seviyesi'],
    goal: '16 oyuncuyu yerleştir, botun puanını geç.',
    steps: [
      (
        'Zorluğu seç',
        'Kolayda 20, ortada 15, zorda 12 saniyen var. Süre her oyuncuda yenilenir. Zorlaştıkça futbolcular daha az bilinir ve bot daha isabetli oynar.',
      ),
      (
        'Uygun kutuyu bul',
        'Gelen oyuncuyu kulüp, milliyet veya lig kriterine uyan boş bir kutuya yerleştir.',
      ),
      (
        'Sonucu gör',
        'Yerleştirmelerin oyun sonunda kontrol edilir. Pas geçersen veya süre dolarsa sıradaki oyuncu gelir. Maç başına 2 duraklatma hakkın var; uygulamadan çıkmak da bir hak kullanır.',
      ),
    ],
    scoring: 'Doğru yerleştirme +10 puan; yanlış, pas ve süre aşımı 0 puan. Sen ve bot aynı oyuncularla ayrı tahtalarda oynarsınız. Yüksek puan kazanır; eşit puan beraberliktir.',
    action: 'Zorluk seç',
  );

  static const teamRace = BotGameDefinition(
    entry: GameEntry(
      title: 'Takım Yarışı',
      subtitle: 'İki kulübün ortak oyuncularını bottan önce bul.',
      icon: Icons.shield_outlined,
      page: VsBotClubSelectionPage(),
      requiresRepository: false,
      modern: true,
      music: MusicTrack.rush,
    ),
    tags: ['Ortak oyuncu', '3 tur galibiyeti', '3 bot seviyesi'],
    goal: 'Üç tur kazanan maçı alır; maç en fazla beş tur sürer.',
    steps: [
      (
        'Takımını seç',
        'Bir kulüp ve bot zorluğu seç. Her tur için rakip kulüp rastgele belirlenir; zorluk arttıkça daha az bilinen ortak futbolcular da gelir.',
      ),
      (
        'Ortak oyuncuları bul',
        'Her iki kulüpte de oynamış futbolcuları yaz. Sen ve bot aynı anda yarışır; bulunan oyuncu o turda tekrar kullanılamaz.',
      ),
      (
        'Turu kazan',
        'Ortak oyuncular tükenince, 70 saniye dolunca ya da turu sen bitirince daha çok oyuncu bulan turu kazanır. Berabere biten tur kimseye galibiyet yazmaz.',
      ),
    ],
    scoring: 'Her doğru oyuncu +1. İlk üç tur galibiyetine ulaşan maçı kazanır; beş turda kimse üçe ulaşamazsa çok tur kazanan, o da eşitse toplamda çok oyuncu bulan kazanır. Kolay bot yalnız çok bilinen oyuncuları yavaş bulur, orta bot bilinenleri orta hızda, zor bot herkesi hızlı bulur. Maç başına 2 duraklatma hakkın var.',
    action: 'Takımını seç',
  );

  static const classicGrid = BotGameDefinition(
    entry: GameEntry(
      title: 'Klasik Grid',
      subtitle: 'İki kritere uyan futbolcuyla kutuyu kazan.',
      icon: Icons.grid_view_rounded,
      page: ClassicGridPage(),
      requiresRepository: false,
      modern: true,
      music: MusicTrack.competitive,
    ),
    tags: ['3×3 tahta', 'Sıra tabanlı', '3 bot seviyesi'],
    goal: 'Üç kutuyu bir çizgide tamamla.',
    steps: [
      ('Bir kutu seç', 'Boş kutunun satır ve sütun kriterlerine bak.'),
      (
        'Ortak oyuncuyu yaz',
        'İki kritere de uyan bir futbolcu bul. Doğru cevap kutuyu sana kazandırır; yanlış cevapta sıra bota geçer.',
      ),
      (
        'Üçlü oluştur',
        'Yatay, dikey veya çapraz üç kutuyu tamamla. Kullandığınız oyuncular tekrar kullanılamaz.',
      ),
    ],
    scoring: 'Her kazanılan kutu +1 puan. Üçlü yapan hemen kazanır. Üçlü olmadan tahta dolarsa veya oynanabilir hamle kalmazsa yüksek puan kazanır. Bot seviyesi botun isabetini ve üçlünü ne sıklıkla engellediğini belirler.',
  );

  static const reverseGrid = BotGameDefinition(
    entry: GameEntry(
      title: 'Tersten Grid',
      subtitle: 'Futbolcuları gör, ortak kriteri çöz.',
      icon: Icons.swap_horiz_rounded,
      page: VsBotReverseGridPage(),
      modern: true,
      music: MusicTrack.competitive,
    ),
    tags: ['9 oyuncu', '6 ortak kriter', '3 bot seviyesi'],
    goal: 'Altı satır ve sütundan daha fazlasını çöz.',
    steps: [
      (
        'Oyuncuları incele',
        'Tahtadaki bir satır veya sütunun üç futbolcusuna bak.',
      ),
      (
        'Ortak noktayı yaz',
        'Üç oyuncuyu bağlayan bir kriter bul: örneğin bir kulüp, milliyet veya mevki. Üçüne de uyan alternatif cevaplar geçerlidir.',
      ),
      (
        'Sıranı tamamla',
        'Doğru veya yanlış tahminden sonra bot oynar. Kazanılmış satır ve sütunlar tekrar seçilemez.',
      ),
    ],
    scoring: 'Her doğru kriter +1 puan. Üç satır ve üç sütun çözülünce yüksek puan kazanır; eşitlik beraberliktir. Bot seviyesi botun ne sıklıkla doğru kriteri bulduğunu belirler.',
  );

  static const randomGrid = BotGameDefinition(
    entry: GameEntry(
      title: 'Rastgele Grid',
      subtitle: 'Kulüp çiftini çöz, tahtadaki yerini seç.',
      icon: Icons.shuffle_rounded,
      page: VsBotRandomGridPage(),
      modern: true,
      music: MusicTrack.competitive,
    ),
    tags: ['3×3 tahta', 'Sıra tabanlı', '3 bot seviyesi'],
    goal: 'Bağlantı kurarak üçlü oluştur.',
    steps: [
      (
        'Bir kulüp çifti üret',
        'Gelen iki kulüpte de oynamış bir futbolcu bul.',
      ),
      (
        'Tahtaya yerleştir',
        'Doğrulanan çifti uygun bir boş kesişime yerleştir. Oluşmuş kesişimleri de doğru oyuncuyla doldurabilirsin.',
      ),
      (
        'Üçlüyü tamamla',
        'Yatay, dikey veya çapraz üç kutuyu kazan. Yanlış oyuncu cevabında sıra bota geçer.',
      ),
    ],
    scoring: 'Her kazanılan kutu +1 puan. Üçlü yapan hemen kazanır. Tahta üçlü olmadan dolarsa veya oynanabilir hamle kalmazsa yüksek puan kazanır. Bot seviyesi botun isabetini ve üçlünü ne sıklıkla engellediğini belirler.',
  );

  static const cinko = BotGameDefinition(
    entry: GameEntry(
      title: 'Futbol Çinko',
      subtitle: 'Bir oyuncuyla birbirine bağlı kutuları boya.',
      icon: Icons.grid_on_rounded,
      page: VsBotCinkoPage(),
      requiresRepository: false,
      modern: true,
      music: MusicTrack.competitive,
    ),
    tags: ['5×5 tahta', 'Bağlı kutular', '3 bot seviyesi'],
    goal: 'Doğru kutuları birleştir, daha çok puan topla.',
    steps: [
      (
        'Bağlı kutuları seç',
        'Aynı futbolcuya uyacak açık kulüp, milliyet veya lig kutularını yan yana veya üst üste seç. L şekli geçerlidir; çapraz bağlantı sayılmaz.',
      ),
      (
        'Futbolcuyu yaz',
        'Alttaki aramada futbolcuyu yaz ve öneriye dokun. Doğru kutular sana geçer, sonra bot oynar. Kullanılan futbolcu yeniden seçilemez.',
      ),
      (
        'Sırayla oyna',
        'İlk başlayan rastgele seçilir; ikinci başlayan maça +1 puanla başlar. İstersen puan kaybetmeden pas geçebilirsin.',
      ),
    ],
    scoring: 'Her doğru kutu +1, yanlış kutu −1, pas 0 puan. Tahta dolduğunda, kullanılabilecek oyuncu kalmadığında veya dört pas üst üste geldiğinde yüksek puan kazanır; eşitlik beraberliktir. Bot kolayda en fazla 2, ortada en fazla 3, zorda en uzun bağlı kutu grubunu alır; kolaylaştıkça daha az futbolcu bilir ve daha sık yanlış kutu işaretler. Senin bağlantı uzunluğun sınırsız. Milliyet vatandaşlığı, lig ise veritabanındaki kariyer kulüplerinin ligini ifade eder.',
  );

  static const five = BotGameDefinition(
    entry: GameEntry(
      title: 'Rastgele Beşler',
      subtitle: 'Beş kulübün mümkün olduğunca çoğunu bağla.',
      icon: Icons.filter_5_outlined,
      page: VsBotRandomFivePage(),
      requiresRepository: false,
      modern: true,
      music: MusicTrack.competitive,
    ),
    tags: ['5 beşli', 'Aynı anda tahmin', '3 bot seviyesi'],
    goal: 'Beş beşli sonunda daha çok puan topla.',
    steps: [
      (
        'Beş kulübü incele',
        'Botun seviyesini seç ve maça başla. Beş kulüpten en çoğunda oynamış futbolcuyu bul; ne kadar çok kulübe uyarsa o kadar değerli.',
      ),
      (
        'Aynı anda tahmin et',
        'Bot tahminini önceden kilitler; sen cevaplayınca ikisi birlikte açılır. Bir futbolcuyu maçta bir kez yazabilirsin. Bulamazsan pas geçebilirsin.',
      ),
      (
        'Yeni beşliye geç',
        'İki cevabı, kapsadıkları kulüpleri ve beşlinin en iyi cevaplarını incele; Sonraki beşli ile devam et.',
      ),
    ],
    scoring: 'Puan: 1 kulüp +1, 2 kulüp +2, 3 kulüp +4, 4 kulüp +6, 5 kulüp +8; bir maç en fazla 40 puan. Pas 0 puandır. Hiçbir kulübe uymayan isim için 3 deneme hakkın var; üçü de uymazsa beşli pas sayılır. Beş beşli sonunda yüksek toplam puan kazanır; eşitlik beraberliktir. Kolay bot 1–2 kulübe uyan cevaplar verir ve bazen pas geçer; orta bot çoğunlukla 3, ara sıra 4 kulübe uyan cevabı bulur; zor bot bildiği en iyi cevabı bulur.',
  );

  static const gridVariants = [classicGrid, reverseGrid, randomGrid];
  static const all = [loto, teamRace, ...gridVariants, cinko, five];
}
