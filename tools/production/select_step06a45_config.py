from pathlib import Path
import json
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = "com.burakozturk.linkball"
REPORT = ROOT / "reports/production/06a"
GOOGLE = ROOT / "android/app/google-services.json"
OPTIONS = ROOT / "lib/firebase_options.dart"

def read_config(path):
    data = json.loads(path.read_text(encoding="utf-8"))
    packages = []

    for client in data.get("client") or []:
        info = client.get("client_info") or {}
        android = info.get("android_client_info") or {}
        package = android.get("package_name")
        if package:
            packages.append(str(package))

    return data, packages

def values_for_target(data):
    project = data.get("project_info") or {}

    for client in data.get("client") or []:
        info = client.get("client_info") or {}
        android = info.get("android_client_info") or {}

        if android.get("package_name") != PACKAGE:
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
                "Matching Firebase config missing: "
                + ", ".join(missing)
            )

        return values

    raise RuntimeError("Target Android client not found")

def patch_options(values):
    if not OPTIONS.exists():
        raise RuntimeError("firebase_options.dart missing")

    original = OPTIONS.read_text(
        encoding="utf-8",
        errors="replace",
    )

    backup = OPTIONS.with_suffix(
        OPTIONS.suffix + ".step06a45.bak"
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
    candidates = sorted(
        REPORT.glob("candidate_*.google-services.json")
    )

    if not candidates:
        raise SystemExit(
            "[FAIL] No candidate SDK config files were downloaded"
        )

    matches = []

    for candidate in candidates:
        try:
            data, packages = read_config(candidate)
        except Exception as exc:
            print("[SKIP]", candidate.name, "=>", exc)
            continue

        print(
            "[CHECK]",
            candidate.name,
            "=>",
            ", ".join(packages) or "(none)",
        )

        if PACKAGE in packages:
            matches.append((candidate, data))

    if not matches:
        print()
        print(
            "[FAIL] None of the Firebase Android apps is registered as:"
        )
        print(" ", PACKAGE)
        print(
            "[INFO] In that case the earlier 06A.2 registration did not "
            "actually create the production app."
        )
        raise SystemExit(2)

    if len(matches) > 1:
        raise SystemExit(
            "[FAIL] Multiple Firebase Android apps match production package"
        )

    candidate, data = matches[0]
    values = values_for_target(data)

    if GOOGLE.exists():
        backup = GOOGLE.with_suffix(
            GOOGLE.suffix + ".step06a45.bak"
        )
        if not backup.exists():
            shutil.copy2(GOOGLE, backup)

    shutil.copy2(candidate, GOOGLE)
    patch_options(values)

    result = {
        "package": PACKAGE,
        "firebaseAppId": values["appId"],
        "sourceCandidate": candidate.name,
        "repairedBy": "06A.4.5",
    }

    (REPORT / "firebase_android_app.json").write_text(
        json.dumps(result, indent=2) + "\n",
        encoding="utf-8",
    )

    print()
    print("[PASS] Exact Firebase package match:", PACKAGE)
    print("[PASS] Firebase appId:", values["appId"])
    print("[FIX] google-services.json synchronized")
    print("[FIX] firebase_options.dart Android block synchronized")

if __name__ == "__main__":
    main()
