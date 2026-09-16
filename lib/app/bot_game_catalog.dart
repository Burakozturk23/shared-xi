import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/loto_bot_page.dart';
import '../screens/classic_grid_page.dart';
import '../screens/vs_bot_cinko_page.dart';
import '../screens/vs_bot_club_selection_page.dart';
import '../screens/vs_bot_random_five_page.dart';
import '../screens/vs_bot_random_grid_page.dart';
import '../screens/vs_bot_reverse_grid_page.dart';
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
    ),
    tags: ['4×4 tahta', '16 oyuncu', 'Süreli'],
    goal: '16 oyuncuyu yerleştir, botun puanını geç.',
    steps: [
      (
        'Ligini ve zorluğu seç',
        'Kolayda 20, ortada 15, zorda 12 saniyen var. Süre her oyuncuda yenilenir.',
      ),
      (
        'Uygun kutuyu bul',
        'Gelen oyuncuyu kulüp, milliyet, lig, mevki veya dönem kriterine uyan boş bir kutuya yerleştir.',
      ),
      (
        'Sonucu gör',
        'Yerleştirmelerin oyun sonunda kontrol edilir. Pas geçersen veya süre dolarsa sıradaki oyuncu gelir.',
      ),
    ],
    scoring: 'Doğru yerleştirme +10 puan; yanlış, pas ve süre aşımı 0 puan. Sen ve bot aynı oyuncularla ayrı tahtalarda oynarsınız. Yüksek puan kazanır; eşit puan beraberliktir.',
    action: 'Lig ve zorluk seç',
  );

  static const teamRace = BotGameDefinition(
    entry: GameEntry(
      title: 'Takım Yarışı',
      subtitle: 'İki kulübün ortak oyuncularını bottan önce bul.',
      icon: Icons.shield_outlined,
      page: VsBotClubSelectionPage(),
      requiresRepository: false,
      modern: true,
    ),
    tags: ['Ortak oyuncu', '3 tur galibiyeti'],
    goal: 'Üç tur kazanan maçı alır.',
    steps: [
      (
        'Takımını seç',
        'Bir kulüp ve bot zorluğu seç. Her tur için rakip kulüp rastgele belirlenir.',
      ),
      (
        'Ortak oyuncuları bul',
        'Her iki kulüpte de oynamış futbolcuları yaz. Sen ve bot aynı anda yarışır; bulunan oyuncu o turda tekrar kullanılamaz.',
      ),
      (
        'Turu kazan',
        'Ortak oyuncular tükenince daha çok oyuncu bulan turu kazanır. Berabere biten tur kimseye galibiyet yazmaz.',
      ),
    ],
    scoring: 'Her doğru oyuncu +1. İlk üç tur galibiyetine ulaşan maçı kazanır. Zorluk, botun hızı ve isabet oranını değiştirir.',
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
    ),
    tags: ['3×3 tahta', 'Sıra tabanlı'],
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
    scoring: 'Her kazanılan kutu +1 puan. Üçlü yapan hemen kazanır. Üçlü olmadan tahta dolarsa yüksek puan kazanır.',
  );

  static const reverseGrid = BotGameDefinition(
    entry: GameEntry(
      title: 'Tersten Grid',
      subtitle: 'Futbolcuları gör, ortak kriteri çöz.',
      icon: Icons.swap_horiz_rounded,
      page: VsBotReverseGridPage(),
    ),
    tags: ['9 oyuncu', '6 ortak kriter'],
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
    scoring: 'Her doğru kriter +1 puan. Üç satır ve üç sütun çözülünce yüksek puan kazanır; eşitlik beraberliktir.',
  );

  static const randomGrid = BotGameDefinition(
    entry: GameEntry(
      title: 'Rastgele Grid',
      subtitle: 'Kulüp çiftini çöz, tahtadaki yerini seç.',
      icon: Icons.shuffle_rounded,
      page: VsBotRandomGridPage(),
    ),
    tags: ['3×3 tahta', 'Sıra tabanlı'],
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
    scoring: 'Her kazanılan kutu +1 puan. Üçlü yapan hemen kazanır. Tahta üçlü olmadan dolarsa yüksek puan kazanır.',
  );

  static const cinko = BotGameDefinition(
    entry: GameEntry(
      title: 'Futbol Çinko',
      subtitle: 'Bir oyuncuyla birbirine bağlı kutuları boya.',
      icon: Icons.grid_on_rounded,
      page: VsBotCinkoPage(),
      requiresRepository: false,
      modern: true,
    ),
    tags: ['5×5 tahta', 'Bağlı kutular', '3 bot seviyesi'],
    goal: 'Doğru kutuları birleştir, daha çok puan topla.',
    steps: [
      (
        'Önce oyuncunu bul',
        'Tahtadaki en az bir açık kulüp, milliyet veya lig kutusuna uyan futbolcuyu seç.',
      ),
      (
        'Bağlı kutuları seç',
        'Aynı oyuncuya uyan kutuları yan yana veya üst üste bağla. L şekli geçerlidir; çapraz bağlantı sayılmaz.',
      ),
      (
        'Seçimini onayla',
        'Doğru kutular sana geçer. Sonra bot oynar. Kullanılan futbolcu yeniden seçilemez. İstersen puan kaybetmeden pas geçebilirsin.',
      ),
    ],
    scoring: 'Her doğru kutu +1, yanlış kutu −1, pas 0 puan. Tahta dolduğunda veya kullanılabilecek oyuncu kalmadığında yüksek puan kazanır; eşitlik beraberliktir. Bot kolayda 1, ortada en fazla 3, zorda en uzun bağlı kutu grubunu kazanır. Senin bağlantı uzunluğun sınırsız. Milliyet vatandaşlığı, lig ise veritabanındaki kariyer kulüplerinin ligini ifade eder.',
  );

  static const five = BotGameDefinition(
    entry: GameEntry(
      title: 'Rastgele Beşler',
      subtitle: 'Beş kulübün mümkün olduğunca çoğunu bağla.',
      icon: Icons.filter_5_outlined,
      page: VsBotRandomFivePage(),
      requiresRepository: false,
      modern: true,
    ),
    tags: ['5 tur', 'Yenilenen kulüpler', '3 bot seviyesi'],
    goal: 'Beş tur sonunda daha fazla bağlantı kur.',
    steps: [
      (
        'Beş kulübü incele',
        'Botun seviyesini seç ve maça başla. Beş kulüpten en az birinde oynamış bir futbolcu bul; her eşleşme +1 puan.',
      ),
      (
        'Botla sırayla oyna',
        'Önce sen, sonra bot aynı beş kulüp için cevap verir. Futbolcular maç boyunca tekrar kullanılamaz. Bulamazsan pas geçebilirsin.',
      ),
      (
        'Yeni tura geç',
        'İkinizin cevabını ve eşleşen kulüpleri incele; Sonraki tur ile yeni beşliye geç. Her oyuncunun beş cevap hakkı vardır.',
      ),
    ],
    scoring: 'Her eşleşen kulüp +1; bir cevap en fazla +5, bir maç en fazla 25 puan. Pas 0 puandır ve sırayı bota geçirir. Bulunamayan veya kulüplere uymayan cevap düzenlenebilir; sıranı tüketmez. Beş tur sonunda yüksek toplam puan kazanır; eşitlik beraberliktir. Kolay bot 1–2, orta bot en fazla 3 bağlantılı cevapları tercih eder; bu aralıkta seçenek yoksa en düşük puanlı cevabı seçer. Zor bot kalan en yüksek puanlı cevabı bulur.',
  );

  static const gridVariants = [classicGrid, reverseGrid, randomGrid];
  static const all = [loto, teamRace, ...gridVariants, cinko, five];
}
