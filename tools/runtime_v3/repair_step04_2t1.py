from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "lib/services/pyramid_generator.dart"
IMPORT = "import 'package:flutter/foundation.dart';"

def main():
    if not TARGET.exists():
        raise SystemExit(f"[FAIL] Eksik: {TARGET}")

    text = TARGET.read_text(encoding="utf-8")

    for marker in ["generateRuntime({", "[HybridV3] Pyramid SQLite", "debugPrint("]:
        if marker not in text:
            raise RuntimeError(f"04.2T marker eksik: {marker}")

    if IMPORT in text:
        print("[PASS] foundation.dart import zaten mevcut.")
        return

    bak = TARGET.with_suffix(TARGET.suffix + ".step04_2t1.bak")
    if not bak.exists():
        shutil.copy2(TARGET, bak)

    if "import 'dart:math';" in text:
        text = text.replace(
            "import 'dart:math';",
            "import 'dart:math';\n\n" + IMPORT,
            1,
        )
    elif "import '../models/club.dart';" in text:
        text = text.replace(
            "import '../models/club.dart';",
            IMPORT + "\n\nimport '../models/club.dart';",
            1,
        )
    else:
        raise RuntimeError("Guvenli import anchor bulunamadi.")

    with TARGET.open("w", encoding="utf-8", newline="\n") as f:
        f.write(text.replace("\r\n", "\n").replace("\r", "\n"))

    print("[FIX] pyramid_generator.dart -> flutter/foundation.dart eklendi.")
    print("[OK] Step 04.2T.1 applied.")

if __name__ == "__main__":
    main()
