from pathlib import Path
import subprocess
import shutil

ROOT = Path(__file__).resolve().parents[2]
GITIGNORE = ROOT / ".gitignore"
TARGET = "reports/data_audit/"

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

def main():
    if not (ROOT / ".git").exists():
        raise RuntimeError("Not a Git repository root.")

    existing = ""
    if GITIGNORE.exists():
        existing = GITIGNORE.read_text(encoding="utf-8", errors="replace")

    bak = GITIGNORE.with_suffix(GITIGNORE.suffix + ".step07b345.bak")
    if GITIGNORE.exists() and not bak.exists():
        shutil.copy2(GITIGNORE, bak)
        print("[BACKUP]", bak.relative_to(ROOT))

    lines = existing.splitlines()
    stripped = {x.strip() for x in lines}

    if TARGET not in stripped:
        if lines and lines[-1].strip():
            lines.append("")
        lines.append("# Linkball generated data audit reports")
        lines.append(TARGET)

        GITIGNORE.write_text(
            "\n".join(lines).rstrip() + "\n",
            encoding="utf-8",
            newline="\n",
        )
        print("[FIX] .gitignore +", TARGET)
    else:
        print("[PASS] .gitignore already contains", TARGET)

    # Find tracked files under the generated report directory.
    tracked = git(["ls-files", "reports/data_audit"]).stdout.splitlines()
    tracked = [x.strip() for x in tracked if x.strip()]

    if tracked:
        print(f"[INFO] Tracked generated report files found: {len(tracked)}")
        print("[FIX] Removing them from Git index ONLY; local files stay on disk.")

        r = git(
            ["rm", "-r", "--cached", "--ignore-unmatch", "reports/data_audit"],
            check=False,
        )
        if r.returncode != 0:
            raise RuntimeError(r.stderr or r.stdout)

        print("[PASS] Git index cleaned; local reports preserved.")
    else:
        print("[PASS] reports/data_audit is not currently tracked.")

    local = ROOT / "reports/data_audit"
    if local.exists():
        print("[SAFE] Local reports/data_audit directory still exists.")

    print()
    print("[OK] STEP 07B.3.4.5 DATA-AUDIT IGNORE PASS")

if __name__ == "__main__":
    main()
