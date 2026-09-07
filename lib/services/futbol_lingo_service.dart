import 'dart:math';

import '../data/continents.dart';
import '../utils/country_names.dart';
import 'runtime_v4/game_data_v4_database.dart';

enum FutbolLingoCategory { mixed, player, club, country }

extension FutbolLingoCategoryX on FutbolLingoCategory {
  String get label {
    switch (this) {
      case FutbolLingoCategory.mixed:
        return 'Karışık';
      case FutbolLingoCategory.player:
        return 'Futbolcu';
      case FutbolLingoCategory.club:
        return 'Kulüp';
      case FutbolLingoCategory.country:
        return 'Ülke';
    }
  }
}

class FutbolLingoPuzzle {
  final FutbolLingoCategory category;
  final String answer;
  final String displayAnswer;
  final String primaryHint;
  final String secondaryHint;
  final String key;

  const FutbolLingoPuzzle({
    required this.category,
    required this.answer,
    required this.displayAnswer,
    required this.primaryHint,
    required this.secondaryHint,
    required this.key,
  });
}

class _LingoCandidate {
  final int? id;
  final String answer;
  final String displayAnswer;
  final String country;
  final String extra;

  const _LingoCandidate({
    required this.answer,
    required this.displayAnswer,
    required this.country,
    required this.extra,
    this.id,
  });
}

/// V4 SQLite-backed content source for Futbol Lingo.
///
/// The playable word itself is normalized to ASCII A-Z so the same puzzle
/// works with Turkish/international football names without requiring a giant
/// accented keyboard. The result card still shows the canonical display text.
class FutbolLingoService {
  FutbolLingoService._();

  static final FutbolLingoService instance = FutbolLingoService._();

  static const int minWordLength = 4;
  static const int maxWordLength = 11;

  final Random _random = Random();

  List<_LingoCandidate>? _playerCache;
  List<_LingoCandidate>? _clubCache;
  List<_LingoCandidate>? _countryCache;

  GameDataV4Database get _source => GameDataV4Database.instance;

  Future<FutbolLingoPuzzle> createPuzzle(
    FutbolLingoCategory requestedCategory, {
    Set<String> excludeKeys = const <String>{},
  }) async {
    await _source.initialize();

    final actualCategory = requestedCategory == FutbolLingoCategory.mixed
        ? <FutbolLingoCategory>[
            FutbolLingoCategory.player,
            FutbolLingoCategory.club,
            FutbolLingoCategory.country,
          ][_random.nextInt(3)]
        : requestedCategory;

    switch (actualCategory) {
      case FutbolLingoCategory.player:
        return _createPlayerPuzzle(excludeKeys);
      case FutbolLingoCategory.club:
        return _createClubPuzzle(excludeKeys);
      case FutbolLingoCategory.country:
        return _createCountryPuzzle(excludeKeys);
      case FutbolLingoCategory.mixed:
        throw StateError('Karışık kategori gerçek puzzle türü olamaz.');
    }
  }

  Future<bool> isValidGuess(
    FutbolLingoCategory category,
    String rawGuess,
  ) async {
    final guess = normalizeWord(rawGuess);
    if (guess.isEmpty) return false;

    switch (category) {
      case FutbolLingoCategory.player:
        return (await _playerCandidates()).any((row) => row.answer == guess);
      case FutbolLingoCategory.club:
        return (await _clubCandidates()).any((row) => row.answer == guess);
      case FutbolLingoCategory.country:
        return (await _countryCandidates()).any((row) => row.answer == guess);
      case FutbolLingoCategory.mixed:
        return false;
    }
  }

  Future<FutbolLingoPuzzle> _createPlayerPuzzle(Set<String> excludeKeys) async {
    final candidate = _pickCandidate(
      await _playerCandidates(),
      FutbolLingoCategory.player,
      excludeKeys,
    );

    var clubHint = '';
    final playerId = candidate.id;
    if (playerId != null) {
      final clubRows = await _source.database.rawQuery(
        '''
        SELECT c.name
        FROM player_clubs pc
        JOIN clubs c ON c.id = pc.club_id
        WHERE pc.player_id = ?
          AND TRIM(COALESCE(c.name, '')) <> ''
          AND LOWER(TRIM(c.name)) NOT LIKE 'club %'
        ORDER BY
          COALESCE(c.popularity_seed, 0) DESC,
          c.name COLLATE NOCASE
        LIMIT 1
        ''',
        <Object?>[playerId],
      );

      if (clubRows.isNotEmpty) {
        clubHint = clubRows.first['name']?.toString().trim() ?? '';
      }
    }

    final secondaryParts = <String>[
      if (candidate.extra.isNotEmpty) 'Pozisyon: ${candidate.extra}',
      if (clubHint.isNotEmpty) 'Kulüp geçmişi: $clubHint',
    ];

    return FutbolLingoPuzzle(
      category: FutbolLingoCategory.player,
      answer: candidate.answer,
      displayAnswer: candidate.displayAnswer,
      primaryHint: 'Ülke: ${candidate.country}',
      secondaryHint: secondaryParts.isEmpty
          ? 'Futbolcu ipucu bulunamadı'
          : secondaryParts.join(' • '),
      key: 'player:${candidate.id ?? candidate.answer}',
    );
  }

  Future<FutbolLingoPuzzle> _createClubPuzzle(Set<String> excludeKeys) async {
    final candidate = _pickCandidate(
      await _clubCandidates(),
      FutbolLingoCategory.club,
      excludeKeys,
    );

    return FutbolLingoPuzzle(
      category: FutbolLingoCategory.club,
      answer: candidate.answer,
      displayAnswer: candidate.displayAnswer,
      primaryHint: 'Ülke: ${candidate.country}',
      secondaryHint: candidate.extra.isEmpty
          ? 'Lig bilgisi yok'
          : 'Lig: ${candidate.extra}',
      key: 'club:${candidate.id ?? candidate.answer}',
    );
  }

  Future<FutbolLingoPuzzle> _createCountryPuzzle(
    Set<String> excludeKeys,
  ) async {
    final candidate = _pickCandidate(
      await _countryCandidates(),
      FutbolLingoCategory.country,
      excludeKeys,
    );

    return FutbolLingoPuzzle(
      category: FutbolLingoCategory.country,
      answer: candidate.answer,
      displayAnswer: candidate.displayAnswer,
      primaryHint: candidate.extra.isEmpty
          ? 'Kıta bilgisi yok'
          : 'Kıta: ${candidate.extra}',
      secondaryHint: 'İlk harf: ${candidate.answer[0]}',
      key: 'country:${candidate.answer}',
    );
  }

  _LingoCandidate _pickCandidate(
    List<_LingoCandidate> pool,
    FutbolLingoCategory category,
    Set<String> excludeKeys,
  ) {
    if (pool.isEmpty) {
      throw StateError(
        '${category.label} kategorisinde oynanabilir kelime yok.',
      );
    }

    final candidates = <_LingoCandidate>[
      for (final row in pool)
        if (!excludeKeys.contains('${category.name}:${row.id ?? row.answer}'))
          row,
    ];

    final source = candidates.isEmpty ? pool : candidates;
    return source[_random.nextInt(source.length)];
  }

  Future<List<_LingoCandidate>> _playerCandidates() async {
    final cached = _playerCache;
    if (cached != null) return cached;

    final rows = await _source.database.rawQuery('''
      SELECT
        p.id,
        p.name,
        p.country,
        p.position,
        p.selection_rank
      FROM players p
      WHERE p.selection_rank BETWEEN 1 AND 7000
        AND TRIM(COALESCE(p.name, '')) <> ''
        AND TRIM(COALESCE(p.country, '')) <> ''
      ORDER BY p.selection_rank, p.id
      LIMIT 2500
      ''');

    final seenAnswers = <String>{};
    final result = <_LingoCandidate>[];

    for (final row in rows) {
      final name = row['name']?.toString().trim() ?? '';
      final token = _playerPlayableToken(name);
      if (token == null) continue;

      final answer = normalizeWord(token);
      if (!_playableLength(answer) || !seenAnswers.add(answer)) continue;

      final country = CountryNames.canonical(row['country']?.toString() ?? '');
      if (country.isEmpty) continue;

      result.add(
        _LingoCandidate(
          id: (row['id'] as num).toInt(),
          answer: answer,
          displayAnswer: token,
          country: country,
          extra: _positionLabel(row['position']?.toString() ?? ''),
        ),
      );
    }

    _playerCache = List<_LingoCandidate>.unmodifiable(result);
    return _playerCache!;
  }

  Future<List<_LingoCandidate>> _clubCandidates() async {
    final cached = _clubCache;
    if (cached != null) return cached;

    final rows = await _source.database.rawQuery('''
      SELECT
        c.id,
        c.name,
        c.country,
        c.competition,
        c.popularity_seed
      FROM clubs c
      WHERE TRIM(COALESCE(c.name, '')) <> ''
        AND COALESCE(c.popularity_seed, 0) > 0
        AND LOWER(TRIM(c.name)) NOT LIKE 'club %'
        AND LOWER(c.name) NOT LIKE '% u19%'
        AND LOWER(c.name) NOT LIKE '% u21%'
        AND LOWER(c.name) NOT LIKE '% u23%'
        AND LOWER(c.name) NOT LIKE '%youth%'
        AND LOWER(c.name) NOT LIKE '%academy%'
        AND LOWER(c.name) NOT LIKE '%reserve%'
        AND LOWER(COALESCE(c.entity_type, '')) NOT IN (
          'youth', 'academy', 'reserve', 'reserves', 'development'
        )
      ORDER BY
        COALESCE(c.popularity_seed, 0) DESC,
        c.name COLLATE NOCASE,
        c.id
      LIMIT 1000
      ''');

    final seenAnswers = <String>{};
    final result = <_LingoCandidate>[];

    for (final row in rows) {
      final rawName = row['name']?.toString().trim() ?? '';
      final display = _stripClubTokens(rawName);
      final answer = normalizeWord(display);

      if (!_playableLength(answer) || !seenAnswers.add(answer)) continue;

      final country = CountryNames.canonical(row['country']?.toString() ?? '');
      if (country.isEmpty) continue;

      result.add(
        _LingoCandidate(
          id: (row['id'] as num).toInt(),
          answer: answer,
          displayAnswer: display,
          country: country,
          extra: row['competition']?.toString().trim() ?? '',
        ),
      );
    }

    _clubCache = List<_LingoCandidate>.unmodifiable(result);
    return _clubCache!;
  }

  Future<List<_LingoCandidate>> _countryCandidates() async {
    final cached = _countryCache;
    if (cached != null) return cached;

    final rows = await _source.database.rawQuery('''
      SELECT
        p.country,
        COUNT(*) AS player_count
      FROM players p
      WHERE p.selection_rank BETWEEN 1 AND 12000
        AND TRIM(COALESCE(p.country, '')) <> ''
      GROUP BY p.country
      HAVING COUNT(*) >= 12
      ORDER BY player_count DESC, p.country COLLATE NOCASE
      ''');

    final seenAnswers = <String>{};
    final result = <_LingoCandidate>[];

    for (final row in rows) {
      final country = CountryNames.canonical(row['country']?.toString() ?? '');
      if (country.isEmpty) continue;

      final answer = normalizeWord(country);
      if (!_playableLength(answer) || !seenAnswers.add(answer)) continue;

      result.add(
        _LingoCandidate(
          answer: answer,
          displayAnswer: country,
          country: country,
          extra: _continentLabel(continentOf(country)),
        ),
      );
    }

    _countryCache = List<_LingoCandidate>.unmodifiable(result);
    return _countryCache!;
  }

  static String normalizeWord(String raw) {
    var value = raw.trim().toLowerCase();

    const replacements = <String, String>{
      'ı': 'i',
      'ş': 's',
      'ğ': 'g',
      'ü': 'u',
      'ö': 'o',
      'ç': 'c',
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'ã': 'a',
      'å': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ñ': 'n',
      'ć': 'c',
      'č': 'c',
      'š': 's',
      'ž': 'z',
      'đ': 'd',
      'ł': 'l',
    };

    for (final entry in replacements.entries) {
      value = value.replaceAll(entry.key, entry.value);
    }

    return value.replaceAll(RegExp(r'[^a-z]'), '').toUpperCase();
  }

  static bool _playableLength(String answer) {
    return answer.length >= minWordLength && answer.length <= maxWordLength;
  }

  static String? _playerPlayableToken(String name) {
    final tokens = name
        .replaceAll('-', ' ')
        .replaceAll('.', ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.trim().isNotEmpty)
        .toList(growable: false);

    if (tokens.isEmpty) return null;

    const generic = <String>{
      'jr',
      'junior',
      'filho',
      'neto',
      'dos',
      'das',
      'de',
      'da',
      'do',
    };

    for (final token in tokens.reversed) {
      final normalized = normalizeWord(token);
      if (generic.contains(token.toLowerCase())) continue;
      if (_playableLength(normalized)) return token;
    }

    return null;
  }

  static String _stripClubTokens(String raw) {
    return raw
        .replaceAll(
          RegExp(r'\b(fc|cf|sc|ac|afc|fk|sk|cd|rc|ss)\b', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _positionLabel(String raw) {
    final value = raw.trim().toLowerCase();

    if (value.contains('goal') || value == 'gk') return 'Kaleci';
    if (value.contains('def')) return 'Defans';
    if (value.contains('mid')) return 'Orta saha';
    if (value.contains('attack') ||
        value.contains('forward') ||
        value.contains('striker')) {
      return 'Forvet';
    }

    return raw.trim();
  }

  static String _continentLabel(Continent? continent) {
    switch (continent) {
      case Continent.europe:
        return 'Avrupa';
      case Continent.southAmerica:
        return 'Güney Amerika';
      case Continent.northAmerica:
        return 'Kuzey Amerika';
      case Continent.africa:
        return 'Afrika';
      case Continent.asia:
        return 'Asya';
      case Continent.oceania:
        return 'Okyanusya';
      case null:
        return '';
    }
  }
}
