from __future__ import annotations

from pathlib import Path
import json
import os
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = "com.burakozturk.linkball"
PROJECT = "sharedix"

GOOGLE = ROOT / "android/app/google-services.json"
OPTIONS = ROOT / "lib/firebase_options.dart"
REPORT = ROOT / "reports/production/06a"
REPORT.mkdir(parents=True, exist_ok=True)

def resolve_firebase_cli() -> str:
    candidates = []

    # Python PATH resolution on Windows: npm global commands are commonly .cmd.
    for name in ("firebase.cmd", "firebase.exe", "firebase"):
        found = shutil.which(name)
        if found:
            candidates.append(found)

    # Common npm global locations.
    appdata = os.environ.get("APPDATA")
    if appdata:
        candidates.extend([
            str(Path(appdata) / "npm" / "firebase.cmd"),
            str(Path(appdata) / "npm" / "firebase.exe"),
        ])

    localappdata = os.environ.get("LOCALAPPDATA")
    if localappdata:
        candidates.extend([
            str(Path(localappdata) / "npm" / "firebase.cmd"),
        ])

    seen = set()
    for candidate in candidates:
        if not candidate:
            continue
        norm = os.path.normcase(os.path.abspath(candidate))
        if norm in seen:
            continue
        seen.add(norm)
        if Path(candidate).exists():
            return str(Path(candidate))

    raise RuntimeError(
        "Firebase CLI executable bulunamadi. "
        "BAT firebase'i calistirabiliyorsa, 'where firebase' ciktisini gonder."
    )

FIREBASE = resolve_firebase_cli()

def run(args, check=True):
    cmd = [FIREBASE, *args]
    print("[RUN]", " ".join(cmd))
    result = subprocess.run(
        cmd,
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
            f"Command failed ({result.returncode}): {' '.join(cmd)}"
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
        if package or app_id:
            found.append({"package": package, "app_id": app_id})
        for child in value.values():
            found.extend(walk_apps(child))
    elif isinstance(value, list):
        for child in value:
            found.extend(walk_apps(child))
    return found

def resolve_target_app_id():
    result = run(
        [
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
            "firebase apps:list failed. Firebase login/project access kontrol et."
        )

    data = parse_json_maybe(result.stdout)
    if data:
        for app in walk_apps(data):
            if (
                str(app.get("package") or "") == PACKAGE
                and app.get("app_id")
            ):
                return str(app["app_id"])

    # Use Step 06A.2 report as a fallback for Firebase CLI versions that omit
    # Android package metadata from apps:list.
    prior = REPORT / "firebase_android_app.json"
    if prior.exists():
        try:
            info = json.loads(prior.read_text(encoding="utf-8"))
            if (
                info.get("package") == PACKAGE
                and info.get("firebaseAppId")
            ):
                print(
                    "[INFO] Using Step 06A.2 Firebase appId fallback:",
                    info["firebaseAppId"],
                )
                return str(info["firebaseAppId"])
        except Exception:
            pass

    raise RuntimeError(
        f"Firebase Android app for {PACKAGE} could not be resolved."
    )

def read_google(path):
    data = json.loads(path.read_text(encoding="utf-8"))
    packages = []
    for client in data.get("client") or []:
        info = client.get("client_info") or {}
        android = info.get("android_client_info") or {}
        package = android.get("package_name")
        if package:
            packages.append(str(package))
    return data, packages

def extract_android_values(data):
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

        missing = [key for key, value in values.items() if not value]
        if missing:
            raise RuntimeError(
                "Downloaded Firebase config missing: " + ", ".join(missing)
            )

        return values

    raise RuntimeError(
        "Downloaded google-services.json package mismatch."
    )

def patch_options(values):
    if not OPTIONS.exists():
        raise RuntimeError("lib/firebase_options.dart not found.")

    original = OPTIONS.read_text(encoding="utf-8", errors="replace")
    backup = OPTIONS.with_suffix(OPTIONS.suffix + ".step06a42.bak")
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
        handle.write(
            updated.replace("\r\n", "\n").replace("\r", "\n")
        )

def main():
    print("[PASS] Firebase CLI resolved:")
    print(" ", FIREBASE)

    version = run(["--version"], check=False)
    if version.returncode != 0:
        raise RuntimeError("Firebase CLI exists but could not run.")

    app_id = resolve_target_app_id()
    print("[PASS] Target Firebase Android appId:", app_id)

    temp = REPORT / "google-services.production.tmp.json"
    temp.unlink(missing_ok=True)

    run(
        [
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
        raise RuntimeError(
            "Firebase CLI did not create the temporary SDK config."
        )

    data, packages = read_google(temp)
    print("[INFO] Downloaded package names:", ", ".join(packages) or "(none)")

    if PACKAGE not in packages:
        raise RuntimeError(
            f"Firebase returned wrong package. Expected {PACKAGE}; got {packages}"
        )

    values = extract_android_values(data)

    if GOOGLE.exists():
        backup = GOOGLE.with_suffix(GOOGLE.suffix + ".step06a42.bak")
        if not backup.exists():
            shutil.copy2(GOOGLE, backup)

    shutil.copy2(temp, GOOGLE)
    temp.unlink(missing_ok=True)

    patch_options(values)

    (REPORT / "firebase_android_app.json").write_text(
        json.dumps(
            {
                "project": PROJECT,
                "package": PACKAGE,
                "firebaseAppId": app_id,
                "repairedBy": "06A.4.2",
                "firebaseCli": FIREBASE,
            },
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )

    print("[FIX] google-services.json synchronized.")
    print("[FIX] firebase_options.dart Android block synchronized.")
    print("[OK] Firebase package =", PACKAGE)
    print("[OK] Firebase appId   =", values["appId"])

if __name__ == "__main__":
    main()
