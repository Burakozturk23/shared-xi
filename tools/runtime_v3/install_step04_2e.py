from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVERSE = ROOT / "lib/controllers/reverse_grid_controller.dart"
HYBRID = ROOT / "lib/services/runtime_v3/hybrid_gameplay_data_service.dart"

IMPORT_LINE = "import '../services/runtime_v3/hybrid_gameplay_data_service.dart';"

def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step04_2e.bak")
    if not bak.exists():
        shutil.copy2(path, bak)

def main() -> None:
    if not REVERSE.exists():
        raise SystemExit(f"[FAIL] Eksik: {REVERSE}")
    if not HYBRID.exists():
        raise SystemExit(
            "[FAIL] Hybrid runtime service yok. Once 04.2A kurulmus olmali."
        )

    original = REVERSE.read_text(encoding="utf-8")
    text = original

    if (
        "grid_question_normal" in text
        and "_runtimeClubIdsByPlayer" in text
        and "_matchesCriterion" in text
    ):
        print("[PASS] reverse_grid_controller.dart already migrated.")
        return

    required = [
        "import 'dart:math';",
        "import '../services/search_service.dart';",
        "void initialize() {",
        "List<GridCriterion> _generateColumnCriteria",
        "() => GridCriterion.goals(goals.removeLast()),",
        "bool _validateCommonPoint(List<Player> axisPlayers, String guess)",
        "if (axisPlayers.every((p) => p.clubs.contains(club.id))) return true;",
        "if (axisPlayers.every((p) => p.careerGoals >= n)) return true;",
    ]
    for marker in required:
        if marker not in text:
            raise RuntimeError(f"Reverse Grid local shape bulunamadi: {marker}")

    if "import 'dart:async';" not in text:
        text = text.replace(
            "import 'dart:math';",
            "import 'dart:async';\nimport 'dart:math';",
            1,
        )

    if IMPORT_LINE not in text:
        anchor = "import '../services/search_service.dart';"
        text = text.replace(anchor, anchor + "\n" + IMPORT_LINE, 1)

    state_marker = "  ReverseGridState get state => _state;"
    if state_marker not in text:
        raise RuntimeError("Reverse Grid state marker bulunamadi")

    text = text.replace(
        state_marker,
        state_marker + r"""

  bool _usingRuntimeV3 = false;
  List<Player> _runtimePlayers = const [];
  List<Club> _runtimeClubs = const [];
  Map<int, List<int>> _runtimeClubIdsByPlayer = const {};
""",
        1,
    )

    # Replace initialize() through the next method declaration.
    pattern = re.compile(
        r"  void initialize\(\)\s*\{.*?\n  \}\s*"
        r"List<GridCriterion> _generateColumnCriteria",
        re.S,
    )
    match = pattern.search(text)
    if not match:
        # tolerate one blank line / indentation variation
        pattern = re.compile(
            r"  void initialize\(\)\s*\{.*?\n  \}\s*\n\s*"
            r"List<GridCriterion> _generateColumnCriteria",
            re.S,
        )
        match = pattern.search(text)
    if not match:
        raise RuntimeError("Reverse Grid initialize block bulunamadi")

    replacement = r"""  void initialize() {
    unawaited(_initializeHybrid());
  }

  Future<void> _initializeHybrid() async {
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      _runtimePlayers = await hybrid.playersInPool('grid_question_normal');
      _runtimeClubIdsByPlayer =
          await hybrid.playerClubIdsForPool('grid_question_normal');
      _runtimeClubs = await hybrid.topGameplayClubs(limit: 120);

      if (_runtimePlayers.length < 500 ||
          _runtimeClubIdsByPlayer.length < 500 ||
          _runtimeClubs.length < 20) {
        debugPrint(
          '[HybridV3] ReverseGrid SQLite pool too small; legacy fallback.',
        );
        _usingRuntimeV3 = false;
      } else {
        debugPrint(
          '[HybridV3] ReverseGrid SQLite '
          'players=${_runtimePlayers.length} '
          'clubs=${_runtimeClubs.length}',
        );
      }
    }

    _buildPuzzle();
  }

  List<int> _clubIdsForPlayer(Player player) {
    return _usingRuntimeV3
        ? (_runtimeClubIdsByPlayer[player.id] ?? const <int>[])
        : player.clubs;
  }

  bool _matchesCriterion(GridCriterion criterion, Player player) {
    if (!_usingRuntimeV3) return criterion.matches(player);

    switch (criterion.type) {
      case GridCriterionType.club:
        return _clubIdsForPlayer(player).contains(criterion.clubId);
      case GridCriterionType.country:
        return player.countries.contains(criterion.countryName);
      case GridCriterionType.position:
        return player.position == criterion.position;
      case GridCriterionType.goals:
        // Historical source-window coverage is not a complete career total.
        return false;
    }
  }

  List<Club> _runtimeDiverseClubs({
    required List<Club> source,
    required int count,
    int maxPerLeague = 2,
    int maxPerCountry = 3,
  }) {
    final shuffled = List<Club>.from(source)..shuffle(_random);
    final result = <Club>[];
    final leagueCounts = <String, int>{};
    final countryCounts = <String, int>{};

    for (final club in shuffled) {
      final league = club.league.trim();
      final country = club.country.trim();

      if (league.isNotEmpty &&
          (leagueCounts[league] ?? 0) >= maxPerLeague) {
        continue;
      }
      if (country.isNotEmpty &&
          (countryCounts[country] ?? 0) >= maxPerCountry) {
        continue;
      }

      result.add(club);
      if (league.isNotEmpty) {
        leagueCounts[league] = (leagueCounts[league] ?? 0) + 1;
      }
      if (country.isNotEmpty) {
        countryCounts[country] = (countryCounts[country] ?? 0) + 1;
      }

      if (result.length >= count) break;
    }

    if (result.length < count) {
      for (final club in shuffled) {
        if (result.any((c) => c.id == club.id)) continue;
        result.add(club);
        if (result.length >= count) break;
      }
    }

    return result;
  }

  void _buildPuzzle() {
    final players =
        _usingRuntimeV3 ? _runtimePlayers : Repository.instance.players;
    final clubs =
        _usingRuntimeV3 ? _runtimeClubs : PopularClubs.resolveAll();

    // Runtime pool is already selectionRankV3 ordered.
    final ranked = _usingRuntimeV3
        ? List<Player>.from(players)
        : (List<Player>.from(players)
          ..sort((a, b) {
            double fame(Player p) =>
                p.careerGoals * 50.0 +
                p.peakMarketValue +
                p.marketValue * 0.5;
            return fame(b).compareTo(fame(a));
          }));

    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      final diverse = _usingRuntimeV3
          ? _runtimeDiverseClubs(source: clubs, count: 8)
          : PopularClubs.pickDiverse(
              count: 8,
              maxPerLeague: 2,
              maxPerCountry: 3,
              random: _random,
            );

      final pool = diverse.isNotEmpty
          ? diverse
          : (List<Club>.from(clubs)..shuffle(_random));

      final rowClubs = pool.take(3).toList();
      final rows = rowClubs.map(GridCriterion.club).toList();
      final remaining = pool.skip(3).toList()..shuffle(_random);
      final cols = _generateColumnCriteria(remaining);

      final usedIds = <int>{};
      final cellPlayers = <Player>[];
      var valid = true;

      for (final row in rows) {
        for (final col in cols) {
          Player? found;
          for (final p in ranked) {
            if (p.name.trim().isEmpty) continue;
            if (!usedIds.contains(p.id) &&
                _matchesCriterion(row, p) &&
                _matchesCriterion(col, p)) {
              found = p;
              break;
            }
          }

          if (found == null) {
            valid = false;
            break;
          }

          usedIds.add(found.id);
          cellPlayers.add(found);
        }
        if (!valid) break;
      }

      if (valid) {
        _state = _state.copyWith(
          isLoading: false,
          rowCriteria: rows,
          colCriteria: cols,
          cellPlayers: cellPlayers,
        );
        notifyListeners();
        return;
      }
    }

    _state = _state.copyWith(isLoading: false);
    notifyListeners();
  }

  List<GridCriterion> _generateColumnCriteria"""
    text = text[:match.start()] + replacement + text[match.end():]

    old_pickers = """    final pickers = <GridCriterion Function()>[
      () => GridCriterion.club(availableClubs.removeLast()),
      () => GridCriterion.country(countries.removeLast()),
      () {
        final picked = positions.removeLast();
        return GridCriterion.position(picked.value, picked.label);
      },
      () => GridCriterion.goals(goals.removeLast()),
    ];"""
    new_pickers = """    final pickers = <GridCriterion Function()>[
      () => GridCriterion.club(availableClubs.removeLast()),
      () => GridCriterion.country(countries.removeLast()),
      () {
        final picked = positions.removeLast();
        return GridCriterion.position(picked.value, picked.label);
      },
      if (!_usingRuntimeV3) () => GridCriterion.goals(goals.removeLast()),
    ];"""
    if old_pickers not in text:
        raise RuntimeError("Reverse Grid picker block bulunamadi")
    text = text.replace(old_pickers, new_pickers, 1)

    # Free-text common-club validation must use canonical relations.
    text = text.replace(
        "if (axisPlayers.every((p) => p.clubs.contains(club.id))) return true;",
        "if (axisPlayers.every(\n"
        "            (p) => _clubIdsForPlayer(p).contains(club.id))) {\n"
        "          return true;\n"
        "        }",
        1,
    )

    # Numeric free-text goal answers are only valid on legacy data.
    text = text.replace(
        "if (axisPlayers.every((p) => p.careerGoals >= n)) return true;",
        "if (!_usingRuntimeV3 &&\n"
        "            axisPlayers.every((p) => p.careerGoals >= n)) {\n"
        "          return true;\n"
        "        }",
        1,
    )

    final_markers = [
        "grid_question_normal",
        "_runtimeClubIdsByPlayer",
        "_runtimeDiverseClubs",
        "_matchesCriterion(row, p)",
        "if (!_usingRuntimeV3) () => GridCriterion.goals",
        "_clubIdsForPlayer(p).contains(club.id)",
        "!_usingRuntimeV3 &&",
        "[HybridV3] ReverseGrid SQLite",
    ]
    for marker in final_markers:
        if marker not in text:
            raise RuntimeError(f"Reverse Grid final marker eksik: {marker}")

    backup(REVERSE)
    REVERSE.write_text(text, encoding="utf-8")
    print("[OK] patched lib/controllers/reverse_grid_controller.dart")
    print("[DONE] Step 04.2E Reverse Grid migration installed.")
    print("[SAFE] Random Grid is intentionally deferred to 04.2F.")
    print("[SAFE] Feature flag OFF keeps legacy behavior.")

if __name__ == "__main__":
    main()
