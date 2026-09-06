from pathlib import Path
import shutil
import zipfile
import subprocess

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/07b21"
STAGE = REPORT / "snapshot"
OUTZIP = REPORT / "linkball_07b21_widget_test_sources.zip"

FILES = [
    "test/widget_test.dart",
    "lib/main.dart",
    "lib/screens/welcome_page.dart",
    "lib/repositories/repository.dart",
    "lib/services/database_service.dart",
    "lib/services/runtime_v3/runtime_v3_service.dart",
    "lib/services/runtime_v3/runtime_v3_flags.dart",
    "lib/services/auth_service.dart",
    "pubspec.yaml",
]

EXCLUDED = {
    "firebase_options.dart",
    "google-services.json",
    "key.properties",
    "local.properties",
}

def copy(rel):
    src = ROOT / rel
    if not src.exists() or not src.is_file():
        return False
    if src.name in EXCLUDED:
        return False
    dst = STAGE / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return True

def main():
    shutil.rmtree(STAGE, ignore_errors=True)
    STAGE.mkdir(parents=True, exist_ok=True)

    copied, missing = [], []
    for rel in FILES:
        if copy(rel):
            copied.append(rel)
        else:
            missing.append(rel)

    # Include all current tests; they are small and important for CI baseline.
    test_dir = ROOT / "test"
    if test_dir.exists():
        for path in test_dir.rglob("*.dart"):
            rel = str(path.relative_to(ROOT)).replace("\\", "/")
            if rel not in copied and copy(rel):
                copied.append(rel)

    # Capture the exact current test failure in a text file.
    try:
        result = subprocess.run(
            ["flutter", "test", "--reporter", "expanded"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=180,
        )
        failure = (result.stdout or "") + (result.stderr or "")
        rc = result.returncode
    except Exception as exc:
        failure = f"Could not run flutter test: {exc}\n"
        rc = 999

    (STAGE / "CURRENT_FLUTTER_TEST_OUTPUT.txt").write_text(
        failure,
        encoding="utf-8",
        newline="\n",
    )

    (STAGE / "SNAPSHOT_MANIFEST.txt").write_text(
        "\n".join([
            "LINKBALL STEP 07B.2.1 - WIDGET TEST SNAPSHOT",
            "",
            f"flutter_test_returncode={rc}",
            f"copied_files={len(copied)}",
            "",
            "Included:",
            *["  + " + x for x in sorted(copied)],
            "",
            "Missing optional:",
            *["  - " + x for x in missing],
            "",
            "Sensitive Firebase/signing files excluded.",
            "No project source was modified.",
        ]) + "\n",
        encoding="utf-8",
        newline="\n",
    )

    if OUTZIP.exists():
        OUTZIP.unlink()

    with zipfile.ZipFile(OUTZIP, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for p in STAGE.rglob("*"):
            if p.is_file():
                z.write(p, p.relative_to(STAGE))

    print("=" * 64)
    print("LINKBALL STEP 07B.2.1 - WIDGET TEST SNAPSHOT")
    print("=" * 64)
    print()
    print(f"[PASS] Source/test files collected: {len(copied)}")
    print(f"[INFO] Current flutter test return code: {rc}")
    print("[SAFE] No project source was modified.")
    print("[SAFE] Firebase/signing secrets were excluded.")
    print()
    print("[OUTPUT]")
    print(
        "  reports\\production\\07b21\\"
        "linkball_07b21_widget_test_sources.zip"
    )
    print()
    print("[NEXT] Upload that ZIP here.")

if __name__ == "__main__":
    main()
