from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
checks = {
    "lib/services/runtime_v3/hybrid_gameplay_data_service.dart": [
        "sharedXiAnswerIds",
        "playerPool = 'grid_answer'",
    ],
    "lib/controllers/random_grid_controller.dart": [
        "pool=grid_answer",
        "_pairAnswerIds",
        "_answersForPair",
        "_generatePairRuntime",
        "_primePairCache(newRows, newCols)",
        "_cachedPairContains(row, col, player.id)",
        "_runtimeRarityBonus",
        "[HybridV3] RandomGrid SQLite",
    ],
}

errors = []
for rel, markers in checks.items():
    p = ROOT / rel
    if not p.exists():
        errors.append(f"MISSING: {rel}")
        continue
    text = p.read_text(encoding="utf-8")
    for marker in markers:
        if marker not in text:
            errors.append(f"{rel}: missing {marker}")

if errors:
    print("[FAIL] Step 04.2F verification")
    for e in errors:
        print("  -", e)
    raise SystemExit(1)

print("[PASS] Step 04.2F static integration OK.")
print("[INFO] Android Random Grid gameplay test is final verification.")
