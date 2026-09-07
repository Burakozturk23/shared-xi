import 'dart:math';

import '../data/build_xi_formations.dart';
import '../data/country_codes.dart';
import '../models/club.dart';
import '../utils/country_names.dart';
import 'runtime_v4/game_data_v4_database.dart';

class KadroKasasiSlot {
  final int playerId;
  final String playerName;
  final String country;
  final String broadPosition;
  final String detailedPosition;
  final FormationSlot formationSlot;

  const KadroKasasiSlot({
    required this.playerId,
    required this.playerName,
    required this.country,
    required this.broadPosition,
    required this.detailedPosition,
    required this.formationSlot,
  });
}

class KadroKasasiPuzzle {
  final Club club;
  final Formation formation;
  final List<KadroKasasiSlot> slots;

  const KadroKasasiPuzzle({
    required this.club,
    required this.formation,
    required this.slots,
  });

  String get league => club.league;
}

class _PuzzlePlayerRow {
  final int id;
  final String name;
  final String country;
  final String broadPosition;
  final String detailedPosition;
  final int selectionRank;

  const _PuzzlePlayerRow({
    required this.id,
    required this.name,
    required this.country,
    required this.broadPosition,
    required this.detailedPosition,
    required this.selectionRank,
  });
}

class KadroKasasiService {
  KadroKasasiService._();

  static final KadroKasasiService instance = KadroKasasiService._();

  final Random _random = Random();
  List<Map<String, Object?>>? _clubCandidateCache;

  GameDataV4Database get _source => GameDataV4Database.instance;

  Future<KadroKasasiPuzzle> createPuzzle({
    Set<int> excludeClubIds = const <int>{},
  }) async {
    await _source.initialize();

    final candidates = List<Map<String, Object?>>.from(await _clubCandidates())
      ..shuffle(_random);

    final preferredFormations = allFormations
        .where(
          (formation) => const <String>{
            '4-3-3',
            '4-4-2',
            '4-2-3-1',
            '3-5-2',
          }.contains(formation.id),
        )
        .toList(growable: false);

    var attempts = 0;

    for (final row in candidates) {
      final clubId = (row['id'] as num?)?.toInt() ?? 0;
      if (clubId <= 0 || excludeClubIds.contains(clubId)) continue;

      attempts += 1;
      if (attempts > 60) break;

      final players = await _playersForClub(clubId);
      if (players.length < 14) continue;

      final formations = List<Formation>.from(preferredFormations)
        ..shuffle(_random);

      for (final formation in formations) {
        final assigned = _assignFormation(players, formation);
        if (assigned == null) continue;

        final countries = <String>{
          for (final slot in assigned)
            CountryNames.canonical(slot.country).toLowerCase(),
        }..remove('');

        if (countries.length < 4) continue;

        final club = Club(
          id: clubId,
          name: row['name']?.toString() ?? '',
          league: row['competition']?.toString() ?? '',
          country: CountryNames.canonical(row['country']?.toString() ?? ''),
          badgeKey: _optionalString(row['badge_key']),
          color: (row['color'] as num?)?.toInt(),
        );

        if (club.name.trim().isEmpty) continue;

        return KadroKasasiPuzzle(
          club: club,
          formation: formation,
          slots: List<KadroKasasiSlot>.unmodifiable(assigned),
        );
      }
    }

    throw StateError(
      'Kadro Kasası için uygun kulüp/pozisyon dağılımı üretilemedi.',
    );
  }

  Future<List<Club>> searchClubs(String query, {int limit = 10}) async {
    await _source.initialize();

    final q = query.trim();
    if (q.length < 2) return const <Club>[];

    final safeLimit = limit.clamp(1, 20).toInt();
    final rows = await _source.database.rawQuery(
      '''
      SELECT
        c.id,
        c.name,
        c.country,
        c.competition,
        c.badge_key,
        c.color
      FROM clubs c
      WHERE TRIM(c.name) <> ''
        AND c.name LIKE ? COLLATE NOCASE
        AND LOWER(TRIM(c.name)) NOT LIKE 'club %'
        AND LOWER(COALESCE(c.entity_type, '')) NOT IN (
          'youth', 'academy', 'reserve', 'reserves', 'development'
        )
      ORDER BY
        COALESCE(c.popularity_seed, 0) DESC,
        c.name COLLATE NOCASE,
        c.id
      LIMIT ?
      ''',
      <Object?>['%$q%', safeLimit],
    );

    return List<Club>.unmodifiable(
      rows.map(
        (row) => Club(
          id: (row['id'] as num).toInt(),
          name: row['name']?.toString() ?? '',
          league: row['competition']?.toString() ?? '',
          country: CountryNames.canonical(row['country']?.toString() ?? ''),
          badgeKey: _optionalString(row['badge_key']),
          color: (row['color'] as num?)?.toInt(),
        ),
      ),
    );
  }

  bool guessMatches(KadroKasasiPuzzle puzzle, String guess) {
    final normalizedGuess = _normalizeClubName(guess);
    if (normalizedGuess.isEmpty) return false;

    final keys = <String>{
      _normalizeClubName(puzzle.club.name),
      _normalizeClubName(_stripClubTokens(puzzle.club.name)),
    }..remove('');

    return keys.contains(normalizedGuess);
  }

  Future<List<Map<String, Object?>>> _clubCandidates() async {
    final cached = _clubCandidateCache;
    if (cached != null) return cached;

    final rows = await _source.database.rawQuery('''
      SELECT
        c.id,
        c.name,
        c.country,
        c.competition,
        c.badge_key,
        c.color,
        c.popularity_seed,
        (
          SELECT COUNT(DISTINCT pc.player_id)
          FROM player_clubs pc
          JOIN players p ON p.id = pc.player_id
          WHERE pc.club_id = c.id
            AND p.selection_rank BETWEEN 1 AND 12000
            AND TRIM(COALESCE(p.name, '')) <> ''
            AND TRIM(COALESCE(p.country, '')) <> ''
        ) AS playable_player_count
      FROM clubs c
      WHERE TRIM(c.name) <> ''
        AND TRIM(COALESCE(c.competition, '')) <> ''
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
      LIMIT 320
      ''');

    final filtered = <Map<String, Object?>>[
      for (final row in rows)
        if (((row['playable_player_count'] as num?)?.toInt() ?? 0) >= 16)
          Map<String, Object?>.from(row),
    ];

    _clubCandidateCache = List<Map<String, Object?>>.unmodifiable(filtered);
    return _clubCandidateCache!;
  }

  Future<List<_PuzzlePlayerRow>> _playersForClub(int clubId) async {
    final rows = await _source.database.rawQuery(
      '''
      SELECT
        p.id,
        p.name,
        p.country,
        p.position,
        p.selection_rank,
        pr.detailed_position
      FROM player_clubs pc
      JOIN players p ON p.id = pc.player_id
      LEFT JOIN profiles pr ON pr.player_id = p.id
      WHERE pc.club_id = ?
        AND p.selection_rank BETWEEN 1 AND 12000
        AND TRIM(COALESCE(p.name, '')) <> ''
        AND TRIM(COALESCE(p.country, '')) <> ''
      ORDER BY
        p.selection_rank,
        p.id
      LIMIT 90
      ''',
      <Object?>[clubId],
    );

    return rows
        .map((row) {
          final broad = _canonicalBroadPosition(
            row['position']?.toString() ?? '',
          );
          final detailed = row['detailed_position']?.toString().trim() ?? '';

          return _PuzzlePlayerRow(
            id: (row['id'] as num).toInt(),
            name: row['name']?.toString() ?? '',
            country: CountryNames.canonical(row['country']?.toString() ?? ''),
            broadPosition: broad,
            detailedPosition: detailed,
            selectionRank: (row['selection_rank'] as num?)?.toInt() ?? 999999,
          );
        })
        .where((row) {
          return row.name.isNotEmpty &&
              row.country.isNotEmpty &&
              row.broadPosition.isNotEmpty &&
              countryIso(row.country) != null;
        })
        .toList(growable: false);
  }

  List<KadroKasasiSlot>? _assignFormation(
    List<_PuzzlePlayerRow> players,
    Formation formation,
  ) {
    final remaining = List<_PuzzlePlayerRow>.from(players);
    final resultBySlot = <int, KadroKasasiSlot>{};

    final slotIndexes = List<int>.generate(formation.slots.length, (i) => i)
      ..sort((a, b) {
        final aScore = _slotSpecificity(formation.slots[a]);
        final bScore = _slotSpecificity(formation.slots[b]);
        return bScore.compareTo(aScore);
      });

    for (final slotIndex in slotIndexes) {
      final slot = formation.slots[slotIndex];

      var matches = remaining
          .where((player) => _detailedFits(player, slot))
          .toList(growable: false);

      if (matches.isEmpty) {
        matches = remaining
            .where(
              (player) =>
                  player.broadPosition.toLowerCase() ==
                  slot.fallbackBroadPosition.toLowerCase(),
            )
            .toList(growable: false);
      }

      if (matches.isEmpty) return null;

      matches = List<_PuzzlePlayerRow>.from(matches)
        ..sort((a, b) => a.selectionRank.compareTo(b.selectionRank));

      final choiceWindow = matches.take(4).toList(growable: false);
      final chosen = choiceWindow[_random.nextInt(choiceWindow.length)];
      remaining.removeWhere((player) => player.id == chosen.id);

      resultBySlot[slotIndex] = KadroKasasiSlot(
        playerId: chosen.id,
        playerName: chosen.name,
        country: chosen.country,
        broadPosition: chosen.broadPosition,
        detailedPosition: chosen.detailedPosition,
        formationSlot: slot,
      );
    }

    if (resultBySlot.length != formation.slots.length) return null;

    return <KadroKasasiSlot>[
      for (var i = 0; i < formation.slots.length; i++) resultBySlot[i]!,
    ];
  }

  bool _detailedFits(_PuzzlePlayerRow player, FormationSlot slot) {
    final detailed = player.detailedPosition.trim().toLowerCase();
    if (detailed.isEmpty) return false;

    return slot.acceptedDetailedPositions.any(
      (accepted) => accepted.toLowerCase() == detailed,
    );
  }

  int _slotSpecificity(FormationSlot slot) {
    switch (slot.code) {
      case 'GK':
        return 100;
      case 'LB':
      case 'RB':
      case 'LWB':
      case 'RWB':
        return 90;
      case 'CB':
        return 80;
      case 'LW':
      case 'RW':
      case 'LM':
      case 'RM':
        return 70;
      case 'ST':
        return 60;
      case 'CDM':
      case 'CAM':
        return 55;
      default:
        return 40;
    }
  }

  String _canonicalBroadPosition(String raw) {
    final value = raw.trim().toLowerCase();

    if (value.contains('goal') || value == 'gk') return 'Goalkeeper';
    if (value.contains('def')) return 'Defender';
    if (value.contains('mid')) return 'Midfield';
    if (value.contains('attack') ||
        value.contains('forward') ||
        value.contains('striker')) {
      return 'Attack';
    }

    return '';
  }

  String _normalizeClubName(String raw) {
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
    };

    for (final entry in replacements.entries) {
      value = value.replaceAll(entry.key, entry.value);
    }

    return value.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _stripClubTokens(String raw) {
    return raw
        .replaceAll(
          RegExp(r'\b(fc|cf|sc|ac|afc|fk|sk|cd|rc|ss)\b', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String? _optionalString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
