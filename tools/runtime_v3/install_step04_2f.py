from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RANDOM = ROOT / "lib/controllers/random_grid_controller.dart"
HYBRID = ROOT / "lib/services/runtime_v3/hybrid_gameplay_data_service.dart"

IMPORT_LINE = "import '../services/runtime_v3/hybrid_gameplay_data_service.dart';"

def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step04_2f.bak")
    if not bak.exists():
        shutil.copy2(path, bak)

def patch_hybrid(text: str) -> str:
    if "sharedXiAnswerIds(" in text:
        return text

    idx = text.rfind("\n}")
    if idx < 0:
        raise RuntimeError("HybridGameplayDataService class end bulunamadi")

    method = r"""
  Future<List<int>> sharedXiAnswerIds(
    int clubIdA,
    int clubIdB, {
    String playerPool = 'grid_answer',
  }) async {
    if (!isGameplayEnabled) return const [];
    try {
      return await _runtime.database.sharedXiPlayerIds(
        clubIdA,
        clubIdB,
        playerPool: playerPool,
      );
    } catch (e) {
      debugPrint(
        '[HybridV3] sharedXiAnswerIds('
        '$clubIdA,$clubIdB,$playerPool) fallback: $e',
      );
      return const [];
    }
  }
"""
    return text[:idx] + method + text[idx:]

def patch_random(text: str) -> str:
    if (
        "grid_answer" in text
        and "_pairAnswerIds" in text
        and "_generatePairRuntime" in text
    ):
        return text

    required = [
        "import 'dart:math';",
        "import '../services/search_service.dart';",
        "List<Player> suggestions = const [];",
        "void initialize() {",
        "void generatePair() {",
        "bool hasKnownCommon(Club a, Club b) {",
        "if (p.careerGoals >= 15 || p.peakMarketValue >= 5000000) return true;",
        "int _rarityBonus(Player player) {",
        "Player? submitPendingPlayerGuess(String answer) {",
        "void placeAtAnchor(int anchorIndex, {required Club rowClub, required Club colClub}) {",
        "Player? submitGuess(int index, String answer) {",
        "void assignPlayer(int index, Player player) {",
    ]
    for marker in required:
        if marker not in text:
            raise RuntimeError(f"Random Grid local shape bulunamadi: {marker}")

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
  List<Club> _runtimeClubs = const [];

  /// key = smallerClubId:largerClubId
  /// value = broad grid_answer IDs, ordered by selectionRankV3.
  final Map<String, List<int>> _pairAnswerIds = {};
""",
        1,
    )

    old_init = """  void initialize() {
    _state = _state.copyWith(isLoading: false);
    notifyListeners();
  }"""
    new_init = r"""  void initialize() {
    unawaited(_initializeHybrid());
  }

  Future<void> _initializeHybrid() async {
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      _runtimeClubs = await hybrid.topGameplayClubs(limit: 120);
      if (_runtimeClubs.length < 20) {
        debugPrint(
          '[HybridV3] RandomGrid SQLite club pool too small; '
          'legacy fallback.',
        );
        _usingRuntimeV3 = false;
      } else {
        debugPrint(
          '[HybridV3] RandomGrid SQLite '
          'clubs=${_runtimeClubs.length} pool=grid_answer',
        );
      }
    }

    _state = _state.copyWith(isLoading: false);
    notifyListeners();
  }

  String _pairKey(int a, int b) {
    return a < b ? '$a:$b' : '$b:$a';
  }

  Future<List<int>> _answersForPair(Club a, Club b) async {
    final key = _pairKey(a.id, b.id);
    final cached = _pairAnswerIds[key];
    if (cached != null) return cached;

    final ids =
        await HybridGameplayDataService.instance.sharedXiAnswerIds(
      a.id,
      b.id,
      playerPool: 'grid_answer',
    );

    final clean = <int>[];
    for (final id in ids) {
      // Search/UI still uses Repository Player objects in hybrid mode.
      if (Repository.instance.playerById(id) != null) {
        clean.add(id);
      }
    }

    _pairAnswerIds[key] = List<int>.unmodifiable(clean);
    return _pairAnswerIds[key]!;
  }

  Future<void> _primePairCache(
    List<Club?> rows,
    List<Club?> cols,
  ) async {
    final jobs = <Future<List<int>>>[];
    for (final row in rows) {
      if (row == null) continue;
      for (final col in cols) {
        if (col == null) continue;
        jobs.add(_answersForPair(row, col));
      }
    }
    if (jobs.isNotEmpty) {
      await Future.wait(jobs);
    }
  }

  bool _cachedPairContains(Club a, Club b, int playerId) {
    final ids = _pairAnswerIds[_pairKey(a.id, b.id)];
    return ids?.contains(playerId) ?? false;
  }

  int _runtimeRarityBonus(Player player, Club a, Club b) {
    final ids = _pairAnswerIds[_pairKey(a.id, b.id)] ?? const <int>[];
    if (ids.isEmpty) return 0;

    final index = ids.indexOf(player.id);
    if (index < 0) return 0;

    final percentile = (index + 1) / ids.length;
    if (percentile > 0.75) return 30;
    if (percentile > 0.50) return 15;
    if (percentile > 0.25) return 5;
    return 0;
  }"""
    if old_init not in text:
        raise RuntimeError("Random Grid initialize exact block bulunamadi")
    text = text.replace(old_init, new_init, 1)

    # Wrap the existing synchronous legacy generatePair rather than deleting it.
    generate_start = text.find("  void generatePair() {")
    rarity_start = text.find("  int _rarityBonus(Player player) {", generate_start)
    if generate_start < 0 or rarity_start < 0:
        raise RuntimeError("Random Grid generatePair/rarity boundaries bulunamadi")

    legacy_generate = text[generate_start:rarity_start]
    legacy_body_start = legacy_generate.find("{") + 1
    legacy_body_end = legacy_generate.rfind("}")
    legacy_body = legacy_generate[legacy_body_start:legacy_body_end]

    # Rename the old logic and keep it exactly as flag-off fallback.
    legacy_method = (
        "  void _generatePairLegacy() {" +
        legacy_body +
        "  }\n"
    )

    runtime_generate = r"""  void generatePair() {
    if (_usingRuntimeV3) {
      unawaited(_generatePairRuntime());
      return;
    }
    _generatePairLegacy();
  }

  Future<void> _generatePairRuntime() async {
    if (_state.roundsUsed >= 3 || _state.hasPendingPair) return;

    final usedClubs = _usedClubIds;
    final usedPlayers = _state.usedPlayerIds;

    final pool = _runtimeClubs
        .where((c) => !usedClubs.contains(c.id))
        .toList();

    if (pool.length < 2) return;

    // Prefer cross-league pairs, but validity is determined only by broad
    // canonical `grid_answer`, never market value or careerGoals.
    for (var attempt = 0; attempt < _maxPairAttempts; attempt++) {
      final shuffled = List<Club>.from(pool)..shuffle(_random);
      Club? a;
      Club? b;

      for (var i = 0; i < shuffled.length; i++) {
        for (var j = i + 1; j < shuffled.length; j++) {
          final first = shuffled[i];
          final second = shuffled[j];

          if (first.league.trim().isNotEmpty &&
              first.league == second.league) {
            continue;
          }

          final ids = await _answersForPair(first, second);
          final usable =
              ids.any((id) => !usedPlayers.contains(id));
          if (!usable) continue;

          a = first;
          b = second;
          break;
        }
        if (a != null) break;
      }

      if (a != null && b != null) {
        _state = _state.copyWith(
          pendingClubA: a,
          pendingClubB: b,
        );
        notifyListeners();
        return;
      }
    }

    // Relax league diversity before giving up.
    final shuffled = List<Club>.from(pool)..shuffle(_random);
    for (var i = 0; i < shuffled.length; i++) {
      for (var j = i + 1; j < shuffled.length; j++) {
        final a = shuffled[i];
        final b = shuffled[j];
        final ids = await _answersForPair(a, b);
        if (!ids.any((id) => !usedPlayers.contains(id))) continue;

        _state = _state.copyWith(
          pendingClubA: a,
          pendingClubB: b,
        );
        notifyListeners();
        return;
      }
    }
  }

"""
    text = (
        text[:generate_start]
        + runtime_generate
        + legacy_method
        + text[rarity_start:]
    )

    # Rarity becomes pair-relative selectionRank order in runtime.
    rarity_pattern = re.compile(
        r"  int _rarityBonus\(Player player\)\s*\{.*?\n  \}",
        re.S,
    )
    match = rarity_pattern.search(text)
    if not match:
        raise RuntimeError("Random Grid rarity block bulunamadi after wrap")

    rarity = r"""  int _rarityBonus(
    Player player, {
    Club? clubA,
    Club? clubB,
  }) {
    if (_usingRuntimeV3 && clubA != null && clubB != null) {
      return _runtimeRarityBonus(player, clubA, clubB);
    }

    final value = player.marketValue;
    if (value <= 0 || value < 250000) return 30;
    if (value < 2000000) return 15;
    if (value < 20000000) return 5;
    return 0;
  }"""
    text = text[:match.start()] + rarity + text[match.end():]

    # Suggestions: when a pending Runtime pair exists, show only valid broad answers.
    old_suggestions = """  void updateSuggestions(String query) {
    suggestions = SearchService.suggestions(
      players: Repository.instance.players,
      query: query,
      excludedPlayerIds: _state.usedPlayerIds,
    );
    notifyListeners();
  }"""
    new_suggestions = r"""  void updateSuggestions(String query) {
    Iterable<Player> source = Repository.instance.players;

    if (_usingRuntimeV3 &&
        _state.pendingClubA != null &&
        _state.pendingClubB != null) {
      final ids = _pairAnswerIds[
          _pairKey(_state.pendingClubA!.id, _state.pendingClubB!.id)];
      if (ids != null) {
        final allowed = ids.toSet();
        source = source.where((p) => allowed.contains(p.id));
      }
    }

    suggestions = SearchService.suggestions(
      players: source,
      query: query,
      excludedPlayerIds: _state.usedPlayerIds,
    );
    notifyListeners();
  }"""
    if old_suggestions not in text:
        raise RuntimeError("Random Grid suggestions block bulunamadi")
    text = text.replace(old_suggestions, new_suggestions, 1)

    # Pending pair validation uses cached broad grid_answer.
    pending_start = text.find("Player? submitPendingPlayerGuess(String answer) {")
    confirm_start = text.find("  void confirmPendingPlayer", pending_start)
    if pending_start < 0 or confirm_start < 0:
        raise RuntimeError("Random Grid pending submit boundaries bulunamadi")

    pending_method = r"""Player? submitPendingPlayerGuess(String answer) {
    final a = _state.pendingClubA;
    final b = _state.pendingClubB;
    if (a == null || b == null) return null;

    final used = _state.usedPlayerIds;

    final r = SearchService.resolve(
      players: Repository.instance.players,
      answer: answer,
      excludedPlayerIds: used,
    );
    if (!r.isFound) return null;

    final player = r.player!;

    if (_usingRuntimeV3) {
      if (!_cachedPairContains(a, b, player.id)) return null;
      return player;
    }

    final candidates = Repository.instance.players
        .where((p) => !used.contains(p.id))
        .where((p) => p.clubs.contains(a.id) && p.clubs.contains(b.id))
        .toList();

    if (!candidates.any((p) => p.id == player.id)) return null;
    return player;
  }

"""
    text = text[:pending_start] + pending_method + text[confirm_start:]

    # placeAtAnchor: runtime must prime every newly visible pair before exposing state.
    place_start = text.find(
        "  void placeAtAnchor(int anchorIndex, {required Club rowClub, required Club colClub}) {"
    )
    submit_start = text.find(
        "  /// Köşegen dışı",
        place_start,
    )
    if place_start < 0 or submit_start < 0:
        raise RuntimeError("Random Grid placeAtAnchor boundaries bulunamadi")

    # Extract existing legacy method.
    legacy_place = text[place_start:submit_start]
    legacy_place_body_start = legacy_place.find("{") + 1
    legacy_place_body_end = legacy_place.rfind("}")
    legacy_place_body = legacy_place[
        legacy_place_body_start:legacy_place_body_end
    ]

    runtime_place = r"""  void placeAtAnchor(
    int anchorIndex, {
    required Club rowClub,
    required Club colClub,
  }) {
    if (_usingRuntimeV3) {
      unawaited(
        _placeAtAnchorRuntime(
          anchorIndex,
          rowClub: rowClub,
          colClub: colClub,
        ),
      );
      return;
    }

    _placeAtAnchorLegacy(
      anchorIndex,
      rowClub: rowClub,
      colClub: colClub,
    );
  }

  Future<void> _placeAtAnchorRuntime(
    int anchorIndex, {
    required Club rowClub,
    required Club colClub,
  }) async {
    final player = _state.pendingPlayer;
    if (player == null) return;

    final row = anchorIndex ~/ 3;
    final col = anchorIndex % 3;

    final newRows = List<Club?>.from(_state.rowClubs)..[row] = rowClub;
    final newCols = List<Club?>.from(_state.colClubs)..[col] = colClub;

    // Important: expose the new grid only after every visible row/column
    // pair has its canonical broad-answer cache ready.
    await _primePairCache(newRows, newCols);

    final newCells = List<GridCellState>.from(_state.cells);
    newCells[anchorIndex] = GridCellState(
      player: player,
      rarityBonus: _rarityBonus(
        player,
        clubA: rowClub,
        clubB: colClub,
      ),
    );

    final finished = newCells.every((c) => c.isFilled);

    _state = _state.copyWith(
      rowClubs: newRows,
      colClubs: newCols,
      cells: newCells,
      roundsUsed: _state.roundsUsed + 1,
      isFinished: finished,
      clearPending: true,
    );

    notifyListeners();
  }

  void _placeAtAnchorLegacy(
    int anchorIndex, {
    required Club rowClub,
    required Club colClub,
  }) {"""
    # legacy body originally starts after signature and closes method.
    runtime_place += legacy_place_body + "  }\n\n"
    text = text[:place_start] + runtime_place + text[submit_start:]

    # submitGuess uses pair cache.
    submit_method_start = text.find("  Player? submitGuess(int index, String answer) {")
    assign_start = text.find("  void assignPlayer(int index, Player player) {", submit_method_start)
    if submit_method_start < 0 or assign_start < 0:
        raise RuntimeError("Random Grid submitGuess boundaries bulunamadi")

    submit_method = r"""  Player? submitGuess(int index, String answer) {
    final row = _state.rowClubs[index ~/ 3];
    final col = _state.colClubs[index % 3];
    if (row == null || col == null) return null;

    final used = _state.usedPlayerIds;

    final r = SearchService.resolve(
      players: Repository.instance.players,
      answer: answer,
      excludedPlayerIds: used,
    );
    if (!r.isFound) return null;

    final player = r.player!;

    if (_usingRuntimeV3) {
      final key = _pairKey(row.id, col.id);
      if (!_pairAnswerIds.containsKey(key)) {
        debugPrint(
          '[HybridV3] RandomGrid pair cache not ready: $key',
        );
        return null;
      }
      if (!_cachedPairContains(row, col, player.id)) return null;
      return player;
    }

    final candidates = Repository.instance.players
        .where((p) => !used.contains(p.id))
        .where(
          (p) =>
              p.clubs.contains(row.id) &&
              p.clubs.contains(col.id),
        )
        .toList();

    if (!candidates.any((p) => p.id == player.id)) return null;
    return player;
  }

"""
    text = text[:submit_method_start] + submit_method + text[assign_start:]

    # assignPlayer needs pair-relative rarity.
    assign_start = text.find("  void assignPlayer(int index, Player player) {")
    finish_start = text.find("  void finishManually() {", assign_start)
    if assign_start < 0 or finish_start < 0:
        raise RuntimeError("Random Grid assignPlayer boundaries bulunamadi")

    assign_method = r"""  void assignPlayer(int index, Player player) {
    final row = _state.rowClubs[index ~/ 3];
    final col = _state.colClubs[index % 3];

    final newCells = List<GridCellState>.from(_state.cells);
    newCells[index] = GridCellState(
      player: player,
      rarityBonus: _rarityBonus(
        player,
        clubA: row,
        clubB: col,
      ),
    );
    final finished = newCells.every((c) => c.isFilled);

    _state = _state.copyWith(
      cells: newCells,
      isFinished: finished,
    );
    notifyListeners();
  }

"""
    text = text[:assign_start] + assign_method + text[finish_start:]

    final_markers = [
        "pool=grid_answer",
        "_pairAnswerIds",
        "_answersForPair",
        "_generatePairRuntime",
        "playerPool: 'grid_answer'",
        "_primePairCache(newRows, newCols)",
        "_cachedPairContains(row, col, player.id)",
        "_runtimeRarityBonus",
        "[HybridV3] RandomGrid SQLite",
    ]
    for marker in final_markers:
        if marker not in text:
            raise RuntimeError(f"Random Grid final marker eksik: {marker}")

    return text

def main() -> None:
    for p in (RANDOM, HYBRID):
        if not p.exists():
            raise SystemExit(f"[FAIL] Eksik gerekli dosya: {p}")

    original_random = RANDOM.read_text(encoding="utf-8")
    original_hybrid = HYBRID.read_text(encoding="utf-8")

    # Atomic: compute both before writing either.
    patched_hybrid = patch_hybrid(original_hybrid)
    patched_random = patch_random(original_random)

    backup(HYBRID)
    backup(RANDOM)

    HYBRID.write_text(patched_hybrid, encoding="utf-8")
    RANDOM.write_text(patched_random, encoding="utf-8")

    print("[OK] patched lib/services/runtime_v3/hybrid_gameplay_data_service.dart")
    print("[OK] patched lib/controllers/random_grid_controller.dart")
    print("[DONE] Step 04.2F Random Grid broad-answer migration installed.")
    print("[SAFE] grid_answer remains broad; question pool was NOT narrowed to 6000.")

if __name__ == "__main__":
    main()
