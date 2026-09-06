from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

checks = {
    "lib/services/match_pair_generator.dart": [
        "generateRuntime({",
        "playersInPool('normal_v3')",
        "playerClubIdsForPool('normal_v3')",
        "topGameplayClubs(limit: 160)",
        "[HybridV3] MatchPair SQLite",
    ],
    "lib/controllers/match_pair_controller.dart": [
        "MatchPairGenerator.generateRuntime(",
        "[HybridV3] MatchPair controller runtime board active",
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
    print("[FAIL] Step 04.2S verification")
    for error in errors:
        print("  -", error)
    raise SystemExit(1)

print("[PASS] Step 04.2S Match Pair static integration OK.")
print("[INFO] flutter analyze + Android Match Pair are final verification.")
