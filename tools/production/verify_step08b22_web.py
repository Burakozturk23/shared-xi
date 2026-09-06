from pathlib import Path
import json
import re
import ssl
import urllib.request
import urllib.error

ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / "lib/config/privacy_config.dart"
FIREBASE_JSON = ROOT / "firebase.json"
REPORT = ROOT / "reports/production/08b22"
REPORT.mkdir(parents=True, exist_ok=True)

def read_text(path):
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="replace")

def parse_dart_url(text, field):
    # Accept both Dart quote styles and arbitrary whitespace.
    pattern = rf"""{re.escape(field)}\s*=\s*["']([^"']+)["']"""
    match = re.search(pattern, text)
    return match.group(1).strip() if match else ""

def firebase_project_id():
    if not FIREBASE_JSON.exists():
        return ""

    try:
        data = json.loads(FIREBASE_JSON.read_text(encoding="utf-8"))
    except Exception:
        return ""

    candidates = []

    flutter = data.get("flutter")
    if isinstance(flutter, dict):
        platforms = flutter.get("platforms")
        if isinstance(platforms, dict):
            android = platforms.get("android")
            if isinstance(android, dict):
                default = android.get("default")
                if isinstance(default, dict):
                    candidates.append(default.get("projectId"))

    candidates.append(data.get("projectId"))

    for value in candidates:
        if isinstance(value, str) and value.strip():
            return value.strip()

    # Last-resort known Firebase rc project alias.
    rc = ROOT / ".firebaserc"
    if rc.exists():
        try:
            rc_data = json.loads(rc.read_text(encoding="utf-8"))
            projects = rc_data.get("projects", {})
            if isinstance(projects, dict):
                default = projects.get("default")
                if isinstance(default, str) and default.strip():
                    return default.strip()
        except Exception:
            pass

    return ""

def resolve_urls():
    config_text = read_text(CONFIG)

    privacy = parse_dart_url(config_text, "privacyPolicyUrl")
    deletion = parse_dart_url(config_text, "accountDeletionUrl")
    source = "privacy_config.dart"

    if privacy and deletion:
        return privacy, deletion, source

    project = firebase_project_id()
    if not project:
        return "", "", "unresolved"

    base = f"https://{project}.web.app"
    return (
        f"{base}/privacy.html",
        f"{base}/account-deletion.html",
        "firebase project fallback",
    )

def fetch(url):
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Linkball-Step08B22-WebVerify/1.0",
            "Cache-Control": "no-cache",
        },
    )

    context = ssl.create_default_context()

    with urllib.request.urlopen(
        req,
        timeout=30,
        context=context,
    ) as response:
        status = getattr(response, "status", response.getcode())
        body = response.read().decode("utf-8", errors="replace")
        final_url = response.geturl()
        return status, body, final_url

def verify_page(label, url, markers):
    print(f"[CHECK] {label}")
    print(f"        {url}")

    try:
        status, body, final_url = fetch(url)
    except urllib.error.HTTPError as error:
        print(f"[FAIL] HTTP {error.code}: {label}")
        return False
    except Exception as error:
        print(f"[FAIL] {label} request error: {error}")
        return False

    if status != 200:
        print(f"[FAIL] {label}: HTTP {status}")
        return False

    lowered = body.lower()
    if not any(marker.lower() in lowered for marker in markers):
        print(
            f"[FAIL] {label}: HTTP 200 but expected Linkball "
            "page marker was not found."
        )
        return False

    print(f"[PASS] {label}: HTTP 200")
    if final_url != url:
        print(f"[INFO] Final URL: {final_url}")
    return True

def main():
    print("=" * 68)
    print("LINKBALL STEP 08B.2.2 - PUBLIC WEB VERIFY FIX")
    print("=" * 68)
    print()

    privacy, deletion, source = resolve_urls()

    if not privacy or not deletion:
        print("[FAIL] Public URLs could not be resolved.")
        print("[INFO] Checked privacy_config.dart, firebase.json and .firebaserc.")
        raise SystemExit(2)

    print(f"[PASS] Public URLs resolved via: {source}")
    print()

    ok_privacy = verify_page(
        "Privacy Policy",
        privacy,
        [
            "Linkball Gizlilik Politikası",
            "Linkball Gizlilik",
        ],
    )
    print()
    ok_deletion = verify_page(
        "Account deletion resource",
        deletion,
        [
            "Linkball hesap ve veri silme talebi",
            "hesap ve veri silme",
        ],
    )

    report = [
        "LINKBALL STEP 08B.2.2 - PUBLIC WEB VERIFY",
        "",
        f"source={source}",
        f"privacy_url={privacy}",
        f"deletion_url={deletion}",
        f"privacy_ok={ok_privacy}",
        f"deletion_ok={ok_deletion}",
    ]
    (REPORT / "public_web_verify.txt").write_text(
        "\n".join(report) + "\n",
        encoding="utf-8",
        newline="\n",
    )

    print()
    if not (ok_privacy and ok_deletion):
        print("[STOP] Public web content is not fully verified.")
        print(
            "[INFO] If STEP 08B.2 deploy previously failed, send that "
            "deployment error instead of redeploying blindly."
        )
        raise SystemExit(3)

    print("=" * 68)
    print("[OK] STEP 08B.2.2 PUBLIC WEB VERIFY PASS")
    print("=" * 68)
    print()
    print("[PASS] Privacy Policy is publicly reachable.")
    print("[PASS] Account deletion resource is publicly reachable.")
    print()
    print("[NEXT] Test the in-app Gizlilik & Hesap screen on Android.")

if __name__ == "__main__":
    main()
