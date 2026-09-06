from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
checks = {
    "lib/models/higher_lower_state.dart": [
        "runtimeV3",
        "runtimeValues",
        "'Kapsanan Resmi Maç'",
        "'Kapsanan Gol'",
    ],
    "lib/controllers/higher_lower_controller.dart": [
        "playerFactsForPool('normal_v3')",
        "higher_lower_apps_v3_best",
        "higher_lower_goals_v3_best",
        "[HybridV3] HigherLower SQLite",
        "runtimeValues: _runtimeValues",
    ],
    "lib/screens/higher_lower_page.dart": [
        "state.runtimeV3",
        "'${v.toInt()} maç'",
    ],
    "lib/screens/higher_lower_mode_selection_page.dart": [
        "RuntimeV3Flags.gameplayEnabled",
        "'Kapsanan Resmi Maç'",
        "'Kapsanan Gol'",
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
    print("[FAIL] Step 04.2J verification")
    for error in errors:
        print("  -", error)
    raise SystemExit(1)

print("[PASS] Step 04.2J static integration OK.")
print("[INFO] Android Higher/Lower gameplay test is final verification.")
