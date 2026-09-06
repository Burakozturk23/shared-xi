from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).resolve().parents[2] / ".github" / "workflows" / "linkball-ci.yml"
TARGET = ROOT / ".github" / "workflows" / "linkball-ci.yml"

# In the extracted package SOURCE and TARGET resolve to the same project path.
# The embedded canonical workflow is shipped next to the installer as a .template.
TEMPLATE = Path(__file__).resolve().parent / "linkball-ci.template.yml"

def main():
    if not TEMPLATE.exists():
        raise RuntimeError("CI workflow template missing")

    TARGET.parent.mkdir(parents=True, exist_ok=True)

    bak = TARGET.with_suffix(TARGET.suffix + ".step07b2.bak")
    created_marker = TARGET.with_suffix(TARGET.suffix + ".step07b2.created")

    if TARGET.exists():
        if not bak.exists():
            shutil.copy2(TARGET, bak)
            print("[BACKUP]", bak.relative_to(ROOT))
    else:
        created_marker.write_text("created by STEP 07B.2\n", encoding="utf-8")
        print("[NEW]", TARGET.relative_to(ROOT))

    content = TEMPLATE.read_text(encoding="utf-8")
    TARGET.write_text(content, encoding="utf-8", newline="\n")

    print("[FIX] GitHub Actions CI baseline installed.")
    print("[INFO] Workflow:", TARGET.relative_to(ROOT))

if __name__ == "__main__":
    main()
