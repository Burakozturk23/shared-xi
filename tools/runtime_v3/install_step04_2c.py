from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GRID = ROOT / "lib/controllers/grid_controller.dart"
HYBRID = ROOT / "lib/services/runtime_v3/hybrid_gameplay_data_service.dart"
IMPORT_LINE = "import '../services/runtime_v3/hybrid_gameplay_data_service.dart';"

def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step04_2c.bak")
    if not bak.exists():
        shutil.copy2(path, bak)

def main() -> None:
    if not GRID.exists():
        raise SystemExit(f"[FAIL] Eksik: {GRID}")
    if not HYBRID.exists():
        raise SystemExit(
            "[FAIL] 04.2A runtime service yok. "
            "Once 04.2A kurulmus olmali."
        )

    original = GRID.read_text(encoding="utf-8")
    text = original

    # Idempotent
    if (
        "grid_question_normal" in text
        and "_runtimeClubIdsByPlayer" in text
        and "_matchesCriterion" in text
    ):
        print("[PASS] grid_controller.dart already migrated.")
        return

    required = [
        "import '../services/search_service.dart';",
        "List<Player> suggestions = const [];",
        "void initialize()",
        "List<GridCriterion> _generateColumnCriteria",
        "() => GridCriterion.goals(goals.removeLast()),",
        "int _rarityBonus(Player player)",
        "if (!row.matches(player) || !col.matches(player)) return null;",
    ]
    for marker in required:
        if marker not in text:
            raise RuntimeError(f"Grid local shape bulunamadi: {marker}")

    if "import 'dart:async';" not in text:
        text = text.replace(
            "import 'dart:math';",
            "import 'dart:async';\nimport 'dart:math';",
            1,
        )

    if IMPORT_LINE not in text:
        anchor = "import '../services/search_service.dart';"
        text = text.replace(anchor, anchor + "\n" + IMPORT_LINE, 1)

    field_marker = "  List<Player> suggestions = const [];"
    text = text.replace(
        field_marker,
        field_marker + r"""

  bool _usingRuntimeV3 = false;
  List<Player> _runtimePlayers = const [];
  List<Club> _runtimeClubs = const [];
  Map<int, List<int>> _runtimeClubIdsByPlayer = const {};
  Map<int, int> _runtimeRankByPlayer = const {};
""",
        1,
    )

    # Replace initialize through the next method signature.
    pattern = re.compile(
        r"  void initialize\(\)\s*\{.*?\n  \}\s*\n"
        r"  List<GridCriterion> _generateColumnCriteria",
        re.S,
    )
    m = pattern.search(text)
    if not m:
        raise RuntimeError("Grid initialize block yapisal olarak bulunamadi")

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

      _runtimeRankByPlayer = {
        for (var i = 0; i < _runtimePlayers.length; i++)
          _runtimePlayers[i].id: i + 1,
      };

      if (_runtimePlayers.length < 500 ||
          _runtimeClubIdsByPlayer.length < 500 ||
          _runtimeClubs.length < 20) {
        debugPrint(
          '[HybridV3] Grid SQLite pool too small; legacy fallback.',
        );
        _usingRuntimeV3 = false;
      } else {
        debugPrint(
          '[HybridV3] Grid SQLite '
          'players=${_runtimePlayers.length} '
          'clubs=${_runtimeClubs.length}',
        );
      }
    }

    _buildPuzzle();
  }

  void _buildPuzzle() {
    final players =
        _usingRuntimeV3 ? _runtimePlayers : Repository.instance.players;
    final clubs =
        _usingRuntimeV3 ? _runtimeClubs : PopularClubs.resolveAll();

    for (var attempt = 0; attempt < _maxGenerationAttempts; attempt++) {
      final shuffledClubs = List<Club>.from(clubs)..shuffle(_random);
      final rowClubs = shuffledClubs.take(3).toList();
      final rows = rowClubs.map(GridCriterion.club).toList();
      final remainingClubs =
          shuffledClubs.skip(3).toList()..shuffle(_random);

      final cols = _generateColumnCriteria(remainingClubs);

      var valid = true;
      for (final row in rows) {
        for (final col in cols) {
          final hasMatch = players.any(
            (p) =>
                _matchesCriterion(row, p) &&
                _matchesCriterion(col, p),
          );
          if (!hasMatch) {
            valid = false;
            break;
          }
        }
        if (!valid) break;
      }

      if (valid) {
        _state = _state.copyWith(
          isLoading: false,
          rowCriteria: rows,
          colCriteria: cols,
        );
        notifyListeners();
        return;
      }
    }

    final fallbackRows =
        (List<Club>.from(clubs)..shuffle(_random)).take(3).toList();
    final fallbackCols =
        (List<Club>.from(clubs)..shuffle(_random)).take(3).toList();

    _state = _state.copyWith(
      isLoading: false,
      rowCriteria: fallbackRows.map(GridCriterion.club).toList(),
      colCriteria: fallbackCols.map(GridCriterion.club).toList(),
    );
    notifyListeners();
  }

  bool _matchesCriterion(GridCriterion criterion, Player player) {
    if (!_usingRuntimeV3) return criterion.matches(player);

    switch (criterion.type) {
      case GridCriterionType.club:
        final ids =
            _runtimeClubIdsByPlayer[player.id] ?? const <int>[];
        return ids.contains(criterion.clubId);

      case GridCriterionType.country:
        return player.countries.contains(criterion.countryName);

      case GridCriterionType.position:
        return player.position == criterion.position;

      case GridCriterionType.goals:
        // Source appearance history is not complete for every historical
        // player. Do not claim unscoped "career goals" in Runtime V3.
        return false;
    }
  }

  List<GridCriterion> _generateColumnCriteria"""
    text = text[:m.start()] + replacement + text[m.end():]

    old_picker = """    final pickers = <GridCriterion Function()>[
      () => GridCriterion.club(availableClubs.removeLast()),
      () => GridCriterion.country(countries.removeLast()),
      () {
        final picked = positions.removeLast();
        return GridCriterion.position(picked.value, picked.label);
      },
      () => GridCriterion.goals(goals.removeLast()),
    ];"""
    new_picker = """    final pickers = <GridCriterion Function()>[
      () => GridCriterion.club(availableClubs.removeLast()),
      () => GridCriterion.country(countries.removeLast()),
      () {
        final picked = positions.removeLast();
        return GridCriterion.position(picked.value, picked.label);
      },
      if (!_usingRuntimeV3) () => GridCriterion.goals(goals.removeLast()),
    ];"""
    if old_picker not in text:
        raise RuntimeError("Grid picker block bulunamadi")
    text = text.replace(old_picker, new_picker, 1)

    rarity_pattern = re.compile(
        r"  int _rarityBonus\(Player player\)\s*\{.*?\n  \}",
        re.S,
    )
    rm = rarity_pattern.search(text)
    if not rm:
        raise RuntimeError("Grid rarity block bulunamadi")

    rarity = r"""  int _rarityBonus(Player player) {
    if (_usingRuntimeV3) {
      final rank = _runtimeRankByPlayer[player.id] ?? 999999;

      // Larger rank = less recognizable = rarer answer.
      if (rank > 4500) return 30;
      if (rank > 2500) return 15;
      if (rank > 1000) return 5;
      return 0;
    }

    final value = player.marketValue;
    if (value <= 0 || value < 250000) return 30;
    if (value < 2000000) return 15;
    if (value < 20000000) return 5;
    return 0;
  }"""
    text = text[:rm.start()] + rarity + text[rm.end():]

    old_check = (
        "    if (!row.matches(player) || !col.matches(player)) return null;"
    )
    check_count = text.count(old_check)
    if check_count < 2:
        raise RuntimeError(
            f"Grid submit checks beklenen 2, bulunan {check_count}"
        )
    text = text.replace(
        old_check,
        "    if (!_matchesCriterion(row, player) ||\n"
        "        !_matchesCriterion(col, player)) return null;",
    )

    final_markers = [
        "grid_question_normal",
        "_runtimeClubIdsByPlayer",
        "_runtimeRankByPlayer[player.id]",
        "if (!_usingRuntimeV3) () => GridCriterion.goals",
        "_matchesCriterion(row, player)",
        "[HybridV3] Grid SQLite",
    ]
    for marker in final_markers:
        if marker not in text:
            raise RuntimeError(f"Final marker eksik: {marker}")

    backup(GRID)
    GRID.write_text(text, encoding="utf-8")
    print("[OK] patched lib/controllers/grid_controller.dart")
    print("[DONE] Step 04.2C Classic Grid migration installed.")
    print("[SAFE] Reverse/Random Grid and Mystery remain unchanged.")
    print("[SAFE] Feature flag OFF keeps legacy behavior.")

if __name__ == "__main__":
    main()
