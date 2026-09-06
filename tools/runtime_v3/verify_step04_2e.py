from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
p = ROOT / "lib/controllers/reverse_grid_controller.dart"

if not p.exists():
    raise SystemExit("[FAIL] reverse_grid_controller.dart yok")

text = p.read_text(encoding="utf-8")
markers = [
    "grid_question_normal",
    "_runtimeClubIdsByPlayer",
    "_runtimeDiverseClubs",
    "_matchesCriterion(row, p)",
    "if (!_usingRuntimeV3) () => GridCriterion.goals",
    "_clubIdsForPlayer(p).contains(club.id)",
    "[HybridV3] ReverseGrid SQLite",
]

missing = [m for m in markers if m not in text]
if missing:
    print("[FAIL] 04.2E markers")
    for m in missing:
        print("  -", m)
    raise SystemExit(1)

print("[PASS] Step 04.2E Reverse Grid static integration OK.")
print("[INFO] Android Reverse Grid gameplay test is final verification.")
