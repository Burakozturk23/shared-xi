from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]

for rel in [
    "lib/screens/privacy_account_page.dart",
    "lib/services/account_deletion_service.dart",
]:
    path = ROOT / rel
    bak = path.with_suffix(path.suffix + ".step08b26.bak")
    if bak.exists():
        shutil.copy2(bak, path)
        print("[RESTORED]", rel)
