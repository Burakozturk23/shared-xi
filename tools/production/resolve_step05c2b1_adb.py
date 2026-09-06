from pathlib import Path
import os
import shutil

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/05c"
REPORT.mkdir(parents=True, exist_ok=True)
OUT = REPORT / "adb_path.txt"

def add(candidates, path):
    if not path:
        return
    p = Path(path)
    try:
        p = p.expanduser()
    except Exception:
        pass
    s = str(p)
    if s not in candidates:
        candidates.append(s)

def main():
    candidates = []

    found = shutil.which("adb.exe") or shutil.which("adb")
    if found:
        add(candidates, found)

    for env_name in ("ANDROID_SDK_ROOT", "ANDROID_HOME"):
        sdk = os.environ.get(env_name)
        if sdk:
            add(candidates, Path(sdk) / "platform-tools" / "adb.exe")

    localappdata = os.environ.get("LOCALAPPDATA")
    if localappdata:
        add(
            candidates,
            Path(localappdata) / "Android" / "Sdk" / "platform-tools" / "adb.exe",
        )

    userprofile = os.environ.get("USERPROFILE")
    if userprofile:
        add(
            candidates,
            Path(userprofile)
            / "AppData"
            / "Local"
            / "Android"
            / "Sdk"
            / "platform-tools"
            / "adb.exe",
        )

    # Common alternative locations.
    program_files = os.environ.get("ProgramFiles")
    if program_files:
        add(
            candidates,
            Path(program_files)
            / "Android"
            / "Android Studio"
            / "platform-tools"
            / "adb.exe",
        )

    existing = [Path(p) for p in candidates if Path(p).exists()]

    if not existing:
        print("[FAIL] adb.exe otomatik bulunamadi.")
        print("[INFO] Kontrol edilen yollar:")
        for candidate in candidates:
            print("  -", candidate)
        raise SystemExit(2)

    adb = existing[0]
    OUT.write_text(str(adb) + "\n", encoding="utf-8", newline="\n")

    print("[PASS] adb.exe bulundu:")
    print(" ", adb)
    print("[INFO] PATH degistirilmedi.")
    print("[INFO] Yol kaydedildi:")
    print(" ", OUT.relative_to(ROOT))

if __name__ == "__main__":
    main()
