from pathlib import Path
import json
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = "com.burakozturk.linkball"
REPORT = ROOT / "reports/production/06a"
GOOGLE = ROOT / "android/app/google-services.json"
OPTIONS = ROOT / "lib/firebase_options.dart"

def config_packages(path: Path):
    data = json.loads(path.read_text(encoding="utf-8"))
    packages = []
    for client in data.get("client") or []:
        info = client.get("client_info") or {}
        android = info.get("android_client_info") or {}
        package = android.get("package_name")
        if package:
            packages.append(str(package))
    return data, packages

def extract_values(data):
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
                "Matching Firebase config missing fields: " + ", ".join(missing)
            )
        return values

    raise RuntimeError("Matching Android client block not found")

def patch_options(values):
    original = OPTIONS.read_text(encoding="utf-8", errors="replace")
    backup = OPTIONS.with_suffix(OPTIONS.suffix + ".step06a44.bak")
    if not backup.exists():
        shutil.copy2(OPTIONS, backup)

    pattern = re.compile(
        r"  static const FirebaseOptions android = FirebaseOptions\(.*?\n  \);",
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

    updated, count = pattern.subn(block, original, count=1)
    if count != 1:
        raise RuntimeError(
            "firebase_options.dart Android FirebaseOptions block not found"
        )

    with OPTIONS.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(updated.replace("\r\n", "\n").replace("\r", "\n"))

def main():
    candidates = sorted(REPORT.glob("candidate_*.google-services.json"))

    if not candidates:
        raise SystemExit("[FAIL] No candidate Firebase configs downloaded")

    matches = []

    for candidate in candidates:
        try:
            data, packages = config_packages(candidate)
        except Exception as exc:
            print("[SKIP]", candidate.name, "parse:", exc)
            continue

        print("[CHECK]", candidate.name, "=>", ", ".join(packages) or "(none)")
        if PACKAGE in packages:
            matches.append((candidate, data))

    if not matches:
        raise SystemExit(
            f"[FAIL] No downloaded Firebase config matches {PACKAGE}"
        )

    if len(matches) > 1:
        raise SystemExit(
            f"[FAIL] Multiple Firebase configs match {PACKAGE}; aborting"
        )

    candidate, data = matches[0]
    values = extract_values(data)

    if GOOGLE.exists():
        backup = GOOGLE.with_suffix(GOOGLE.suffix + ".step06a44.bak")
        if not backup.exists():
            shutil.copy2(GOOGLE, backup)

    shutil.copy2(candidate, GOOGLE)
    patch_options(values)

    result = {
        "package": PACKAGE,
        "firebaseAppId": values["appId"],
        "sourceCandidate": candidate.name,
        "repairedBy": "06A.4.4",
    }
    (REPORT / "firebase_android_app.json").write_text(
        json.dumps(result, indent=2) + "\n",
        encoding="utf-8",
    )

    print("[PASS] Exact package match:", PACKAGE)
    print("[PASS] Firebase appId:", values["appId"])
    print("[FIX] google-services.json synchronized")
    print("[FIX] firebase_options.dart Android block synchronized")

if __name__ == "__main__":
    main()
