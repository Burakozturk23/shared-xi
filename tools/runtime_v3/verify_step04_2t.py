from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

checks = {
    "lib/services/pyramid_generator.dart": [
        "generateRuntime({",
        "playersInPool('normal_v3')",
        "playerClubIdsForPool('normal_v3')",
        "existingGameplayClubMetadata()",
        "_fromRuntimePlayer",
        "remainingPlayerEntities < 9",
        "[HybridV3] Pyramid SQLite",
    ],
    "lib/controllers/pyramid_controller.dart": [
        "import 'dart:async';",
        "_startNewAsync",
        "PyramidGenerator.generateRuntime(",
        "[HybridV3] Pyramid controller runtime board active",
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
    print("[FAIL] Step 04.2T verification")

    for error in errors:
        print("  -", error)

    raise SystemExit(1)

print("[PASS] Step 04.2T Pyramid static integration OK.")
print("[INFO] flutter analyze + Android Pyramid test are final verification.")
