from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "lib/services/loto_generator.dart"
CTRL = ROOT / "lib/controllers/loto_controller.dart"
HYBRID = ROOT / "lib/services/runtime_v3/hybrid_gameplay_data_service.dart"

RUNTIME_IMPORT = "import 'runtime_v3/hybrid_gameplay_data_service.dart';"
FOUNDATION_IMPORT = "import 'package:flutter/foundation.dart';"

def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step04_2q.bak")
    if not bak.exists():
        shutil.copy2(path, bak)

def insert_before_last_class_brace(text: str, block: str) -> str:
    idx = text.rfind("\n}")
    if idx < 0:
        raise RuntimeError("class end bulunamadi")
    return text[:idx] + block + text[idx:]

def patch_generator(text: str) -> str:
    final_markers = [
        "generateRuntime({",
        "build_xi_preview",
        "_runtimeCriterionMatches",
        "coverage_first_year",
        "[HybridV3] Loto SQLite",
    ]
    if all(m in text for m in final_markers):
        return text
    if any(m in text for m in final_markers):
        raise RuntimeError(
            "PARTIAL_04_2Q_GENERATOR: loto_generator kismi migration."
        )

    required = [
        "import 'dart:math';",
        "import '../models/loto_models.dart';",
        "class LotoGenerator {",
        "static _LeagueOpt? _optByLabel(String? label)",
        "static String _posGroup(Player p)",
        "static String _posLabel(String g)",
        "static bool matches(Player player, LotoCriterion c)",
        "static LotoBoard generate({",
    ]
    for marker in required:
        if marker not in text:
            raise RuntimeError(f"LotoGenerator local shape bulunamadi: {marker}")

    if FOUNDATION_IMPORT not in text:
        text = text.replace(
            "import 'dart:math';",
            "import 'dart:math';\n\n" + FOUNDATION_IMPORT,
            1,
        )

    if RUNTIME_IMPORT not in text:
        anchor = "import '../repositories/repository.dart';"
        if anchor not in text:
            raise RuntimeError("LotoGenerator repository import anchor yok")
        text = text.replace(anchor, anchor + "\n" + RUNTIME_IMPORT, 1)

    runtime_block = r'''

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
'''

    return insert_before_last_class_brace(text, runtime_block)

def patch_controller(text: str) -> str:
    final_markers = [
        "_startAsync",
        "LotoGenerator.generateRuntime",
        "validCellsForPlayer[playerId]",
        "[HybridV3] Loto controller runtime board active",
    ]
    if all(m in text for m in final_markers):
        return text
    if any(m in text for m in final_markers):
        raise RuntimeError(
            "PARTIAL_04_2Q_CONTROLLER: loto_controller kismi migration."
        )

    required = [
        "import 'dart:async';",
        "void start({",
        "final board = LotoGenerator.generate(",
        "void restartSame() =>",
        "if (player != null && LotoGenerator.matches(player, cell))",
    ]
    for marker in required:
        if marker not in text:
            raise RuntimeError(f"LotoController local shape bulunamadi: {marker}")

    start_begin = text.find("  void start({")
    restart_begin = text.find("  void restartSame() =>", start_begin)
    if start_begin < 0 or restart_begin < 0:
        raise RuntimeError("LotoController start boundary bulunamadi")

    new_start = r'''  void start({
    String? leagueFilter,
    LotoDifficulty difficulty = LotoDifficulty.medium,
  }) {
    unawaited(
      _startAsync(
        leagueFilter: leagueFilter,
        difficulty: difficulty,
      ),
    );
  }

  Future<void> _startAsync({
    String? leagueFilter,
    required LotoDifficulty difficulty,
  }) async {
    _timer?.cancel();
    _lastLeague = leagueFilter;
    _lastDiff = difficulty;

    var board = await LotoGenerator.generateRuntime(
      leagueFilter: leagueFilter,
      difficulty: difficulty,
    );

    if (board != null) {
      debugPrint(
        '[HybridV3] Loto controller runtime board active '
        'cells=${board.cells.length}',
      );
    } else {
      board = LotoGenerator.generate(
        leagueFilter: leagueFilter,
        difficulty: difficulty,
      );
    }

    _state = LotoState(
      board: board,
      remainingSeconds: difficulty.secondsPerPlayer,
      isPlaying: true,
    );

    notifyListeners();
    _armTimer();
  }

'''
    text = text[:start_begin] + new_start + text[restart_begin:]

    old_score = '''      final player = Repository.instance.playerById(playerId);
      final cell = board.cells[cellIndex];
      if (player != null && LotoGenerator.matches(player, cell)) {
        correct++;
      } else {
        wrong++;
      }'''
    new_score = '''      final validCells =
          board.validCellsForPlayer[playerId] ?? const <int>{};

      if (validCells.contains(cellIndex)) {
        correct++;
      } else {
        wrong++;
      }'''
    if old_score not in text:
        raise RuntimeError("LotoController final scoring block bulunamadi")
    text = text.replace(old_score, new_score, 1)

    return text

def main() -> None:
    for p in (GEN, CTRL, HYBRID):
        if not p.exists():
            raise SystemExit(f"[FAIL] Eksik gerekli dosya: {p}")

    hybrid_text = HYBRID.read_text(encoding="utf-8")
    for marker in [
        "playersInPool",
        "playerClubIdsForPool",
        "playerFactsForPool",
        "existingGameplayClubMetadata",
    ]:
        if marker not in hybrid_text:
            raise SystemExit(
                f"[FAIL] Hybrid Runtime method eksik: {marker}. "
                "Once 04.2H ve factual adimlar kurulmus olmali."
            )

    originals = {
        GEN: GEN.read_text(encoding="utf-8"),
        CTRL: CTRL.read_text(encoding="utf-8"),
    }

    patched = {
        GEN: patch_generator(originals[GEN]),
        CTRL: patch_controller(originals[CTRL]),
    }

    for p in (GEN, CTRL):
        backup(p)

    for p in (GEN, CTRL):
        p.write_text(patched[p], encoding="utf-8")
        print(f"[OK] patched {p.relative_to(ROOT)}")

    print("[DONE] Step 04.2Q Loto Runtime V3 installed.")
    print("[SAFE] Legacy generator remains fallback.")

if __name__ == "__main__":
    main()
