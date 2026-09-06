from pathlib import Path
import subprocess
import re

ROOT = Path(__file__).resolve().parents[2]
SELF = Path(__file__).resolve()

BLOCKED_NAMES = {
    "android/key.properties",
    "android/local.properties",
}

BLOCKED_EXTENSIONS = {
    ".jks",
    ".keystore",
    ".p12",
    ".pfx",
    ".pem",
    ".key",
}

BLOCKED_NAME_PATTERNS = [
    re.compile(r"(^|/)\.env($|\.)", re.I),
    re.compile(r"firebase-adminsdk", re.I),
    re.compile(r"service.?account", re.I),
    re.compile(r"service_account", re.I),
    re.compile(r"credentials?\.json$", re.I),
    re.compile(r"secrets?\.json$", re.I),
    re.compile(r"app_check.*token", re.I),
]

GENERATED_OR_LOCAL_PATTERNS = [
    re.compile(r"(^|/)build/", re.I),
    re.compile(r"(^|/)\.dart_tool/", re.I),
    re.compile(r"(^|/)node_modules/", re.I),
    re.compile(r"(^|/)coverage/", re.I),
    re.compile(r"(^|/)reports/production/", re.I),
    re.compile(r"(^|/)\.idea/", re.I),
]

SECRET_PATTERNS = [
    (
        "private_key_block",
        re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    ),
    (
        "google_service_account_private_key",
        re.compile(r'"private_key"\s*:\s*"-----BEGIN PRIVATE KEY-----'),
    ),
    (
        "github_token",
        re.compile(r"\bgh[pousr]_[A-Za-z0-9_]{20,}\b"),
    ),
    (
        "firebase_ci_token",
        re.compile(r"\b1//[A-Za-z0-9_-]{20,}\b"),
    ),
    (
        "slack_token",
        re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b"),
    ),
    (
        "aws_access_key",
        re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    ),
    (
        "generic_secret_assignment",
        re.compile(
            r"(?i)\b(?:api[_-]?key|secret|token|password|passwd|"
            r"client[_-]?secret)\b\s*[:=]\s*['\"][^'\"]{12,}['\"]"
        ),
    ),
]

SAFE_CONTENT_MARKERS = [
    "${{ secrets.",
    "process.env.",
    "defineSecret(",
    "String.fromEnvironment(",
    "<REDACTED",
    "YOUR_",
    "PLACEHOLDER",
    "re.compile(",
    "assert.match(",
    "assert.doesNotMatch(",
]

MAX_TEXT_SCAN_BYTES = 2 * 1024 * 1024
LARGE_FILE_WARN_BYTES = 5 * 1024 * 1024
LARGE_FILE_BLOCK_BYTES = 50 * 1024 * 1024

def run_git(args):
    try:
        result = subprocess.run(
            ["git", *args],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        raise SystemExit("[FAIL] git was not found in PATH.")

    if result.returncode != 0:
        raise SystemExit(
            "[FAIL] git command failed: git "
            + " ".join(args)
            + "\n"
            + (result.stderr or result.stdout)
        )

    return result.stdout

def normalize(path):
    return path.replace("\\", "/").lstrip("./")

def collect_changed_files():
    files = set()

    out = run_git(["diff", "--cached", "--name-only", "--diff-filter=ACMR"])
    files.update(normalize(x.strip()) for x in out.splitlines() if x.strip())

    out = run_git(["ls-files", "--others", "--exclude-standard"])
    files.update(normalize(x.strip()) for x in out.splitlines() if x.strip())

    out = run_git(["diff", "--name-only", "--diff-filter=ACMR"])
    files.update(normalize(x.strip()) for x in out.splitlines() if x.strip())

    return sorted(files)

def collect_tracked_sensitive_files():
    out = run_git(["ls-files"])
    tracked = [normalize(x.strip()) for x in out.splitlines() if x.strip()]
    return [rel for rel in tracked if is_blocked_filename(rel)]

def is_blocked_filename(rel):
    low = rel.lower()

    if low in BLOCKED_NAMES:
        return True

    if Path(rel).suffix.lower() in BLOCKED_EXTENSIONS:
        return True

    return any(rx.search(rel) for rx in BLOCKED_NAME_PATTERNS)

def is_generated_or_local(rel):
    return any(rx.search(rel) for rx in GENERATED_OR_LOCAL_PATTERNS)

def read_text_safely(path):
    try:
        size = path.stat().st_size
    except FileNotFoundError:
        return None

    if size > MAX_TEXT_SCAN_BYTES:
        return None

    try:
        data = path.read_bytes()
    except Exception:
        return None

    if b"\x00" in data[:4096]:
        return None

    return data.decode("utf-8", errors="replace")

def scan_content(rel):
    path = ROOT / rel

    # Do not self-trigger on the audit's own regex pattern literals.
    try:
        if path.resolve() == SELF:
            return []
    except FileNotFoundError:
        pass

    text = read_text_safely(path)
    if text is None:
        return []

    findings = []

    for name, rx in SECRET_PATTERNS:
        for match in rx.finditer(text):
            line_start = text.rfind("\n", 0, match.start()) + 1
            line_end = text.find("\n", match.end())

            if line_end == -1:
                line_end = len(text)

            line = text[line_start:line_end]

            if any(
                marker.lower() in line.lower()
                for marker in SAFE_CONTENT_MARKERS
            ):
                continue

            line_no = text.count("\n", 0, match.start()) + 1
            findings.append((name, line_no))

    return findings

def gitignore_has(pattern):
    path = ROOT / ".gitignore"

    if not path.exists():
        return False

    lines = [
        line.strip()
        for line in path.read_text(
            encoding="utf-8",
            errors="replace",
        ).splitlines()
        if line.strip() and not line.strip().startswith("#")
    ]

    return pattern in lines

def main():
    print("=" * 68)
    print("LINKBALL STEP 07B.3.4 - GITHUB PRE-PUSH SECURITY AUDIT")
    print("=" * 68)
    print()
    print("READ-ONLY. No git add/commit/push is performed.")
    print("Secret values are never printed.")
    print()

    top = run_git(["rev-parse", "--show-toplevel"]).strip()
    print("[PASS] Git repository:", top)

    changed = collect_changed_files()
    tracked_sensitive = collect_tracked_sensitive_files()

    blockers = []
    warnings = []

    for rel in tracked_sensitive:
        blockers.append(
            f"Sensitive file is already tracked by Git: {rel}"
        )

    print()
    print(f"Changed/staged/untracked files scanned: {len(changed)}")

    for rel in changed:
        path = ROOT / rel

        if is_blocked_filename(rel):
            blockers.append(
                f"Sensitive file must not be committed: {rel}"
            )
            continue

        if is_generated_or_local(rel):
            warnings.append(
                f"Generated/local file should usually stay out of Git: {rel}"
            )

        if not path.exists() or not path.is_file():
            continue

        size = path.stat().st_size

        if size >= LARGE_FILE_BLOCK_BYTES:
            blockers.append(
                f"Very large file ({size / (1024*1024):.1f} MB) "
                f"queued for Git: {rel}"
            )
        elif size >= LARGE_FILE_WARN_BYTES:
            warnings.append(
                f"Large file ({size / (1024*1024):.1f} MB) "
                f"queued for Git: {rel}"
            )

        for kind, line_no in scan_content(rel):
            blockers.append(
                f"Possible secret [{kind}] in {rel}:{line_no}"
            )

    recommended_ignores = [
        "android/key.properties",
        "android/local.properties",
        "*.jks",
        "*.keystore",
        ".env",
        ".env.*",
        "reports/production/",
    ]

    missing_ignores = [
        pattern
        for pattern in recommended_ignores
        if not gitignore_has(pattern)
    ]

    if missing_ignores:
        warnings.append(
            "Recommended .gitignore entries missing: "
            + ", ".join(missing_ignores)
        )

    print()
    print("BLOCKERS:")
    if blockers:
        for item in blockers:
            print("  [FAIL]", item)
    else:
        print("  (none)")

    print()
    print("WARNINGS:")
    if warnings:
        for item in warnings:
            print("  [WARN]", item)
    else:
        print("  (none)")

    print()
    if blockers:
        print("Overall: STOP")
        print()
        print("[STOP] Do NOT push yet.")
        print("Remove/fix the blocker files or secret literals first.")
        raise SystemExit(2)

    print("Overall: PASS")
    print()
    print("[OK] No push-blocking secret/signing issue detected.")
    print("Review WARNINGS manually before git add/commit/push.")

if __name__ == "__main__":
    main()
