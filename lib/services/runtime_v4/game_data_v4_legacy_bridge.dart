import '../../models/club.dart';
import '../../models/player.dart';
import 'game_data_v4_database.dart';

class GameDataV4LegacyBridge {
  GameDataV4LegacyBridge._();

  static int? _yearFromDate(Object? value) {
    if (value == null) return null;

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    final match = RegExp(r'(\d{4})').firstMatch(text);
    if (match == null) return null;

    return int.tryParse(match.group(1)!);
  }


  static const Map<int, int> _shadowPlayerRemaps = {
    34601: 631002,
    111961: 1650,
  };

  static int _canonicalPlayerId(int id) => _shadowPlayerRemaps[id] ?? id;

  static List<int> _uniqueIds(Iterable<int> ids) {
    final seen = <int>{};
    final out = <int>[];
    for (final rawId in ids) {
      final id = _canonicalPlayerId(rawId);
      if (id > 0 && seen.add(id)) out.add(id);
    }
    return out;
  }

  static Iterable<List<int>> _chunks(List<int> ids, {int size = 800}) sync* {
    for (var start = 0; start < ids.length; start += size) {
      final end = (start + size < ids.length) ? start + size : ids.length;
      yield ids.sublist(start, end);
    }
  }

  static String _placeholders(int count) =>
      List<String>.filled(count, '?').join(',');

  /// Hydrates only the requested clubs from the canonical V4 database.
  /// This is the preferred compatibility path for V4-native screens.
  static Future<List<Club>> loadClubsByIds(Iterable<int> ids) async {
    final requested = <int>[];
    final seen = <int>{};
    for (final id in ids) {
      if (id > 0 && seen.add(id)) requested.add(id);
    }
    if (requested.isEmpty) return const <Club>[];

    final source = GameDataV4Database.instance;
    await source.initialize();

    final byId = <int, Club>{};
    for (final chunk in _chunks(requested)) {
      final marks = _placeholders(chunk.length);
      final rows = await source.database.rawQuery(
        '''
        SELECT
          id,
          name,
          country,
          competition,
          badge_key,
          color
        FROM clubs
        WHERE id IN ($marks)
        ''',
        chunk,
      );

      for (final row in rows) {
        final club = Club.fromJson({
          'id': row['id'],
          'name': row['name'],
          'league': row['competition']?.toString() ?? '',
          'country': row['country']?.toString() ?? '',
          'logo': '',
          'badgeKey': row['badge_key']?.toString() ?? '',
          'color': row['color'],
        });
        byId[club.id] = club;
      }
    }

    return [for (final id in requested) if (byId[id] != null) byId[id]!];
  }

  static Future<Club?> loadClubById(int id) async {
    final rows = await loadClubsByIds([id]);
    return rows.isEmpty ? null : rows.first;
  }

  /// Hydrates only the requested players plus the relations required by the
  /// legacy Player model. Large global Repository hydration is intentionally
  /// avoided.
  static Future<List<Player>> loadPlayersByIds(Iterable<int> ids) async {
    final requested = _uniqueIds(ids);
    if (requested.isEmpty) return const <Player>[];

    final source = GameDataV4Database.instance;
    await source.initialize();

    final scalarByPlayer = <int, Map<String, Object?>>{};
    final countriesByPlayer = <int, List<String>>{};
    final aliasesByPlayer = <int, List<String>>{};
    final clubsByPlayer = <int, List<int>>{};
    final careerByPlayer = <int, List<Map<String, dynamic>>>{};

    for (final chunk in _chunks(requested)) {
      final marks = _placeholders(chunk.length);

      final playerRows = await source.database.rawQuery(
        '''
        SELECT
          p.id,
          p.name,
          p.country,
          p.position,
          p.market_value,
          p.peak_market_value,
          p.career_goals,
          p.avatar_key,
          p.selection_rank,
          pr.detailed_position
        FROM players p
        LEFT JOIN profiles pr ON pr.player_id = p.id
        WHERE p.id IN ($marks)
        ''',
        chunk,
      );
      for (final row in playerRows) {
        scalarByPlayer[(row['id'] as num).toInt()] =
            Map<String, Object?>.from(row);
      }

      final countryRows = await source.database.rawQuery(
        '''
        SELECT player_id, country
        FROM player_countries
        WHERE player_id IN ($marks)
        ORDER BY player_id, ord
        ''',
        chunk,
      );
      for (final row in countryRows) {
        final playerId = (row['player_id'] as num).toInt();
        final country = row['country']?.toString().trim() ?? '';
        if (country.isEmpty) continue;
        countriesByPlayer
            .putIfAbsent(playerId, () => <String>[])
            .add(country);
      }

      final aliasRows = await source.database.rawQuery(
        '''
        SELECT player_id, alias
        FROM player_aliases
        WHERE player_id IN ($marks)
        ORDER BY player_id, ord
        ''',
        chunk,
      );
      for (final row in aliasRows) {
        final playerId = (row['player_id'] as num).toInt();
        final alias = row['alias']?.toString().trim() ?? '';
        if (alias.isEmpty) continue;
        aliasesByPlayer
            .putIfAbsent(playerId, () => <String>[])
            .add(alias);
      }

      final clubRows = await source.database.rawQuery(
        '''
        SELECT player_id, club_id
        FROM player_clubs
        WHERE player_id IN ($marks)
        ORDER BY player_id, club_id
        ''',
        chunk,
      );
      for (final row in clubRows) {
        final playerId = (row['player_id'] as num).toInt();
        final clubId = (row['club_id'] as num).toInt();
        clubsByPlayer
            .putIfAbsent(playerId, () => <int>[])
            .add(clubId);
      }

      final careerRows = await source.database.rawQuery(
        '''
        SELECT player_id, sequence, club_id, start_date, end_date
        FROM career_spells
        WHERE player_id IN ($marks)
        ORDER BY player_id, sequence
        ''',
        chunk,
      );
      for (final row in careerRows) {
        final playerId = (row['player_id'] as num).toInt();
        final startYear = _yearFromDate(row['start_date']);
        if (startYear == null) continue;
        careerByPlayer
            .putIfAbsent(playerId, () => <Map<String, dynamic>>[])
            .add({
              'clubId': (row['club_id'] as num).toInt(),
              'startYear': startYear,
              'endYear': _yearFromDate(row['end_date']),
            });
      }
    }

    final byId = <int, Player>{};
    for (final id in requested) {
      final row = scalarByPlayer[id];
      if (row == null) continue;

      final primaryCountry = row['country']?.toString().trim() ?? '';
      final countries = List<String>.from(
        countriesByPlayer[id] ?? const <String>[],
      );
      if (countries.isEmpty && primaryCountry.isNotEmpty) {
        countries.add(primaryCountry);
      }

      final position = row['position']?.toString().trim() ?? '';
      final detailedPosition =
          row['detailed_position']?.toString().trim() ?? '';

      byId[id] = Player.fromJson({
        'id': id,
        'name': row['name']?.toString() ?? '',
        'countries': countries,
        'position': position,
        'detailedPosition':
            detailedPosition.isNotEmpty ? detailedPosition : position,
        'clubIds': clubsByPlayer[id] ?? const <int>[],
        'nationalTeams': const <int>[],
        'primaryNationalTeamId': null,
        'aliases': aliasesByPlayer[id] ?? const <String>[],
        'marketValue': (row['market_value'] as num?)?.toDouble() ?? 0,
        'peakMarketValue':
            (row['peak_market_value'] as num?)?.toDouble() ?? 0,
        'careerGoals': (row['career_goals'] as num?)?.toInt() ?? 0,
        'careerTimeline':
            careerByPlayer[id] ?? const <Map<String, dynamic>>[],
        'avatarKey': row['avatar_key']?.toString() ?? '',
      });
    }

    return [for (final id in requested) if (byId[id] != null) byId[id]!];
  }

  static Future<Player?> loadPlayerById(int id) async {
    final canonicalId = _canonicalPlayerId(id);
    final rows = await loadPlayersByIds([canonicalId]);
    return rows.isEmpty ? null : rows.first;
  }

  static Future<List<Club>> loadClubs() async {
    final watch = Stopwatch()..start();

    final source = GameDataV4Database.instance;
    await source.initialize();

    final rows = await source.database.rawQuery('''
      SELECT
        id,
        name,
        country,
        competition,
        badge_key,
        color
      FROM clubs
      ORDER BY
        popularity_seed DESC,
        name,
        id
    ''');

    final clubs = <Club>[];

    for (final row in rows) {
      clubs.add(
        Club.fromJson({
          'id': row['id'],
          'name': row['name'],
          'league': row['competition']?.toString() ?? '',
          'country': row['country']?.toString() ?? '',
          'logo': '',
          'badgeKey': row['badge_key']?.toString() ?? '',
          'color': row['color'],
        }),
      );
    }

    watch.stop();

    print(
      '[V4Compat] clubs hydrate '
      '${watch.elapsedMilliseconds}ms '
      'count=${clubs.length}',
    );

    return clubs;
  }

  static Future<List<Player>> loadPlayers() async {
    final totalWatch = Stopwatch()..start();

    final source = GameDataV4Database.instance;
    await source.initialize();

    // -------------------------------------------------------
    // Scalar player rows
    // -------------------------------------------------------

    final scalarWatch = Stopwatch()..start();

    final playerRows = await source.database.rawQuery('''
      SELECT
        p.id,
        p.name,
        p.country,
        p.position,
        p.market_value,
        p.peak_market_value,
        p.career_goals,
        p.avatar_key,
        p.selection_rank,
        pr.detailed_position
      FROM players p
      LEFT JOIN profiles pr
        ON pr.player_id = p.id
      ORDER BY
        p.selection_rank IS NULL,
        p.selection_rank,
        p.id
    ''');

    scalarWatch.stop();

    // -------------------------------------------------------
    // Countries
    // -------------------------------------------------------

    final relationWatch = Stopwatch()..start();

    final countriesByPlayer = <int, List<String>>{};

    final countryRows = await source.database.rawQuery('''
      SELECT
        player_id,
        country
      FROM player_countries
      ORDER BY player_id, ord
    ''');

    for (final row in countryRows) {
      final playerId = (row['player_id'] as num).toInt();
      final country = row['country']?.toString().trim() ?? '';

      if (country.isEmpty) continue;

      countriesByPlayer
          .putIfAbsent(playerId, () => <String>[])
          .add(country);
    }

    // -------------------------------------------------------
    // Aliases
    // -------------------------------------------------------

    final aliasesByPlayer = <int, List<String>>{};

    final aliasRows = await source.database.rawQuery('''
      SELECT
        player_id,
        alias
      FROM player_aliases
      ORDER BY player_id, ord
    ''');

    for (final row in aliasRows) {
      final playerId = (row['player_id'] as num).toInt();
      final alias = row['alias']?.toString().trim() ?? '';

      if (alias.isEmpty) continue;

      aliasesByPlayer
          .putIfAbsent(playerId, () => <String>[])
          .add(alias);
    }

    // -------------------------------------------------------
    // Canonical club relations
    // -------------------------------------------------------

    final clubsByPlayer = <int, List<int>>{};

    final clubRows = await source.database.rawQuery('''
      SELECT
        player_id,
        club_id
      FROM player_clubs
      ORDER BY player_id, club_id
    ''');

    for (final row in clubRows) {
      final playerId = (row['player_id'] as num).toInt();
      final clubId = (row['club_id'] as num).toInt();

      clubsByPlayer
          .putIfAbsent(playerId, () => <int>[])
          .add(clubId);
    }

    // -------------------------------------------------------
    // Normalized career timeline
    // -------------------------------------------------------

    final careerByPlayer =
        <int, List<Map<String, dynamic>>>{};

    final careerRows = await source.database.rawQuery('''
      SELECT
        player_id,
        sequence,
        club_id,
        start_date,
        end_date
      FROM career_spells
      ORDER BY player_id, sequence
    ''');

    for (final row in careerRows) {
      final playerId = (row['player_id'] as num).toInt();
      final clubId = (row['club_id'] as num).toInt();

      final startYear = _yearFromDate(row['start_date']);
      final endYear = _yearFromDate(row['end_date']);

      // Legacy CareerStop requires a start year.
      if (startYear == null) continue;

      careerByPlayer
          .putIfAbsent(
            playerId,
            () => <Map<String, dynamic>>[],
          )
          .add({
            'clubId': clubId,
            'startYear': startYear,
            'endYear': endYear,
          });
    }

    relationWatch.stop();

    // -------------------------------------------------------
    // Hydrate old Player contract
    // -------------------------------------------------------

    final hydrateWatch = Stopwatch()..start();

    final players = <Player>[];

    for (final row in playerRows) {
      final id = (row['id'] as num).toInt();

      final primaryCountry =
          row['country']?.toString().trim() ?? '';

      final countries = List<String>.from(
        countriesByPlayer[id] ?? const <String>[],
      );

      if (countries.isEmpty && primaryCountry.isNotEmpty) {
        countries.add(primaryCountry);
      }

      final position =
          row['position']?.toString().trim() ?? '';

      final detailedPosition =
          row['detailed_position']?.toString().trim() ?? '';

      players.add(
        Player.fromJson({
          'id': id,
          'name': row['name']?.toString() ?? '',
          'countries': countries,
          'position': position,
          'detailedPosition':
              detailedPosition.isNotEmpty
                  ? detailedPosition
                  : position,
          'clubIds':
              clubsByPlayer[id] ?? const <int>[],
          'nationalTeams': const <int>[],
          'primaryNationalTeamId': null,
          'aliases':
              aliasesByPlayer[id] ?? const <String>[],
          'marketValue':
              (row['market_value'] as num?)?.toDouble() ?? 0,
          'peakMarketValue':
              (row['peak_market_value'] as num?)?.toDouble() ?? 0,
          'careerGoals':
              (row['career_goals'] as num?)?.toInt() ?? 0,
          'careerTimeline':
              careerByPlayer[id] ??
              const <Map<String, dynamic>>[],
          'avatarKey':
              row['avatar_key']?.toString() ?? '',
        }),
      );
    }

    hydrateWatch.stop();
    totalWatch.stop();

    print(
      '[V4Compat] players scalar '
      '${scalarWatch.elapsedMilliseconds}ms',
    );

    print(
      '[V4Compat] player relations '
      '${relationWatch.elapsedMilliseconds}ms',
    );

    print(
      '[V4Compat] Player objects '
      '${hydrateWatch.elapsedMilliseconds}ms',
    );

    print(
      '[V4Compat] players TOTAL '
      '${totalWatch.elapsedMilliseconds}ms '
      'count=${players.length}',
    );

    return players;
  }
}