from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]

targets = [
    ROOT / "run_step05b2_repair.bat",
    ROOT / "run_step05b_install.bat",
]

errors = []

for path in targets:
    if not path.exists():
        continue
    text = path.read_text(encoding="utf-8", errors="replace")
    if "flutter analyze --no-fatal-warnings --no-fatal-infos" not in text:
        errors.append(f"{path.name}: non-fatal analyze flags missing")

if errors:
    print("[FAIL] Step 05B.3 verification")
    for e in errors:
        print("  -", e)
    raise SystemExit(1)

print("[PASS] Step 05B.3 analyze gate verified.")
print("[INFO] Warning/info may remain visible, but only real errors block the flow.")
