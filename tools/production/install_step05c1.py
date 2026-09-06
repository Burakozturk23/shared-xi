from __future__ import annotations

from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "lib/main.dart"
PUBSPEC = ROOT / "pubspec.yaml"

APP_CHECK_IMPORT = (
    "import 'package:firebase_app_check/firebase_app_check.dart';"
)
FOUNDATION_IMPORT = "import 'package:flutter/foundation.dart';"

BLOCK = """  // STEP 05C.1: Android App Check.
  // Debug builds use the Firebase debug provider so local development remains usable.
  // Release builds use Play Integrity.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kReleaseMode
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
    );
  }
"""

def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step05c1.bak")
    if path.exists() and not bak.exists():
        shutil.copy2(path, bak)

def write_lf(path: Path, text: str) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(text.replace("\r\n", "\n").replace("\r", "\n"))

def insert_import(text: str, import_line: str, after: str) -> str:
    if import_line in text:
        return text
    if after in text:
        return text.replace(
            after,
            after + "\n" + import_line,
            1,
        )
    raise RuntimeError(
        f"Import anchor not found for: {import_line}"
    )

def find_firebase_init_end(text: str) -> int:
    start = text.find("await Firebase.initializeApp(")
    if start < 0:
        raise RuntimeError(
            "Firebase.initializeApp() call not found in lib/main.dart"
        )

    # Find the first statement terminator after the Firebase initialize call.
    end = text.find(");", start)
    if end < 0:
        raise RuntimeError(
            "Firebase.initializeApp() closing ');' not found"
        )
    return end + 2

def main() -> None:
    if not MAIN.exists():
        raise RuntimeError("lib/main.dart missing")
    if not PUBSPEC.exists():
        raise RuntimeError("pubspec.yaml missing")

    text = MAIN.read_text(
        encoding="utf-8",
        errors="replace",
    )

    if "STEP 05C.1: Android App Check." in text:
        print("[PASS] 05C.1 main.dart patch already present.")
        return

    backup(MAIN)

    text = insert_import(
        text,
        FOUNDATION_IMPORT,
        "import 'package:flutter/material.dart';",
    )
    text = insert_import(
        text,
        APP_CHECK_IMPORT,
        "import 'package:firebase_core/firebase_core.dart';",
    )

    end = find_firebase_init_end(text)

    text = (
        text[:end]
        + "\n"
        + BLOCK
        + text[end:]
    )

    write_lf(MAIN, text)

    print("[FIX] firebase_app_check import added.")
    print("[FIX] Android debug provider configured for non-release builds.")
    print("[FIX] Android Play Integrity configured for release builds.")
    print("[SAFE] No Firebase enforcement was enabled.")

if __name__ == "__main__":
    main()
