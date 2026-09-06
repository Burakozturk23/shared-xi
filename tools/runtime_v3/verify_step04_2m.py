from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
checks = {
    "lib/controllers/daily_challenge_controller.dart": [
        "_runtimeMatchingPlayers",
        "playersInPool('shared_xi_answer')",
        "[HybridV3] DailyChallenge SQLite",
    ],
    "lib/controllers/endless_controller.dart": [
        "_runtimePlayersByClub",
        "_generateRuntimePair",
        "endless_${matchMode.name}_${gameStyle.name}_v3_best",
        "[HybridV3] Endless SQLite",
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
    print("[FAIL] Step 04.2M verification")
    for e in errors:
        print("  -", e)
    raise SystemExit(1)
print("[PASS] Step 04.2M static integration OK.")
