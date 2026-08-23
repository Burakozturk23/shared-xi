import '../models/passaparola_question.dart';

/// Elle yazılmış başlangıç bankası.
/// Her harf için en az 1 soru; genişletilebilir.
class PassaparolaSeed {
  PassaparolaSeed._();

  static List<PassaparolaQuestion> get all => _questions;

  /// Her harf için rastgele 1 soru seç (tekrar etmeyen id).
  static List<PassaparolaQuestion> pickRound({int? seed}) {
    final byLetter = <String, List<PassaparolaQuestion>>{};
    for (final q in _questions) {
      byLetter.putIfAbsent(q.letter, () => []).add(q);
    }
    final rnd = seed != null ? seed : DateTime.now().millisecondsSinceEpoch;
    final result = <PassaparolaQuestion>[];
    var i = 0;
    for (final letter in PassaparolaAlphabet.letters) {
      final list = byLetter[letter];
      if (list == null || list.isEmpty) continue;
      final pick = list[(rnd + i * 17) % list.length];
      result.add(pick);
      i++;
    }
    return result;
  }

  static const List<PassaparolaQuestion> _questions = [
    // A
    PassaparolaQuestion(
      id: 'a_club_01',
      letter: 'A',
      category: PassaparolaCategory.club,
      question: 'Londra’nın kırmızı-beyaz formasıyla bilinen kulübü?',
      answers: ['Arsenal'],
      difficulty: 1,
    ),
    PassaparolaQuestion(
      id: 'a_player_01',
      letter: 'A',
      category: PassaparolaCategory.player,
      question: 'Barcelona ve PSG’de oynamış Arjantinli efsane forvet?',
      answers: ['Messi', 'Lionel Messi'],
      difficulty: 1,
    ),
    // B
    PassaparolaQuestion(
      id: 'b_club_01',
      letter: 'B',
      category: PassaparolaCategory.club,
      question: 'İspanya’nın blaugrana renkleriyle bilinen kulübü?',
      answers: ['Barcelona', 'FC Barcelona', 'Barça', 'Barca'],
      difficulty: 1,
    ),
    PassaparolaQuestion(
      id: 'b_manager_01',
      letter: 'B',
      category: PassaparolaCategory.manager,
      question: 'Manchester City’yi modern dönemde zirveye taşıyan İspanyol teknik direktör (soyad)?',
      answers: ['Guardiola', 'Pep Guardiola'],
      difficulty: 1,
    ),
    // C
    PassaparolaQuestion(
      id: 'c_stadium_01',
      letter: 'C',
      category: PassaparolaCategory.stadium,
      question: 'Barcelona’nın ev sahibi olduğu ünlü stadyum?',
      answers: ['Camp Nou', 'Campnou', 'Nou Camp'],
      difficulty: 1,
    ),
    PassaparolaQuestion(
      id: 'c_player_01',
      letter: 'C',
      category: PassaparolaCategory.player,
      question: 'Real Madrid ve Juventus forması giymiş Portekizli yıldız (soyad)?',
      answers: ['Ronaldo', 'Cristiano Ronaldo', 'C Ronaldo'],
      difficulty: 1,
    ),
    // Ç
    PassaparolaQuestion(
      id: 'c_cedilla_club_01',
      letter: 'Ç',
      category: PassaparolaCategory.free,
      question: 'Türkiye’de “Ç” harfiyle anılan efsane teknik direktör lakabı / soyadı ile bilinen isim?',
      answers: ['Çalımbay', 'Ünal Çalımbay'],
      difficulty: 2,
    ),
    // D
    PassaparolaQuestion(
      id: 'd_club_01',
      letter: 'D',
      category: PassaparolaCategory.club,
      question: 'Almanya’nın sarı-siyah renkleriyle bilinen Ruhr kulübü?',
      answers: ['Dortmund', 'Borussia Dortmund', 'BVB'],
      difficulty: 1,
    ),
    // E
    PassaparolaQuestion(
      id: 'e_club_01',
      letter: 'E',
      category: PassaparolaCategory.club,
      question: 'Premier League’de “The Toffees” lakaplı kulüp?',
      answers: ['Everton'],
      difficulty: 2,
    ),
    // F
    PassaparolaQuestion(
      id: 'f_club_01',
      letter: 'F',
      category: PassaparolaCategory.club,
      question: 'İstanbul’un sarı-lacivertli kulübü?',
      answers: ['Fenerbahçe', 'Fenerbahce', 'Fener'],
      difficulty: 1,
    ),
    // G
    PassaparolaQuestion(
      id: 'g_club_01',
      letter: 'G',
      category: PassaparolaCategory.club,
      question: 'İstanbul’un sarı-kırmızılı kulübü?',
      answers: ['Galatasaray'],
      difficulty: 1,
    ),
    // H
    PassaparolaQuestion(
      id: 'h_player_01',
      letter: 'H',
      category: PassaparolaCategory.player,
      question: 'Türkiye Milli Takımı formasıyla efsane olmuş, Inter’de de forma giymiş forvet (soyad)?',
      answers: ['Şükür', 'Hakan Şükür', 'Hakan Suker'],
      difficulty: 1,
    ),
    // I
    PassaparolaQuestion(
      id: 'i_player_01',
      letter: 'I',
      category: PassaparolaCategory.player,
      question: 'Liverpool ve Real Madrid’te oynamış İspanyol orta saha (soyad, I ile)?',
      answers: ['Isco'],
      difficulty: 2,
    ),
    // İ — seed uses İ
    PassaparolaQuestion(
      id: 'i_dot_country_01',
      letter: 'İ',
      category: PassaparolaCategory.country,
      question: '2010 Dünya Kupası şampiyonu Avrupa ülkesi?',
      answers: ['İspanya', 'Ispanya', 'Spain', 'Espana'],
      difficulty: 1,
    ),
    // J
    PassaparolaQuestion(
      id: 'j_club_01',
      letter: 'J',
      category: PassaparolaCategory.club,
      question: 'Torino merkezli, siyah-beyaz çizgili formasıyla ünlü İtalyan kulüp?',
      answers: ['Juventus', 'Juve'],
      difficulty: 1,
    ),
    // K
    PassaparolaQuestion(
      id: 'k_manager_01',
      letter: 'K',
      category: PassaparolaCategory.manager,
      question: 'Liverpool’u Premier League şampiyonu yapan Alman teknik direktör (soyad)?',
      answers: ['Klopp', 'Jurgen Klopp', 'Jürgen Klopp'],
      difficulty: 1,
    ),
    // L
    PassaparolaQuestion(
      id: 'l_club_01',
      letter: 'L',
      category: PassaparolaCategory.club,
      question: 'İngiltere’nin kırmızı formasıyla bilinen Merseyside kulübü?',
      answers: ['Liverpool'],
      difficulty: 1,
    ),
    // M
    PassaparolaQuestion(
      id: 'm_club_01',
      letter: 'M',
      category: PassaparolaCategory.club,
      question: 'Premier League’de “Red Devils” lakaplı kulüp?',
      answers: ['Manchester United', 'Man United', 'Man Utd', 'United'],
      difficulty: 1,
    ),
    PassaparolaQuestion(
      id: 'm_stadium_01',
      letter: 'M',
      category: PassaparolaCategory.stadium,
      question: 'Manchester United’ın stadyumu?',
      answers: ['Old Trafford'],
      difficulty: 1,
    ),
    // N
    PassaparolaQuestion(
      id: 'n_club_01',
      letter: 'N',
      category: PassaparolaCategory.club,
      question: 'İtalya’nın güneyinden, mavi formasıyla bilinen kulüp?',
      answers: ['Napoli', 'SSC Napoli'],
      difficulty: 1,
    ),
    // O
    PassaparolaQuestion(
      id: 'o_stadium_01',
      letter: 'O',
      category: PassaparolaCategory.stadium,
      question: 'Manchester United’ın evi olan stadyum?',
      answers: ['Old Trafford'],
      difficulty: 1,
    ),
    // Ö
    PassaparolaQuestion(
      id: 'o_umlaut_player_01',
      letter: 'Ö',
      category: PassaparolaCategory.player,
      question: 'Arsenal ve Real Madrid forması giymiş Alman-Türk orta saha yıldızı (soyad)?',
      answers: ['Özil', 'Ozil', 'Mesut Özil', 'Mesut Ozil'],
      difficulty: 1,
    ),
    // P
    PassaparolaQuestion(
      id: 'p_club_01',
      letter: 'P',
      category: PassaparolaCategory.club,
      question: 'Fransa’nın başkent kulübü, kısaca PSG olarak bilinen?',
      answers: ['Paris Saint-Germain', 'PSG', 'Paris Saint Germain', 'Paris'],
      difficulty: 1,
    ),
    // R
    PassaparolaQuestion(
      id: 'r_club_01',
      letter: 'R',
      category: PassaparolaCategory.club,
      question: 'İspanya’nın beyaz formasıyla bilinen kraliyet kulübü?',
      answers: ['Real Madrid', 'Madrid'],
      difficulty: 1,
    ),
    // S
    PassaparolaQuestion(
      id: 's_trophy_01',
      letter: 'S',
      category: PassaparolaCategory.trophy,
      question: 'Avrupa kulüplerinin en prestijli organizasyonu (kısaltmasız veya kısaltma)?',
      answers: [
        'Şampiyonlar Ligi',
        'Sampiyonlar Ligi',
        'Champions League',
        'UCL',
      ],
      difficulty: 1,
    ),
    // Ş
    PassaparolaQuestion(
      id: 's_cedilla_trophy_01',
      letter: 'Ş',
      category: PassaparolaCategory.trophy,
      question: 'UEFA’nın kulüpler düzeyindeki en büyük kupası (Türkçe adıyla)?',
      answers: ['Şampiyonlar Ligi', 'Sampiyonlar Ligi'],
      difficulty: 1,
    ),
    // T
    PassaparolaQuestion(
      id: 't_club_01',
      letter: 'T',
      category: PassaparolaCategory.club,
      question: 'Londra’nın beyaz formasıyla bilinen kulübü (kısaca Spurs)?',
      answers: ['Tottenham', 'Tottenham Hotspur', 'Spurs'],
      difficulty: 1,
    ),
    // U
    PassaparolaQuestion(
      id: 'u_trophy_01',
      letter: 'U',
      category: PassaparolaCategory.trophy,
      question: 'Avrupa futbolunu yöneten kurumun kısaltması?',
      answers: ['UEFA'],
      difficulty: 1,
    ),
    // Ü
    PassaparolaQuestion(
      id: 'u_umlaut_manager_01',
      letter: 'Ü',
      category: PassaparolaCategory.manager,
      question: 'Beşiktaş’ta şampiyonluklar yaşamış, “Ü” ile başlayan teknik adam (ad soyad veya soyad)?',
      answers: ['Ünal', 'Ünal Karaman', 'Unal Karaman'],
      difficulty: 2,
    ),
    // V
    PassaparolaQuestion(
      id: 'v_club_01',
      letter: 'V',
      category: PassaparolaCategory.club,
      question: 'İspanya’da “Los Ches” lakaplı, turuncu formasıyla bilinen kulüp?',
      answers: ['Valencia', 'Valencia CF'],
      difficulty: 2,
    ),
    // Y
    PassaparolaQuestion(
      id: 'y_club_01',
      letter: 'Y',
      category: PassaparolaCategory.club,
      question: 'İstanbul’un sarı-kırmızılı rakibi olmayan, “Y” ile anılan Anadolu kulübü (kısaltma veya tam)?',
      answers: ['Yeni Malatyaspor', 'Malatyaspor'],
      difficulty: 2,
    ),
    // Z
    PassaparolaQuestion(
      id: 'z_player_01',
      letter: 'Z',
      category: PassaparolaCategory.player,
      question: 'Real Madrid’te efsane olmuş Fransız orta saha / forvet (soyad)?',
      answers: ['Zidane', 'Zinedine Zidane'],
      difficulty: 1,
    ),
  ];
}
