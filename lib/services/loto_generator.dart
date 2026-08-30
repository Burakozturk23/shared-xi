import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/loto_models.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import 'runtime_v3/hybrid_gameplay_data_service.dart';

class LotoLeagues {
  LotoLeagues._();

  static const display = <_LeagueOpt>[
    _LeagueOpt('İngiltere Ligi', ['Premier League', 'England', 'EPL', 'Championship', 'İngiltere']),
    _LeagueOpt('İspanya Ligi', ['La Liga', 'LaLiga', 'Spain', 'Primera División', 'İspanya']),
    _LeagueOpt('Almanya Ligi', ['Bundesliga', 'Germany', '2. Bundesliga', 'Almanya']),
    _LeagueOpt('Fransa Ligi', ['Ligue 1', 'France', 'Ligue 2', 'Fransa']),
    _LeagueOpt('İtalya Ligi', ['Serie A', 'Italy', 'Serie B', 'İtalya']),
    _LeagueOpt('Türkiye Ligi', ['Süper Lig', 'Super Lig', 'Turkey', 'TFF 1. Lig', 'Türkiye']),
    _LeagueOpt('Hollanda Ligi', ['Eredivisie', 'Netherlands', 'Holland', 'Hollanda']),
    _LeagueOpt('Portekiz Ligi', ['Primeira Liga', 'Portugal', 'Liga Portugal', 'Portekiz']),
    _LeagueOpt('Yunanistan Ligi', ['Super League Greece', 'Greece', 'Yunanistan']),
    _LeagueOpt('Polonya Ligi', ['Ekstraklasa', 'Poland', 'Polonya']),
    _LeagueOpt('Norveç Ligi', ['Eliteserien', 'Norway', 'Norveç']),
    _LeagueOpt('İskoçya Ligi', ['Scottish Premiership', 'Scotland', 'İskoçya']),
    _LeagueOpt('Belçika Ligi', ['Belgian Pro League', 'Belgium', 'Jupiler', 'Belçika']),
    _LeagueOpt('Super Liga Srbije', ['SuperLiga', 'Serbia SuperLiga', 'Serbia', 'Sırbistan']),
    _LeagueOpt('Rusya Ligi', ['Russian Premier League', 'Russia', 'Rusya', 'Premier Liga']),
    _LeagueOpt('İsviçre Ligi', ['Swiss Super League', 'Switzerland', 'İsviçre']),
    _LeagueOpt('Çekya Ligi', ['Czech First League', 'Czech', 'Czechia', 'Çekya']),
    _LeagueOpt('Sırbistan Ligi', ['Serbian SuperLiga', 'Serbia', 'Sırbistan']),
  ];

  static bool clubMatches(_LeagueOpt opt, String league) {
    final L = league.toLowerCase().trim();
    if (L.isEmpty) return false;
    for (final k in opt.keys) {
      final kk = k.toLowerCase();
      if (L.contains(kk) || kk.contains(L)) return true;
    }
    return false;
  }
}

class _LeagueOpt {
  final String label;
  final List<String> keys;
  const _LeagueOpt(this.label, this.keys);
}

class LotoGenerator {
  LotoGenerator._();
  static final _rng = Random();

  static List<String> availableLeagues() =>
      LotoLeagues.display.map((e) => e.label).toList();

  static _LeagueOpt? _optByLabel(String? label) {
    if (label == null || label.isEmpty) return null;
    for (final o in LotoLeagues.display) {
      if (o.label == label) return o;
    }
    return null;
  }

  static String _posGroup(Player p) {
    final raw = '${p.position} ${p.detailedPosition}'.toLowerCase();
    if (raw.contains('goal') || raw.contains('keeper') || raw.contains('gk')) {
      return 'GK';
    }
    if (raw.contains('defen') ||
        raw.contains('back') ||
        raw.contains('stoper') ||
        raw.contains('bek')) {
      return 'DEF';
    }
    if (raw.contains('mid') || raw.contains('orta')) return 'MID';
    if (raw.contains('forw') ||
        raw.contains('attack') ||
        raw.contains('strik') ||
        raw.contains('wing') ||
        raw.contains('forvet')) {
      return 'FWD';
    }
    final x = p.position.trim().toUpperCase();
    if (x == 'G' || x == 'GK') return 'GK';
    if (x == 'D' || x == 'DF') return 'DEF';
    if (x == 'M' || x == 'MF') return 'MID';
    if (x == 'F' || x == 'FW' || x == 'A') return 'FWD';
    return 'MID';
  }

  static String _posLabel(String g) {
    switch (g) {
      case 'GK':
        return 'Kaleci';
      case 'DEF':
        return 'Defans';
      case 'MID':
        return 'Orta saha';
      case 'FWD':
        return 'Forvet';
      default:
        return g;
    }
  }

  static bool matches(Player player, LotoCriterion c) {
    final repo = Repository.instance;
    switch (c.type) {
      case LotoCriterionType.club:
        final id = int.tryParse(c.key);
        return id != null && player.clubs.contains(id);
      case LotoCriterionType.country:
        return player.countries
            .any((x) => x.toLowerCase() == c.key.toLowerCase());
      case LotoCriterionType.league:
        for (final cid in player.clubs) {
          final club = repo.clubById(cid);
          if (club == null) continue;
          final opt = _optByLabel(c.key);
          if (opt != null) {
            if (LotoLeagues.clubMatches(opt, club.league)) return true;
          } else if (club.league.toLowerCase() == c.key.toLowerCase()) {
            return true;
          }
        }
        return false;
      case LotoCriterionType.position:
        return _posGroup(player) == c.key;
      case LotoCriterionType.decade:
        for (final stop in player.careerTimeline) {
          if ('${(stop.startYear ~/ 10) * 10}s' == c.key) return true;
          if (stop.endYear != null &&
              '${(stop.endYear! ~/ 10) * 10}s' == c.key) {
            return true;
          }
        }
        return false;
    }
  }

  static List<Player> _poolForLeague(_LeagueOpt? opt) {
    final repo = Repository.instance;
    if (opt == null) return List<Player>.from(repo.players);
    final clubIds = repo.clubs
        .where((c) => LotoLeagues.clubMatches(opt, c.league))
        .map((c) => c.id)
        .toSet();
    if (clubIds.isEmpty) return List<Player>.from(repo.players);
    final pool = repo.players
        .where((p) => p.clubs.any((id) => clubIds.contains(id)))
        .toList();
    return pool.length >= 16 ? pool : List<Player>.from(repo.players);
  }

  /// 16 hücre + 16 oyuncu birebir: her oyuncu kendi hücresine uyar.
  static LotoBoard generate({
    String? leagueFilter,
    LotoDifficulty difficulty = LotoDifficulty.medium,
  }) {
    final repo = Repository.instance;
    final opt = _optByLabel(leagueFilter);
    var pool = _poolForLeague(opt);

    pool = List<Player>.from(pool);
    pool.sort((a, b) => b.peakMarketValue.compareTo(a.peakMarketValue));
    if (difficulty == LotoDifficulty.easy) {
      pool = pool.take(min(150, pool.length)).toList();
    } else if (difficulty == LotoDifficulty.medium) {
      final skip = min(pool.length ~/ 5, max(0, pool.length - 80));
      pool = pool.skip(skip).take(min(160, pool.length - skip)).toList();
      if (pool.length < 20) pool = _poolForLeague(opt);
    } else {
      final skip = pool.length ~/ 3;
      pool = pool.skip(skip).toList();
      if (pool.length < 20) pool = _poolForLeague(opt);
    }
    pool.shuffle(_rng);

    final leagueClubIds = opt == null
        ? repo.clubs.map((c) => c.id).toSet()
        : repo.clubs
            .where((c) => LotoLeagues.clubMatches(opt, c.league))
            .map((c) => c.id)
            .toSet();

    // --- Aday kriterler (oyuncu garantili) ---
    // Kulüp: ligdeki kulüplerden, en az 1 oyuncu
    final clubCandidates = <({int id, String name, List<Player> players})>[];
    final byClub = <int, List<Player>>{};
    for (final p in pool) {
      for (final cid in p.clubs) {
        if (!leagueClubIds.contains(cid)) continue;
        (byClub[cid] ??= []).add(p);
      }
    }
    for (final e in byClub.entries) {
      if (e.value.isEmpty) continue;
      final club = repo.clubById(e.key);
      if (club == null || club.name.isEmpty) continue;
      clubCandidates.add((id: e.key, name: club.name, players: e.value));
    }
    clubCandidates.shuffle(_rng);

    final byCountry = <String, List<Player>>{};
    for (final p in pool) {
      for (final co in p.countries) {
        (byCountry[co] ??= []).add(p);
      }
    }
    final countryCandidates = byCountry.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => (key: e.key, players: e.value))
        .toList()
      ..shuffle(_rng);

    final byPos = <String, List<Player>>{};
    for (final p in pool) {
      final g = _posGroup(p);
      (byPos[g] ??= []).add(p);
    }

    final byDecade = <String, List<Player>>{};
    for (final p in pool) {
      for (final stop in p.careerTimeline) {
        final d = '${(stop.startYear ~/ 10) * 10}s';
        (byDecade[d] ??= []).add(p);
      }
    }

    // Lig kriteri: seçili lig etiketi
    final leaguePlayers = pool; // zaten filtrelenmiş

    // Tip planı
    final types = <LotoCriterionType>[];
    switch (difficulty) {
      case LotoDifficulty.easy:
        types.addAll([
          ...List.filled(7, LotoCriterionType.club),
          ...List.filled(4, LotoCriterionType.country),
          ...List.filled(2, LotoCriterionType.league),
          ...List.filled(2, LotoCriterionType.decade),
          ...List.filled(1, LotoCriterionType.position),
        ]);
        break;
      case LotoDifficulty.medium:
        types.addAll([
          ...List.filled(5, LotoCriterionType.club),
          ...List.filled(4, LotoCriterionType.country),
          ...List.filled(2, LotoCriterionType.league),
          ...List.filled(3, LotoCriterionType.position),
          ...List.filled(2, LotoCriterionType.decade),
        ]);
        break;
      case LotoDifficulty.hard:
        types.addAll([
          ...List.filled(5, LotoCriterionType.club),
          ...List.filled(4, LotoCriterionType.country),
          ...List.filled(1, LotoCriterionType.league),
          ...List.filled(3, LotoCriterionType.position),
          ...List.filled(3, LotoCriterionType.decade),
        ]);
        break;
    }
    types.shuffle(_rng);

    final cells = <LotoCriterion>[];
    final ownerPlayerIds = <int>[]; // cells[i] ↔ ownerPlayerIds[i]
    final usedPlayers = <int>{};
    var clubIdx = 0;
    var countryIdx = 0;
    final usedClubKeys = <String>{};
    final usedCountryKeys = <String>{};
    final usedPos = <String>{};
    final usedDecade = <String>{};
    var usedLeague = false;

    Player? takePlayer(List<Player> candidates) {
      final free = candidates.where((p) => !usedPlayers.contains(p.id)).toList()
        ..shuffle(_rng);
      if (free.isEmpty) return null;
      // bilinirlik: easy önde
      free.sort((a, b) {
        final cmp = b.peakMarketValue.compareTo(a.peakMarketValue);
        if (difficulty == LotoDifficulty.hard) return -cmp;
        return cmp;
      });
      final pick = free.first;
      usedPlayers.add(pick.id);
      return pick;
    }

    for (final type in types) {
      if (cells.length >= 16) break;

      if (type == LotoCriterionType.club) {
        while (clubIdx < clubCandidates.length) {
          final c = clubCandidates[clubIdx++];
          final key = '${c.id}';
          if (usedClubKeys.contains(key)) continue;
          final p = takePlayer(c.players);
          if (p == null) continue;
          usedClubKeys.add(key);
          cells.add(LotoCriterion(
            cellIndex: cells.length,
            type: LotoCriterionType.club,
            label: c.name,
            subtitle: 'Kulüp',
            key: key,
          ));
          ownerPlayerIds.add(p.id);
          break;
        }
      } else if (type == LotoCriterionType.country) {
        while (countryIdx < countryCandidates.length) {
          final c = countryCandidates[countryIdx++];
          if (usedCountryKeys.contains(c.key.toLowerCase())) continue;
          final p = takePlayer(c.players);
          if (p == null) continue;
          usedCountryKeys.add(c.key.toLowerCase());
          cells.add(LotoCriterion(
            cellIndex: cells.length,
            type: LotoCriterionType.country,
            label: c.key,
            subtitle: 'Milliyet',
            key: c.key,
          ));
          ownerPlayerIds.add(p.id);
          break;
        }
      } else if (type == LotoCriterionType.league && !usedLeague && opt != null) {
        final p = takePlayer(leaguePlayers);
        if (p != null) {
          usedLeague = true;
          cells.add(LotoCriterion(
            cellIndex: cells.length,
            type: LotoCriterionType.league,
            label: opt.label,
            subtitle: 'Lig',
            key: opt.label,
          ));
          ownerPlayerIds.add(p.id);
        }
      } else if (type == LotoCriterionType.position) {
        final order = ['GK', 'DEF', 'MID', 'FWD']..shuffle(_rng);
        for (final g in order) {
          if (usedPos.contains(g)) continue;
          final list = byPos[g] ?? [];
          final p = takePlayer(list);
          if (p == null) continue;
          usedPos.add(g);
          cells.add(LotoCriterion(
            cellIndex: cells.length,
            type: LotoCriterionType.position,
            label: _posLabel(g),
            subtitle: 'Mevki',
            key: g,
          ));
          ownerPlayerIds.add(p.id);
          break;
        }
      } else if (type == LotoCriterionType.decade) {
        final keys = byDecade.keys.toList()..shuffle(_rng);
        for (final d in keys) {
          if (usedDecade.contains(d)) continue;
          final p = takePlayer(byDecade[d] ?? []);
          if (p == null) continue;
          usedDecade.add(d);
          final year = int.tryParse(d.replaceAll('s', '')) ?? 0;
          final label = year >= 2000 ? '${year}\'ler' : '${year % 100}\'ler';
          cells.add(LotoCriterion(
            cellIndex: cells.length,
            type: LotoCriterionType.decade,
            label: label,
            subtitle: 'Dönem',
            key: d,
          ));
          ownerPlayerIds.add(p.id);
          break;
        }
      }
    }

    // Eksik hücreleri kulüp ile doldur
    while (cells.length < 16 && clubIdx < clubCandidates.length) {
      final c = clubCandidates[clubIdx++];
      final key = '${c.id}';
      if (usedClubKeys.contains(key)) continue;
      final p = takePlayer(c.players);
      if (p == null) continue;
      usedClubKeys.add(key);
      cells.add(LotoCriterion(
        cellIndex: cells.length,
        type: LotoCriterionType.club,
        label: c.name,
        subtitle: 'Kulüp',
        key: key,
      ));
      ownerPlayerIds.add(p.id);
    }

    // Hâlâ eksikse country
    while (cells.length < 16 && countryIdx < countryCandidates.length) {
      final c = countryCandidates[countryIdx++];
      if (usedCountryKeys.contains(c.key.toLowerCase())) continue;
      final p = takePlayer(c.players);
      if (p == null) continue;
      usedCountryKeys.add(c.key.toLowerCase());
      cells.add(LotoCriterion(
        cellIndex: cells.length,
        type: LotoCriterionType.country,
        label: c.key,
        subtitle: 'Milliyet',
        key: c.key,
      ));
      ownerPlayerIds.add(p.id);
    }

    // Son çare: rastgele oyuncu + kulübü
    while (cells.length < 16) {
      final free = pool.where((p) => !usedPlayers.contains(p.id)).toList();
      if (free.isEmpty) break;
      free.shuffle(_rng);
      final p = free.first;
      usedPlayers.add(p.id);
      String label = p.name;
      String key = 'p_${p.id}';
      LotoCriterionType type = LotoCriterionType.country;
      if (p.clubs.isNotEmpty) {
        final cid = p.clubs.first;
        final club = repo.clubById(cid);
        if (club != null) {
          type = LotoCriterionType.club;
          label = club.name;
          key = '$cid';
        }
      } else if (p.countries.isNotEmpty) {
        label = p.countries.first;
        key = label;
      }
      cells.add(LotoCriterion(
        cellIndex: cells.length,
        type: type,
        label: label,
        subtitle: type == LotoCriterionType.club ? 'Kulüp' : 'Milliyet',
        key: key,
      ));
      ownerPlayerIds.add(p.id);
    }

    // index düzelt
    final fixed = <LotoCriterion>[];
    for (var i = 0; i < cells.length && i < 16; i++) {
      final c = cells[i];
      fixed.add(LotoCriterion(
        cellIndex: i,
        type: c.type,
        label: c.label,
        subtitle: c.subtitle,
        key: c.key,
      ));
    }

    // Tam 16 çift
    final n = min(16, min(fixed.length, ownerPlayerIds.length));
    final cells16 = fixed.sublist(0, n);
    final owners16 = ownerPlayerIds.sublist(0, n);

    // Kuyruk = sahipler karışık (birebir)
    final queue = List<int>.from(owners16)..shuffle(_rng);

    // Her oyuncu için geçerli hücreler: en az home + diğer uyanlar
    final validMap = <int, Set<int>>{};
    for (var i = 0; i < n; i++) {
      final home = i;
      final pid = owners16[i];
      final p = repo.playerById(pid);
      final set = <int>{home};
      if (p != null) {
        for (final cell in cells16) {
          if (matches(p, cell)) set.add(cell.cellIndex);
        }
      }
      validMap[pid] = set;
    }

    // Eğer n < 16 nadiren olursa pad (olmamalı)
    while (cells16.length < 16) {
      cells16.add(LotoCriterion(
        cellIndex: cells16.length,
        type: LotoCriterionType.position,
        label: 'Orta saha',
        subtitle: 'Mevki',
        key: 'MID',
      ));
    }

    return LotoBoard(
      leagueFilter: opt?.label,
      difficulty: difficulty,
      cells: cells16.length > 16 ? cells16.sublist(0, 16) : cells16,
      playerQueue: queue.length > 16 ? queue.sublist(0, 16) : queue,
      validCellsForPlayer: validMap,
    );
  }

  static String _runtimePosGroup(
    Player player,
    Map<int, Map<String, Object?>> factsByPlayer,
  ) {
    final row = factsByPlayer[player.id];
    final raw =
        row?['position_group']?.toString().trim().toUpperCase() ?? '';

    if (raw == 'GOALKEEPER' || raw == 'GK') return 'GK';
    if (raw == 'DEFENDER' || raw == 'DEF') return 'DEF';

    if (raw == 'MIDFIELD' ||
        raw == 'MIDFIELDER' ||
        raw == 'MID') {
      return 'MID';
    }

    if (raw == 'ATTACK' ||
        raw == 'ATTACKER' ||
        raw == 'FORWARD' ||
        raw == 'FWD') {
      return 'FWD';
    }

    return _posGroup(player);
  }

  static List<int> _runtimeClubIds(
    Player player,
    Map<int, List<int>> clubIdsByPlayer,
  ) {
    return clubIdsByPlayer[player.id] ?? const <int>[];
  }

  static bool _runtimeCriterionMatches(
    Player player,
    LotoCriterion criterion, {
    required Map<int, List<int>> clubIdsByPlayer,
    required Map<int, Map<String, Object?>> factsByPlayer,
    required Map<int, String> leagueMetaByClubId,
  }) {
    switch (criterion.type) {
      case LotoCriterionType.club:
        final id = int.tryParse(criterion.key);
        return id != null &&
            _runtimeClubIds(player, clubIdsByPlayer).contains(id);

      case LotoCriterionType.country:
        return player.countries.any(
          (x) => x.toLowerCase() == criterion.key.toLowerCase(),
        );

      case LotoCriterionType.league:
        final opt = _optByLabel(criterion.key);
        for (final clubId in _runtimeClubIds(player, clubIdsByPlayer)) {
          final meta = leagueMetaByClubId[clubId] ?? '';
          if (meta.isEmpty) continue;

          if (opt != null) {
            if (LotoLeagues.clubMatches(opt, meta)) return true;
          } else if (meta.toLowerCase() ==
              criterion.key.toLowerCase()) {
            return true;
          }
        }
        return false;

      case LotoCriterionType.position:
        return _runtimePosGroup(player, factsByPlayer) == criterion.key;

      case LotoCriterionType.decade:
        final row = factsByPlayer[player.id];
        if (row == null) return false;

        final first =
            (row['coverage_first_year'] as num?)?.toInt() ?? 0;
        final last =
            (row['coverage_last_year'] as num?)?.toInt() ?? first;

        if (first <= 0 || last <= 0) return false;

        final decade =
            int.tryParse(criterion.key.replaceAll('s', '')) ?? 0;
        if (decade <= 0) return false;

        final decadeEnd = decade + 9;
        return first <= decadeEnd && last >= decade;
    }
  }

  static Future<LotoBoard?> generateRuntime({
    String? leagueFilter,
    LotoDifficulty difficulty = LotoDifficulty.medium,
  }) async {
    final hybrid = HybridGameplayDataService.instance;
    if (!hybrid.isGameplayEnabled) return null;

    try {
      final orderedPlayers =
          await hybrid.playersInPool('build_xi_preview');
      final clubIdsByPlayer =
          await hybrid.playerClubIdsForPool('build_xi_preview');
      final factsByPlayer =
          await hybrid.playerFactsForPool('build_xi_preview');
      final clubRows = await hybrid.existingGameplayClubMetadata();

      if (orderedPlayers.length < 5000 ||
          clubIdsByPlayer.length < 5000 ||
          factsByPlayer.length < 5000 ||
          clubRows.length < 100) {
        debugPrint(
          '[HybridV3] Loto SQLite source too small; legacy fallback.',
        );
        return null;
      }

      final clubNameById = <int, String>{};
      final leagueMetaByClubId = <int, String>{};
      final clubRank = <int, int>{};

      for (var i = 0; i < clubRows.length; i++) {
        final row = clubRows[i];
        final rawId = row['exposed_club_id'] as num?;
        if (rawId == null) continue;

        final clubId = rawId.toInt();
        final name = row['name']?.toString().trim() ?? '';
        final competition =
            row['competition']?.toString().trim() ?? '';
        final country = row['country']?.toString().trim() ?? '';

        if (name.isNotEmpty) clubNameById[clubId] = name;
        leagueMetaByClubId[clubId] =
            '$competition $country'.trim();
        clubRank[clubId] = i;
      }

      final opt = _optByLabel(leagueFilter);

      final leagueClubIds = opt == null
          ? clubNameById.keys.toSet()
          : leagueMetaByClubId.entries
              .where(
                (e) => LotoLeagues.clubMatches(opt, e.value),
              )
              .map((e) => e.key)
              .toSet();

      if (opt != null && leagueClubIds.length < 2) {
        debugPrint(
          '[HybridV3] Loto SQLite league mapping too small '
          'league=$leagueFilter; legacy fallback.',
        );
        return null;
      }

      final filtered = opt == null
          ? List<Player>.from(orderedPlayers)
          : orderedPlayers.where((player) {
              return _runtimeClubIds(player, clubIdsByPlayer)
                  .any(leagueClubIds.contains);
            }).toList();

      if (filtered.length < 40) {
        debugPrint(
          '[HybridV3] Loto SQLite filtered player pool too small '
          'league=$leagueFilter players=${filtered.length}; '
          'legacy fallback.',
        );
        return null;
      }

      var pool = <Player>[];

      switch (difficulty) {
        case LotoDifficulty.easy:
          pool = filtered.take(min(900, filtered.length)).toList();
          break;

        case LotoDifficulty.medium:
          final skip = min(
            filtered.length ~/ 8,
            max(0, filtered.length - 120),
          );
          pool = filtered
              .skip(skip)
              .take(min(2400, filtered.length - skip))
              .toList();
          break;

        case LotoDifficulty.hard:
          final skip = filtered.length ~/ 3;
          pool = filtered
              .skip(skip)
              .take(min(5000, filtered.length - skip))
              .toList();
          break;
      }

      if (pool.length < 40) {
        pool = List<Player>.from(filtered);
      }

      final rankByPlayerId = <int, int>{
        for (var i = 0; i < orderedPlayers.length; i++)
          orderedPlayers[i].id: i,
      };

      final byClub = <int, List<Player>>{};
      for (final player in pool) {
        for (final clubId in _runtimeClubIds(
          player,
          clubIdsByPlayer,
        )) {
          if (!leagueClubIds.contains(clubId)) continue;
          if (!clubNameById.containsKey(clubId)) continue;
          byClub.putIfAbsent(clubId, () => <Player>[]).add(player);
        }
      }

      final clubCandidates = byClub.entries
          .where((e) => e.value.isNotEmpty)
          .map(
            (e) => (
              id: e.key,
              name: clubNameById[e.key] ?? 'Club ${e.key}',
              players: e.value,
            ),
          )
          .toList()
        ..sort(
          (a, b) => (clubRank[a.id] ?? 999999)
              .compareTo(clubRank[b.id] ?? 999999),
        );

      final clubHead =
          clubCandidates.take(min(80, clubCandidates.length)).toList()
            ..shuffle(_rng);
      final clubTail =
          clubCandidates.skip(min(80, clubCandidates.length)).toList()
            ..shuffle(_rng);
      final orderedClubCandidates = [...clubHead, ...clubTail];

      final byCountry = <String, List<Player>>{};
      final byPos = <String, List<Player>>{};
      final byDecade = <String, List<Player>>{};

      for (final player in pool) {
        for (final country in player.countries) {
          if (country.trim().isEmpty) continue;
          byCountry
              .putIfAbsent(country, () => <Player>[])
              .add(player);
        }

        final group = _runtimePosGroup(player, factsByPlayer);
        byPos.putIfAbsent(group, () => <Player>[]).add(player);

        final row = factsByPlayer[player.id];
        final first =
            (row?['coverage_first_year'] as num?)?.toInt() ?? 0;
        final last =
            (row?['coverage_last_year'] as num?)?.toInt() ?? first;

        if (first > 0 && last > 0) {
          var decade = (first ~/ 10) * 10;
          final lastDecade = (last ~/ 10) * 10;

          while (decade <= lastDecade) {
            final key = '${decade}s';
            byDecade
                .putIfAbsent(key, () => <Player>[])
                .add(player);
            decade += 10;
          }
        }
      }

      final countryCandidates = byCountry.entries
          .where((e) => e.value.isNotEmpty)
          .map((e) => (key: e.key, players: e.value))
          .toList()
        ..shuffle(_rng);

      final types = <LotoCriterionType>[];

      switch (difficulty) {
        case LotoDifficulty.easy:
          types.addAll([
            ...List.filled(7, LotoCriterionType.club),
            ...List.filled(4, LotoCriterionType.country),
            ...List.filled(2, LotoCriterionType.league),
            ...List.filled(2, LotoCriterionType.decade),
            ...List.filled(1, LotoCriterionType.position),
          ]);
          break;

        case LotoDifficulty.medium:
          types.addAll([
            ...List.filled(5, LotoCriterionType.club),
            ...List.filled(4, LotoCriterionType.country),
            ...List.filled(2, LotoCriterionType.league),
            ...List.filled(3, LotoCriterionType.position),
            ...List.filled(2, LotoCriterionType.decade),
          ]);
          break;

        case LotoDifficulty.hard:
          types.addAll([
            ...List.filled(5, LotoCriterionType.club),
            ...List.filled(4, LotoCriterionType.country),
            ...List.filled(1, LotoCriterionType.league),
            ...List.filled(3, LotoCriterionType.position),
            ...List.filled(3, LotoCriterionType.decade),
          ]);
          break;
      }

      types.shuffle(_rng);

      final cells = <LotoCriterion>[];
      final ownerPlayerIds = <int>[];
      final usedPlayers = <int>{};

      final usedClubKeys = <String>{};
      final usedCountryKeys = <String>{};
      final usedPos = <String>{};
      final usedDecade = <String>{};

      var usedLeague = false;
      var clubIndex = 0;
      var countryIndex = 0;

      Player? takePlayer(List<Player> candidates) {
        final free = candidates
            .where((p) => !usedPlayers.contains(p.id))
            .toList();

        if (free.isEmpty) return null;

        free.sort(
          (a, b) => (rankByPlayerId[a.id] ?? 999999)
              .compareTo(rankByPlayerId[b.id] ?? 999999),
        );

        final int cap;
        switch (difficulty) {
          case LotoDifficulty.easy:
            cap = min(8, free.length);
            break;
          case LotoDifficulty.medium:
            cap = min(20, free.length);
            break;
          case LotoDifficulty.hard:
            cap = free.length;
            break;
        }

        final pick = free[_rng.nextInt(cap)];
        usedPlayers.add(pick.id);
        return pick;
      }

      void addClubCell() {
        while (clubIndex < orderedClubCandidates.length) {
          final candidate = orderedClubCandidates[clubIndex++];
          final key = '${candidate.id}';

          if (!usedClubKeys.add(key)) continue;

          final player = takePlayer(candidate.players);
          if (player == null) continue;

          cells.add(
            LotoCriterion(
              cellIndex: cells.length,
              type: LotoCriterionType.club,
              label: candidate.name,
              subtitle: 'Kulüp',
              key: key,
            ),
          );
          ownerPlayerIds.add(player.id);
          return;
        }
      }

      void addCountryCell() {
        while (countryIndex < countryCandidates.length) {
          final candidate = countryCandidates[countryIndex++];
          final normalized = candidate.key.toLowerCase();

          if (!usedCountryKeys.add(normalized)) continue;

          final player = takePlayer(candidate.players);
          if (player == null) continue;

          cells.add(
            LotoCriterion(
              cellIndex: cells.length,
              type: LotoCriterionType.country,
              label: candidate.key,
              subtitle: 'Milliyet',
              key: candidate.key,
            ),
          );
          ownerPlayerIds.add(player.id);
          return;
        }
      }

      void addPositionCell() {
        final order = ['GK', 'DEF', 'MID', 'FWD']..shuffle(_rng);

        for (final group in order) {
          if (!usedPos.add(group)) continue;

          final player = takePlayer(byPos[group] ?? const <Player>[]);
          if (player == null) continue;

          cells.add(
            LotoCriterion(
              cellIndex: cells.length,
              type: LotoCriterionType.position,
              label: _posLabel(group),
              subtitle: 'Mevki',
              key: group,
            ),
          );
          ownerPlayerIds.add(player.id);
          return;
        }
      }

      void addDecadeCell() {
        final keys = byDecade.keys.toList()..shuffle(_rng);

        for (final key in keys) {
          if (!usedDecade.add(key)) continue;

          final player = takePlayer(byDecade[key] ?? const <Player>[]);
          if (player == null) continue;

          final year =
              int.tryParse(key.replaceAll('s', '')) ?? 0;
          final label = year >= 2000
              ? '${year}\'ler'
              : '${year % 100}\'ler';

          cells.add(
            LotoCriterion(
              cellIndex: cells.length,
              type: LotoCriterionType.decade,
              label: label,
              subtitle: 'Veri dönemi',
              key: key,
            ),
          );
          ownerPlayerIds.add(player.id);
          return;
        }
      }

      void addLeagueCell() {
        if (usedLeague || opt == null) return;

        final player = takePlayer(pool);
        if (player == null) return;

        usedLeague = true;
        cells.add(
          LotoCriterion(
            cellIndex: cells.length,
            type: LotoCriterionType.league,
            label: opt.label,
            subtitle: 'Lig',
            key: opt.label,
          ),
        );
        ownerPlayerIds.add(player.id);
      }

      for (final type in types) {
        if (cells.length >= 16) break;

        switch (type) {
          case LotoCriterionType.club:
            addClubCell();
            break;
          case LotoCriterionType.country:
            addCountryCell();
            break;
          case LotoCriterionType.league:
            addLeagueCell();
            break;
          case LotoCriterionType.position:
            addPositionCell();
            break;
          case LotoCriterionType.decade:
            addDecadeCell();
            break;
        }
      }

      while (cells.length < 16) {
        final before = cells.length;

        addClubCell();
        if (cells.length >= 16) break;

        addCountryCell();
        if (cells.length >= 16) break;

        addPositionCell();
        if (cells.length >= 16) break;

        addDecadeCell();

        if (cells.length == before) break;
      }

      if (cells.length < 16 || ownerPlayerIds.length < 16) {
        debugPrint(
          '[HybridV3] Loto SQLite could not build 16 unique '
          'criteria; legacy fallback.',
        );
        return null;
      }

      final cells16 = cells.take(16).toList();
      final owners16 = ownerPlayerIds.take(16).toList();
      final queue = List<int>.from(owners16)..shuffle(_rng);

      final playerById = <int, Player>{
        for (final player in pool) player.id: player,
      };

      final validMap = <int, Set<int>>{};

      for (var i = 0; i < 16; i++) {
        final playerId = owners16[i];
        final player = playerById[playerId];
        final set = <int>{i};

        if (player != null) {
          for (final cell in cells16) {
            if (_runtimeCriterionMatches(
              player,
              cell,
              clubIdsByPlayer: clubIdsByPlayer,
              factsByPlayer: factsByPlayer,
              leagueMetaByClubId: leagueMetaByClubId,
            )) {
              set.add(cell.cellIndex);
            }
          }
        }

        validMap[playerId] = set;
      }

      debugPrint(
        '[HybridV3] Loto SQLite '
        'league=${leagueFilter ?? 'all'} '
        'difficulty=${difficulty.name} '
        'pool=${pool.length} clubs=${byClub.length}',
      );

      return LotoBoard(
        leagueFilter: opt?.label,
        difficulty: difficulty,
        cells: cells16,
        playerQueue: queue,
        validCellsForPlayer: validMap,
      );
    } catch (e) {
      debugPrint('[HybridV3] Loto SQLite fallback: $e');
      return null;
    }
  }

}
