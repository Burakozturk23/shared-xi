from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
p = ROOT / "lib/services/pyramid_generator.dart"

if not p.exists():
    raise SystemExit("[FAIL] pyramid_generator.dart yok")

text = p.read_text(encoding="utf-8")

required = [
    "import 'package:flutter/foundation.dart';",
    "generateRuntime({",
    "[HybridV3] Pyramid SQLite",
    "debugPrint(",
]

missing = [m for m in required if m not in text]
if missing:
    print("[FAIL] 04.2T.1 verification")
    for m in missing:
        print("  -", m)
    raise SystemExit(1)

print("[PASS] 04.2T.1 static verification OK.")
