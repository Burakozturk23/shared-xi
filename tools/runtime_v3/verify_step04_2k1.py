from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
p = ROOT / "lib/controllers/streak_controller.dart"

if not p.exists():
    raise SystemExit("[FAIL] streak_controller.dart yok")

text = p.read_text(encoding="utf-8")

checks = [
    "import '../models/player.dart';",
    "final found = <Player>[];",
    "_nextRoundRuntime",
    "[HybridV3] Streak SQLite",
]

missing = [m for m in checks if m not in text]
if missing:
    print("[FAIL] 04.2K.1 verification")
    for m in missing:
        print("  -", m)
    raise SystemExit(1)

print("[PASS] Step 04.2K.1 Player import hotfix OK.")
print("[INFO] flutter analyze final verification olacak.")
