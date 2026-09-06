from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

checks = {
    "lib/models/blind_ranking_state.dart": [
        "trueOrderPlayerIds",
        "if (trueOrderPlayerIds.isNotEmpty)",
    ],
    "lib/controllers/blind_ranking_controller.dart": [
        "normal_v3",
        "_initializeHybrid",
        "trueOrderPlayerIds: trueOrderIds",
        "[HybridV3] BlindRanking SQLite",
        "_initializeLegacy",
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
    print("[FAIL] Step 04.2I verification")
    for error in errors:
        print("  -", error)
    raise SystemExit(1)

print("[PASS] Step 04.2I static integration OK.")
print("[INFO] Android Blind Ranking gameplay test is final verification.")
