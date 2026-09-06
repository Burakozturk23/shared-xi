from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = "com.burakozturk.linkball"

GOOGLE = ROOT / "android/app/google-services.json"
OPTIONS = ROOT / "lib/firebase_options.dart"
GRADLE = ROOT / "android/app/build.gradle.kts"
REPORT = ROOT / "reports/production/07a"
REPORT.mkdir(parents=True, exist_ok=True)

errors = []
warnings = []

def firebase_android_from_google():
    data = json.loads(GOOGLE.read_text(encoding="utf-8"))
    project = data.get("project_info") or {}
    matches = []

    for client in data.get("client") or []:
        info = client.get("client_info") or {}
        android = info.get("android_client_info") or {}
        if android.get("package_name") != PACKAGE:
            continue

        keys = client.get("api_key") or []
        api_key = ""
        if keys and isinstance(keys[0], dict):
            api_key = str(keys[0].get("current_key") or "")

        matches.append({
            "package": str(android.get("package_name") or ""),
            "appId": str(info.get("mobilesdk_app_id") or ""),
            "projectId": str(project.get("project_id") or ""),
            "projectNumber": str(project.get("project_number") or ""),
            "apiKey": api_key,
            "storageBucket": str(project.get("storage_bucket") or ""),
            "services": client.get("services") or {},
        })

    return matches

def android_options_block():
    text = OPTIONS.read_text(encoding="utf-8", errors="replace")
    m = re.search(
        r"static const FirebaseOptions android = FirebaseOptions\((.*?)\n\s*\);",
        text,
        re.S,
    )
    if not m:
        return {}

    block = m.group(1)
    result = {}
    for key in [
        "apiKey",
        "appId",
        "messagingSenderId",
        "projectId",
        "storageBucket",
    ]:
        mm = re.search(
            rf"{key}\s*:\s*'([^']*)'",
            block,
        )
        if mm:
            result[key] = mm.group(1)
    return result

def redact(value):
    if not value:
        return "(empty)"
    if len(value) <= 10:
        return value
    return value[:6] + "..." + value[-4:]

def main():
    for path in [GOOGLE, OPTIONS, GRADLE]:
        if not path.exists():
            errors.append("Missing: " + str(path.relative_to(ROOT)))

    if errors:
        for e in errors:
            print("[FAIL]", e)
        raise SystemExit(1)

    matches = firebase_android_from_google()

    if len(matches) != 1:
        errors.append(
            f"Expected exactly one google-services client for {PACKAGE}; "
            f"found {len(matches)}"
        )
        local = {}
    else:
        local = matches[0]

    opts = android_options_block()
    if not opts:
        errors.append("Could not parse Android FirebaseOptions block")

    if local and opts:
        comparisons = [
            ("appId", "appId"),
            ("projectId", "projectId"),
            ("projectNumber", "messagingSenderId"),
            ("storageBucket", "storageBucket"),
            ("apiKey", "apiKey"),
        ]

        for g_key, o_key in comparisons:
            if local.get(g_key) != opts.get(o_key):
                errors.append(
                    f"Firebase config mismatch {g_key}: "
                    f"google-services={redact(local.get(g_key,''))} "
                    f"firebase_options={redact(opts.get(o_key,''))}"
                )

    gradle = GRADLE.read_text(encoding="utf-8", errors="replace")
    for marker in [
        'applicationId = "com.burakozturk.linkball"',
        'namespace = "com.burakozturk.linkball"',
        'id("com.google.gms.google-services")',
    ]:
        if marker not in gradle:
            errors.append("Android Gradle missing: " + marker)

    print("==========================================================")
    print("STEP 07A.3 LOCAL FIREBASE ANALYTICS CONFIG AUDIT")
    print("==========================================================")

    if local:
        print("[INFO] package      =", local["package"])
        print("[INFO] Firebase app =", local["appId"])
        print("[INFO] projectId    =", local["projectId"])
        print("[INFO] projectNo    =", local["projectNumber"])
        print("[INFO] apiKey       =", redact(local["apiKey"]))

        services = local.get("services") or {}
        if services:
            print("[INFO] google-services client services keys:")
            for key in sorted(services):
                print("  -", key)
        else:
            print("[INFO] google-services client has no explicit services block.")

    if errors:
        print()
        print("[FAIL] Local Firebase configuration is inconsistent:")
        for error in errors:
            print("  -", error)
        raise SystemExit(1)

    print()
    print("[PASS] google-services.json production package exact match")
    print("[PASS] firebase_options.dart Android appId/project exact match")
    print("[PASS] applicationId/namespace/google-services plugin exact match")

    (REPORT / "analytics_local_config_summary.txt").write_text(
        "\n".join([
            f"package={local.get('package','')}",
            f"appId={local.get('appId','')}",
            f"projectId={local.get('projectId','')}",
            f"projectNumber={local.get('projectNumber','')}",
        ]) + "\n",
        encoding="utf-8",
        newline="\n",
    )

if __name__ == "__main__":
    main()
