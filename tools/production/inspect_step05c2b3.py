from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
LOCK = ROOT / "pubspec.lock"
PUBSPEC = ROOT / "pubspec.yaml"

TARGETS = {
    "firebase_core": "4.13.0",
    "firebase_auth": "6.5.7",
    "firebase_app_check": "0.4.6",
}

def lock_versions():
    result = {}
    if not LOCK.exists():
        return result
    lines = LOCK.read_text(encoding="utf-8", errors="replace").splitlines()
    current = None
    indent = None
    for line in lines:
        m = re.match(r"^  ([A-Za-z0-9_]+):\s*$", line)
        if m:
            current = m.group(1)
            continue
        if current in TARGETS:
            m = re.match(r'^\s+version:\s+"?([^"]+)"?\s*$', line)
            if m:
                result[current] = m.group(1)
                current = None
    return result

def main():
    print("==========================================================")
    print("CURRENT FLUTTERFIRE VERSIONS")
    print("==========================================================")
    versions = lock_versions()
    for name in TARGETS:
        print(f"{name:22} : {versions.get(name, '(not locked)')}")
    print()
    print("Target compatibility train:")
    for name, version in TARGETS.items():
        print(f"{name:22} : {version}")
    print()
    print("[INFO] Existing pubspec/pubspec.lock will be backed up before change.")

if __name__ == "__main__":
    main()
