from pathlib import Path
import shutil
import zipfile
import re

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/07a8a"
STAGE = REPORT / "snapshot"
ZIP = REPORT / "linkball_07a8a_startup_sources.zip"

STATIC_FILES = [
    "lib/main.dart",
    "lib/repositories/repository.dart",
    "lib/services/database_service.dart",
    "lib/services/runtime_v3/runtime_v3_service.dart",
    "lib/services/runtime_v3/runtime_v3_database.dart",
    "lib/services/runtime_v3/runtime_v3_platform_io.dart",
    "lib/services/runtime_v3/runtime_v3_flags.dart",
    "lib/services/runtime_v3/hybrid_gameplay_data_service.dart",
    "pubspec.yaml",
]

SEARCH_TERMS = [
    "Repository.initialize",
    ".initialize()",
    "initializeIfEnabled",
    "DatabaseService.loadPlayers",
    "DatabaseService.loadClubs",
    "loadPlayers(",
    "loadClubs(",
    "Oyuncu ve kulüp verisi",
    "Oyuncu ve kulup verisi",
    "RuntimeV3Service.instance",
]

EXCLUDED_BASENAMES = {
    "firebase_options.dart",
    "google-services.json",
    "key.properties",
    "local.properties",
}

def safe_copy(rel: str):
    src = ROOT / rel
    if not src.exists() or not src.is_file():
        return False
    if src.name in EXCLUDED_BASENAMES:
        return False
    dst = STAGE / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return True

def main():
    shutil.rmtree(STAGE, ignore_errors=True)
    REPORT.mkdir(parents=True, exist_ok=True)
    STAGE.mkdir(parents=True, exist_ok=True)

    copied = []
    missing = []

    for rel in STATIC_FILES:
        if safe_copy(rel):
            copied.append(rel)
        else:
            missing.append(rel)

    # Search Dart callsites related to startup/loading and copy only those files.
    callsites = []
    lib = ROOT / "lib"
    if lib.exists():
        for path in lib.rglob("*.dart"):
            if path.name in EXCLUDED_BASENAMES:
                continue
            try:
                text = path.read_text(encoding="utf-8", errors="replace")
            except Exception:
                continue

            hits = []
            for term in SEARCH_TERMS:
                if term in text:
                    hits.append(term)

            if not hits:
                continue

            rel = str(path.relative_to(ROOT)).replace("\\", "/")
            callsites.append((rel, hits))

            # Include startup-related files, but avoid ballooning the snapshot.
            if rel not in copied and (
                "main" in rel.lower()
                or "splash" in rel.lower()
                or "loading" in rel.lower()
                or "startup" in rel.lower()
                or "repository" in rel.lower()
                or "database" in rel.lower()
                or "runtime_v3" in rel.lower()
                or "app" in rel.lower()
            ):
                if safe_copy(rel):
                    copied.append(rel)

    callsite_report = STAGE / "CALLSITES.txt"
    lines = []
    lines.append("LINKBALL STEP 07A.8A - STARTUP CALLSITES")
    lines.append("")
    for rel, hits in sorted(callsites):
        lines.append(rel)
        for hit in hits:
            lines.append("  - " + hit)
    callsite_report.write_text(
        "\n".join(lines) + "\n",
        encoding="utf-8",
        newline="\n",
    )

    # Include the existing measured reports if present.
    for rel in [
        "reports/production/07a6/runtime_bootstrap_forensics.txt",
        "reports/production/07a71/startup_phase_summary.txt",
        "reports/production/07a5/v3_release_summary.txt",
        "reports/production/07a4/startup_summary.txt",
    ]:
        if safe_copy(rel):
            copied.append(rel)

    # Explicit manifest of what was/wasn't included.
    manifest = STAGE / "SNAPSHOT_MANIFEST.txt"
    manifest.write_text(
        "\n".join([
            "LINKBALL STEP 07A.8A - STARTUP SOURCE SNAPSHOT",
            "",
            "Included project files:",
            *["  + " + x for x in sorted(set(copied))],
            "",
            "Missing optional files:",
            *["  - " + x for x in missing],
            "",
            "Explicit exclusions:",
            "  - lib/firebase_options.dart",
            "  - android/app/google-services.json",
            "  - android/key.properties",
            "  - android/local.properties",
            "  - keystores / passwords / tokens",
            "",
            "Purpose:",
            "  Determine how to skip/lazy-load legacy players JSON when Runtime V3 gameplay is active.",
        ]) + "\n",
        encoding="utf-8",
        newline="\n",
    )

    if ZIP.exists():
        ZIP.unlink()

    with zipfile.ZipFile(ZIP, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for p in STAGE.rglob("*"):
            if p.is_file():
                z.write(p, p.relative_to(STAGE))

    print("==========================================================")
    print("LINKBALL STEP 07A.8A - STARTUP SOURCE SNAPSHOT")
    print("==========================================================")
    print()
    print(f"[PASS] Source files collected: {len(set(copied))}")
    print(f"[INFO] Startup callsite files found: {len(callsites)}")
    print()
    print("[SAFE] Sensitive Firebase/signing files were excluded.")
    print("[SAFE] No project source was modified.")
    print()
    print("[OUTPUT]")
    print("  reports\\production\\07a8a\\linkball_07a8a_startup_sources.zip")
    print()
    print("[NEXT] Upload that ZIP to ChatGPT.")

if __name__ == "__main__":
    main()
