from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
for rel in ("pubspec.yaml", "lib/main.dart"):
    p = ROOT / rel
    bak = p.with_suffix(p.suffix + ".step04_1.bak")
    if bak.exists():
        shutil.copy2(bak, p)
        print(f"[RESTORED] {rel}")
    else:
        print(f"[SKIP] backup missing: {rel}")
