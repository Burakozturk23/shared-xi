from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
checks = {
    "lib/services/loto_generator.dart": [
        "generateRuntime({",
        "build_xi_preview",
        "_runtimeCriterionMatches",
        "coverage_first_year",
        "coverage_last_year",
        "subtitle: 'Veri dönemi'",
        "[HybridV3] Loto SQLite",
    ],
    "lib/controllers/loto_controller.dart": [
        "_startAsync",
        "LotoGenerator.generateRuntime",
        "validCellsForPlayer[playerId]",
        "[HybridV3] Loto controller runtime board active",
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
    print("[FAIL] Step 04.2Q verification")
    for e in errors:
        print("  -", e)
    raise SystemExit(1)

print("[PASS] Step 04.2Q Loto static integration OK.")
print("[INFO] flutter analyze + Android Loto tests are final verification.")
