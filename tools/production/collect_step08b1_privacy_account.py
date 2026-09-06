from pathlib import Path
import shutil
import zipfile
import re

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/08b1"
STAGE = REPORT / "snapshot"
OUTZIP = REPORT / "linkball_08b1_privacy_account_sources.zip"

EXCLUDED_NAMES = {
    "key.properties",
    "local.properties",
    "google-services.json",
    "firebase_options.dart",
}

BASE_FILES = [
    "pubspec.yaml",
    "firebase.json",
    "database.rules.json",
    "functions/index.js",
    "functions/package.json",
    "lib/main.dart",
    "lib/services/auth_service.dart",
]

SOURCE_PATTERNS = [
    re.compile(r"FirebaseAuth", re.I),
    re.compile(r"signIn", re.I),
    re.compile(r"signOut", re.I),
    re.compile(r"createUser", re.I),
    re.compile(r"deleteAccount", re.I),
    re.compile(r"\.delete\(", re.I),
    re.compile(r"currentUser", re.I),
    re.compile(r"users/", re.I),
    re.compile(r"dailyLeaderboard", re.I),
    re.compile(r"dailyScoreSessions", re.I),
    re.compile(r"matchmaking", re.I),
    re.compile(r"matches/", re.I),
    re.compile(r"rooms/", re.I),
    re.compile(r"gridMatches", re.I),
    re.compile(r"cinkoMatches", re.I),
    re.compile(r"fiveMatches", re.I),
    re.compile(r"privacy", re.I),
    re.compile(r"gizlilik", re.I),
    re.compile(r"ayar", re.I),
    re.compile(r"settings", re.I),
    re.compile(r"profile", re.I),
    re.compile(r"profil", re.I),
]

def safe_copy(rel):
    src = ROOT / rel
    if not src.exists() or not src.is_file():
        return False
    if src.name in EXCLUDED_NAMES:
        return False
    if "node_modules" in src.parts:
        return False
    dst = STAGE / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return True

def source_matches(path):
    if not path.exists() or not path.is_file():
        return False
    if path.name in EXCLUDED_NAMES:
        return False
    try:
        if path.stat().st_size > 2 * 1024 * 1024:
            return False
        text = path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return False
    return any(rx.search(text) for rx in SOURCE_PATTERNS)

def collect_user_data_paths():
    hits = []
    roots = [ROOT / "lib", ROOT / "functions"]
    patterns = [
        re.compile(r"""(?:ref|child)\(\s*['"]([^'"]+)['"]\s*\)"""),
        re.compile(r"""['"]((?:users|dailyLeaderboard|dailyScoreSessions|matchmaking|matches|rooms|gridMatches|cinkoMatches|fiveMatches)[^'"]*)['"]"""),
    ]

    for base in roots:
        if not base.exists():
            continue
        for path in base.rglob("*"):
            if not path.is_file() or "node_modules" in path.parts:
                continue
            if path.suffix not in {".dart", ".js"}:
                continue
            try:
                text = path.read_text(encoding="utf-8", errors="replace")
            except Exception:
                continue
            for i, line in enumerate(text.splitlines(), 1):
                for rx in patterns:
                    for match in rx.finditer(line):
                        value = match.group(1).strip()
                        if value:
                            hits.append(
                                (
                                    str(path.relative_to(ROOT)).replace("\\", "/"),
                                    i,
                                    value,
                                )
                            )
    return hits

def main():
    shutil.rmtree(STAGE, ignore_errors=True)
    STAGE.mkdir(parents=True, exist_ok=True)

    copied = []
    missing = []

    for rel in BASE_FILES:
        if safe_copy(rel):
            copied.append(rel)
        else:
            missing.append(rel)

    # Collect only source files relevant to auth/account/settings/user-data paths.
    lib = ROOT / "lib"
    if lib.exists():
        for path in lib.rglob("*.dart"):
            if source_matches(path):
                rel = str(path.relative_to(ROOT)).replace("\\", "/")
                if rel not in copied and safe_copy(rel):
                    copied.append(rel)

    paths = collect_user_data_paths()
    (STAGE / "USER_DATA_PATH_EVIDENCE.txt").write_text(
        "\n".join(
            f"{p}:{line}: {value}"
            for p, line, value in paths
        ) + ("\n" if paths else "(none)\n"),
        encoding="utf-8",
        newline="\n",
    )

    # Search for likely account/profile/settings screens by filename.
    screen_candidates = []
    for base_name in ["lib/screens", "lib/widgets", "lib/pages"]:
        base = ROOT / base_name
        if not base.exists():
            continue
        for path in base.rglob("*.dart"):
            low = path.name.lower()
            if any(
                token in low
                for token in [
                    "setting", "ayar", "profile", "profil",
                    "account", "hesap", "auth", "login",
                    "welcome", "home",
                ]
            ):
                rel = str(path.relative_to(ROOT)).replace("\\", "/")
                screen_candidates.append(rel)
                if rel not in copied and safe_copy(rel):
                    copied.append(rel)

    (STAGE / "SCREEN_CANDIDATES.txt").write_text(
        "\n".join(sorted(set(screen_candidates)))
        + ("\n" if screen_candidates else "(none)\n"),
        encoding="utf-8",
        newline="\n",
    )

    (STAGE / "SNAPSHOT_MANIFEST.txt").write_text(
        "\n".join([
            "LINKBALL STEP 08B.1 - PRIVACY / ACCOUNT DELETION SNAPSHOT",
            "",
            f"copied_files={len(copied)}",
            f"user_data_path_evidence={len(paths)}",
            "",
            "Included:",
            *["  + " + x for x in sorted(copied)],
            "",
            "Missing optional:",
            *["  - " + x for x in missing],
            "",
            "Explicitly excluded:",
            "  - android/key.properties",
            "  - android/local.properties",
            "  - google-services.json",
            "  - firebase_options.dart",
            "  - keystore files",
            "  - node_modules",
            "",
            "Purpose:",
            "  Design a safe account-deletion flow that removes:",
            "  - Firebase Auth account",
            "  - user-owned RTDB profile/state",
            "  - server session data where appropriate",
            "  while preserving shared/global game data and leaderboard integrity.",
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

    print("=" * 70)
    print("LINKBALL STEP 08B.1 - PRIVACY / ACCOUNT DELETION SNAPSHOT")
    print("=" * 70)
    print()
    print(f"[PASS] Relevant source files collected: {len(copied)}")
    print(f"[INFO] User-data path evidence lines: {len(paths)}")
    print("[SAFE] No project source was modified.")
    print("[SAFE] Signing/Firebase client config files were excluded.")
    print()
    print("[OUTPUT]")
    print(
        "  reports\\production\\08b1\\"
        "linkball_08b1_privacy_account_sources.zip"
    )
    print()
    print("[NEXT] Upload that ZIP here.")

if __name__ == "__main__":
    main()
