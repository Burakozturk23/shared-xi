from pathlib import Path
import json
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]

def run(args, check=True):
    try:
        r = subprocess.run(
            args,
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        raise RuntimeError(f"Command not found: {args[0]}")
    if check and r.returncode != 0:
        raise RuntimeError(
            f"Command failed ({r.returncode}): {' '.join(args)}\n"
            + (r.stderr or r.stdout)
        )
    return r

def read(rel):
    p = ROOT / rel
    if not p.exists():
        return ""
    return p.read_text(encoding="utf-8", errors="replace")

def resolve_project_id():
    # privacy_config.dart
    t = read("lib/config/privacy_config.dart")
    m = re.search(
        r"""https://([a-zA-Z0-9-]+)\.web\.app/(?:privacy|account-deletion)\.html""",
        t,
    )
    if m:
        return m.group(1)

    # firebase.json flutter config
    t = read("firebase.json")
    if t:
        try:
            data = json.loads(t)
            value = (
                data.get("flutter", {})
                .get("platforms", {})
                .get("android", {})
                .get("default", {})
                .get("projectId")
            )
            if isinstance(value, str) and value.strip():
                return value.strip()
        except Exception:
            pass

    # .firebaserc
    t = read(".firebaserc")
    if t:
        try:
            data = json.loads(t)
            value = data.get("projects", {}).get("default")
            if isinstance(value, str) and value.strip():
                return value.strip()
        except Exception:
            pass

    return ""

def main():
    print("=" * 70)
    print("LINKBALL STEP 08B.2.3 - FIREBASE HOSTING DIAGNOSTIC")
    print("=" * 70)
    print()

    blockers = []

    firebase_json = ROOT / "firebase.json"
    if not firebase_json.exists():
        blockers.append("firebase.json missing")
    else:
        try:
            data = json.loads(firebase_json.read_text(encoding="utf-8"))
            hosting = data.get("hosting")
            if not isinstance(hosting, dict):
                blockers.append("firebase.json hosting config missing")
            elif hosting.get("public") != "play_store_web":
                blockers.append(
                    "firebase.json hosting.public is not play_store_web"
                )
            else:
                print("[PASS] firebase.json hosting.public = play_store_web")
        except Exception as e:
            blockers.append(f"firebase.json parse failed: {e}")

    for rel, marker in [
        ("play_store_web/privacy.html", "Linkball Gizlilik"),
        ("play_store_web/account-deletion.html", "hesap ve veri silme"),
        ("play_store_web/index.html", "LINKBALL"),
    ]:
        p = ROOT / rel
        if not p.exists():
            blockers.append(f"{rel} missing")
            continue
        text = p.read_text(encoding="utf-8", errors="replace")
        if marker.lower() not in text.lower():
            blockers.append(f"{rel} does not contain expected marker")
        else:
            print(f"[PASS] {rel}")

    project = resolve_project_id()
    if not project:
        blockers.append("Firebase project id could not be resolved")
    else:
        print(f"[PASS] Firebase project resolved: {project}")

    # Firebase CLI
    firebase_cmd = "firebase.cmd" if sys.platform.startswith("win") else "firebase"
    version = run([firebase_cmd, "--version"], check=False)
    if version.returncode != 0:
        blockers.append("Firebase CLI is not available")
    else:
        print("[PASS] Firebase CLI:", version.stdout.strip())

    if project and version.returncode == 0:
        sites = run(
            [firebase_cmd, "hosting:sites:list", "--project", project],
            check=False,
        )
        print()
        print("--- firebase hosting:sites:list ---")
        print((sites.stdout or sites.stderr).strip())
        print("--- end sites list ---")
        print()
        if sites.returncode != 0:
            blockers.append(
                "Could not list Firebase Hosting sites for project"
            )

        projects = run(
            [firebase_cmd, "projects:list", "--json"],
            check=False,
        )
        if projects.returncode != 0:
            print("[WARN] firebase projects:list could not be verified.")
        elif project not in projects.stdout:
            blockers.append(
                f"Authenticated Firebase CLI cannot see project {project}"
            )
        else:
            print("[PASS] Firebase CLI can access the target project.")

    print()
    print("BLOCKERS:")
    if blockers:
        for item in blockers:
            print("  [FAIL]", item)
        print()
        print("Overall: STOP")
        raise SystemExit(2)

    print("  (none)")
    print()
    print("Overall: READY_TO_DEPLOY_HOSTING")
    print()
    print("[SAFE] No Firebase deployment was performed.")

    (ROOT / "reports/production/08b23").mkdir(
        parents=True, exist_ok=True
    )
    (ROOT / "reports/production/08b23/project_id.txt").write_text(
        project + "\n",
        encoding="utf-8",
    )

if __name__ == "__main__":
    main()
