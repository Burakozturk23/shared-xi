from __future__ import annotations

from pathlib import Path
import json
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = "com.burakozturk.linkball"
PROJECT = "sharedix"

GOOGLE = ROOT / "android/app/google-services.json"
OPTIONS = ROOT / "lib/firebase_options.dart"
REPORT = ROOT / "reports/production/06a"
REPORT.mkdir(parents=True, exist_ok=True)

def run(args, check=True):
    print("[RUN]", " ".join(args))
    result = subprocess.run(
        args,
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if result.stdout.strip():
        print(result.stdout.strip())
    if result.stderr.strip():
        print(result.stderr.strip())
    if check and result.returncode != 0:
        raise RuntimeError(
            f"Command failed ({result.returncode}): {' '.join(args)}"
        )
    return result

def parse_json_maybe(text):
    text = text.strip()
    try:
        return json.loads(text)
    except Exception:
        start = text.find("{")
        end = text.rfind("}")
        if start >= 0 and end > start:
            try:
                return json.loads(text[start:end + 1])
            except Exception:
                return None
    return None

def walk_apps(value):
    found = []
    if isinstance(value, dict):
        package = (
            value.get("packageName")
            or value.get("package_name")
            or value.get("androidPackageName")
        )
        app_id = value.get("appId") or value.get("app_id")
        platform = value.get("platform") or value.get("platformId")
        if package or app_id:
            found.append(
                {
                    "package": package,
                    "app_id": app_id,
                    "platform": platform,
                }
            )
        for child in value.values():
            found.extend(walk_apps(child))
    elif isinstance(value, list):
        for child in value:
            found.extend(walk_apps(child))
    return found

def resolve_target_app_id():
    result = run(
        [
            "firebase",
            "apps:list",
            "android",
            "--project",
            PROJECT,
            "--json",
        ],
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(
            "Firebase apps:list failed. Check firebase login/project access."
        )

    data = parse_json_maybe(result.stdout)
    if data is None:
        raise RuntimeError("Could not parse firebase apps:list JSON output.")

    apps = walk_apps(data)

    # Exact production package must win.
    for app in apps:
        if str(app.get("package") or "") == PACKAGE and app.get("app_id"):
            return str(app["app_id"])

    # Some CLI versions omit packageName from apps:list.
    report = REPORT / "firebase_android_app.json"
    if report.exists():
        try:
            previous = json.loads(report.read_text(encoding="utf-8"))
            if previous.get("package") == PACKAGE and previous.get("firebaseAppId"):
                candidate = str(previous["firebaseAppId"])
                print(
                    "[INFO] apps:list package metadata unavailable; "
                    "using prior 06A Firebase appId:",
                    candidate,
                )
                return candidate
        except Exception:
            pass

    raise RuntimeError(
        f"No Firebase Android app found for package {PACKAGE}. "
        "Re-run 06A.2 and send its full output."
    )

def package_names_from_google(path):
    data = json.loads(path.read_text(encoding="utf-8"))
    names = []
    for client in data.get("client") or []:
        info = client.get("client_info") or {}
        android = info.get("android_client_info") or {}
        name = android.get("package_name")
        if name:
            names.append(str(name))
    return data, names

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
                "Downloaded Firebase config is missing: " + ", ".join(missing)
            )
        return values

    raise RuntimeError(
        f"Downloaded google-services.json does not contain {PACKAGE}"
    )

def patch_firebase_options(values):
    if not OPTIONS.exists():
        raise RuntimeError("lib/firebase_options.dart not found")

    original = OPTIONS.read_text(encoding="utf-8", errors="replace")
    backup = OPTIONS.with_suffix(OPTIONS.suffix + ".step06a41.bak")
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
            "firebase_options.dart Android FirebaseOptions block not found."
        )

    with OPTIONS.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(updated.replace("\r\n", "\n").replace("\r", "\n"))

def main():
    version = run(["firebase", "--version"], check=False)
    if version.returncode != 0:
        raise RuntimeError("Firebase CLI not found.")

    app_id = resolve_target_app_id()
    print("[PASS] Target Firebase Android appId:", app_id)

    temp = REPORT / "google-services.production.tmp.json"
    if temp.exists():
        temp.unlink()

    run(
        [
            "firebase",
            "apps:sdkconfig",
            "android",
            app_id,
            "-o",
            str(temp),
            "--project",
            PROJECT,
        ]
    )

    if not temp.exists():
        raise RuntimeError("Firebase CLI did not create temporary SDK config.")

    data, packages = package_names_from_google(temp)
    print("[INFO] Downloaded package names:", ", ".join(packages) or "(none)")

    if PACKAGE not in packages:
        raise RuntimeError(
            "Firebase returned a config for the wrong Android package. "
            f"Expected {PACKAGE}; got {packages}."
        )

    values = extract_values(data)

    if GOOGLE.exists():
        backup = GOOGLE.with_suffix(GOOGLE.suffix + ".step06a41.bak")
        if not backup.exists():
            shutil.copy2(GOOGLE, backup)

    shutil.copy2(temp, GOOGLE)
    temp.unlink(missing_ok=True)

    patch_firebase_options(values)

    (REPORT / "firebase_android_app.json").write_text(
        json.dumps(
            {
                "project": PROJECT,
                "package": PACKAGE,
                "firebaseAppId": app_id,
                "repairedBy": "06A.4.1",
            },
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )

    print("[FIX] android/app/google-services.json synchronized.")
    print("[FIX] lib/firebase_options.dart Android block synchronized.")
    print("[OK] Firebase package =", PACKAGE)
    print("[OK] Firebase appId   =", values["appId"])

if __name__ == "__main__":
    main()
