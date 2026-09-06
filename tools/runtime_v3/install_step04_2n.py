from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ODD = ROOT / "lib/controllers/odd_club_controller.dart"
HYBRID = ROOT / "lib/services/runtime_v3/hybrid_gameplay_data_service.dart"

IMPORT_LINE = "import '../services/runtime_v3/hybrid_gameplay_data_service.dart';"

def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step04_2n.bak")
    if not bak.exists():
        shutil.copy2(path, bak)

def add_import(text: str, anchor: str) -> str:
    if IMPORT_LINE in text:
        return text
    if anchor not in text:
        raise RuntimeError(f"import anchor bulunamadi: {anchor}")
    return text.replace(anchor, anchor + "\n" + IMPORT_LINE, 1)

def main() -> None:
    if not ODD.exists():
        raise SystemExit(f"[FAIL] Eksik: {ODD}")
    if not HYBRID.exists():
        raise SystemExit("[FAIL] Hybrid runtime service yok.")

    original = ODD.read_text(encoding="utf-8")
    text = original

    if (
        "OddClub SQLite" in text
        and "_runtimeClubIdsByPlayer" in text
        and "_initializeLegacy" in text
    ):
        print("[PASS] odd_club_controller.dart already migrated.")
        return

    required = [
        "import '../services/high_score_service.dart';",
        "late List<Player> _pool;",
        "late List<Club> _clubPool;",
        "bool _ready = false;",
        "Future<void> initialize() async {",
        "final poolClubIds = _clubPool.map((c) => c.id).toSet();",
        "p.peakMarketValue >= 40000000",
        "_pool.sort((a, b) => b.peakMarketValue.compareTo(a.peakMarketValue));",
        "final realIds = player.clubs.toSet().intersection(poolClubIds).toList()",
        "void restart() {",
    ]
    for marker in required:
        if marker not in text:
            raise RuntimeError(f"Odd Club local shape bulunamadi: {marker}")

    text = add_import(text, "import '../services/high_score_service.dart';")

    field_marker = "  bool _ready = false;"
    text = text.replace(
        field_marker,
        field_marker + r"""

  bool _usingRuntimeV3 = false;
  Map<int, List<int>> _runtimeClubIdsByPlayer = const {};
""",
        1,
    )

    # High-score namespace: V3 mode difficulty/player universe is different.
    old_ctor = """  OddClubController({required this.timed})
      : _highScoreKey =
            timed ? 'odd_club_timed_best' : 'odd_club_endless_best';"""
    new_ctor = """  OddClubController({required this.timed})
      : _highScoreKey =
            timed ? 'odd_club_timed_best' : 'odd_club_endless_best';"""
    # Keep ctor unchanged; runtime save key is routed via getter below to avoid
    # final-field constructor changes that may affect callers.
    if old_ctor not in text:
        raise RuntimeError("Odd Club constructor block bulunamadi")

    # Insert effective key helper after _ready/runtime fields.
    insert_after = """  bool _usingRuntimeV3 = false;
  Map<int, List<int>> _runtimeClubIdsByPlayer = const {};
"""
    replacement = insert_after + r"""

  String get _effectiveHighScoreKey =>
      _usingRuntimeV3 ? '${_highScoreKey}_v3' : _highScoreKey;
"""
    text = text.replace(insert_after, replacement, 1)

    # Replace initialize with runtime bootstrap + exact legacy fallback.
    init_start = text.find("  Future<void> initialize() async {")
    dispose_start = text.find("  @override\n  void dispose()", init_start)
    if init_start < 0 or dispose_start < 0:
        raise RuntimeError("Odd Club initialize boundary bulunamadi")

    legacy_block = text[init_start:dispose_start]
    body_start = legacy_block.find("{") + 1
    body_end = legacy_block.rfind("}")
    legacy_body = legacy_block[body_start:body_end]

    new_init = r"""  Future<void> initialize() async {
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      _clubPool = await hybrid.topGameplayClubs(limit: 120);

      final orderedPlayers = await hybrid.playersInPool('normal_v3');
      _runtimeClubIdsByPlayer =
          await hybrid.playerClubIdsForPool('normal_v3');

      final poolClubIds = _clubPool.map((c) => c.id).toSet();

      // normal_v3 is selectionRankV3 ordered. Keep players that have enough
      // canonical top-club history for 3 real clubs + 1 fake-club gameplay.
      _pool = orderedPlayers.where((p) {
        final realCount = (_runtimeClubIdsByPlayer[p.id] ?? const <int>[])
            .where(poolClubIds.contains)
            .toSet()
            .length;
        return realCount >= 3;
      }).take(1800).toList();

      if (_clubPool.length < 20 ||
          _runtimeClubIdsByPlayer.length < 5000 ||
          _pool.length < 120) {
        debugPrint(
          '[HybridV3] OddClub SQLite pool too small; legacy fallback.',
        );
        _usingRuntimeV3 = false;
        await _initializeLegacy();
        return;
      }

      final best = await HighScoreService.getHighScore(
        key: _effectiveHighScoreKey,
      );

      _ready = true;
      _state = _state.copyWith(
        isLoading: false,
        bestStreak: best,
      );

      debugPrint(
        '[HybridV3] OddClub SQLite '
        'timed=$timed players=${_pool.length} clubs=${_clubPool.length}',
      );

      _nextQuestion(resetLives: true);
      return;
    }

    await _initializeLegacy();
  }

  Future<void> _initializeLegacy() async {""" + legacy_body + r"""
  }

  List<int> _clubIdsForPlayer(Player player) {
    return _usingRuntimeV3
        ? (_runtimeClubIdsByPlayer[player.id] ?? const <int>[])
        : player.clubs;
  }

"""
    text = text[:init_start] + new_init + text[dispose_start:]

    # Real club selection must use canonical relations in runtime.
    old_real_ids = """    final realIds = player.clubs.toSet().intersection(poolClubIds).toList()
      ..shuffle(_random);"""
    new_real_ids = """    final realIds = _clubIdsForPlayer(player)
        .toSet()
        .intersection(poolClubIds)
        .toList()
      ..shuffle(_random);"""
    if old_real_ids not in text:
        raise RuntimeError("Odd Club realIds block bulunamadi")
    text = text.replace(old_real_ids, new_real_ids, 1)

    # V3 high-score key must remain separate at read/save points.
    # Legacy initialize copied above still uses _highScoreKey; that's intentional.
    save_old = """    await HighScoreService.saveHighScore(_state.score, key: _highScoreKey);"""
    save_new = """    await HighScoreService.saveHighScore(
      _state.score,
      key: _effectiveHighScoreKey,
    );"""
    if save_old not in text:
        raise RuntimeError("Odd Club saveHighScore block bulunamadi")
    text = text.replace(save_old, save_new, 1)

    final_markers = [
        "_runtimeClubIdsByPlayer",
        "_effectiveHighScoreKey",
        "playersInPool('normal_v3')",
        "playerClubIdsForPool('normal_v3')",
        "realCount >= 3",
        "_initializeLegacy",
        "_clubIdsForPlayer(player)",
        "[HybridV3] OddClub SQLite",
    ]
    for marker in final_markers:
        if marker not in text:
            raise RuntimeError(f"Odd Club final marker eksik: {marker}")

    backup(ODD)
    ODD.write_text(text, encoding="utf-8")

    print("[OK] patched lib/controllers/odd_club_controller.dart")
    print("[DONE] Step 04.2N Odd Club / Find Imposter migration installed.")
    print("[SAFE] Feature flag OFF keeps legacy market-value behavior.")

if __name__ == "__main__":
    main()
