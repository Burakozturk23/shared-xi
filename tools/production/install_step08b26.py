from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
TEMPLATES = Path(__file__).resolve().parent / "step08b26_templates"

PAGE = ROOT / "lib/screens/privacy_account_page.dart"
SERVICE = ROOT / "lib/services/account_deletion_service.dart"

def backup(path):
    if not path.exists():
        raise RuntimeError(f"Required STEP 08B.2 file missing: {path}")

    bak = path.with_suffix(path.suffix + ".step08b26.bak")
    if not bak.exists():
        shutil.copy2(path, bak)
        print("[BACKUP]", path.relative_to(ROOT))

def write_lf(path, content):
    with path.open("w", encoding="utf-8", newline="\n") as f:
        f.write(content.replace("\r\n", "\n").replace("\r", "\n"))

def main():
    page = PAGE.read_text(encoding="utf-8", errors="replace")
    service = SERVICE.read_text(encoding="utf-8", errors="replace")

    required_page = [
        "PrivacyAccountPage",
        "AccountDeletionService.deleteCurrentAccount",
        "Gizlilik & Hesap",
        "Hesabımı ve verilerimi sil",
    ]
    required_service = [
        "class AccountDeletionService",
        "httpsCallable('deleteMyAccount')",
    ]

    for marker in required_page:
        if marker not in page:
            raise RuntimeError(
                f"Current privacy page does not match STEP 08B.2: {marker}"
            )

    for marker in required_service:
        if marker not in service:
            raise RuntimeError(
                f"Current deletion service does not match STEP 08B.2: {marker}"
            )

    if "_inlineDeleteConfirmation" in page:
        print("[PASS] STEP 08B.2.6 page already installed.")
    else:
        backup(PAGE)
        write_lf(
            PAGE,
            (TEMPLATES / "privacy_account_page.dart").read_text(
                encoding="utf-8"
            ),
        )
        print("[FIX] Modal delete confirmation replaced with inline flow.")

    if "[AccountDelete] callable_start" in service:
        print("[PASS] STEP 08B.2.6 service markers already installed.")
    else:
        backup(SERVICE)
        write_lf(
            SERVICE,
            (TEMPLATES / "account_deletion_service.dart").read_text(
                encoding="utf-8"
            ),
        )
        print("[FIX] Safe AccountDelete progress markers added.")

    print()
    print("[OK] STEP 08B.2.6 source patch complete.")
    print("[INFO] Firebase backend/Hosting were not modified.")

if __name__ == "__main__":
    main()
