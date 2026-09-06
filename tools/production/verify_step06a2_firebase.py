from pathlib import Path
import json
ROOT = Path(__file__).resolve().parents[2]
PACKAGE = "com.burakozturk.linkball"
data = json.loads((ROOT / "android/app/google-services.json").read_text(encoding="utf-8"))
app_ids = []
for client in data.get("client") or []:
    info = client.get("client_info") or {}
    android = info.get("android_client_info") or {}
    if android.get("package_name") == PACKAGE:
        app_ids.append(info.get("mobilesdk_app_id"))
if not app_ids:
    raise SystemExit("[FAIL] google-services.json package mismatch")
options = (ROOT / "lib/firebase_options.dart").read_text(encoding="utf-8")
if f"appId: '{app_ids[0]}'" not in options:
    raise SystemExit("[FAIL] firebase_options.dart Android appId mismatch")
print("[PASS] 06A.2 Firebase config matches", PACKAGE)
