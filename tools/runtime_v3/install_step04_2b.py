from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHAIN = ROOT / "lib/controllers/chain_controller.dart"
HYBRID = ROOT / "lib/services/runtime_v3/hybrid_gameplay_data_service.dart"
GRAPH = ROOT / "lib/services/runtime_v3/hybrid_chain_graph_service.dart"

IMPORT_LINE = (
    "import '../services/runtime_v3/hybrid_chain_graph_service.dart';"
)

def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step04_2b.bak")
    if not bak.exists():
        shutil.copy2(path, bak)

def require(text: str, marker: str, label: str) -> None:
    if marker not in text:
        raise RuntimeError(f"{label} bulunamadi: {marker}")

def main() -> None:
    if not CHAIN.exists():
        raise SystemExit(f"[FAIL] Eksik: {CHAIN}")
    if not HYBRID.exists() or not GRAPH.exists():
        raise SystemExit(
            "[FAIL] 04.2A runtime dosyalari yok. "
            "Once Step 04.2A v2 kurulmus olmali."
        )

    original = CHAIN.read_text(encoding="utf-8")
    text = original

    # Idempotent: if all core markers exist, only verify.
    if (
        "HybridChainGraphSnapshot? _runtimeGraph;" in text
        and "_initializeHybridGraph" in text
        and "_clubIdsForPlayer" in text
        and "Chain SQLite enabled" in text
    ):
        print("[PASS] chain_controller.dart already migrated.")
        return

    # Validate all important local shapes BEFORE writing anything.
    required = [
        ("import '../services/search_service.dart';", "import anchor"),
        ("Map<int, List<Player>>? _playersByClub;", "playersByClub field"),
        ("void initialize()", "initialize"),
        ("void newPuzzle()", "newPuzzle"),
        ("void _buildIndexIfNeeded()", "legacy index"),
        ("List<Club> _quizClubs()", "quiz clubs"),
        ("final famous = chainClubPool.toSet();", "BFS famous pool"),
        ("for (final next in p.clubs)", "BFS player clubs"),
        ("final pool = _playersByClub?[currentId]", "player query"),
        ("final clubIds = <int>{...player.clubs};", "national wildcard seed"),
        ("for (final p in Repository.instance.players)", "national wildcard scan"),
        ("clubIds.addAll(p.clubs);", "national wildcard club add"),
        ("options = player.clubs", "normal next-club options"),
        ("if (p.clubs.contains(targetId))", "bridge target test"),
    ]
    for marker, label in required:
        require(text, marker, label)

    # Import.
    if IMPORT_LINE not in text:
        anchor = "import '../services/search_service.dart';"
        text = text.replace(anchor, anchor + "\n" + IMPORT_LINE, 1)

    # Runtime graph field.
    field_marker = "  Map<int, List<Player>>? _playersByClub;"
    text = text.replace(
        field_marker,
        field_marker
        + "\n\n  /// 04.2B canonical SQLite graph snapshot."
        + "\n  HybridChainGraphSnapshot? _runtimeGraph;",
        1,
    )

    # initialize() -> async graph bootstrap without changing public method shape.
    init_pattern = re.compile(
        r"  void initialize\(\)\s*\{\s*"
        r"_buildIndexIfNeeded\(\);\s*"
        r"_startPuzzle\(keepSession:\s*false\);\s*"
        r"\}",
        re.S,
    )
    m = init_pattern.search(text)
    if not m:
        raise RuntimeError("initialize body yapisal olarak bulunamadi")

    init_new = r"""  void initialize() {
    // Chain screen API remains synchronous. Graph bootstrap is async because
    // SQLite is async; ChainState is already loading by default.
    unawaited(_initializeHybridGraph());
  }

  Future<void> _initializeHybridGraph() async {
    final snapshot = await HybridChainGraphService.instance.load();

    if (snapshot != null) {
      _runtimeGraph = snapshot;
      _playersByClub = snapshot.playersByClub;
      debugPrint(
        '[HybridV3] Chain SQLite enabled '
        'players=${snapshot.players.length} '
        'clubs=${snapshot.playersByClub.length}',
      );
    } else {
      _runtimeGraph = null;
      _buildIndexIfNeeded();
      debugPrint('[HybridV3] Chain legacy JSON graph active');
    }

    _startPuzzle(keepSession: false);
  }"""
    text = text[:m.start()] + init_new + text[m.end():]

    # Helper methods before BFS comment.
    bfs_marker = "  /// BFS: start → target en az kaç oyuncu (hamle)."
    require(text, bfs_marker, "BFS comment")
    helpers = r"""  List<int> _clubIdsForPlayer(Player player) {
    return _runtimeGraph?.clubIdsByPlayer[player.id] ?? player.clubs;
  }

  Iterable<Player> _graphPlayers() {
    return _runtimeGraph?.players ?? Repository.instance.players;
  }

  Set<int> _graphFamousClubIds() {
    return _runtimeGraph?.graphClubIds ?? chainClubPool.toSet();
  }

"""
    text = text.replace(bfs_marker, helpers + bfs_marker, 1)

    # Quiz clubs: SQLite metadata replaces hard-coded start/target selection
    # while legacy list remains untouched for flag-off fallback.
    quiz_marker = "  List<Club> _quizClubs() {"
    text = text.replace(
        quiz_marker,
        quiz_marker
        + "\n    final runtime = _runtimeGraph;"
        + "\n    if (runtime != null && runtime.quizClubs.length >= 2) {"
        + "\n      return List<Club>.from(runtime.quizClubs);"
        + "\n    }",
        1,
    )

    # BFS relation authority.
    text = text.replace(
        "    final famous = chainClubPool.toSet();",
        "    final famous = _graphFamousClubIds();",
        1,
    )
    text = text.replace(
        "        for (final next in p.clubs) {",
        "        for (final next in _clubIdsForPlayer(p)) {",
        1,
    )

    # Search block: in Runtime V3 the per-club list is already ordered by
    # selection_rank. No peakMarketValue filtering/sorting.
    query_pattern = re.compile(
        r"    final pool = _playersByClub\?\[currentId\] \?\? const <Player>\[\];\s*"
        r"    final candidates = pool\s*"
        r"\.where\(\(p\) => SearchService\.contains\(p\.name, q\)\)\s*"
        r"\.where\(\(p\) => p\.peakMarketValue >= 3000000 \|\| p\.clubs\.length >= 3\)\s*"
        r"\.toList\(\)\s*"
        r"\.\.sort\(\(a, b\) => b\.peakMarketValue\.compareTo\(a\.peakMarketValue\)\);\s*"
        r"    final limited = candidates\.take\(15\)\.toList\(\);",
        re.S,
    )
    qm = query_pattern.search(text)
    if not qm:
        raise RuntimeError("Chain player query legacy value block bulunamadi")

    query_new = r"""    final pool = _playersByClub?[currentId] ?? const <Player>[];
    var candidates = pool
        .where((p) => SearchService.contains(p.name, q))
        .toList();

    if (_runtimeGraph == null) {
      // Legacy fallback only. Runtime V3 uses selection-rank ordered pool.
      candidates = candidates
          .where((p) => p.peakMarketValue >= 3000000 || p.clubs.length >= 3)
          .toList()
        ..sort((a, b) => b.peakMarketValue.compareTo(a.peakMarketValue));
    }

    final limited = candidates.take(15).toList();"""
    text = text[:qm.start()] + query_new + text[qm.end():]

    # Next-club / wildcard graph authority.
    text = text.replace(
        "      final clubIds = <int>{...player.clubs};",
        "      final clubIds = <int>{..._clubIdsForPlayer(player)};",
        1,
    )
    text = text.replace(
        "      for (final p in Repository.instance.players) {",
        "      for (final p in _graphPlayers()) {",
        1,
    )
    text = text.replace(
        "        clubIds.addAll(p.clubs);",
        "        clubIds.addAll(_clubIdsForPlayer(p));",
        1,
    )
    text = text.replace(
        "      options = player.clubs",
        "      options = _clubIdsForPlayer(player)",
        1,
    )

    # Bridge hint.
    text = text.replace(
        "      if (p.clubs.contains(targetId)) {",
        "      if (_clubIdsForPlayer(p).contains(targetId)) {",
        1,
    )

    # Final safety checks before write.
    final_markers = [
        "HybridChainGraphSnapshot? _runtimeGraph;",
        "unawaited(_initializeHybridGraph());",
        "return _runtimeGraph?.clubIdsByPlayer[player.id] ?? player.clubs;",
        "final famous = _graphFamousClubIds();",
        "for (final next in _clubIdsForPlayer(p))",
        "if (_runtimeGraph == null)",
        "final clubIds = <int>{..._clubIdsForPlayer(player)};",
        "for (final p in _graphPlayers())",
        "options = _clubIdsForPlayer(player)",
        "if (_clubIdsForPlayer(p).contains(targetId))",
    ]
    for marker in final_markers:
        if marker not in text:
            raise RuntimeError(f"Final marker eksik: {marker}")

    backup(CHAIN)
    CHAIN.write_text(text, encoding="utf-8")
    print("[OK] patched lib/controllers/chain_controller.dart")
    print("[DONE] Step 04.2B Chain SQLite graph migration installed.")
    print("[SAFE] Feature flag OFF => legacy JSON graph remains available.")

if __name__ == "__main__":
    main()
