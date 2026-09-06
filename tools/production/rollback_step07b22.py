from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]

FILES = [
    ROOT / "test/widget_test.dart",
    ROOT / ".github/workflows/linkball-ci.yml",
]

for path in FILES:
    bak = path.with_suffix(path.suffix + ".step07b22.bak")
    created = path.with_suffix(path.suffix + ".step07b22.created")

    if bak.exists():
        shutil.copy2(bak, path)
        print("[RESTORED]", path.relative_to(ROOT))
    elif created.exists():
        if path.exists():
            path.unlink()
            print("[REMOVED]", path.relative_to(ROOT))
    else:
        print("[INFO] No rollback marker:", path.relative_to(ROOT))

    if created.exists():
        created.unlink()
