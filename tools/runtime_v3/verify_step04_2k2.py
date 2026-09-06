from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
p = ROOT / "lib/controllers/streak_controller.dart"

if not p.exists():
    raise SystemExit("[FAIL] streak_controller.dart yok")

text = p.read_text(encoding="utf-8")

checks = [
    "import '../models/player.dart';",
    "_nextRoundRuntime",
    "[HybridV3] Streak SQLite",
]

missing = [m for m in checks if m not in text]

if missing:
    print("[FAIL] Step 04.2K.2 verification")
    for m in missing:
        print("  -", m)
    raise SystemExit(1)

print("[PASS] Step 04.2K.2 static repair OK.")
print("[INFO] Exact Player generic spelling is intentionally NOT enforced.")
print("[INFO] flutter analyze is the final Dart verification.")
