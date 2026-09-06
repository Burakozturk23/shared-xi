from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
PAGE = ROOT / "lib/screens/privacy_account_page.dart"
BAK = PAGE.with_suffix(PAGE.suffix + ".step08b27.bak")

if BAK.exists():
    shutil.copy2(BAK, PAGE)
    print("[RESTORED] lib/screens/privacy_account_page.dart")
