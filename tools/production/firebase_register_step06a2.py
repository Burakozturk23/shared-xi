from pathlib import Path
import json
import re
import subprocess

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
        raise RuntimeError("Command failed: " + " ".join(args))
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

def walk(value):
    found = []
    if isinstance(value, dict):
        package = (
            value.get("packageName")
            or value.get("package_name")
            or value.get("androidPackageName")
        )
        app_id = value.get("appId") or value.get("app_id")
        if package or app_id:
            found.append((package, app_id))
        for child in value.values():
            found.extend(walk(child))
    elif isinstance(value, list):
        for child in value:
            found.extend(walk(child))
    return found

def find_existing():
    result = run(
        ["firebase", "apps:list", "android", "--project", PROJECT, "--json"],
        check=False,
    )
    if result.returncode != 0:
        return None
    data = parse_json_maybe(result.stdout)
    if not data:
        return None
    for package, app_id in walk(data):
        if str(package or "") == PACKAGE and app_id:
            return str(app_id)
    return None

def create_app():
    result = run(
        [
            "firebase",
            "apps:create",
            "-a",
            PACKAGE,
            "android",
            "Linkball Android",
            "--project",
            PROJECT,
            "--json",
        ]
    )
    data = parse_json_maybe(result.stdout)
    if data:
        for package, app_id in walk(data):
            if app_id and (not package or str(package) == PACKAGE):
                return str(app_id)
    return find_existing()

def patch_options(values):
    original = OPTIONS.read_text(encoding="utf-8", errors="replace")
    backup = OPTIONS.with_suffix(OPTIONS.suffix + ".step06a.bak")
    if not backup.exists():
        backup.write_text(original, encoding="utf-8", newline="\n")

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
        raise RuntimeError("firebase_options.dart Android block not found")

    with OPTIONS.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(updated.replace("\r\n", "\n").replace("\r", "\n"))

def main():
    if run(["firebase", "--version"], check=False).returncode != 0:
        raise RuntimeError(
            "Firebase CLI not found. Run: npm install -g firebase-tools ; firebase login"
        )

    app_id = find_existing()
    if app_id:
        print("[PASS] Existing Firebase Android app:", app_id)
    else:
        print("[INFO] Creating Firebase Android app for", PACKAGE)
        app_id = create_app()

    if not app_id:
        raise RuntimeError("Firebase Android appId could not be resolved")

    if GOOGLE.exists():
        backup = GOOGLE.with_suffix(GOOGLE.suffix + ".step06a.bak")
        if not backup.exists():
            backup.write_bytes(GOOGLE.read_bytes())

    run(
        [
            "firebase",
            "apps:sdkconfig",
            "android",
            app_id,
            "-o",
            str(GOOGLE),
            "--project",
            PROJECT,
        ]
    )

    data = json.loads(GOOGLE.read_text(encoding="utf-8"))
    project = data.get("project_info") or {}
    values = None

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
        break

    if not values:
        raise RuntimeError("Target package not found in google-services.json")

    patch_options(values)

    (REPORT / "firebase_android_app.json").write_text(
        json.dumps(
            {
                "project": PROJECT,
                "package": PACKAGE,
                "firebaseAppId": app_id,
            },
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )

    print("[OK] google-services.json updated")
    print("[OK] firebase_options.dart Android block updated")
    print("[OK] Firebase Android appId:", app_id)

if __name__ == "__main__":
    main()
