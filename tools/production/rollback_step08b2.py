from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]

FILES = [
    ROOT / "lib/screens/welcome_page.dart",
    ROOT / "functions/index.js",
    ROOT / "firebase.json",
    ROOT / "tools/production/audit_step08a_launch_readiness.py",
    ROOT / "lib/config/privacy_config.dart",
    ROOT / "lib/services/account_deletion_service.dart",
    ROOT / "lib/screens/privacy_account_page.dart",
    ROOT / "functions/test/account_deletion_contracts.test.js",
    ROOT / "play_store_web/index.html",
    ROOT / "play_store_web/privacy.html",
    ROOT / "play_store_web/account-deletion.html",
    ROOT / "docs/production/PRIVACY_POLICY.md",
    ROOT / "docs/production/DATA_SAFETY_DRAFT.md",
    ROOT / "docs/production/ACCOUNT_DELETION.md",
]

restored = 0
for path in FILES:
    bak = path.with_suffix(path.suffix + ".step08b2.bak")
    created = path.with_suffix(path.suffix + ".step08b2.created")

    if bak.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(bak, path)
        print("[RESTORED]", path.relative_to(ROOT))
        restored += 1
    elif created.exists():
        if path.exists():
            path.unlink()
            print("[REMOVED]", path.relative_to(ROOT))
        restored += 1

    if created.exists():
        created.unlink()

print(f"[INFO] STEP 08B.2 rollback handled {restored} file(s).")
