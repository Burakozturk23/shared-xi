from pathlib import Path
import json
import re
import zipfile

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/07a10a"
REPORT.mkdir(parents=True, exist_ok=True)

PUBSPEC = ROOT / "pubspec.yaml"
DBSERVICE = ROOT / "lib/services/database_service.dart"
META = ROOT / "assets/data/meta.json"
APK = ROOT / "build/app/outputs/flutter-apk/app-release.apk"

CANDIDATES = [
    "assets/data/players.json",
    "assets/data/players_min.json",
    "assets/data/clubs.json",
    "assets/data/clubs_min.json",
    "assets/data/coaches_min.json",
    "assets/data/famous_transfers.json",
    "assets/runtime/linkball_runtime_v3.sqlite",
]

def size_mb(n):
    return f"{n / (1024*1024):.1f} MB"

def find_source_refs(asset):
    refs = []
    lib = ROOT / "lib"
    if not lib.exists():
        return refs

    name = Path(asset).name

    for path in lib.rglob("*.dart"):
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue

        for i, line in enumerate(text.splitlines(), start=1):
            if asset in line or name in line:
                refs.append((str(path.relative_to(ROOT)), i, line.strip()))
    return refs

def pubspec_context():
    if not PUBSPEC.exists():
        return []
    lines = PUBSPEC.read_text(encoding="utf-8", errors="replace").splitlines()
    out = []
    for i, line in enumerate(lines, start=1):
        if "assets/" in line:
            out.append((i, line))
    return out

def meta_info():
    if not META.exists():
        return {"missing": True}
    try:
        data = json.loads(META.read_text(encoding="utf-8"))
    except Exception as e:
        return {"parse_error": str(e)}
    return data

def dbservice_context():
    if not DBSERVICE.exists():
        return []
    text = DBSERVICE.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()

    hits = []
    keys = [
        "_useMin",
        "players_min.json",
        "players.json",
        "clubs_min.json",
        "clubs.json",
    ]

    for i, line in enumerate(lines, start=1):
        if any(k in line for k in keys):
            start = max(1, i - 3)
            end = min(len(lines), i + 3)
            hits.append((start, end, lines[start-1:end]))
    return hits

def apk_entries():
    rows = {}
    if not APK.exists():
        return rows

    with zipfile.ZipFile(APK, "r") as zf:
        for info in zf.infolist():
            normalized = info.filename.replace("\\", "/")
            for asset in CANDIDATES:
                suffix = "assets/flutter_assets/" + asset
                if normalized.endswith(suffix):
                    rows[asset] = {
                        "apk_name": normalized,
                        "size": info.file_size,
                        "compressed": info.compress_size,
                        "stored": info.compress_type == 0,
                    }
    return rows

def main():
    print("=" * 64)
    print("LINKBALL STEP 07A.10A - RELEASE ASSET SLIMMING AUDIT")
    print("=" * 64)
    print()

    meta = meta_info()
    apk = apk_entries()

    print("Current data meta:")
    if meta.get("missing"):
        print("  [WARN] assets/data/meta.json missing")
    elif "parse_error" in meta:
        print("  [WARN] meta.json parse error:", meta["parse_error"])
    else:
        for key in sorted(meta):
            value = meta[key]
            if isinstance(value, (str, int, float, bool)) or value is None:
                print(f"  {key}: {value}")
    print()

    print("Candidate assets:")
    decisions = []

    for asset in CANDIDATES:
        path = ROOT / asset
        exists = path.exists()
        size = path.stat().st_size if exists else 0
        refs = find_source_refs(asset)
        apk_row = apk.get(asset)

        print(f"  {asset}")
        print(f"    local: {'YES' if exists else 'NO'}"
              + (f" ({size_mb(size)})" if exists else ""))
        print(f"    source refs: {len(refs)}")
        for rel, line, content in refs[:8]:
            print(f"      {rel}:{line}: {content}")

        if apk_row:
            print(
                f"    release APK: {size_mb(apk_row['size'])} -> "
                f"{size_mb(apk_row['compressed'])} "
                f"{'STORED' if apk_row['stored'] else 'DEFLATED'}"
            )
        else:
            print("    release APK: not found / APK missing")

        print()

    print("DatabaseService min/full selection context:")
    contexts = dbservice_context()
    for start, end, lines in contexts[:8]:
        print(f"  ---- L{start}-L{end} ----")
        for idx, line in enumerate(lines, start=start):
            print(f"  L{idx}: {line}")
    print()

    print("Pubspec asset declarations:")
    for line_no, line in pubspec_context():
        print(f"  L{line_no}: {line}")
    print()

    # Conservative automated recommendations.
    players_full_refs = find_source_refs("assets/data/players.json")
    players_min_refs = find_source_refs("assets/data/players_min.json")
    clubs_full_refs = find_source_refs("assets/data/clubs.json")
    clubs_min_refs = find_source_refs("assets/data/clubs_min.json")

    print("Automated recommendations:")

    # players.json is a candidate only if min path exists and there are no
    # app modes directly hardcoding the full asset outside DatabaseService.
    direct_players_full = [
        r for r in players_full_refs
        if "database_service.dart" not in r[0].replace("\\", "/")
    ]

    if (ROOT / "assets/data/players_min.json").exists() and not direct_players_full:
        print(
            "  [CANDIDATE] players.json can likely be removed from production "
            "after DatabaseService full/min fallback is made release-safe."
        )
    else:
        print(
            "  [HOLD] players.json still has direct consumers or players_min is missing."
        )

    direct_clubs_full = [
        r for r in clubs_full_refs
        if "database_service.dart" not in r[0].replace("\\", "/")
    ]
    if (ROOT / "assets/data/clubs_min.json").exists() and not direct_clubs_full:
        print(
            "  [CANDIDATE] clubs.json can likely be removed after the same "
            "release-safe min-path gate."
        )
    else:
        print("  [HOLD] clubs.json still has direct consumers or clubs_min is missing.")

    print(
        "  [KEEP] players_min.json remains required until Repository is fully "
        "bridged to Runtime V3."
    )
    print(
        "  [KEEP] Runtime V3 SQLite is the production gameplay database."
    )

    report = REPORT / "release_asset_audit.txt"
    report.write_text(
        "\n".join([
            "STEP 07A.10A completed.",
            f"players_json_exists={(ROOT/'assets/data/players.json').exists()}",
            f"players_min_exists={(ROOT/'assets/data/players_min.json').exists()}",
            f"clubs_json_exists={(ROOT/'assets/data/clubs.json').exists()}",
            f"clubs_min_exists={(ROOT/'assets/data/clubs_min.json').exists()}",
            f"players_json_direct_refs={len(direct_players_full)}",
            f"clubs_json_direct_refs={len(direct_clubs_full)}",
        ]) + "\n",
        encoding="utf-8",
        newline="\n",
    )

    print()
    print("[OK] STEP 07A.10A AUDIT COMPLETE")
    print("[INFO] Report: reports/production/07a10a/release_asset_audit.txt")

if __name__ == "__main__":
    main()
