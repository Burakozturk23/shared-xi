from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
DBSERVICE = ROOT / "lib/services/database_service.dart"
PUBSPEC = ROOT / "pubspec.yaml"

errors = []

db = DBSERVICE.read_text(encoding="utf-8", errors="replace")
pub = PUBSPEC.read_text(encoding="utf-8", errors="replace")

for forbidden in [
    "'assets/data/players.json'",
    "'assets/data/clubs.json'",
    "static Future<bool> _useMin()",
]:
    if forbidden in db:
        errors.append("DatabaseService still contains: " + forbidden)

for required in [
    "'assets/data/players_min.json'",
    "'assets/data/clubs_min.json'",
    "STEP 07A.10C: production runtime ships min JSON only.",
]:
    if required not in db:
        errors.append("DatabaseService missing: " + required)

if "    - assets/data/\n" in pub:
    errors.append("pubspec still includes the entire assets/data directory")

for forbidden in [
    "    - assets/data/players.json",
    "    - assets/data/clubs.json",
]:
    if forbidden in pub:
        errors.append("pubspec still packages: " + forbidden.strip())

for required in [
    "    - assets/data/players_min.json",
    "    - assets/data/clubs_min.json",
    "    - assets/data/meta.json",
]:
    if required not in pub:
        errors.append("pubspec missing required production asset: " + required.strip())

# Runtime source references: comments are ignored.
runtime_refs = []
for path in (ROOT / "lib").rglob("*.dart"):
    text = path.read_text(encoding="utf-8", errors="replace")
    for i, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if stripped.startswith("//"):
            continue
        if "players.json" in line or "clubs.json" in line:
            runtime_refs.append(f"{path.relative_to(ROOT)}:{i}: {stripped}")

if runtime_refs:
    errors.append(
        "Non-comment full JSON source references remain: "
        + " | ".join(runtime_refs[:8])
    )

if errors:
    print("[FAIL] STEP 07A.10C source verification")
    for error in errors:
        print("  -", error)
    raise SystemExit(1)

print("[PASS] DatabaseService no longer references full JSON assets")
print("[PASS] pubspec excludes players.json and clubs.json")
print("[PASS] players_min.json / clubs_min.json / meta.json are packaged")
print("[PASS] No non-comment Dart references to full JSON remain")
