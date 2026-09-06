from pathlib import Path
import os
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
ADB_PATH_FILE = ROOT / "reports/production/05c/adb_path.txt"

def fail(message, code=1):
    print(message)
    raise SystemExit(code)

def main():
    if not ADB_PATH_FILE.exists():
        fail("[FAIL] reports/production/05c/adb_path.txt missing")

    adb = (
        ADB_PATH_FILE
        .read_text(encoding="utf-8", errors="replace")
        .strip()
        .strip('"')
    )

    if not adb:
        fail("[FAIL] saved adb path is empty")

    adb_path = Path(adb)
    if not adb_path.exists():
        fail(f"[FAIL] saved adb path does not exist: {adb}")

    result = subprocess.run(
        [str(adb_path), "devices"],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )

    print(result.stdout)

    devices = []
    for line in result.stdout.splitlines():
        line = line.strip()
        if not line or line.startswith("List of devices"):
            continue

        parts = line.split()
        if len(parts) >= 2 and parts[1] == "device":
            devices.append(parts[0])

    if len(devices) != 1:
        fail(
            "[STOP] Expected exactly one Android test device/emulator; "
            f"found {len(devices)}"
        )

    serial = devices[0]
    print("[PASS] Test device:", serial)
    print()

    # STEP 07B.3.2:
    # On Windows, Flutter is normally flutter.bat. Python's CreateProcess
    # cannot execute .bat files directly. Run Flutter through cmd.exe so the
    # shell resolves flutter.bat exactly as a normal terminal does.
    if os.name == "nt":
        cmd = shutil.which("cmd.exe") or os.environ.get(
            "COMSPEC",
            r"C:\Windows\System32\cmd.exe",
        )

        flutter_cmd = [
            "flutter",
            "test",
            "integration_test/welcome_smoke_test.dart",
            "-d",
            serial,
            "--reporter",
            "expanded",
        ]

        command_line = subprocess.list2cmdline(flutter_cmd)

        print("[RUN] Flutter integration smoke via cmd.exe...")
        print("      flutter test integration_test/welcome_smoke_test.dart "
              f"-d {serial} --reporter expanded")
        print()

        proc = subprocess.run(
            [cmd, "/d", "/s", "/c", command_line],
            cwd=ROOT,
        )
    else:
        flutter = shutil.which("flutter")
        if not flutter:
            fail("[FAIL] flutter executable was not found in PATH")

        print("[RUN] Flutter integration smoke...")
        print()

        proc = subprocess.run(
            [
                flutter,
                "test",
                "integration_test/welcome_smoke_test.dart",
                "-d",
                serial,
                "--reporter",
                "expanded",
            ],
            cwd=ROOT,
        )

    raise SystemExit(proc.returncode)

if __name__ == "__main__":
    main()
