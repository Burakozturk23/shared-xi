from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
p = ROOT / "lib/controllers/guess_the_player_controller.dart"
if not p.exists():
    raise SystemExit("[FAIL] guess_the_player_controller.dart yok")

text = p.read_text(encoding="utf-8")
markers = [
    "import '../models/player.dart';",
    "_runtimeClubPool",
    "_runtimeAnswerPlayers",
    "_runtimeClubIdsByPlayer",
    "playersInPool('grid_answer')",
    "playerClubIdsForPool('grid_answer')",
    "_clubIdsForPlayer(p)",
    "[HybridV3] GuessThePlayer SQLite",
]
missing = [m for m in markers if m not in text]
if missing:
    print("[FAIL] Step 04.2O verification")
    for m in missing:
        print("  -", m)
    raise SystemExit(1)

print("[PASS] Step 04.2O Guess the Player static integration OK.")
print("[INFO] flutter analyze + Android gameplay are final verification.")
