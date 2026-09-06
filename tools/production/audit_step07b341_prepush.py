from pathlib import Path
import subprocess
import re

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/07b341"
REPORT.mkdir(parents=True, exist_ok=True)
BLOCKERS_FILE = REPORT / "blockers.txt"
WARNINGS_FILE = REPORT / "warnings.txt"
FULL_FILE = REPORT / "prepush_full_report.txt"

BLOCKED_NAMES = {
    "android/key.properties",
    "android/local.properties",
}

BLOCKED_EXTENSIONS = {
    ".jks", ".keystore", ".p12", ".pfx", ".pem", ".key",
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

GENERATED_PATTERNS = [
    re.compile(r"(^|/)build/", re.I),
    re.compile(r"(^|/)\.dart_tool/", re.I),
    re.compile(r"(^|/)node_modules/", re.I),
    re.compile(r"(^|/)coverage/", re.I),
    re.compile(r"(^|/)reports/production/", re.I),
    re.compile(r"(^|/)\.idea/", re.I),
]

SECRET_PATTERNS = [
    ("private_key", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
    ("github_token", re.compile(r"\bgh[pousr]_[A-Za-z0-9_]{20,}\b")),
    ("firebase_ci_token", re.compile(r"\b1//[A-Za-z0-9_-]{20,}\b")),
    ("aws_access_key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("generic_secret_assignment", re.compile(
        r"(?i)\b(?:api[_-]?key|secret|token|password|passwd|client[_-]?secret)\b"
        r"\s*[:=]\s*['\"][^'\"]{12,}['\"]"
    )),
]

SAFE_LINE_MARKERS = [
    "${{ secrets.",
    "process.env.",
    "defineSecret(",
    "String.fromEnvironment(",
    "<REDACTED",
    "YOUR_",
    "PLACEHOLDER",
    "re.compile(",
]

MAX_SCAN = 2 * 1024 * 1024
WARN_SIZE = 5 * 1024 * 1024
BLOCK_SIZE = 50 * 1024 * 1024

def git(args):
    r = subprocess.run(
        ["git", *args],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if r.returncode != 0:
        raise SystemExit("[FAIL] git " + " ".join(args) + "\n" + (r.stderr or r.stdout))
    return r.stdout

def norm(s):
    return s.replace("\\", "/").lstrip("./")

def changed():
    files = set()
    for args in [
        ["diff", "--cached", "--name-only", "--diff-filter=ACMR"],
        ["diff", "--name-only", "--diff-filter=ACMR"],
        ["ls-files", "--others", "--exclude-standard"],
    ]:
        files.update(norm(x.strip()) for x in git(args).splitlines() if x.strip())
    return sorted(files)

def blocked_name(rel):
    low = rel.lower()
    if low in BLOCKED_NAMES:
        return True
    if Path(rel).suffix.lower() in BLOCKED_EXTENSIONS:
        return True
    return any(rx.search(rel) for rx in BLOCKED_NAME_PATTERNS)

def generated(rel):
    return any(rx.search(rel) for rx in GENERATED_PATTERNS)

def text_of(path):
    if not path.exists() or not path.is_file():
        return None
    try:
        size = path.stat().st_size
    except Exception:
        return None
    if size > MAX_SCAN:
        return None
    try:
        data = path.read_bytes()
    except Exception:
        return None
    if b"\x00" in data[:4096]:
        return None
    return data.decode("utf-8", errors="replace")

def scan_secret(rel):
    # Don't self-trigger on audit source regexes.
    if rel.replace("\\", "/").endswith(
        "tools/production/audit_step07b341_prepush.py"
    ):
        return []

    text = text_of(ROOT / rel)
    if text is None:
        return []

    out = []
    for kind, rx in SECRET_PATTERNS:
        for m in rx.finditer(text):
            line_start = text.rfind("\n", 0, m.start()) + 1
            line_end = text.find("\n", m.end())
            if line_end < 0:
                line_end = len(text)
            line = text[line_start:line_end]

            if any(x.lower() in line.lower() for x in SAFE_LINE_MARKERS):
                continue

            line_no = text.count("\n", 0, m.start()) + 1
            out.append(f"Possible secret [{kind}] in {rel}:{line_no}")
    return out

def main():
    blockers = []
    warnings = []

    # Sensitive files already tracked.
    tracked = [norm(x) for x in git(["ls-files"]).splitlines() if x.strip()]
    for rel in tracked:
        if blocked_name(rel):
            blockers.append(f"Sensitive file is already tracked by Git: {rel}")

    files = changed()

    for rel in files:
        path = ROOT / rel

        if blocked_name(rel):
            blockers.append(f"Sensitive file must not be committed: {rel}")
            continue

        if generated(rel):
            warnings.append(f"Generated/local file: {rel}")

        if path.exists() and path.is_file():
            size = path.stat().st_size
            if size >= BLOCK_SIZE:
                blockers.append(
                    f"Very large file ({size/(1024*1024):.1f} MB): {rel}"
                )
            elif size >= WARN_SIZE:
                warnings.append(
                    f"Large file ({size/(1024*1024):.1f} MB): {rel}"
                )

            blockers.extend(scan_secret(rel))

    # Deduplicate while preserving order.
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

    full = [
        "LINKBALL STEP 07B.3.4.1 PRE-PUSH REPORT",
        "",
        f"changed_files={len(files)}",
        f"blockers={len(blockers)}",
        f"warnings={len(warnings)}",
        "",
        "BLOCKERS:",
        *(["  [FAIL] " + x for x in blockers] if blockers else ["  (none)"]),
        "",
        "WARNINGS:",
        *(["  [WARN] " + x for x in warnings] if warnings else ["  (none)"]),
        "",
    ]
    FULL_FILE.write_text("\n".join(full), encoding="utf-8")

    print("=" * 68)
    print("LINKBALL STEP 07B.3.4.1 - PRE-PUSH BLOCKER VIEW")
    print("=" * 68)
    print()
    print(f"Changed files scanned : {len(files)}")
    print(f"Blockers              : {len(blockers)}")
    print(f"Warnings              : {len(warnings)}")
    print()

    # Keep console short. Warnings are not dumped individually here.
    if warnings:
        print(
            f"[INFO] {len(warnings)} warning(s) saved to:"
        )
        print("       reports\\production\\07b341\\warnings.txt")
        print()

    print("============================================================")
    print("BLOCKERS - THESE ARE THE ONLY LINES THAT STOP THE PUSH")
    print("============================================================")
    if blockers:
        for x in blockers:
            print("[FAIL]", x)
    else:
        print("(none)")
    print("============================================================")
    print()

    if blockers:
        print("Overall: STOP")
        print()
        print("[STOP] Do NOT push yet.")
        print("[INFO] Blockers also saved to:")
        print("       reports\\production\\07b341\\blockers.txt")
        raise SystemExit(2)

    print("Overall: PASS")
    print()
    print("[OK] No push-blocking item detected.")

if __name__ == "__main__":
    main()
