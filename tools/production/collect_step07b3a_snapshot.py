from pathlib import Path
import shutil
import zipfile
import json

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/07b3a"
STAGE = REPORT / "snapshot"
OUTZIP = REPORT / "linkball_07b3a_release_test_sources.zip"

FILES = [
    ".github/workflows/linkball-ci.yml",
    "pubspec.yaml",
    "analysis_options.yaml",

    "android/app/build.gradle",
    "android/app/build.gradle.kts",
    "android/build.gradle",
    "android/build.gradle.kts",
    "android/settings.gradle",
    "android/settings.gradle.kts",
    "android/gradle.properties",
    "android/app/src/main/AndroidManifest.xml",

    "functions/package.json",
    "functions/index.js",

    "test/widget_test.dart",
]

EXCLUDED_NAMES = {
    "key.properties",
    "local.properties",
    "google-services.json",
    "firebase_options.dart",
}

def safe_copy(rel):
    src = ROOT / rel
    if not src.exists() or not src.is_file():
        return False

    if src.name in EXCLUDED_NAMES:
        return False

    dst = STAGE / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return True

def signing_summary():
    candidates = [
        ROOT / "android/app/build.gradle",
        ROOT / "android/app/build.gradle.kts",
    ]

    out = [
        "LINKBALL STEP 07B.3A - SIGNING SUMMARY",
        "",
    ]

    for path in candidates:
        if not path.exists():
            continue

        text = path.read_text(encoding="utf-8", errors="replace")
        out.append("FILE: " + str(path.relative_to(ROOT)).replace("\\", "/"))

        keys = [
            "signingConfigs",
            "signingConfig",
            "key.properties",
            "storeFile",
            "storePassword",
            "keyAlias",
            "keyPassword",
            "applicationId",
            "namespace",
            "compileSdk",
            "targetSdk",
        ]

        for i, line in enumerate(text.splitlines(), 1):
            if any(key in line for key in keys):
                # Never echo literal password-looking assignment values.
                clean = line
                for secret_key in ["storePassword", "keyPassword"]:
                    if secret_key in clean and "=" in clean:
                        lhs = clean.split("=", 1)[0]
                        clean = lhs + "= <REDACTED_OR_CONFIG_REFERENCE>"
                out.append(f"  L{i}: {clean.strip()}")

        out.append("")

    key_props = ROOT / "android/key.properties"
    out.append(
        "android/key.properties exists: "
        + ("YES" if key_props.exists() else "NO")
    )
    out.append("Its contents are intentionally NOT included.")
    out.append("")

    return "\n".join(out)

def functions_summary():
    pkg = ROOT / "functions/package.json"
    out = [
        "LINKBALL STEP 07B.3A - FUNCTIONS SUMMARY",
        "",
    ]

    if not pkg.exists():
        out.append("functions/package.json missing")
        return "\n".join(out)

    try:
        data = json.loads(pkg.read_text(encoding="utf-8"))
    except Exception as exc:
        out.append("package.json parse error: " + str(exc))
        return "\n".join(out)

    out.append("scripts:")
    for key, value in sorted((data.get("scripts") or {}).items()):
        out.append(f"  {key}: {value}")

    out.append("")
    out.append("dependencies of interest:")
    deps = {}
    deps.update(data.get("dependencies") or {})
    deps.update(data.get("devDependencies") or {})

    for key in sorted(deps):
        if (
            "firebase" in key.lower()
            or "jest" in key.lower()
            or "mocha" in key.lower()
            or "eslint" in key.lower()
            or "test" in key.lower()
        ):
            out.append(f"  {key}: {deps[key]}")

    return "\n".join(out)

def test_summary():
    tests = []
    for folder in ["test", "integration_test"]:
        base = ROOT / folder
        if not base.exists():
            continue
        for p in base.rglob("*.dart"):
            tests.append(str(p.relative_to(ROOT)).replace("\\", "/"))

    out = [
        "LINKBALL STEP 07B.3A - TEST SURFACE",
        "",
        f"dart_test_files={len(tests)}",
        *["  - " + x for x in sorted(tests)],
    ]
    return "\n".join(out)

def main():
    shutil.rmtree(STAGE, ignore_errors=True)
    STAGE.mkdir(parents=True, exist_ok=True)

    copied = []
    missing = []

    for rel in FILES:
        if safe_copy(rel):
            copied.append(rel)
        else:
            missing.append(rel)

    # Copy all current unit/widget tests, but no generated reports.
    test_dir = ROOT / "test"
    if test_dir.exists():
        for p in test_dir.rglob("*.dart"):
            rel = str(p.relative_to(ROOT)).replace("\\", "/")
            if rel not in copied and safe_copy(rel):
                copied.append(rel)

    (STAGE / "SIGNING_SUMMARY.txt").write_text(
        signing_summary() + "\n",
        encoding="utf-8",
        newline="\n",
    )
    (STAGE / "FUNCTIONS_SUMMARY.txt").write_text(
        functions_summary() + "\n",
        encoding="utf-8",
        newline="\n",
    )
    (STAGE / "TEST_SURFACE.txt").write_text(
        test_summary() + "\n",
        encoding="utf-8",
        newline="\n",
    )

    (STAGE / "SNAPSHOT_MANIFEST.txt").write_text(
        "\n".join([
            "LINKBALL STEP 07B.3A - RELEASE / TEST SNAPSHOT",
            "",
            f"copied_files={len(copied)}",
            "",
            "Included:",
            *["  + " + x for x in sorted(copied)],
            "",
            "Missing optional:",
            *["  - " + x for x in missing],
            "",
            "Explicitly excluded:",
            "  - android/key.properties contents",
            "  - android/local.properties",
            "  - google-services.json",
            "  - firebase_options.dart",
            "  - keystore files",
            "  - passwords / signing secrets",
            "",
            "Purpose:",
            "  Prepare STEP 07B.3:",
            "  - signed release AAB CI gate",
            "  - integration_test baseline",
            "  - Functions test script",
        ]) + "\n",
        encoding="utf-8",
        newline="\n",
    )

    if OUTZIP.exists():
        OUTZIP.unlink()

    with zipfile.ZipFile(
        OUTZIP,
        "w",
        zipfile.ZIP_DEFLATED,
        compresslevel=9,
    ) as z:
        for p in STAGE.rglob("*"):
            if p.is_file():
                z.write(p, p.relative_to(STAGE))

    print("=" * 66)
    print("LINKBALL STEP 07B.3A - RELEASE / TEST SNAPSHOT")
    print("=" * 66)
    print()
    print(f"[PASS] Files collected: {len(copied)}")
    print("[SAFE] Signing passwords/keystore contents were NOT collected.")
    print("[SAFE] Firebase config secrets were NOT collected.")
    print("[SAFE] No project source was modified.")
    print()
    print("[OUTPUT]")
    print(
        "  reports\\production\\07b3a\\"
        "linkball_07b3a_release_test_sources.zip"
    )
    print()
    print("[NEXT] Upload that ZIP here.")

if __name__ == "__main__":
    main()
