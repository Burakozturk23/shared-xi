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

    for name in ("firebase.cmd", "firebase.exe", "firebase"):
        found = shutil.which(name)
        if found:
            candidates.append(found)

    appdata = os.environ.get("APPDATA")
    if appdata:
        candidates.append(str(Path(appdata) / "npm" / "firebase.cmd"))

    localappdata = os.environ.get("LOCALAPPDATA")
    if localappdata:
        candidates.append(str(Path(localappdata) / "npm" / "firebase.cmd"))

    seen = set()
    for candidate in candidates:
        if not candidate:
            continue
        key = os.path.normcase(os.path.abspath(candidate))
        if key in seen:
            continue
        seen.add(key)
        if Path(candidate).exists():
            return str(Path(candidate))

    raise RuntimeError(
        "Firebase CLI executable bulunamadi. "
        "'where firebase' ciktisini gonder."
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

def collect_android_app_ids(value):
    ids = []

    if isinstance(value, dict):
        platform = str(
            value.get("platform")
            or value.get("platformId")
            or ""
        ).upper()

        app_id = (
            value.get("appId")
            or value.get("app_id")
            or value.get("appIdValue")
        )

        # apps:list android already scopes results, but keep platform filter
        # permissive for different Firebase CLI JSON shapes.
        if app_id and (not platform or platform == "ANDROID"):
            ids.append(str(app_id))

        for child in value.values():
            ids.extend(collect_android_app_ids(child))

    elif isinstance(value, list):
        for child in value:
            ids.extend(collect_android_app_ids(child))

    # Stable de-duplication
    out = []
    seen = set()
    for app_id in ids:
        if app_id not in seen:
            seen.add(app_id)
            out.append(app_id)
    return out

def packages_from_config(path: Path):
    data = json.loads(path.read_text(encoding="utf-8"))
    packages = []
    for client in data.get("client") or []:
        info = client.get("client_info") or {}
        android = info.get("android_client_info") or {}
        package = android.get("package_name")
        if package:
            packages.append(str(package))
    return data, packages

def resolve_target_by_sdkconfig():
    result = run(
        [
            "apps:list",
            "android",
            "--project",
            PROJECT,
            "--json",
        ]
    )

    data = parse_json_maybe(result.stdout)
    if data is None:
        raise RuntimeError(
            "Firebase apps:list JSON parse edilemedi."
        )

    app_ids = collect_android_app_ids(data)

    if not app_ids:
        raise RuntimeError(
            "Firebase Android appId listesi bos."
        )

    print(f"[INFO] Android Firebase app count: {len(app_ids)}")

    matches = []

    for index, app_id in enumerate(app_ids, start=1):
        temp = REPORT / f"candidate_{index}.google-services.json"
        temp.unlink(missing_ok=True)

        print()
        print(f"[CHECK {index}/{len(app_ids)}] {app_id}")

        result = run(
            [
                "apps:sdkconfig",
                "android",
                app_id,
                "-o",
                str(temp),
                "--project",
                PROJECT,
            ],
            check=False,
        )

        if result.returncode != 0 or not temp.exists():
            print("[SKIP] sdkconfig indirilemedi.")
            temp.unlink(missing_ok=True)
            continue

        try:
            config, packages = packages_from_config(temp)
        except Exception as exc:
            print("[SKIP] Config parse edilemedi:", exc)
            temp.unlink(missing_ok=True)
            continue

        print(
            "[INFO] package(s):",
            ", ".join(packages) if packages else "(none)",
        )

        if PACKAGE in packages:
            matches.append((app_id, temp, config))
        else:
            temp.unlink(missing_ok=True)

    if not matches:
        raise RuntimeError(
            "Firebase projesindeki Android app config'leri tarandi "
            f"ama {PACKAGE} bulunamadi. "
            "06A.2 kaydi gercekte olusmamis olabilir."
        )

    if len(matches) > 1:
        raise RuntimeError(
            f"{PACKAGE} icin birden fazla Firebase Android app bulundu. "
            "Otomatik secim guvenli degil."
        )

    app_id, temp, config = matches[0]
    print()
    print("[PASS] Exact package match found:")
    print("  appId  =", app_id)
    print("  package=", PACKAGE)

    return app_id, temp, config

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

        missing = [k for k, v in values.items() if not v]
        if missing:
            raise RuntimeError(
                "Firebase config alanlari eksik: " + ", ".join(missing)
            )

        return values

    raise RuntimeError("Exact package client block not found.")

def patch_options(values):
    if not OPTIONS.exists():
        raise RuntimeError("lib/firebase_options.dart bulunamadi.")

    original = OPTIONS.read_text(encoding="utf-8", errors="replace")
    backup = OPTIONS.with_suffix(OPTIONS.suffix + ".step06a43.bak")
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
            "firebase_options.dart Android FirebaseOptions block bulunamadi."
        )

    with OPTIONS.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(
            updated.replace("\r\n", "\n").replace("\r", "\n")
        )

def cleanup_candidates(keep: Path | None = None):
    for path in REPORT.glob("candidate_*.google-services.json"):
        if keep is not None and path.resolve() == keep.resolve():
            continue
        path.unlink(missing_ok=True)

def main():
    print("[PASS] Firebase CLI:", FIREBASE)

    version = run(["--version"], check=False)
    if version.returncode != 0:
        raise RuntimeError("Firebase CLI calistirilamadi.")

    app_id, temp, config = resolve_target_by_sdkconfig()

    values = extract_android_values(config)

    if GOOGLE.exists():
        backup = GOOGLE.with_suffix(
            GOOGLE.suffix + ".step06a43.bak"
        )
        if not backup.exists():
            shutil.copy2(GOOGLE, backup)

    shutil.copy2(temp, GOOGLE)
    patch_options(values)

    (REPORT / "firebase_android_app.json").write_text(
        json.dumps(
            {
                "project": PROJECT,
                "package": PACKAGE,
                "firebaseAppId": app_id,
                "repairedBy": "06A.4.3",
                "resolver": "enumerate_sdkconfig",
            },
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )

    cleanup_candidates()

    print()
    print("[FIX] google-services.json exact production app ile degistirildi.")
    print("[FIX] firebase_options.dart Android block senkronize edildi.")
    print("[OK] Firebase package =", PACKAGE)
    print("[OK] Firebase appId   =", values["appId"])

if __name__ == "__main__":
    main()
