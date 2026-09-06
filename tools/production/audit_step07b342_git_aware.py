from pathlib import Path
import subprocess
import re

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/07b342"
REPORT.mkdir(parents=True, exist_ok=True)

BLOCKERS_FILE = REPORT / "blockers.txt"
WARNINGS_FILE = REPORT / "warnings.txt"

SAFE_LARGE_RUNTIME_ASSETS = {
    "assets/runtime/linkball_runtime_v3.sqlite",
}

SKIP_PREFIXES = (
    "functions/node_modules/",
    "node_modules/",
    "build/",
    ".dart_tool/",
    "coverage/",
    "reports/production/",
    "reports/data_platform_v3/",
)

SKIP_SUFFIXES = (
    ".bak",
    ".log",
    ".tmp",
)

SENSITIVE_EXACT = {
    "android/key.properties",
    "android/local.properties",
}

SENSITIVE_EXTS = {
    ".jks", ".keystore", ".p12", ".pfx", ".pem", ".key",
}

SENSITIVE_NAME_PATTERNS = [
    re.compile(r"(^|/)\.env($|\.)", re.I),
    re.compile(r"firebase-adminsdk", re.I),
    re.compile(r"service.?account", re.I),
    re.compile(r"service_account", re.I),
]

SECRET_PATTERNS = [
    ("private_key", re.compile(
        r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"
    )),
    ("github_token", re.compile(r"\bgh[pousr]_[A-Za-z0-9_]{20,}\b")),
    ("firebase_ci_token", re.compile(r"\b1//[A-Za-z0-9_-]{20,}\b")),
    ("aws_access_key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
]

SAFE_FILES_FOR_CLIENT_CONFIG = {
    "lib/firebase_options.dart",
    "android/app/google-services.json",
}

MAX_SCAN = 2 * 1024 * 1024
WARN_SIZE = 20 * 1024 * 1024
GITHUB_HARD_LIMIT = 100 * 1024 * 1024

def git(args, check=True):
    r = subprocess.run(
        ["git", *args],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if check and r.returncode != 0:
        raise SystemExit(
            "[FAIL] git " + " ".join(args) + "\n" + (r.stderr or r.stdout)
        )
    return r

def norm(x):
    return x.replace("\\", "/").lstrip("./")

def collect_candidate_files():
    files = set()

    for args in [
        ["diff", "--cached", "--name-only", "--diff-filter=ACMR"],
        ["diff", "--name-only", "--diff-filter=ACMR"],
        ["ls-files", "--others", "--exclude-standard"],
    ]:
        r = git(args)
        files.update(norm(x.strip()) for x in r.stdout.splitlines() if x.strip())

    return sorted(files)

def already_tracked():
    r = git(["ls-files"])
    return {norm(x.strip()) for x in r.stdout.splitlines() if x.strip()}

def skip_generated(rel):
    if rel.startswith(SKIP_PREFIXES):
        return True
    return rel.endswith(SKIP_SUFFIXES)

def sensitive_name(rel):
    low = rel.lower()

    if low in SENSITIVE_EXACT:
        return True

    if Path(rel).suffix.lower() in SENSITIVE_EXTS:
        return True

    return any(rx.search(rel) for rx in SENSITIVE_NAME_PATTERNS)

def text_of(path):
    if not path.exists() or not path.is_file():
        return None
    if path.stat().st_size > MAX_SCAN:
        return None

    try:
        data = path.read_bytes()
    except Exception:
        return None

    if b"\x00" in data[:4096]:
        return None

    return data.decode("utf-8", errors="replace")

def scan_secrets(rel):
    if rel in SAFE_FILES_FOR_CLIENT_CONFIG:
        return []

    # Do not scan audit tools for their own regex literal examples.
    if rel.startswith("tools/production/") and "audit_" in Path(rel).name:
        return []

    text = text_of(ROOT / rel)
    if text is None:
        return []

    hits = []
    for kind, rx in SECRET_PATTERNS:
        for m in rx.finditer(text):
            line = text.count("\n", 0, m.start()) + 1
            hits.append(f"Possible secret [{kind}] in {rel}:{line}")
    return hits

def is_ignored(rel):
    r = git(["check-ignore", "-q", "--", rel], check=False)
    return r.returncode == 0

def main():
    print("=" * 70)
    print("LINKBALL STEP 07B.3.4.2 - GIT-AWARE PRE-PUSH AUDIT")
    print("=" * 70)
    print()
    print("Scans only files Git could actually commit.")
    print("Known generated/dependency trees are excluded.")
    print("Secret values are never printed.")
    print()

    candidates = collect_candidate_files()
    tracked = already_tracked()

    blockers = []
    warnings = []
    excluded = []

    # Check dangerous files already tracked.
    for rel in sorted(tracked):
        if sensitive_name(rel):
            blockers.append(f"Sensitive file is already tracked by Git: {rel}")

    for rel in candidates:
        if is_ignored(rel):
            excluded.append(rel)
            continue

        if skip_generated(rel):
            excluded.append(rel)
            # If a generated file is already tracked, that is worth warning about.
            if rel in tracked:
                warnings.append(
                    f"Generated/local file is already tracked and should be untracked: {rel}"
                )
            continue

        if sensitive_name(rel):
            blockers.append(f"Sensitive file must not be committed: {rel}")
            continue

        path = ROOT / rel
        if not path.exists() or not path.is_file():
            continue

        size = path.stat().st_size

        if size >= GITHUB_HARD_LIMIT:
            blockers.append(
                f"GitHub 100 MB hard-limit risk "
                f"({size/(1024*1024):.1f} MB): {rel}"
            )
        elif size >= WARN_SIZE and rel not in SAFE_LARGE_RUNTIME_ASSETS:
            warnings.append(
                f"Large file queued for Git "
                f"({size/(1024*1024):.1f} MB): {rel}"
            )
        elif rel in SAFE_LARGE_RUNTIME_ASSETS:
            warnings.append(
                f"Large REQUIRED production runtime asset "
                f"({size/(1024*1024):.1f} MB): {rel}"
            )

        blockers.extend(scan_secrets(rel))

    blockers = list(dict.fromkeys(blockers))
    warnings = list(dict.fromkeys(warnings))

    BLOCKERS_FILE.write_text(
        "\n".join(blockers) + ("\n" if blockers else "(none)\n"),
        encoding="utf-8",
    )
    WARNINGS_FILE.write_text(
        "\n".join(warnings) + ("\n" if warnings else "(none)\n"),
        encoding="utf-8",
    )

    print(f"Candidate changed files : {len(candidates)}")
    print(f"Excluded generated/ignored: {len(excluded)}")
    print(f"Warnings                : {len(warnings)}")
    print(f"Blockers                : {len(blockers)}")
    print()

    print("BLOCKERS:")
    if blockers:
        for item in blockers:
            print("  [FAIL]", item)
    else:
        print("  (none)")

    print()
    print("IMPORTANT WARNINGS:")
    if warnings:
        for item in warnings[:20]:
            print("  [WARN]", item)
        if len(warnings) > 20:
            print(
                f"  [INFO] {len(warnings)-20} more warning(s) saved to "
                "reports\\production\\07b342\\warnings.txt"
            )
    else:
        print("  (none)")

    print()
    if blockers:
        print("Overall: STOP")
        print()
        print("[STOP] Do NOT push yet.")
        raise SystemExit(2)

    print("Overall: PASS")
    print()
    print("[OK] No push-blocking secret/signing issue detected.")
    print("[INFO] Required Runtime V3 SQLite is allowed even though it is large.")

if __name__ == "__main__":
    main()
