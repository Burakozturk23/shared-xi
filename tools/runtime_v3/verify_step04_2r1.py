from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
p = ROOT / "lib/controllers/mystery_player_controller.dart"

if not p.exists():
    raise SystemExit("[FAIL] mystery_player_controller.dart yok")

text = p.read_text(encoding="utf-8")
markers = [
    "_runtimePlayers",
    "_runtimeClubIdsByPlayer",
    "_runtimeFactsByPlayer",
    "_runtimeClubNameById",
    "playersInPool('normal_v3')",
    "playerClubIdsForPool('normal_v3')",
    "playerFactsForPool('normal_v3')",
    "_startRoundRuntime",
    "_runtimeStatsHint",
    "'Veri dönemi'",
    "[HybridV3] MysteryPlayer SQLite",
]
missing = [m for m in markers if m not in text]
if missing:
    print("[FAIL] Step 04.2R verification")
    for m in missing:
        print("  -", m)
    raise SystemExit(1)

print("[PASS] Step 04.2R Mystery Player static integration OK.")
