from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / ".github" / "workflows" / "linkball-ci.yml"
BAK = TARGET.with_suffix(TARGET.suffix + ".step07b2.bak")
CREATED = TARGET.with_suffix(TARGET.suffix + ".step07b2.created")

if BAK.exists():
    shutil.copy2(BAK, TARGET)
    print("[RESTORED]", TARGET.relative_to(ROOT))
elif CREATED.exists():
    if TARGET.exists():
        TARGET.unlink()
        print("[REMOVED]", TARGET.relative_to(ROOT))
else:
    print("[INFO] No STEP 07B.2 workflow rollback marker found.")

if CREATED.exists():
    CREATED.unlink()
