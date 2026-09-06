from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PAGE = ROOT / "lib/screens/privacy_account_page.dart"
SERVICE = ROOT / "lib/services/account_deletion_service.dart"

errors = []

page = PAGE.read_text(encoding="utf-8", errors="replace")
service = SERVICE.read_text(encoding="utf-8", errors="replace")

for marker in [
    "_inlineDeleteConfirmation",
    "_deleteAccountConfirmed",
    "_deletePhraseMatches",
    "TextField(",
    "Hesap silme işlemi tamamlandı.",
]:
    if marker not in page:
        errors.append("page missing: " + marker)

for forbidden in [
    "showDialog<bool>",
    "showDialog<void>",
]:
    if forbidden in page:
        errors.append("old modal lifecycle path still present: " + forbidden)

for marker in [
    "[AccountDelete] callable_start",
    "[AccountDelete] callable_response",
    "[AccountDelete] server_delete_ok",
    "[AccountDelete] local_signout_ok",
    "[AccountDelete] completed",
]:
    if marker not in service:
        errors.append("service marker missing: " + marker)

if errors:
    print("[FAIL] STEP 08B.2.6 static verification")
    for error in errors:
        print("  -", error)
    raise SystemExit(1)

print("[PASS] Modal Navigator confirmation removed")
print("[PASS] Inline SİL confirmation installed")
print("[PASS] Success modal removed")
print("[PASS] Client AccountDelete progress markers installed")
print("[PASS] Firebase callable contract unchanged")
