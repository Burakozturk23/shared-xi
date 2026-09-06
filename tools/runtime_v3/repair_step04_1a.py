from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "lib/main.dart"
PUBSPEC = ROOT / "pubspec.yaml"

REQUIRED = [
    ROOT / "lib/services/runtime_v3/runtime_v3_service.dart",
    ROOT / "lib/services/runtime_v3/runtime_v3_database.dart",
    ROOT / "lib/services/runtime_v3/runtime_v3_flags.dart",
    ROOT / "lib/services/runtime_v3/runtime_v3_platform_base.dart",
    ROOT / "lib/services/runtime_v3/runtime_v3_platform_io.dart",
    ROOT / "lib/services/runtime_v3/runtime_v3_platform_stub.dart",
    ROOT / "assets/runtime/linkball_runtime_v3.sqlite",
    ROOT / "assets/runtime/runtime_manifest_v3.json",
]

def main() -> None:
    print("=" * 70)
    print("LINKBALL STEP 04.1A - SIDECAR REPAIR")
    print("=" * 70)

    if not MAIN.exists() or not PUBSPEC.exists():
        raise SystemExit(
            "[FAIL] ZIP proje ana dizinine cikarilmamis. "
            "Bu dosyanin yaninda lib/, assets/, pubspec.yaml olmali."
        )

    missing = [str(p.relative_to(ROOT)) for p in REQUIRED if not p.exists()]
    if missing:
        print("[FAIL] Eksik dosyalar:")
        for p in missing:
            print("  -", p)
        raise SystemExit(1)

    main_text = MAIN.read_text(encoding="utf-8")
    pub = PUBSPEC.read_text(encoding="utf-8")

    imp = "import 'services/runtime_v3/runtime_v3_service.dart';"
    if imp not in main_text:
        marker = "import 'repositories/repository.dart';"
        if marker not in main_text:
            raise SystemExit("[FAIL] main.dart Repository import bulunamadi.")
        backup = MAIN.with_suffix(MAIN.suffix + ".step04_1a.bak")
        if not backup.exists():
            shutil.copy2(MAIN, backup)
        main_text = main_text.replace(marker, marker + "\n" + imp, 1)
        MAIN.write_text(main_text, encoding="utf-8")
        print("[FIX] RuntimeV3Service import eklendi.")
    else:
        print("[PASS] RuntimeV3Service import mevcut.")

    if not re.search(r"(?m)^\s*sqflite\s*:", pub):
        print("[FAIL] pubspec.yaml icinde sqflite dependency yok.")
        print("       Onceki 04.1 install yarim kalmis olabilir.")
        raise SystemExit(1)
    print("[PASS] sqflite dependency mevcut.")

    if "assets/runtime/" not in pub:
        print("[FAIL] pubspec.yaml icinde assets/runtime/ asset kaydi yok.")
        raise SystemExit(1)
    print("[PASS] assets/runtime/ kaydi mevcut.")

    print("[PASS] Runtime V3 Dart dosyalari: 6/6")
    print("[PASS] SQLite DB + manifest mevcut")
    print()
    print("[DONE] 04.1A repair tamam.")
    print("Sonraki komut:")
    print(
        "flutter run --dart-define=LINKBALL_SQLITE_V3=true "
        "--dart-define=LINKBALL_SQLITE_PARITY=true"
    )

if __name__ == "__main__":
    main()
