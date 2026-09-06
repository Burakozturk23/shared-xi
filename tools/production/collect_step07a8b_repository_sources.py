from pathlib import Path
import shutil
import sqlite3
import zipfile

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/07a8b"
STAGE = REPORT / "snapshot"
OUTZIP = REPORT / "linkball_07a8b_repository_v3_sources.zip"

EXCLUDED = {
    "firebase_options.dart",
    "google-services.json",
    "key.properties",
    "local.properties",
}

STATIC = [
    "lib/models/player.dart",
    "lib/models/club.dart",
    "lib/models/coach.dart",
    "lib/models/famous_transfer.dart",
    "lib/screens/welcome_page.dart",
    "lib/services/search_service.dart",
    "lib/repositories/repository.dart",
    "lib/services/database_service.dart",
    "lib/services/runtime_v3/runtime_v3_database.dart",
    "lib/services/runtime_v3/runtime_v3_platform_base.dart",
    "lib/services/runtime_v3/runtime_v3_platform_io.dart",
    "lib/services/runtime_v3/runtime_v3_service.dart",
    "lib/services/runtime_v3/runtime_v3_flags.dart",
    "lib/services/runtime_v3/hybrid_gameplay_data_service.dart",
    "lib/main.dart",
    "pubspec.yaml",
]

REPO_TERMS = [
    "Repository.instance.players",
    "Repository.instance.playerById",
    "Repository.instance.clubs",
    "Repository.instance.clubById",
    "Repository.instance.coaches",
    "Repository.instance.famousTransfers",
    "Repository.instance.playerCount",
    "Repository.instance.clubCount",
    "Repository.instance.countries",
    "Repository.instance.initialize",
]

def safe_copy(rel):
    src = ROOT / rel
    if not src.exists() or not src.is_file():
        return False
    if src.name in EXCLUDED:
        return False
    dst = STAGE / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return True

def sqlite_report():
    db = ROOT / "assets/runtime/linkball_runtime_v3.sqlite"
    out = STAGE / "RUNTIME_V3_SCHEMA.txt"

    if not db.exists():
        out.write_text(
            "Runtime V3 SQLite asset not found.\n",
            encoding="utf-8",
            newline="\n",
        )
        return

    con = sqlite3.connect(f"file:{db.as_posix()}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row

    tables = [
        "players",
        "profiles",
        "player_stats",
        "clubs",
        "player_clubs",
        "metadata",
    ]

    lines = [
        "LINKBALL STEP 07A.8B - RUNTIME V3 SCHEMA",
        "",
    ]

    for table in tables:
        lines.append("=" * 72)
        lines.append(f"TABLE: {table}")
        lines.append("=" * 72)

        try:
            cols = con.execute(f"PRAGMA table_info({table})").fetchall()
        except sqlite3.Error as e:
            lines.append("ERROR: " + str(e))
            lines.append("")
            continue

        lines.append("Columns:")
        for row in cols:
            lines.append(
                f"  {row['cid']:>2} | {row['name']} | "
                f"{row['type']} | notnull={row['notnull']} | "
                f"pk={row['pk']}"
            )

        lines.append("")
        lines.append("Sample rows (max 3):")

        try:
            rows = con.execute(f"SELECT * FROM {table} LIMIT 3").fetchall()
            for idx, row in enumerate(rows, 1):
                lines.append(f"  Row {idx}:")
                for key in row.keys():
                    value = row[key]
                    # Keep report compact and avoid huge blobs.
                    if isinstance(value, (bytes, bytearray)):
                        value = f"<{len(value)} bytes>"
                    text = repr(value)
                    if len(text) > 240:
                        text = text[:237] + "..."
                    lines.append(f"    {key} = {text}")
        except sqlite3.Error as e:
            lines.append("  ERROR: " + str(e))

        lines.append("")

    # Useful joined sample for model mapping.
    lines.append("=" * 72)
    lines.append("JOINED PLAYER SAMPLE")
    lines.append("=" * 72)

    query = """
    SELECT
      p.*,
      pr.birth_year,
      pr.citizenship,
      pr.position_group,
      pr.detailed_position,
      pr.foot,
      pr.height_cm,
      pr.international_caps,
      pr.international_goals,
      ps.appearances,
      ps.goals,
      ps.assists,
      ps.minutes,
      ps.coverage_first_year,
      ps.coverage_last_year
    FROM players p
    LEFT JOIN profiles pr ON pr.player_id = p.id
    LEFT JOIN player_stats ps ON ps.player_id = p.id
    WHERE p.is_shadow = 0
    ORDER BY
      CASE WHEN p.selection_rank IS NULL THEN 1 ELSE 0 END,
      p.selection_rank,
      p.id
    LIMIT 5
    """

    try:
        rows = con.execute(query).fetchall()
        for idx, row in enumerate(rows, 1):
            lines.append(f"Player {idx}:")
            for key in row.keys():
                lines.append(f"  {key} = {repr(row[key])}")
            lines.append("")
    except sqlite3.Error as e:
        lines.append("ERROR: " + str(e))

    con.close()
    out.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")

def main():
    shutil.rmtree(STAGE, ignore_errors=True)
    STAGE.mkdir(parents=True, exist_ok=True)

    copied = []
    missing = []

    for rel in STATIC:
        if safe_copy(rel):
            copied.append(rel)
        else:
            missing.append(rel)

    # Find all direct Repository consumers and include those Dart source files.
    consumers = []
    lib = ROOT / "lib"

    if lib.exists():
        for path in lib.rglob("*.dart"):
            if path.name in EXCLUDED:
                continue

            try:
                text = path.read_text(encoding="utf-8", errors="replace")
            except Exception:
                continue

            hits = [term for term in REPO_TERMS if term in text]
            if not hits:
                continue

            rel = str(path.relative_to(ROOT)).replace("\\", "/")
            consumers.append((rel, hits))

            if rel not in copied:
                if safe_copy(rel):
                    copied.append(rel)

    calls = STAGE / "REPOSITORY_CONSUMERS.txt"
    lines = [
        "LINKBALL STEP 07A.8B - REPOSITORY CONSUMERS",
        "",
    ]
    for rel, hits in sorted(consumers):
        lines.append(rel)
        for hit in hits:
            lines.append("  - " + hit)

    calls.write_text(
        "\n".join(lines) + "\n",
        encoding="utf-8",
        newline="\n",
    )

    sqlite_report()

    manifest = STAGE / "SNAPSHOT_MANIFEST.txt"
    manifest.write_text(
        "\n".join([
            "LINKBALL STEP 07A.8B - REPOSITORY V3 SNAPSHOT",
            "",
            f"Copied source files: {len(set(copied))}",
            f"Repository consumer files: {len(consumers)}",
            "",
            "Missing optional files:",
            *["  - " + x for x in missing],
            "",
            "Sensitive files explicitly excluded:",
            "  - firebase_options.dart",
            "  - google-services.json",
            "  - key.properties",
            "  - local.properties",
            "  - keystores/passwords/tokens",
            "",
            "SQLite binary is NOT copied.",
            "Only table schema + tiny sample rows are included.",
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

    print("=" * 58)
    print("LINKBALL STEP 07A.8B - REPOSITORY V3 SNAPSHOT")
    print("=" * 58)
    print()
    print(f"[PASS] Source files collected: {len(set(copied))}")
    print(f"[PASS] Repository consumers found: {len(consumers)}")
    print("[PASS] Runtime V3 schema report generated")
    print()
    print("[SAFE] SQLite binary itself was NOT included.")
    print("[SAFE] Firebase/signing secrets were excluded.")
    print("[SAFE] Project source was not modified.")
    print()
    print("[OUTPUT]")
    print("  reports\\production\\07a8b\\linkball_07a8b_repository_v3_sources.zip")
    print()
    print("[NEXT] Upload that ZIP here.")

if __name__ == "__main__":
    main()
