from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GITIGNORE = ROOT / ".gitignore"
ENTRY = "reports/production/05c/app_check_debug_token.local.txt"

text = ""
if GITIGNORE.exists():
    text = GITIGNORE.read_text(encoding="utf-8", errors="replace")

lines = text.replace("\r\n", "\n").replace("\r", "\n").splitlines()

if ENTRY not in lines:
    lines.append(ENTRY)

with GITIGNORE.open("w", encoding="utf-8", newline="\n") as handle:
    handle.write("\n".join(lines).rstrip() + "\n")

print("[PASS] Debug token local file is ignored by Git.")
