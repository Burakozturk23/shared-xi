from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

checks = {
    "lib/services/runtime_v3/hybrid_gameplay_data_service.dart":
        "class HybridGameplayDataService",
    "lib/services/runtime_v3/runtime_v3_flags.dart":
        "LINKBALL_SQLITE_GAMEPLAY_V3",
    "lib/services/runtime_v3/runtime_v3_platform_io.dart":
        "playerClubIdsForPool",
    "lib/controllers/game_controller.dart":
        "sharedXiMatchingPlayers",
    "lib/controllers/odd_club_controller.dart":
        "odd_club_normal",
    "lib/controllers/guess_the_player_controller.dart":
        "guess_the_player_clubs",
}

failed = []
for rel, marker in checks.items():
    p = ROOT / rel
    if not p.exists():
        failed.append(f"{rel}: MISSING")
        continue
    if marker not in p.read_text(encoding="utf-8"):
        failed.append(f"{rel}: marker missing: {marker}")

if failed:
    print("[FAIL] Step 04.2A verification:")
    for item in failed:
        print("  -", item)
    raise SystemExit(1)

print("[PASS] Step 04.2A static integration markers OK.")
print("[INFO] Android compile/run is the final verification.")
