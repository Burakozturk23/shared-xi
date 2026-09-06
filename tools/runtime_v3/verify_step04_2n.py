from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
p = ROOT / "lib/controllers/odd_club_controller.dart"

if not p.exists():
    raise SystemExit("[FAIL] odd_club_controller.dart yok")

text = p.read_text(encoding="utf-8")
markers = [
    "_runtimeClubIdsByPlayer",
    "_effectiveHighScoreKey",
    "playersInPool('normal_v3')",
    "playerClubIdsForPool('normal_v3')",
    "realCount >= 3",
    "_initializeLegacy",
    "_clubIdsForPlayer(player)",
    "[HybridV3] OddClub SQLite",
]

missing = [m for m in markers if m not in text]
if missing:
    print("[FAIL] Step 04.2N verification")
    for m in missing:
        print("  -", m)
    raise SystemExit(1)

print("[PASS] Step 04.2N Odd Club static integration OK.")
print("[INFO] Android Find Imposter / Odd Club gameplay test is final verification.")
