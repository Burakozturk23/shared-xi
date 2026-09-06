from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
p = ROOT / "lib/controllers/cinko_controller.dart"

if not p.exists():
    raise SystemExit("[FAIL] cinko_controller.dart yok")

text = p.read_text(encoding="utf-8")
markers = [
    "_runtimeClubPool",
    "_runtimeClubIdsByPlayer",
    "_runtimeAnswerPlayerIds",
    "_runtimeLeagueByClubId",
    "playersInPool('grid_answer')",
    "playerClubIdsForPool('grid_answer')",
    "existingGameplayClubMetadata()",
    "_clubIdsForPlayer(player)",
    "[HybridV3] Cinko SQLite",
]

missing = [m for m in markers if m not in text]
if missing:
    print("[FAIL] Step 04.2L markers")
    for m in missing:
        print("  -", m)
    raise SystemExit(1)

print("[PASS] Step 04.2L Cinko static integration OK.")
print("[INFO] Android Cinko gameplay test is final verification.")
