from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SAFE_LIST = ROOT / "reports/production/07b348/safe_release_commit.txt"
REPORT = ROOT / "reports/production/07b349"
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

def norm(value):
    value = value.replace("\\", "/")
    if value.startswith("./"):
        value = value[2:]
    return value

def sensitive(path):
    if path.lower() in SENSITIVE_EXACT:
        return True
    return Path(path).suffix.lower() in SENSITIVE_EXTS

def load_safe():
    if not SAFE_LIST.exists():
        raise RuntimeError(
            "Missing reports/production/07b348/safe_release_commit.txt. "
            "Run STEP 07B.3.4.8 first."
        )

    rows = []
    for line in SAFE_LIST.read_text(
        encoding="utf-8",
        errors="replace",
    ).splitlines():
        line = norm(line.strip())
        if not line or line == "(none)":
            continue
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

def main():
    safe = load_safe()
    safe_set = set(safe)

    if not safe:
        raise RuntimeError("Safe release list is empty.")

    bad_safe = [x for x in safe if sensitive(x)]
    if bad_safe:
        print("[FAIL] Sensitive path unexpectedly exists in SAFE manifest:")
        for rel in bad_safe:
            print("  ", rel)
        raise SystemExit(2)

    # INSTALL.txt was the sole V3 manual-review entry and is intentionally local.
    if "INSTALL.txt" in safe_set:
        raise RuntimeError(
            "Safety stop: INSTALL.txt unexpectedly entered SAFE list."
        )

    before = staged()
    outside_before = [x for x in before if x not in safe_set]

    print("=" * 70)
    print("LINKBALL STEP 07B.3.4.9 - SAFE RELEASE STAGING")
    print("=" * 70)
    print()
    print(f"Approved SAFE paths : {len(safe)}")
    print(f"Already staged      : {len(before)}")
    print()

    # Never trample an existing staging area that contains unrelated files.
    if outside_before:
        print("[STOP] Existing staged files are outside the approved SAFE list:")
        for rel in outside_before:
            print("  [STAGED-OUTSIDE-SAFE]", rel)

        (REPORT / "preexisting_staged_outside_safe.txt").write_text(
            "\n".join(outside_before) + "\n",
            encoding="utf-8",
        )

        print()
        print("Nothing new was staged by STEP 07B.3.4.9.")
        raise SystemExit(3)

    print("[RUN] Staging ONLY approved SAFE release paths...")

    # Stage in manageable chunks and use -- to terminate git options.
    chunk_size = 40
    for i in range(0, len(safe), chunk_size):
        chunk = safe[i:i + chunk_size]
        r = git(["add", "--", *chunk], check=False)
        if r.returncode != 0:
            raise RuntimeError(r.stderr or r.stdout)

    after = staged()
    outside_after = [x for x in after if x not in safe_set]
    sensitive_after = [x for x in after if sensitive(x)]

    if outside_after or sensitive_after:
        print("[FAIL] Post-stage safety invariant failed.")
        if outside_after:
            print("Staged outside SAFE:")
            for rel in outside_after:
                print("  ", rel)
        if sensitive_after:
            print("Sensitive staged:")
            for rel in sensitive_after:
                print("  ", rel)

        print()
        print(
            "The script will NOT auto-reset your Git index because it may "
            "contain user work. Do not commit."
        )
        raise SystemExit(4)

    (REPORT / "staged_release_files.txt").write_text(
        "\n".join(after) + ("\n" if after else "(none)\n"),
        encoding="utf-8",
    )

    # Show concise staged diff statistics.
    stat = git(["diff", "--cached", "--stat"]).stdout

    print()
    print("STAGED RELEASE SUMMARY")
    print("----------------------")
    print(f"Staged approved files: {len(after)}")
    print("Sensitive staged     : 0")
    print("Outside SAFE staged  : 0")
    print()

    if stat.strip():
        print(stat.rstrip())
        print()

    print("[PASS] INSTALL.txt remains outside the release staging set.")
    print("[PASS] Only V3 SAFE production paths are staged.")
    print("[PASS] No signing/keystore path is staged.")
    print()
    print("Overall: READY_TO_COMMIT")
    print()
    print("[SAFE] No commit or push was performed.")

if __name__ == "__main__":
    main()
