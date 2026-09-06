from __future__ import annotations

from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
FUNCTIONS = ROOT / "functions"
INDEX = FUNCTIONS / "index.js"

errors = []

if not INDEX.exists():
    errors.append("functions/index.js missing")
else:
    data = INDEX.read_bytes()
    if b"\r\n" in data or b"\r" in data:
        errors.append("functions/index.js still contains CRLF/CR")

    text = INDEX.read_text(encoding="utf-8")
    for marker in [
        "exports.startDailyScoreSession",
        "exports.submitDailyScore",
        "dailyScoreSessions/",
        "serverValidated",
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
    print("[FAIL] Step 05B.2 verification")
    for error in errors:
        print("  -", error)
    raise SystemExit(1)

print("[PASS] functions/index.js LF OK.")
print("[PASS] Step 05B server-authority markers present.")
print("[PASS] node_modules intentionally ignored.")
