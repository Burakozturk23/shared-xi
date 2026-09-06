from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]

targets = [
    (
        ROOT / "functions/index.js",
        ROOT / "functions/index.js.step05b1.bak",
    ),
    (
        ROOT / "tools/production/install_step05b.py",
        ROOT / "tools/production/install_step05b.py.step05b1.bak",
    ),
]

for target, backup in targets:
    if backup.exists():
        shutil.copy2(backup, target)
        print(f"[RESTORED] {target.relative_to(ROOT)}")
    else:
        print(f"[SKIP] backup yok: {target.relative_to(ROOT)}")
