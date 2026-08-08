import '../models/player.dart';

enum ResolveStatus {
  /// Tek net oyuncu bulundu
  found,

  /// Hiç kimse uymaz
  notFound,

  /// Birden fazla aday (soyisim vs.)
  ambiguous,
}

class ResolveResult {
  final ResolveStatus status;
  final Player? player;
  final List<Player> candidates;
  final String message;

  const ResolveResult._({
    required this.status,
    this.player,
    this.candidates = const [],
    required this.message,
  });

  factory ResolveResult.found(Player player) => ResolveResult._(
        status: ResolveStatus.found,
        player: player,
        message: '',
      );

  factory ResolveResult.notFound([String? msg]) => ResolveResult._(
        status: ResolveStatus.notFound,
        message: msg ?? 'Böyle bir oyuncu bulunamadı.',
      );

  factory ResolveResult.ambiguous(List<Player> candidates) => ResolveResult._(
        status: ResolveStatus.ambiguous,
        candidates: candidates,
        message: candidates.length <= 3
            ? 'Birden fazla oyuncu: ${candidates.map((p) => p.name).join(', ')}. Daha net yaz.'
            : 'Birden fazla oyuncu var. İsim + soyisim yaz (örn. Luis Suarez).',
      );

  bool get isFound => status == ResolveStatus.found;
}

class SearchService {
  SearchService._();

  static const int minQueryLengthForSuggest = 3;
  static const int minTokenLengthForPartial = 4;

  static String normalize(String input) {
    final text = input.toLowerCase().trim();

    final replaced = text
        .replaceAll(RegExp(r'[áàäâãåā]'), 'a')
        .replaceAll(RegExp(r'[çćč]'), 'c')
        .replaceAll(RegExp(r'[ďđ]'), 'd')
        .replaceAll(RegExp(r'[éèëêē]'), 'e')
        .replaceAll(RegExp(r'[ğ]'), 'g')
        .replaceAll(RegExp(r'[íìïîīı]'), 'i')
        .replaceAll(RegExp(r'[ñń]'), 'n')
        .replaceAll(RegExp(r'[óòöôõō]'), 'o')
        .replaceAll(RegExp(r'[şśš]'), 's')
        .replaceAll(RegExp(r'[úùüûū]'), 'u')
        .replaceAll(RegExp(r'[ýÿ]'), 'y')
        .replaceAll(RegExp(r'[žźż]'), 'z')
        .replaceAll(RegExp(r"[’'`´-]"), '');

    return replaced.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static bool equals(String a, String b) {
    return normalize(a) == normalize(b);
  }

  static bool contains(String text, String query) {
    final q = normalize(query);
    if (q.isEmpty) return false;
    return normalize(text).contains(q);
  }

  /// Oyuncunun tüm aranabilir etiketleri (isim + alias).
  static List<String> _labels(Player player) {
    if (player.aliases.isNotEmpty) return player.aliases;
    return [player.name];
  }

  static List<String> _normalizedLabels(Player player) {
    if (player.normalizedAliases.isNotEmpty) {
      return player.normalizedAliases;
    }
    if (player.normalizedName.isNotEmpty) {
      return [player.normalizedName];
    }
    return _labels(player).map(normalize).toList();
  }

  /// Birebir (eski davranış).
  static bool matches(Player player, String answer) {
    final q = normalize(answer);
    if (q.isEmpty) return false;
    return _normalizedLabels(player).any((n) => n == q);
  }

  /// Soyisim / son token eşleşmesi.
  static bool matchesLastName(Player player, String answer) {
    final q = normalize(answer);
    if (q.length < minTokenLengthForPartial) return false;

    for (final label in _labels(player)) {
      final parts = label.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty) continue;
      final last = normalize(parts.last);
      if (last == q) return true;
    }
    return false;
  }

  /// Normalize edilmiş etiket query'yi içeriyor mu (kısmi).
  static bool matchesPartial(Player player, String answer) {
    final q = normalize(answer);
    if (q.length < minTokenLengthForPartial) return false;
    return _normalizedLabels(player).any((n) => n.contains(q));
  }

  /// Eski API — tam eşleşme.
  static Player? findExactPlayer({
    required List<Player> players,
    required String answer,
  }) {
    for (final player in players) {
      if (matches(player, answer)) return player;
    }
    return null;
  }

  /// Esnek çözüm: exact → benzersiz soyisim → benzersiz kısmi.
  ///
  /// [players] arama havuzu (genelde tüm oyuncular veya hücre adayları).
  static ResolveResult resolve({
    required List<Player> players,
    required String answer,
    Set<int> excludedPlayerIds = const {},
  }) {
    final trimmed = answer.trim();
    if (trimmed.isEmpty) {
      return ResolveResult.notFound('İsim boş olamaz.');
    }

    final pool = players
        .where((p) => !excludedPlayerIds.contains(p.id))
        .toList(growable: false);

    // 1) Tam eşleşme
    final exact = <Player>[];
    for (final p in pool) {
      if (matches(p, trimmed)) exact.add(p);
    }
    if (exact.length == 1) return ResolveResult.found(exact.first);
    if (exact.length > 1) return ResolveResult.ambiguous(exact.take(5).toList());

    // 2) Soyisim / son kelime — yalnızca tek aday
    final byLast = <Player>[];
    for (final p in pool) {
      if (matchesLastName(p, trimmed)) byLast.add(p);
    }
    if (byLast.length == 1) return ResolveResult.found(byLast.first);
    if (byLast.length > 1) {
      return ResolveResult.ambiguous(byLast.take(5).toList());
    }

    // 3) Kısmi contains — yalnızca tek aday
    final byPartial = <Player>[];
    for (final p in pool) {
      if (matchesPartial(p, trimmed)) byPartial.add(p);
    }
    if (byPartial.length == 1) return ResolveResult.found(byPartial.first);
    if (byPartial.length > 1) {
      return ResolveResult.ambiguous(byPartial.take(5).toList());
    }

    return ResolveResult.notFound();
  }

  /// Geriye dönük: resolve → Player? (ambiguous/notFound → null)
  static Player? findPlayer({
    required List<Player> players,
    required String answer,
    Set<int> excludedPlayerIds = const {},
  }) {
    final r = resolve(
      players: players,
      answer: answer,
      excludedPlayerIds: excludedPlayerIds,
    );
    return r.isFound ? r.player : null;
  }

  /// Autocomplete — TÜM havuz, cevabı spoiler etmez.
  /// min 3 harf, contains ile sıralı.
  static List<Player> suggestions({
    required List<Player> players,
    required String query,
    Set<int> excludedPlayerIds = const {},
    int limit = 8,
  }) {
    final q = normalize(query);
    if (q.length < minQueryLengthForSuggest) return const [];

    final starts = <Player>[];
    final middles = <Player>[];

    for (final player in players) {
      if (excludedPlayerIds.contains(player.id)) continue;

      var best = -1; // 2 = startsWith label token, 1 = contains
      for (final label in _labels(player)) {
        final n = normalize(label);
        if (n.startsWith(q)) {
          best = 2;
          break;
        }
        final parts = label.trim().split(RegExp(r'\s+'));
        for (final part in parts) {
          final pn = normalize(part);
          if (pn.startsWith(q)) {
            best = 2;
            break;
          }
        }
        if (best == 2) break;
        if (n.contains(q)) best = 1;
      }

      if (best == 2) {
        starts.add(player);
      } else if (best == 1) {
        middles.add(player);
      }

      if (starts.length >= limit) break;
    }

    final result = <Player>[...starts];
    for (final p in middles) {
      if (result.length >= limit) break;
      result.add(p);
    }
    return result;
  }
}
