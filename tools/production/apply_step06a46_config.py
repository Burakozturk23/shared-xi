from pathlib import Path
import json
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = "com.burakozturk.linkball"

REPORT = ROOT / "reports/production/06a"
CONFIG = REPORT / "production.google-services.json"
GOOGLE = ROOT / "android/app/google-services.json"
OPTIONS = ROOT / "lib/firebase_options.dart"
APP_ID_FILE = REPORT / "firebase_created_app_id.txt"

def load_values():
    data = json.loads(CONFIG.read_text(encoding="utf-8"))
    project = data.get("project_info") or {}

    packages = []

    for client in data.get("client") or []:
        info = client.get("client_info") or {}
        android = info.get("android_client_info") or {}

        package = android.get("package_name")
        if package:
            packages.append(str(package))

        if package != PACKAGE:
            continue

        keys = client.get("api_key") or []
        api_key = ""
        if keys and isinstance(keys[0], dict):
            api_key = str(keys[0].get("current_key") or "")

        values = {
            "apiKey": api_key,
            "appId": str(info.get("mobilesdk_app_id") or ""),
            "messagingSenderId": str(project.get("project_number") or ""),
            "projectId": str(project.get("project_id") or ""),
            "storageBucket": str(project.get("storage_bucket") or ""),
        }

        missing = [k for k, v in values.items() if not v]
        if missing:
            raise RuntimeError(
                "Firebase config missing: " + ", ".join(missing)
            )

        return data, values, packages

    raise RuntimeError(
        "Downloaded SDK config does not contain "
        f"{PACKAGE}. Packages: {packages}"
    )

def patch_options(values):
    if not OPTIONS.exists():
        raise RuntimeError("lib/firebase_options.dart missing")

    original = OPTIONS.read_text(
        encoding="utf-8",
        errors="replace",
    )

    backup = OPTIONS.with_suffix(
        OPTIONS.suffix + ".step06a46.bak"
    )
    if not backup.exists():
        shutil.copy2(OPTIONS, backup)

    pattern = re.compile(
        r"  static const FirebaseOptions android = "
        r"FirebaseOptions\(.*?\n  \);",
        re.S,
    )

    block = (
        "  static const FirebaseOptions android = FirebaseOptions(\n"
        f"    apiKey: '{values['apiKey']}',\n"
        f"    appId: '{values['appId']}',\n"
        f"    messagingSenderId: '{values['messagingSenderId']}',\n"
        f"    projectId: '{values['projectId']}',\n"
        f"    storageBucket: '{values['storageBucket']}',\n"
        "  );"
    )

    updated, count = pattern.subn(
        block,
        original,
        count=1,
    )

    if count != 1:
        raise RuntimeError(
            "Android FirebaseOptions block not found"
        )

    with OPTIONS.open(
        "w",
        encoding="utf-8",
        newline="\n",
    ) as handle:
        handle.write(
            updated.replace("\r\n", "\n").replace("\r", "\n")
        )

def main():
    if not CONFIG.exists():
        raise SystemExit("[FAIL] production.google-services.json missing")
    if not APP_ID_FILE.exists():
        raise SystemExit("[FAIL] firebase_created_app_id.txt missing")

    _, values, packages = load_values()

    created_id = APP_ID_FILE.read_text(
        encoding="utf-8"
    ).strip()

    if values["appId"] != created_id:
        raise RuntimeError(
            "Created appId and downloaded config appId do not match: "
            f"{created_id} != {values['appId']}"
        )

    if GOOGLE.exists():
        backup = GOOGLE.with_suffix(
            GOOGLE.suffix + ".step06a46.bak"
        )
        if not backup.exists():
            shutil.copy2(GOOGLE, backup)

    shutil.copy2(CONFIG, GOOGLE)
    patch_options(values)

    result = {
        "project": "sharedix",
        "package": PACKAGE,
        "firebaseAppId": values["appId"],
        "createdBy": "06A.4.6",
    }
    (REPORT / "firebase_android_app.json").write_text(
        json.dumps(result, indent=2) + "\n",
        encoding="utf-8",
    )

    print("[PASS] Firebase package:", PACKAGE)
    print("[PASS] Firebase appId:", values["appId"])
    print("[FIX] google-services.json installed")
    print("[FIX] firebase_options.dart Android block synchronized")

if __name__ == "__main__":
    main()
