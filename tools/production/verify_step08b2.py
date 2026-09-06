from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[2]
errors = []

def text(rel):
    p = ROOT / rel
    if not p.exists():
        errors.append(rel + " missing")
        return ""
    return p.read_text(encoding="utf-8", errors="replace")

welcome = text("lib/screens/welcome_page.dart")
if "LINKBALL_08B_PRIVACY_ENTRY" not in welcome:
    errors.append("Welcome privacy/account entry missing")
if "PrivacyAccountPage" not in welcome:
    errors.append("Welcome does not navigate to PrivacyAccountPage")

privacy_page = text("lib/screens/privacy_account_page.dart")
for marker in [
    "Hesabımı ve verilerimi sil",
    "AccountDeletionService.deleteCurrentAccount",
    "PrivacyConfig.privacyPolicyUrl",
    "PrivacyConfig.accountDeletionUrl",
    "SİL",
]:
    if marker not in privacy_page:
        errors.append("privacy page missing: " + marker)

service = text("lib/services/account_deletion_service.dart")
if "httpsCallable('deleteMyAccount')" not in service:
    errors.append("Flutter deleteMyAccount callable missing")

functions = text("functions/index.js")
for marker in [
    "LINKBALL_08B_ACCOUNT_DELETION_START",
    "exports.deleteMyAccount",
    "admin.auth().deleteUser(uid)",
    'updates["users/" + uid] = null',
    'updates["dailyScoreSessions/" + uid] = null',
    "LB_ACCOUNT_SHARED_COLLECTIONS",
    "LB_ACCOUNT_QUEUE_PATHS",
    '"Silinmiş oyuncu"',
]:
    if marker not in functions:
        errors.append("Functions deletion contract missing: " + marker)

config = text("lib/config/privacy_config.dart")
m = re.search(r"contactEmail = '([^']+)'", config)
if not m or "@" not in m.group(1):
    errors.append("Public privacy contact email not configured")

firebase = json.loads(text("firebase.json") or "{}")
hosting = firebase.get("hosting")
if not isinstance(hosting, dict):
    errors.append("Firebase Hosting config missing")
elif hosting.get("public") != "play_store_web":
    errors.append("Firebase Hosting public dir is not play_store_web")

for rel in [
    "play_store_web/privacy.html",
    "play_store_web/account-deletion.html",
    "docs/production/PRIVACY_POLICY.md",
    "docs/production/DATA_SAFETY_DRAFT.md",
    "docs/production/ACCOUNT_DELETION.md",
    "functions/test/account_deletion_contracts.test.js",
]:
    value = text(rel)
    if "__CONTACT_EMAIL__" in value:
        errors.append(rel + " still contains CONTACT placeholder")

if errors:
    print("[FAIL] STEP 08B.2 static verification")
    for error in errors:
        print("  -", error)
    raise SystemExit(1)

print("[PASS] In-app Privacy & Account entry exists")
print("[PASS] In-app destructive account deletion flow exists")
print("[PASS] Server-authoritative deleteMyAccount exists")
print("[PASS] Profile/daily/queue deletion markers exist")
print("[PASS] Shared match de-identification markers exist")
print("[PASS] Firebase Auth deletion marker exists")
print("[PASS] Privacy Policy web page exists")
print("[PASS] External account-deletion web resource exists")
print("[PASS] Data Safety evidence draft exists")
print("[PASS] Firebase Hosting points to play_store_web")
