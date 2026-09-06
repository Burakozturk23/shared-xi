from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/07b346"
REPORT.mkdir(parents=True, exist_ok=True)

SAFE_PREFIXES = (
    ".github/workflows/",
    "android/",
    "assets/runtime/",
    "functions/",
    "integration_test/",
    "lib/",
    "test/",
)

SAFE_EXACT = {
    ".gitignore",
    "pubspec.yaml",
    "pubspec.lock",
    "firebase.json",
    "database.rules.json",
}

EXCLUDE_PREFIXES = (
    "reports/",
    "build/",
    ".dart_tool/",
    "node_modules/",
    "functions/node_modules/",
    "tools/production/",
)

EXCLUDE_SUFFIXES = (
    ".bak",
    ".log",
    ".tmp",
)

SENSITIVE_EXACT = {
    "android/key.properties",
    "android/local.properties",
}

SENSITIVE_EXTS = {
    ".jks",
    ".keystore",
    ".p12",
    ".pfx",
    ".pem",
    ".key",
}

def git(args, check=True):
    r = subprocess.run(
        ["git", *args],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if check and r.returncode != 0:
        raise RuntimeError(
            "git " + " ".join(args) + " failed:\n" + (r.stderr or r.stdout)
        )
    return r

def norm(x):
    return x.replace("\\", "/").lstrip("./")

def changed_files():
    files = set()

    for args in [
        ["diff", "--cached", "--name-only", "--diff-filter=ACMR"],
        ["diff", "--name-only", "--diff-filter=ACMR"],
        ["ls-files", "--others", "--exclude-standard"],
    ]:
        r = git(args)
        files.update(
            norm(x.strip())
            for x in r.stdout.splitlines()
            if x.strip()
        )

    return sorted(files)

def is_sensitive(rel):
    if rel.lower() in SENSITIVE_EXACT:
        return True
    if Path(rel).suffix.lower() in SENSITIVE_EXTS:
        return True
    return False

def is_excluded(rel):
    if rel.startswith(EXCLUDE_PREFIXES):
        return True
    if rel.endswith(EXCLUDE_SUFFIXES):
        return True
    return False

def is_safe_candidate(rel):
    if rel in SAFE_EXACT:
        return True
    if rel.startswith(SAFE_PREFIXES):
        return True
    return False

def main():
    files = changed_files()

    safe = []
    excluded = []
    review = []
    blocked = []

    for rel in files:
        if is_sensitive(rel):
            blocked.append(rel)
        elif is_excluded(rel):
            excluded.append(rel)
        elif is_safe_candidate(rel):
            safe.append(rel)
        else:
            review.append(rel)

    (REPORT / "safe_commit_candidates.txt").write_text(
        "\n".join(safe) + ("\n" if safe else "(none)\n"),
        encoding="utf-8",
    )
    (REPORT / "excluded_local_generated.txt").write_text(
        "\n".join(excluded) + ("\n" if excluded else "(none)\n"),
        encoding="utf-8",
    )
    (REPORT / "manual_review.txt").write_text(
        "\n".join(review) + ("\n" if review else "(none)\n"),
        encoding="utf-8",
    )
    (REPORT / "blocked_sensitive.txt").write_text(
        "\n".join(blocked) + ("\n" if blocked else "(none)\n"),
        encoding="utf-8",
    )

    print("=" * 68)
    print("LINKBALL STEP 07B.3.4.6 - SAFE COMMIT MANIFEST")
    print("=" * 68)
    print()
    print(f"Changed files        : {len(files)}")
    print(f"Safe candidates      : {len(safe)}")
    print(f"Excluded local/gen   : {len(excluded)}")
    print(f"Manual review        : {len(review)}")
    print(f"Sensitive blocked    : {len(blocked)}")
    print()

    print("SENSITIVE BLOCKED:")
    if blocked:
        for rel in blocked:
            print("  [FAIL]", rel)
    else:
        print("  (none)")
    print()

    print("MANUAL REVIEW:")
    if review:
        for rel in review[:40]:
            print("  [REVIEW]", rel)
        if len(review) > 40:
            print(
                f"  [INFO] {len(review)-40} more saved to "
                "reports\\production\\07b346\\manual_review.txt"
            )
    else:
        print("  (none)")
    print()

    print("SAFE COMMIT CANDIDATES:")
    for rel in safe[:60]:
        print("  [SAFE]", rel)
    if len(safe) > 60:
        print(
            f"  [INFO] {len(safe)-60} more saved to "
            "reports\\production\\07b346\\safe_commit_candidates.txt"
        )

    print()
    if blocked:
        print("Overall: STOP")
        print("[STOP] Sensitive changed files exist. Do not stage yet.")
        raise SystemExit(2)

    print("Overall: READY_FOR_REVIEW")
    print()
    print("[SAFE] Nothing was staged, committed or pushed.")
    print("[NEXT] Send the MANUAL REVIEW section.")
    print(
        "[INFO] Full safe list: "
        "reports\\production\\07b346\\safe_commit_candidates.txt"
    )

if __name__ == "__main__":
    main()
