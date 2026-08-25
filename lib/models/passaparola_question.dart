/// Passaparola soru modeli — çok kategorili.
enum PassaparolaCategory {
  player,
  club,
  country,
  stadium,
  manager,
  trophy,
  free,
}

extension PassaparolaCategoryX on PassaparolaCategory {
  String get label {
    switch (this) {
      case PassaparolaCategory.player:
        return 'Oyuncu';
      case PassaparolaCategory.club:
        return 'Kulüp';
      case PassaparolaCategory.country:
        return 'Ülke / milli';
      case PassaparolaCategory.stadium:
        return 'Stadyum';
      case PassaparolaCategory.manager:
        return 'Teknik direktör';
      case PassaparolaCategory.trophy:
        return 'Kupa / turnuva';
      case PassaparolaCategory.free:
        return 'Genel';
    }
  }
}

class PassaparolaQuestion {
  final String id;
  final String letter;
  final PassaparolaCategory category;
  final String question;
  final List<String> answers;
  final int difficulty; // 1 kolay – 3 zor
  final String source; // manual | generated

  const PassaparolaQuestion({
    required this.id,
    required this.letter,
    required this.category,
    required this.question,
    required this.answers,
    this.difficulty = 1,
    this.source = 'manual',
  });

  /// Cevap eşleştirme (normalize + alternatifler).
  /// Soyad eşleşmesinde kelime, soru harfiyle uyumlu olmalı
  /// (B harfinde Guardiola gibi hataları engeller).
  bool matchesAnswer(String input) {
    final n = normalizeAnswer(input);
    if (n.isEmpty) return false;
    final letterN = normalizeAnswer(letter);
    if (letterN.isEmpty) return false;

    for (final a in answers) {
      final na = normalizeAnswer(a);
      if (na == n) return true;

      final parts = na.split(' ');
      if (parts.length > 1 && parts.last == n) {
        // Soyad kabulü: soyad harfle başlamalı
        if (parts.last.startsWith(letterN)) return true;
      }
      // Tek kelimelik giriş, cevabın herhangi bir kelimesine eşit + harf uyumu
      for (final p in parts) {
        if (p == n && p.startsWith(letterN)) return true;
      }
    }
    return false;
  }

  static String normalizeAnswer(String s) {
    var t = s.trim().toLowerCase();
    t = t
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return t;
  }

  factory PassaparolaQuestion.fromJson(Map<String, dynamic> json) {
    return PassaparolaQuestion(
      id: json['id']?.toString() ?? '',
      letter: json['letter']?.toString().toUpperCase() ?? '',
      category: _parseCategory(json['category']?.toString()),
      question: json['question']?.toString() ?? '',
      answers: (json['answers'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
      source: json['source']?.toString() ?? 'manual',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'letter': letter,
        'category': category.name,
        'question': question,
        'answers': answers,
        'difficulty': difficulty,
        'source': source,
      };

  static PassaparolaCategory _parseCategory(String? v) {
    switch (v) {
      case 'player':
        return PassaparolaCategory.player;
      case 'club':
        return PassaparolaCategory.club;
      case 'country':
        return PassaparolaCategory.country;
      case 'stadium':
        return PassaparolaCategory.stadium;
      case 'manager':
        return PassaparolaCategory.manager;
      case 'trophy':
        return PassaparolaCategory.trophy;
      default:
        return PassaparolaCategory.free;
    }
  }
}

/// Harf durumu.
enum LetterStatus {
  pending, // henüz gelmedi / pas
  current,
  correct,
  wrong,
  passed, // pas geçildi, tekrar gelecek
}

/// Türkçe Passaparola alfabesi (29 harf).
class PassaparolaAlphabet {
  static const List<String> letters = [
    'A', 'B', 'C', 'Ç', 'D', 'E', 'F', 'G', 'H', 'I', 'İ', 'J', 'K', 'L', 'M',
    'N', 'O', 'Ö', 'P', 'R', 'S', 'Ş', 'T', 'U', 'Ü', 'V', 'Y', 'Z',
  ];
  // Not: Q, W, X yok (Türkçe yayın formatına yakın). İstersen eklenir.
}
