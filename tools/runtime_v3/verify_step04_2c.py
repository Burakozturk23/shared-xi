from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
p = ROOT / "lib/controllers/grid_controller.dart"

if not p.exists():
    raise SystemExit("[FAIL] grid_controller.dart yok")

text = p.read_text(encoding="utf-8")
markers = [
    "grid_question_normal",
    "_runtimeClubIdsByPlayer",
    "_runtimeRankByPlayer[player.id]",
    "if (!_usingRuntimeV3) () => GridCriterion.goals",
    "_matchesCriterion(row, player)",
    "[HybridV3] Grid SQLite",
]

missing = [m for m in markers if m not in text]
if missing:
    print("[FAIL] 04.2C markers:")
    for m in missing:
        print("  -", m)
    raise SystemExit(1)

print("[PASS] Step 04.2C Classic Grid static integration OK.")
print("[INFO] Android Grid gameplay test is final verification.")
