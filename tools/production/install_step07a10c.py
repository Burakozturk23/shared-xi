from pathlib import Path
import shutil
import re

ROOT = Path(__file__).resolve().parents[2]
DBSERVICE = ROOT / "lib/services/database_service.dart"
PUBSPEC = ROOT / "pubspec.yaml"
DATA_DIR = ROOT / "assets/data"

EXCLUDED = {
    "assets/data/players.json",
    "assets/data/clubs.json",
}

def backup(path):
    bak = path.with_suffix(path.suffix + ".step07a10c.bak")
    if not bak.exists():
        shutil.copy2(path, bak)
        print("[BACKUP]", bak.relative_to(ROOT))
    else:
        print("[PASS] Backup exists:", bak.relative_to(ROOT))
    return bak

def write_lf(path, text):
    with path.open("w", encoding="utf-8", newline="\n") as f:
        f.write(text.replace("\r\n", "\n").replace("\r", "\n"))

def patch_database_service():
    text = DBSERVICE.read_text(encoding="utf-8", errors="replace")

    if "STEP 07A.10C: production runtime ships min JSON only." in text:
        print("[PASS] database_service.dart already patched")
        return

    # Remove the min/full selector method entirely.
    pattern = re.compile(
        r"\n\s*static Future<bool> _useMin\(\) async \{.*?\n\s*\}\n",
        re.S,
    )
    text, count = pattern.subn("\n", text, count=1)
    if count != 1:
        raise RuntimeError("_useMin() selector method not found exactly once")

    old_clubs = """  static Future<List<Club>> loadClubs() async {
    if (_clubsCache != null) return _clubsCache!;
    final preferMin = await _useMin();
    final path = preferMin
        ? 'assets/data/clubs_min.json'
        : 'assets/data/clubs.json';
    String raw;
    try {
      raw = await rootBundle.loadString(path);
    } catch (_) {
      raw = await rootBundle.loadString('assets/data/clubs_min.json');
    }
    _clubsCache = await compute(_parseClubs, raw);
    return _clubsCache!;
  }
"""

    new_clubs = """  static Future<List<Club>> loadClubs() async {
    if (_clubsCache != null) return _clubsCache!;

    // STEP 07A.10C: production runtime ships min JSON only.
    // Full clubs.json is intentionally excluded from APK/AAB.
    final raw = await rootBundle.loadString('assets/data/clubs_min.json');
    _clubsCache = await compute(_parseClubs, raw);
    return _clubsCache!;
  }
"""

    if old_clubs not in text:
        raise RuntimeError("loadClubs() expected block not found")
    text = text.replace(old_clubs, new_clubs, 1)

    old_players = """  static Future<List<Player>> loadPlayers() async {
    if (_playersCache != null) return _playersCache!;
    final preferMin = await _useMin();
    final path = preferMin
        ? 'assets/data/players_min.json'
        : 'assets/data/players.json';
    String raw;
    try {
      raw = await rootBundle.loadString(path);
    } catch (_) {
      raw = await rootBundle.loadString('assets/data/players_min.json');
    }
    _playersCache = await compute(_parsePlayers, raw);
    return _playersCache!;
  }
"""

    new_players = """  static Future<List<Player>> loadPlayers() async {
    if (_playersCache != null) return _playersCache!;

    // STEP 07A.10C: production runtime ships min JSON only.
    // Full players.json is intentionally excluded from APK/AAB.
    final raw = await rootBundle.loadString('assets/data/players_min.json');
    _playersCache = await compute(_parsePlayers, raw);
    return _playersCache!;
  }
"""

    if old_players not in text:
        raise RuntimeError("loadPlayers() expected block not found")
    text = text.replace(old_players, new_players, 1)

    write_lf(DBSERVICE, text)
    print("[FIX] DatabaseService now uses min JSON paths only.")

def collect_data_assets():
    if not DATA_DIR.exists():
        raise RuntimeError("assets/data directory missing")

    files = []
    excluded_found = []

    for path in sorted(DATA_DIR.rglob("*")):
        if not path.is_file():
            continue

        rel = path.relative_to(ROOT).as_posix()

        if rel in EXCLUDED:
            excluded_found.append(rel)
            continue

        files.append(rel)

    required = {
        "assets/data/meta.json",
        "assets/data/players_min.json",
        "assets/data/clubs_min.json",
    }

    missing = sorted(required - set(files))
    if missing:
        raise RuntimeError(
            "Required production data asset(s) missing: " + ", ".join(missing)
        )

    return files, excluded_found

def patch_pubspec():
    text = PUBSPEC.read_text(encoding="utf-8", errors="replace")

    if "# STEP 07A.10C: explicit production data assets" in text:
        print("[PASS] pubspec.yaml already patched")
        return

    files, excluded_found = collect_data_assets()

    if "    - assets/data/\n" not in text:
        raise RuntimeError("pubspec assets/data/ directory declaration not found")

    lines = [
        "    # STEP 07A.10C: explicit production data assets.",
        "    # Full players.json/clubs.json remain in repo but are excluded",
        "    # from APK/AAB to avoid shipping redundant full datasets.",
    ]
    lines.extend("    - " + rel for rel in files)

    replacement = "\n".join(lines) + "\n"
    text = text.replace("    - assets/data/\n", replacement, 1)

    write_lf(PUBSPEC, text)

    print(f"[FIX] Explicit production data assets: {len(files)}")
    for rel in sorted(excluded_found):
        path = ROOT / rel
        size = path.stat().st_size if path.exists() else 0
        print(
            f"[EXCLUDE] {rel} "
            f"({size / (1024*1024):.1f} MB local source retained)"
        )

def main():
    for path in [DBSERVICE, PUBSPEC]:
        if not path.exists():
            raise RuntimeError("Required file missing: " + str(path.relative_to(ROOT)))
        backup(path)

    patch_database_service()
    patch_pubspec()

    print()
    print("[OK] STEP 07A.10C source patch complete.")
    print("[SAFE] Full JSON files were NOT deleted from the repository.")
    print("[SAFE] Story/Player Journey source was not modified.")

if __name__ == "__main__":
    main()
