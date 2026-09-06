from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GITIGNORE = ROOT / ".gitignore"

line = "reports/production/05c/app_check_debug_token.local.txt"

if GITIGNORE.exists():
    text = GITIGNORE.read_text(encoding="utf-8", errors="replace")
else:
    text = ""

lines = text.replace("\r\n", "\n").replace("\r", "\n").splitlines()

if line not in lines:
    lines.append(line)

with GITIGNORE.open("w", encoding="utf-8", newline="\n") as handle:
    handle.write("\n".join(lines).rstrip() + "\n")

print("[PASS] Local App Check debug token path is ignored by Git.")
