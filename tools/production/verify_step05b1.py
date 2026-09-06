from __future__ import annotations

from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
FUNCTIONS_DIR = ROOT / "functions"
INDEX = FUNCTIONS_DIR / "index.js"

errors = []

if not INDEX.exists():
    errors.append("functions/index.js missing")
else:
    for path in FUNCTIONS_DIR.rglob("*.js"):
        if not path.is_file():
            continue
        data = path.read_bytes()
        if b"\r\n" in data or b"\r" in data:
            errors.append(f"CRLF/CR remains: {path.relative_to(ROOT)}")

    text = INDEX.read_text(encoding="utf-8")
    for marker in [
        "exports.startDailyScoreSession",
        "exports.submitDailyScore",
        "dailyScoreSessions/",
        "serverValidated: true",
    ]:
        if marker not in text:
            errors.append(f"05B marker missing: {marker}")

try:
    node = subprocess.run(
        ["node", "--check", str(INDEX)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    if node.returncode != 0:
        errors.append("node --check failed: " + node.stderr.strip())
except FileNotFoundError:
    print("[WARN] node bulunamadi; JS syntax check atlandi.")

if errors:
    print("[FAIL] Step 05B.1 verification")
    for error in errors:
        print("  -", error)
    raise SystemExit(1)

print("[PASS] Step 05B.1 LF + 05B markers verified.")
