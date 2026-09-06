from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PUBSPEC = ROOT / "pubspec.yaml"
MAIN = ROOT / "lib/main.dart"

def backup(path: Path):
    bak = path.with_suffix(path.suffix + ".step04_1.bak")
    if not bak.exists():
        shutil.copy2(path, bak)

def patch_pubspec():
    text = PUBSPEC.read_text(encoding="utf-8")
    backup(PUBSPEC)

    if not re.search(r"(?m)^\s*sqflite\s*:", text):
        m = re.search(r"(?m)^(\s*)shared_preferences\s*:[^\n]*$", text)
        if m:
            indent = m.group(1)
            text = text[:m.end()] + f"\n{indent}sqflite: ^2.4.2" + text[m.end():]
        else:
            m = re.search(r"(?m)^dependencies:\s*$", text)
            if not m:
                raise RuntimeError("dependencies: not found")
            text = text[:m.end()] + "\n  sqflite: ^2.4.2" + text[m.end():]

    if "assets/runtime/" not in text:
        m = re.search(r"(?m)^(\s*)-\s*assets/data/\s*$", text)
        if not m:
            raise RuntimeError("assets/data/ line not found")
        indent = m.group(1)
        text = text[:m.end()] + f"\n{indent}- assets/runtime/" + text[m.end():]

    PUBSPEC.write_text(text, encoding="utf-8")
    print("[OK] pubspec.yaml")

def patch_main():
    text = MAIN.read_text(encoding="utf-8")
    backup(MAIN)

    imp = "import 'services/runtime_v3/runtime_v3_service.dart';"
    if imp not in text:
        marker = "import 'repositories/repository.dart';"
        if marker not in text:
            raise RuntimeError("Repository import not found")
        text = text.replace(marker, marker + "\n" + imp, 1)

    init_call = "await RuntimeV3Service.instance.initializeIfEnabled();"
    parity_call = (
        "await RuntimeV3Service.instance.runParityAudit(Repository.instance);"
    )

    if init_call not in text:
        marker = "await Repository.instance.initialize();"
        if marker not in text:
            raise RuntimeError("Repository.initialize call not found")
        text = text.replace(
            marker,
            marker + "\n      " + init_call + "\n      " + parity_call,
            1,
        )
    elif parity_call not in text:
        text = text.replace(
            init_call,
            init_call + "\n      " + parity_call,
            1,
        )

    MAIN.write_text(text, encoding="utf-8")
    print("[OK] lib/main.dart")

def main():
    if not PUBSPEC.exists() or not MAIN.exists():
        raise SystemExit("[FAIL] Run from shared-xi project root.")

    patch_pubspec()
    patch_main()
    print("[DONE] Step 04.1 installed.")
    print("[INFO] SQLite default OFF; JSON gameplay unchanged.")
    print(
        "[TEST] flutter run "
        "--dart-define=LINKBALL_SQLITE_V3=true "
        "--dart-define=LINKBALL_SQLITE_PARITY=true"
    )

if __name__ == "__main__":
    main()
