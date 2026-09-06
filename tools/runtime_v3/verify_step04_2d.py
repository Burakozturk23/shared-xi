from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
checks = {
    "lib/services/runtime_v3/runtime_v3_platform_io.dart": [
        "playerFactsForPool",
        "LEFT JOIN profiles",
        "LEFT JOIN player_stats",
        "coverage_class",
    ],
    "lib/services/runtime_v3/hybrid_gameplay_data_service.dart": [
        "playerFactsForPool",
    ],
    "lib/controllers/mystery_player_controller.dart": [
        "mystery_normal",
        "_runtimeClubIdsByPlayer",
        "_runtimeFactsByPlayer",
        "_factualStatsText",
        "_physicalProfileText",
        "title: _usingRuntimeV3 ? 'Profil' : 'Piyasa'",
        "[HybridV3] Mystery SQLite",
    ],
}
errors = []
for rel, markers in checks.items():
    p = ROOT / rel
    if not p.exists():
        errors.append(f"MISSING {rel}")
        continue
    text = p.read_text(encoding="utf-8")
    for marker in markers:
        if marker not in text:
            errors.append(f"{rel}: missing {marker}")
if errors:
    print("[FAIL] 04.2D verification")
    for e in errors:
        print("  -", e)
    raise SystemExit(1)
print("[PASS] Step 04.2D static integration OK.")
print("[INFO] Android Mystery Player run is final verification.")
