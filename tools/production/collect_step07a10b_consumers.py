from pathlib import Path
import shutil
import zipfile
import re

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/07a10b"
STAGE = REPORT / "snapshot"
OUTZIP = REPORT / "linkball_07a10b_full_json_consumers.zip"

TARGETS = [
    "assets/data/players.json",
    "assets/data/clubs.json",
]

BASENAMES = [
    "players.json",
    "clubs.json",
]

EXCLUDED_NAMES = {
    "firebase_options.dart",
    "google-services.json",
    "key.properties",
    "local.properties",
}

STATIC_FILES = [
    "lib/services/database_service.dart",
    "lib/repositories/repository.dart",
    "lib/services/runtime_v3/runtime_v3_flags.dart",
    "lib/services/runtime_v3/runtime_v3_service.dart",
    "lib/services/runtime_v3/runtime_v3_database.dart",
    "lib/screens/welcome_page.dart",
    "lib/main.dart",
    "pubspec.yaml",
    "assets/data/meta.json",
]

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

def source_matches():
    matches = []

    lib = ROOT / "lib"
    if not lib.exists():
        return matches

    for path in lib.rglob("*.dart"):
        if path.name in EXCLUDED_NAMES:
            continue

        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue

        lines = text.splitlines()

        for i, line in enumerate(lines, start=1):
            if any(target in line for target in TARGETS) or any(
                basename in line for basename in BASENAMES
            ):
                matches.append({
                    "file": str(path.relative_to(ROOT)).replace("\\", "/"),
                    "line": i,
                    "text": line.strip(),
                })

    return matches

def context_for_file(rel, hit_lines):
    path = ROOT / rel
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()

    ranges = []
    for hit in hit_lines:
        start = max(1, hit - 20)
        end = min(len(lines), hit + 20)
        ranges.append((start, end))

    # Merge overlapping ranges.
    ranges.sort()
    merged = []
    for start, end in ranges:
        if not merged or start > merged[-1][1] + 1:
            merged.append([start, end])
        else:
            merged[-1][1] = max(merged[-1][1], end)

    out = []
    for start, end in merged:
        out.append(f"---- {rel} L{start}-L{end} ----")
        for idx in range(start, end + 1):
            marker = ">>" if idx in hit_lines else "  "
            out.append(f"{marker} L{idx}: {lines[idx-1]}")
        out.append("")

    return "\n".join(out)

def classify(matches):
    by_file = {}
    for item in matches:
        by_file.setdefault(item["file"], []).append(item)

    rows = []

    for rel, items in sorted(by_file.items()):
        text = (ROOT / rel).read_text(encoding="utf-8", errors="replace")
        lower = text.lower()

        classification = "DIRECT_UNKNOWN"

        if "database_service.dart" in rel.replace("\\", "/"):
            classification = "DATABASE_SERVICE_FALLBACK"
        elif "rootbundle.loadstring" in lower:
            classification = "DIRECT_ASSET_LOAD"
        elif "rootbundle.load(" in lower:
            classification = "DIRECT_ASSET_LOAD"
        elif "assetbundle" in lower:
            classification = "DIRECT_ASSET_LOAD"
        elif "players.json" in lower or "clubs.json" in lower:
            classification = "DIRECT_LITERAL_REFERENCE"

        rows.append((rel, classification, items))

    return rows

def main():
    shutil.rmtree(STAGE, ignore_errors=True)
    STAGE.mkdir(parents=True, exist_ok=True)

    copied = []
    for rel in STATIC_FILES:
        if safe_copy(rel):
            copied.append(rel)

    matches = source_matches()
    classified = classify(matches)

    # Copy every actual consumer file.
    for rel, classification, items in classified:
        if rel not in copied and safe_copy(rel):
            copied.append(rel)

    # Produce exact line/context report.
    report_lines = [
        "=" * 72,
        "LINKBALL STEP 07A.10B - FULL JSON CONSUMER REPORT",
        "=" * 72,
        "",
        f"Total matching source lines: {len(matches)}",
        f"Consumer files: {len(classified)}",
        "",
    ]

    direct_players = []
    direct_clubs = []

    for rel, classification, items in classified:
        report_lines.append(f"FILE: {rel}")
        report_lines.append(f"CLASS: {classification}")

        for item in items:
            report_lines.append(
                f"  L{item['line']}: {item['text']}"
            )
            if "players.json" in item["text"]:
                direct_players.append((rel, classification, item))
            if "clubs.json" in item["text"]:
                direct_clubs.append((rel, classification, item))

        report_lines.append("")

        hit_lines = {x["line"] for x in items}
        report_lines.append(context_for_file(rel, hit_lines))

    report_lines.append("=" * 72)
    report_lines.append("SUMMARY")
    report_lines.append("=" * 72)
    report_lines.append(
        f"players.json matching lines: {len(direct_players)}"
    )
    report_lines.append(
        f"clubs.json matching lines: {len(direct_clubs)}"
    )
    report_lines.append("")

    report_lines.append("Non-DatabaseService players.json consumers:")
    non_db_players = [
        x for x in direct_players
        if x[1] != "DATABASE_SERVICE_FALLBACK"
    ]

    if non_db_players:
        for rel, cls, item in non_db_players:
            report_lines.append(
                f"  - {rel}:{item['line']} [{cls}] {item['text']}"
            )
    else:
        report_lines.append("  (none)")

    report_lines.append("")
    report_lines.append("Non-DatabaseService clubs.json consumers:")
    non_db_clubs = [
        x for x in direct_clubs
        if x[1] != "DATABASE_SERVICE_FALLBACK"
    ]

    if non_db_clubs:
        for rel, cls, item in non_db_clubs:
            report_lines.append(
                f"  - {rel}:{item['line']} [{cls}] {item['text']}"
            )
    else:
        report_lines.append("  (none)")

    report_lines.append("")
    report_lines.append("Decision guidance:")
    if non_db_players:
        report_lines.append(
            "  [HOLD] players.json cannot be removed yet. "
            "Direct consumers must be migrated first."
        )
    else:
        report_lines.append(
            "  [READY] No non-DatabaseService players.json consumer remains."
        )

    if non_db_clubs:
        report_lines.append(
            "  [HOLD] clubs.json has direct consumers."
        )
    else:
        report_lines.append(
            "  [READY] No non-DatabaseService clubs.json consumer remains."
        )

    report_path = STAGE / "FULL_JSON_CONSUMER_REPORT.txt"
    report_path.write_text(
        "\n".join(report_lines) + "\n",
        encoding="utf-8",
        newline="\n",
    )

    manifest = STAGE / "SNAPSHOT_MANIFEST.txt"
    manifest.write_text(
        "\n".join([
            "LINKBALL STEP 07A.10B - FULL JSON CONSUMER SNAPSHOT",
            "",
            f"Copied files: {len(set(copied))}",
            f"Consumer files: {len(classified)}",
            "",
            "Sensitive files excluded:",
            "  - firebase_options.dart",
            "  - google-services.json",
            "  - key.properties",
            "  - local.properties",
            "  - keystores/tokens/passwords",
            "",
            "Purpose:",
            "  Migrate remaining direct players.json/clubs.json consumers",
            "  before removing redundant full JSON assets from production.",
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

    print("=" * 64)
    print("LINKBALL STEP 07A.10B - FULL JSON CONSUMER SNAPSHOT")
    print("=" * 64)
    print()
    print(f"[PASS] Consumer files found: {len(classified)}")
    print(
        f"[INFO] Non-DatabaseService players.json refs: "
        f"{len(non_db_players)}"
    )
    print(
        f"[INFO] Non-DatabaseService clubs.json refs: "
        f"{len(non_db_clubs)}"
    )
    print()

    if non_db_players:
        print("players.json direct consumers:")
        for rel, cls, item in non_db_players:
            print(f"  {rel}:{item['line']} [{cls}]")
    else:
        print("[PASS] No direct players.json consumer outside DatabaseService.")

    print()
    if non_db_clubs:
        print("clubs.json direct consumers:")
        for rel, cls, item in non_db_clubs:
            print(f"  {rel}:{item['line']} [{cls}]")
    else:
        print("[PASS] No direct clubs.json consumer outside DatabaseService.")

    print()
    print("[SAFE] No project source was modified.")
    print("[SAFE] Full JSON assets were NOT deleted.")
    print()
    print("[OUTPUT]")
    print(
        "  reports\\production\\07a10b\\"
        "linkball_07a10b_full_json_consumers.zip"
    )
    print()
    print("[NEXT] Upload that ZIP here.")

if __name__ == "__main__":
    main()
