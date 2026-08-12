import '../models/player.dart';

enum ResolveStatus { found, notFound, ambiguous }

class ResolveResult {
  final ResolveStatus status;
  final Player? player;
  final String message;
  final List<Player> candidates;

  const ResolveResult._({
    required this.status,
    this.player,
    required this.message,
    this.candidates = const [],
  });

  bool get isFound => status == ResolveStatus.found;

  factory ResolveResult.found(Player player) => ResolveResult._(
        status: ResolveStatus.found,
        player: player,
        message: '',
      );

  factory ResolveResult.notFound([String msg = 'Oyuncu bulunamadı.']) =>
      ResolveResult._(status: ResolveStatus.notFound, message: msg);

  factory ResolveResult.ambiguous(List<Player> candidates) => ResolveResult._(
        status: ResolveStatus.ambiguous,
        message: candidates.length > 1
            ? 'Birden fazla oyuncu. Listeden seç.'
            : 'Birden fazla oyuncu.',
        candidates: candidates,
      );
}

class SearchService {
  SearchService._();

  static const int minQueryLengthForSuggest = 2;
  static const int minTokenLengthForPartial = 4;

  /// normalizedName / alias ilk 2 karakter → oyuncu listesi (bir kez kurulur).
  static Map<String, List<Player>>? _prefixIndex;

  static void buildIndex(List<Player> players) {
    final map = <String, List<Player>>{};
    for (final p in players) {
      if (p.name.trim().isEmpty) continue;
      final keys = <String>{};
      void addKey(String raw) {
        final n = normalize(raw);
        if (n.length >= 2) keys.add(n.substring(0, 2));
        if (n.length >= 1) keys.add(n.substring(0, 1));
      }

      if (p.normalizedName.isNotEmpty) {
        addKey(p.normalizedName);
      } else {
        addKey(p.name);
      }
      for (final a in p.normalizedAliases) {
        if (a.isNotEmpty) addKey(a);
      }
      for (final a in p.aliases) {
        addKey(a);
      }
      // soyadı
      final parts = p.name.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) addKey(parts.last);

      for (final k in keys) {
        (map[k] ??= []).add(p);
      }
    }
    _prefixIndex = map;
  }

  static void clearIndex() => _prefixIndex = null;

  static String normalize(String input) {
    var s = input.trim().toLowerCase();
    const from = 'áàäâãåāăąéèëêēėęíìïîīįóòöôõøōúùüûūųýÿçćčñńňşšśžźżđ';
    const to   = 'aaaaaaaaaeeeeeeeiiiiiiioooooouuuuuuyycccnnnssszzzd';
    final buf = StringBuffer();
    for (final code in s.runes) {
      final ch = String.fromCharCode(code);
      final i = from.indexOf(ch);
      if (i >= 0) {
        buf.write(to[i]);
      } else if (ch == 'ı') {
        buf.write('i');
      } else if (ch == 'ğ') {
        buf.write('g');
      } else if (ch == 'ü') {
        buf.write('u');
      } else if (ch == 'ö') {
        buf.write('o');
      } else if (ch == 'ş') {
        buf.write('s');
      } else if (ch == 'ç') {
        buf.write('c');
      } else {
        buf.write(ch);
      }
    }
    // noktalama / fazla boşluk
    s = buf.toString().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  static bool equals(String a, String b) => normalize(a) == normalize(b);

  static bool contains(String text, String query) {
    final q = normalize(query);
    if (q.isEmpty) return true;
    return normalize(text).contains(q);
  }

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

  static bool matches(Player player, String answer) {
    final q = normalize(answer);
    if (q.isEmpty) return false;
    return _normalizedLabels(player).any((n) => n == q);
  }

  static bool matchesLastName(Player player, String answer) {
    final q = normalize(answer);
    if (q.length < 3) return false;
    for (final label in _labels(player)) {
      final parts = label.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty) continue;
      final last = normalize(parts.last);
      if (last == q) return true;
    }
    return false;
  }

  static bool matchesPartial(Player player, String answer) {
    final q = normalize(answer);
    if (q.length < minTokenLengthForPartial) return false;
    return _normalizedLabels(player).any((n) => n.contains(q));
  }

  static Player? findExactPlayer({
    required List<Player> players,
    required String answer,
  }) {
    for (final player in players) {
      if (matches(player, answer)) return player;
    }
    return null;
  }

  static ResolveResult resolve({
    required List<Player> players,
    required String answer,
    Set<int> excludedPlayerIds = const {},
  }) {
    final trimmed = answer.trim();
    if (trimmed.isEmpty) return ResolveResult.notFound();

    final pool = players
        .where((p) => !excludedPlayerIds.contains(p.id) && p.name.trim().isNotEmpty)
        .toList();

    final exact = <Player>[];
    for (final p in pool) {
      if (matches(p, trimmed)) exact.add(p);
    }
    if (exact.length == 1) return ResolveResult.found(exact.first);
    if (exact.length > 1) return ResolveResult.ambiguous(exact);

    final byLast = <Player>[];
    for (final p in pool) {
      if (matchesLastName(p, trimmed)) byLast.add(p);
    }
    if (byLast.length == 1) return ResolveResult.found(byLast.first);
    if (byLast.length > 1) return ResolveResult.ambiguous(byLast);

    final byPartial = <Player>[];
    for (final p in pool) {
      if (matchesPartial(p, trimmed)) byPartial.add(p);
    }
    if (byPartial.length == 1) return ResolveResult.found(byPartial.first);
    if (byPartial.length > 1) {
      return ResolveResult.ambiguous(byPartial.take(12).toList());
    }

    return ResolveResult.notFound();
  }

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

  /// Hızlı autocomplete: önek indeksi + erken çıkış.
  static List<Player> suggestions({
    required List<Player> players,
    required String query,
    Set<int> excludedPlayerIds = const {},
    int limit = 8,
  }) {
    final q = normalize(query);
    if (q.length < minQueryLengthForSuggest) return const [];

    // Aday kümesi: indeks varsa daralt, yoksa verilen liste
    Iterable<Player> pool;
    final index = _prefixIndex;
    if (index != null && q.isNotEmpty) {
      final key2 = q.length >= 2 ? q.substring(0, 2) : q.substring(0, 1);
      final key1 = q.substring(0, 1);
      final a = index[key2] ?? const <Player>[];
      final b = index[key1] ?? const <Player>[];
      // key2 daha dar — önce onu kullan
      pool = a.isNotEmpty ? a : b;
      if (pool is List && (pool as List).isEmpty) {
        pool = players;
      }
    } else {
      pool = players;
    }

    final starts = <Player>[];
    final middles = <Player>[];
    final seen = <int>{};

    for (final player in pool) {
      if (excludedPlayerIds.contains(player.id)) continue;
      if (!seen.add(player.id)) continue;

      final labels = _normalizedLabels(player);
      var best = -1;

      for (final n in labels) {
        if (n.startsWith(q)) {
          best = 2;
          break;
        }
        // token (soyadı vb.)
        for (final part in n.split(' ')) {
          if (part.startsWith(q)) {
            best = 2;
            break;
          }
        }
        if (best == 2) break;
        if (best < 1 && n.contains(q)) best = 1;
      }

      if (best == 2) {
        starts.add(player);
        if (starts.length >= limit) break; // yeter
      } else if (best == 1) {
        middles.add(player);
      }
    }

    if (starts.length >= limit) return starts.sublist(0, limit);

    final result = <Player>[...starts];
    for (final p in middles) {
      if (result.length >= limit) break;
      result.add(p);
    }
    return result;
  }
}