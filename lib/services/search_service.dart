import 'dart:async';

import '../models/player.dart';
import '../utils/player_dedupe.dart';

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

class _PreparedQuery {
  final String normalized;
  final String compact;
  final List<String> tokens;

  const _PreparedQuery({
    required this.normalized,
    required this.compact,
    required this.tokens,
  });
}

class _SearchDocument {
  final Player player;
  final List<String> normalizedLabels;
  final Set<String> lastNameKeys;
  final String displayNormalized;
  final String displayCompact;

  const _SearchDocument({
    required this.player,
    required this.normalizedLabels,
    required this.lastNameKeys,
    required this.displayNormalized,
    required this.displayCompact,
  });
}

class SearchService {
  SearchService._();

  static const int minQueryLengthForSuggest = 2;
  static const int minTokenLengthForPartial = 4;

  static final RegExp _nonSearchChars = RegExp(r'[^a-z0-9\s]');
  static final RegExp _whitespace = RegExp(r'\s+');

  static Map<String, List<Player>>? _prefixIndex;

  // Search metadata is warmed in small chunks after Repository initialization.
  // This keeps startup responsive while preserving the fast submit path once
  // the cache has warmed.
  static final Map<int, _SearchDocument> _documentCache = {};
  static const int _indexBuildChunkSize = 64;
  static int _indexBuildGeneration = 0;

  static void buildIndex(List<Player> players) {
    final generation = ++_indexBuildGeneration;
    _prefixIndex = null;
    _documentCache.clear();

    // Do not block Repository._initializeInternal(). The previous optimized
    // implementation prepared every search document synchronously here, which
    // moved the submit cost to app startup and could trigger an Android ANR.
    unawaited(_buildIndexChunked(players, generation));
  }

  static Future<void> _buildIndexChunked(
    List<Player> players,
    int generation,
  ) async {
    final map = <String, List<Player>>{};

    // Yield once immediately so buildIndex() returns before any heavy work.
    await Future<void>.delayed(Duration.zero);

    var processed = 0;
    for (final p in players) {
      if (generation != _indexBuildGeneration) return;
      if (p.name.trim().isEmpty) continue;

      final doc = _buildDocument(p);
      _documentCache[p.id] = doc;

      final keys = <String>{};

      void addPreparedKey(String normalized) {
        if (normalized.isEmpty) return;
        final compactValue = _compactNormalized(normalized);
        if (normalized.length >= 2) keys.add(normalized.substring(0, 2));
        if (normalized.isNotEmpty) keys.add(normalized.substring(0, 1));
        if (compactValue.length >= 2) keys.add(compactValue.substring(0, 2));
        if (compactValue.isNotEmpty) keys.add(compactValue.substring(0, 1));
      }

      for (final label in doc.normalizedLabels) {
        addPreparedKey(label);
      }
      final nameParts = p.name.trim().split(_whitespace);
      if (nameParts.length >= 2) {
        addPreparedKey(normalize(nameParts.last));
      }

      for (final k in keys) {
        (map[k] ??= []).add(p);
      }

      processed++;
      if (processed % _indexBuildChunkSize == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    if (generation == _indexBuildGeneration) {
      _prefixIndex = map;
    }
  }

  static void clearIndex() {
    _indexBuildGeneration++;
    _prefixIndex = null;
    _documentCache.clear();
  }

  static String normalize(String input) {
    var s = input.trim().toLowerCase();
    const from = 'áàäâãåāăąéèëêēėęíìïîīįóòöôõøōúùüûūųýÿçćčñńňşšśžźżđ';
    const to = 'aaaaaaaaaeeeeeeeiiiiiiioooooouuuuuuyycccnnnssszzzd';
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
    s = buf.toString().replaceAll(_nonSearchChars, ' ');
    s = s.replaceAll(_whitespace, ' ').trim();
    return s;
  }

  static String _compactNormalized(String normalized) =>
      normalized.replaceAll(' ', '');

  static String compact(String input) => _compactNormalized(normalize(input));

  static _PreparedQuery _prepareQuery(String input) {
    final q = normalize(input);
    return _PreparedQuery(
      normalized: q,
      compact: _compactNormalized(q),
      tokens: q.isEmpty ? const [] : q.split(' '),
    );
  }

  static bool equals(String a, String b) {
    final an = normalize(a);
    final bn = normalize(b);
    if (an == bn) return true;
    return _compactNormalized(an) == _compactNormalized(bn);
  }

  static bool contains(String text, String query) {
    final prepared = _prepareQuery(query);
    if (prepared.normalized.isEmpty) return true;
    final n = normalize(text);
    if (n.contains(prepared.normalized)) return true;
    return _compactNormalized(n).contains(prepared.compact);
  }

  static List<String> _labels(Player player) {
    final out = <String>{};
    if (player.name.trim().isNotEmpty) out.add(player.name);
    out.addAll(player.aliases.where((a) => a.trim().isNotEmpty));
    return out.toList();
  }

  static _SearchDocument _buildDocument(Player player) {
    final normalizedLabels = <String>{};

    void addRaw(String raw) {
      if (raw.trim().isEmpty) return;
      final n = normalize(raw);
      if (n.isNotEmpty) normalizedLabels.add(n);
      final c = _compactNormalized(n);
      if (c.isNotEmpty) normalizedLabels.add(c);
    }

    if (player.normalizedName.isNotEmpty) addRaw(player.normalizedName);
    for (final a in player.normalizedAliases) {
      addRaw(a);
    }
    addRaw(player.name);
    for (final a in player.aliases) {
      addRaw(a);
    }

    if (normalizedLabels.isEmpty && player.name.trim().isNotEmpty) {
      addRaw(player.name);
    }

    final lastNameKeys = <String>{};
    for (final label in _labels(player)) {
      final parts = label.trim().split(_whitespace);
      if (parts.isEmpty) continue;
      final last = normalize(parts.last);
      if (last.isEmpty) continue;
      lastNameKeys.add(last);
      lastNameKeys.add(_compactNormalized(last));
    }

    final displayNormalized = normalize(player.name);

    return _SearchDocument(
      player: player,
      normalizedLabels: normalizedLabels.toList(growable: false),
      lastNameKeys: lastNameKeys,
      displayNormalized: displayNormalized,
      displayCompact: _compactNormalized(displayNormalized),
    );
  }

  static _SearchDocument _documentFor(Player player) {
    final cached = _documentCache[player.id];
    if (cached != null && identical(cached.player, player)) {
      return cached;
    }

    final doc = _buildDocument(player);
    _documentCache[player.id] = doc;
    return doc;
  }

  static bool _matchesPrepared(_SearchDocument doc, _PreparedQuery query) {
    if (query.normalized.isEmpty) return false;
    return doc.normalizedLabels
        .any((n) => n == query.normalized || n == query.compact);
  }

  static bool matches(Player player, String answer) =>
      _matchesPrepared(_documentFor(player), _prepareQuery(answer));

  static bool _matchesLastNamePrepared(
    _SearchDocument doc,
    _PreparedQuery query,
  ) {
    if (query.normalized.length < 3) return false;
    return doc.lastNameKeys.contains(query.normalized) ||
        doc.lastNameKeys.contains(query.compact);
  }

  static bool matchesLastName(Player player, String answer) =>
      _matchesLastNamePrepared(_documentFor(player), _prepareQuery(answer));

  static bool _matchesPartialPrepared(
    _SearchDocument doc,
    _PreparedQuery query,
  ) {
    if (query.normalized.length < minTokenLengthForPartial &&
        query.compact.length < minTokenLengthForPartial) {
      return false;
    }

    return doc.normalizedLabels.any((n) {
      if (query.normalized.isNotEmpty && n.contains(query.normalized)) {
        return true;
      }
      if (query.compact.isNotEmpty && n.contains(query.compact)) {
        return true;
      }
      return false;
    });
  }

  static bool matchesPartial(Player player, String answer) =>
      _matchesPartialPrepared(_documentFor(player), _prepareQuery(answer));

  static bool _matchesTokensPrepared(String label, _PreparedQuery query) {
    final tokens = query.tokens;
    if (tokens.isEmpty) return false;

    if (tokens.length == 1) {
      final t = tokens.first;
      final c = _compactNormalized(label);
      return label.startsWith(t) ||
          label.contains(t) ||
          c.startsWith(t) ||
          c.contains(t) ||
          label.split(' ').any((p) => p.startsWith(t));
    }

    final cLabel = _compactNormalized(label);
    if (cLabel.contains(query.compact) || cLabel.startsWith(query.compact)) {
      return true;
    }

    for (final t in tokens) {
      final ok = label.contains(t) ||
          cLabel.contains(t) ||
          label.split(' ').any((p) => p.startsWith(t));
      if (!ok) return false;
    }
    return true;
  }

  static Player? findExactPlayer({
    required List<Player> players,
    required String answer,
  }) {
    final query = _prepareQuery(answer);
    if (query.normalized.isEmpty) return null;

    for (final player in players) {
      if (_matchesPrepared(_documentFor(player), query)) return player;
    }
    return null;
  }

  static ResolveResult resolve({
    required List<Player> players,
    required String answer,
    Set<int> excludedPlayerIds = const {},
  }) {
    final query = _prepareQuery(answer);
    if (query.normalized.isEmpty) return ResolveResult.notFound();

    // Important: the old implementation created a filtered list, then scanned
    // that list three times. It also normalized the same query and player labels
    // repeatedly inside each scan. Here we keep the exact same priority
    // (exact > last name > partial) while doing one pass over the supplied pool
    // and using precomputed player search metadata.
    final exact = <Player>[];
    final byLast = <Player>[];
    final byPartial = <Player>[];

    final allowLastName = query.normalized.length >= 3;
    final allowPartial =
        query.normalized.length >= minTokenLengthForPartial ||
            query.compact.length >= minTokenLengthForPartial;

    for (final p in players) {
      if (excludedPlayerIds.contains(p.id) || p.name.trim().isEmpty) continue;

      final doc = _documentFor(p);

      if (_matchesPrepared(doc, query)) {
        exact.add(p);
        continue;
      }

      if (allowLastName && _matchesLastNamePrepared(doc, query)) {
        byLast.add(p);
      }

      if (allowPartial && _matchesPartialPrepared(doc, query)) {
        byPartial.add(p);
      }
    }

    if (exact.length == 1) return ResolveResult.found(exact.first);
    if (exact.length > 1) return ResolveResult.ambiguous(exact);

    if (byLast.length == 1) return ResolveResult.found(byLast.first);
    if (byLast.length > 1) return ResolveResult.ambiguous(byLast);

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

  static List<Player> suggestions({
    required List<Player> players,
    required String query,
    Set<int> excludedPlayerIds = const {},
    int limit = 8,
  }) {
    final prepared = _prepareQuery(query);
    final q = prepared.normalized;
    if (q.length < minQueryLengthForSuggest) return const [];
    final qc = prepared.compact;

    Iterable<Player> pool;
    final index = _prefixIndex;
    if (index != null && q.isNotEmpty) {
      final firstToken = prepared.tokens.firstWhere(
        (t) => t.isNotEmpty,
        orElse: () => q,
      );
      final keySrc = firstToken.length >= 2 ? firstToken : qc;
      final key2 =
          keySrc.length >= 2 ? keySrc.substring(0, 2) : keySrc.substring(0, 1);
      final key1 = keySrc.substring(0, 1);
      final a = index[key2] ?? const <Player>[];
      final b = index[key1] ?? const <Player>[];
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

      final doc = _documentFor(player);
      final labels = doc.normalizedLabels;
      var best = -1;

      for (final n in labels) {
        if (n.startsWith(q) || (qc.isNotEmpty && n.startsWith(qc))) {
          best = 2;
          break;
        }
        for (final part in n.split(' ')) {
          if (part.startsWith(q) || (qc.isNotEmpty && part.startsWith(qc))) {
            best = 2;
            break;
          }
        }
        if (best == 2) break;

        if (_matchesTokensPrepared(n, prepared)) {
          best = 2;
          break;
        }

        if (best < 1) {
          if (n.contains(q) || (qc.isNotEmpty && n.contains(qc))) {
            best = 1;
          }
        }
      }

      if (best < 2) {
        final display = doc.displayNormalized;
        if (_matchesTokensPrepared(display, prepared) ||
            display.startsWith(q) ||
            doc.displayCompact.startsWith(qc)) {
          best = 2;
        } else if (best < 1 &&
            (display.contains(q) || doc.displayCompact.contains(qc))) {
          best = 1;
        }
      }

      if (best == 2) {
        starts.add(player);
        if (starts.length >= limit) break;
      } else if (best == 1) {
        middles.add(player);
      }
    }

    if (starts.length >= limit) {
      return PlayerDedupe.dedupe(starts).take(limit).toList();
    }

    final result = <Player>[...starts];
    for (final p in middles) {
      if (result.length >= limit * 2) break;
      result.add(p);
    }
    return PlayerDedupe.dedupe(result).take(limit).toList();
  }
}
