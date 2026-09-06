from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CTRL = ROOT / "lib/controllers/guess_the_player_controller.dart"
HYBRID = ROOT / "lib/services/runtime_v3/hybrid_gameplay_data_service.dart"

HYBRID_IMPORT = "import '../services/runtime_v3/hybrid_gameplay_data_service.dart';"
PLAYER_IMPORT = "import '../models/player.dart';"

def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step04_2o.bak")
    if not bak.exists():
        shutil.copy2(path, bak)

def add_import(text: str, line: str, anchors: list[str]) -> str:
    if line in text:
        return text
    for anchor in anchors:
        if anchor in text:
            return text.replace(anchor, anchor + "\n" + line, 1)
    raise RuntimeError(f"import anchor bulunamadi: {line}")

def main() -> None:
    if not CTRL.exists():
        raise SystemExit(f"[FAIL] Eksik: {CTRL}")
    if not HYBRID.exists():
        raise SystemExit("[FAIL] Hybrid runtime service yok.")

    original = CTRL.read_text(encoding="utf-8")
    text = original

    final_markers = [
        "_runtimeClubPool",
        "_runtimeAnswerPlayers",
        "_runtimeClubIdsByPlayer",
        "playersInPool('grid_answer')",
        "playerClubIdsForPool('grid_answer')",
        "_clubIdsForPlayer",
        "[HybridV3] GuessThePlayer SQLite",
    ]

    if all(m in text for m in final_markers):
        print("[PASS] GuessThePlayer already fully migrated.")
        return

    if any(m in text for m in final_markers):
        raise RuntimeError(
            "PARTIAL_04_2O: kismi migration bulundu. "
            "Otomatik ustune yazilmadi."
        )

    required = [
        "import 'dart:async';",
        "import '../models/club.dart';",
        "import '../services/search_service.dart';",
        "Timer? _feedbackTimer;",
        "void initialize() {",
        "_pickNewClub();",
        "void _pickNewClub() {",
        "final pool = chainClubPool",
        ".where((p) => p.clubs.contains(club.id))",
    ]
    for marker in required:
        if marker not in text:
            raise RuntimeError(f"GuessThePlayer local shape bulunamadi: {marker}")

    text = add_import(
        text,
        PLAYER_IMPORT,
        ["import '../models/club.dart';"],
    )
    text = add_import(
        text,
        HYBRID_IMPORT,
        ["import '../services/search_service.dart';"],
    )

    text = text.replace(
        "  Timer? _feedbackTimer;",
        """  Timer? _feedbackTimer;

  bool _usingRuntimeV3 = false;
  List<Club> _runtimeClubPool = const [];
  List<Player> _runtimeAnswerPlayers = const [];
  Map<int, List<int>> _runtimeClubIdsByPlayer = const {};
""",
        1,
    )

    old_init = """  void initialize() {
    _pickNewClub();
  }"""
    new_init = r"""  void initialize() {
    unawaited(_initializeHybrid());
  }

  Future<void> _initializeHybrid() async {
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      _runtimeClubPool = await hybrid.topGameplayClubs(limit: 120);
      _runtimeAnswerPlayers = await hybrid.playersInPool('grid_answer');
      _runtimeClubIdsByPlayer =
          await hybrid.playerClubIdsForPool('grid_answer');

      if (_runtimeClubPool.length < 20 ||
          _runtimeAnswerPlayers.length < 5000 ||
          _runtimeClubIdsByPlayer.length < 5000) {
        debugPrint(
          '[HybridV3] GuessThePlayer SQLite pool too small; '
          'legacy fallback.',
        );
        _usingRuntimeV3 = false;
      } else {
        debugPrint(
          '[HybridV3] GuessThePlayer SQLite '
          'clubs=${_runtimeClubPool.length} '
          'answers=${_runtimeAnswerPlayers.length}',
        );
      }
    }

    _pickNewClub();
  }

  List<int> _clubIdsForPlayer(Player player) {
    return _usingRuntimeV3
        ? (_runtimeClubIdsByPlayer[player.id] ?? const <int>[])
        : player.clubs;
  }"""
    if old_init not in text:
        raise RuntimeError("GuessThePlayer initialize exact block bulunamadi")
    text = text.replace(old_init, new_init, 1)

    old_pick = """  void _pickNewClub() {
    final pool = chainClubPool
        .map((id) => Repository.instance.clubById(id))
        .whereType<Club>()
        .toList();

    final club = pool[_random.nextInt(pool.length)];"""
    new_pick = r"""  void _pickNewClub() {
    final pool = _usingRuntimeV3
        ? List<Club>.from(_runtimeClubPool)
        : chainClubPool
            .map((id) => Repository.instance.clubById(id))
            .whereType<Club>()
            .toList();

    if (pool.isEmpty) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return;
    }

    final club = pool[_random.nextInt(pool.length)];"""
    if old_pick not in text:
        raise RuntimeError("GuessThePlayer club picker exact block bulunamadi")
    text = text.replace(old_pick, new_pick, 1)

    old_candidates = """    final candidates = Repository.instance.players
        .where((p) => !used.contains(p.id))
        .where((p) => p.clubs.contains(club.id))
        .toList();"""
    new_candidates = r"""    final source = _usingRuntimeV3
        ? _runtimeAnswerPlayers
        : Repository.instance.players;

    final candidates = source
        .where((p) => !used.contains(p.id))
        .where((p) => _clubIdsForPlayer(p).contains(club.id))
        .toList();"""
    if old_candidates not in text:
        raise RuntimeError("GuessThePlayer candidate exact block bulunamadi")
    text = text.replace(old_candidates, new_candidates, 1)

    for marker in final_markers + [PLAYER_IMPORT]:
        if marker not in text:
            raise RuntimeError(f"GuessThePlayer final marker eksik: {marker}")

    backup(CTRL)
    CTRL.write_text(text, encoding="utf-8")

    print("[OK] patched lib/controllers/guess_the_player_controller.dart")
    print("[DONE] Step 04.2O Guess the Player migration installed.")
    print("[SAFE] Flag OFF keeps legacy chainClubPool + Player.clubs behavior.")

if __name__ == "__main__":
    main()
