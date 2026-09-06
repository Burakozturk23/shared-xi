from pathlib import Path
import zipfile
import sys

ROOT = Path(__file__).resolve().parents[2]

ARTIFACTS = [
    ROOT / "build/app/outputs/flutter-apk/app-release.apk",
    ROOT / "build/app/outputs/bundle/release/app-release.aab",
]

FORBIDDEN_SUFFIXES = [
    "assets/flutter_assets/assets/data/players.json",
    "assets/flutter_assets/assets/data/clubs.json",
]

REQUIRED_SUFFIXES = [
    "assets/flutter_assets/assets/data/players_min.json",
    "assets/flutter_assets/assets/data/clubs_min.json",
    "assets/flutter_assets/assets/data/meta.json",
    "assets/flutter_assets/assets/runtime/linkball_runtime_v3.sqlite",
]

def fmt(n):
    return f"{n / (1024*1024):.1f} MB"

errors = []

print("=" * 66)
print("LINKBALL STEP 07A.10C - RELEASE ASSET VERIFY")
print("=" * 66)
print()

for artifact in ARTIFACTS:
    if not artifact.exists():
        errors.append("Missing artifact: " + str(artifact.relative_to(ROOT)))
        continue

    print(f"{artifact.relative_to(ROOT)}")
    print(f"  artifact size: {fmt(artifact.stat().st_size)}")

    with zipfile.ZipFile(artifact, "r") as zf:
        names = [x.filename.replace("\\", "/") for x in zf.infolist()]

        for suffix in FORBIDDEN_SUFFIXES:
            matches = [name for name in names if name.endswith(suffix)]
            if matches:
                errors.append(
                    f"{artifact.name} still contains forbidden {suffix}"
                )
            else:
                print(f"  [PASS] absent: {Path(suffix).name}")

        for suffix in REQUIRED_SUFFIXES:
            matches = [
                info for info in zf.infolist()
                if info.filename.replace("\\", "/").endswith(suffix)
            ]

            if not matches:
                errors.append(
                    f"{artifact.name} missing required {suffix}"
                )
            else:
                info = matches[0]
                print(
                    f"  [PASS] present: {Path(suffix).name} "
                    f"{fmt(info.file_size)}"
                )

    print()

if errors:
    print("[FAIL] Release asset verification")
    for error in errors:
        print("  -", error)
    raise SystemExit(1)

print("[PASS] Full players.json is absent from APK and AAB")
print("[PASS] Full clubs.json is absent from APK and AAB")
print("[PASS] Runtime V3 + min compatibility assets remain packaged")
print()
print("[OK] STEP 07A.10C RELEASE ASSET PASS")
