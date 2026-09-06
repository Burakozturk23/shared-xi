from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
GITIGNORE = ROOT / ".gitignore"

RULES = [
    "",
    "# Linkball local/generated security exclusions (STEP 07B.3.4.2)",
    "android/key.properties",
    "android/local.properties",
    "*.jks",
    "*.keystore",
    ".env",
    ".env.*",
    "functions/node_modules/",
    "node_modules/",
    "build/",
    ".dart_tool/",
    "coverage/",
    "reports/production/",
    "reports/data_platform_v3/",
    "*.bak",
]

def main():
    existing = ""
    if GITIGNORE.exists():
        existing = GITIGNORE.read_text(encoding="utf-8", errors="replace")

    bak = GITIGNORE.with_suffix(GITIGNORE.suffix + ".step07b342.bak")
    if GITIGNORE.exists() and not bak.exists():
        shutil.copy2(GITIGNORE, bak)
        print("[BACKUP]", bak.relative_to(ROOT))

    lines = existing.splitlines()
    present = {x.strip() for x in lines}

    added = []
    for rule in RULES:
        if not rule:
            continue
        if rule.startswith("#"):
            if rule not in existing:
                lines.append("")
                lines.append(rule)
                added.append(rule)
        elif rule not in present:
            lines.append(rule)
            present.add(rule)
            added.append(rule)

    GITIGNORE.write_text(
        "\n".join(lines).rstrip() + "\n",
        encoding="utf-8",
        newline="\n",
    )

    if added:
        print("[FIX] .gitignore hardened:")
        for item in added:
            print("  +", item)
    else:
        print("[PASS] Required .gitignore rules already present.")

    print()
    print("[SAFE] No file was deleted.")
    print("[SAFE] Git index was not modified.")

if __name__ == "__main__":
    main()
