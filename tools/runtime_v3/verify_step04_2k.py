from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
checks = {
    "lib/controllers/streak_controller.dart": [
        "_runtimeQuizClubs",
        "_nextRoundRuntime",
        "playerPool: 'shared_xi_answer'",
        "_advanceRound",
        "[HybridV3] Streak SQLite clubs=",
    ],
    "lib/controllers/random_five_controller.dart": [
        "_runtimeClubPool",
        "_runtimeClubIdsByPlayer",
        "_runtimeAnswerPlayerIds",
        "playersInPool('grid_answer')",
        "playerClubIdsForPool('grid_answer')",
        "_pickRuntimeDiverseClubs",
        "[HybridV3] RandomFive SQLite",
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
    print("[FAIL] Step 04.2K verification")
    for e in errors:
        print("  -", e)
    raise SystemExit(1)
print("[PASS] Step 04.2K static integration OK.")
print("[INFO] Android Streak + Random Five gameplay test is final verification.")
