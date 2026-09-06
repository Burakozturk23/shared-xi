from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
SAFE_LIST = ROOT / "reports/production/07b348/safe_release_commit.txt"
REPORT = ROOT / "reports/production/07b3410"
REPORT.mkdir(parents=True, exist_ok=True)

SENSITIVE_EXACT = {
    "android/key.properties",
    "android/local.properties",
}

SENSITIVE_EXTS = {
    ".jks", ".keystore", ".p12", ".pfx", ".pem", ".key",
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
    x = x.replace("\\", "/")
    if x.startswith("./"):
        x = x[2:]
    return x

def load_safe():
    if not SAFE_LIST.exists():
        raise RuntimeError(
            "Missing safe manifest. Run STEP 07B.3.4.8 first."
        )
    rows = []
    for line in SAFE_LIST.read_text(
        encoding="utf-8",
        errors="replace",
    ).splitlines():
        line = norm(line.strip())
        if line and line != "(none)":
            rows.append(line)
    return list(dict.fromkeys(rows))

def staged():
    out = git(
        ["diff", "--cached", "--name-only", "--diff-filter=ACMRD"]
    ).stdout
    return sorted(
        norm(x.strip())
        for x in out.splitlines()
        if x.strip()
    )

def sensitive(rel):
    if rel.lower() in SENSITIVE_EXACT:
        return True
    return Path(rel).suffix.lower() in SENSITIVE_EXTS

def main():
    safe = set(load_safe())
    staged_now = staged()

    if not staged_now:
        raise RuntimeError(
            "Nothing is staged. Run STEP 07B.3.4.9 first."
        )

    outside = [x for x in staged_now if x not in safe]
    sensitive_paths = [x for x in staged_now if sensitive(x)]

    if outside or sensitive_paths:
        print("[STOP] Staged set is no longer the approved SAFE set.")
        for x in outside:
            print("  [OUTSIDE-SAFE]", x)
        for x in sensitive_paths:
            print("  [SENSITIVE]", x)
        raise SystemExit(2)

    branch = git(["branch", "--show-current"]).stdout.strip()
    remote = git(["remote", "get-url", "origin"], check=False)

    if remote.returncode != 0:
        remote_url = "(origin not configured)"
    else:
        remote_url = remote.stdout.strip()

    status = git(["status", "--short"]).stdout

    print("=" * 70)
    print("LINKBALL STEP 07B.3.4.10 - COMMIT/PUSH PRECHECK")
    print("=" * 70)
    print()
    print("Branch :", branch or "(detached HEAD)")
    print("Origin :", remote_url)
    print("Staged :", len(staged_now), "approved SAFE paths")
    print("Outside SAFE staged : 0")
    print("Sensitive staged    : 0")
    print()

    if not branch:
        print("[STOP] Detached HEAD. Do not commit/push from here.")
        raise SystemExit(3)

    if remote.returncode != 0:
        print("[STOP] Git remote 'origin' is not configured.")
        raise SystemExit(4)

    (REPORT / "precommit_status.txt").write_text(
        status,
        encoding="utf-8",
        newline="\n",
    )

    print("[PASS] Commit/push precheck passed.")
    print()
    print("Commit message:")
    print("  chore: production hardening runtime v3 ci release gates")
    print()
    print("[SAFE] No commit or push performed by precheck.")

if __name__ == "__main__":
    main()
