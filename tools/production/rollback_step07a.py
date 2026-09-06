from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]

for rel in [
    "pubspec.yaml",
    "pubspec.lock",
    "android/settings.gradle.kts",
    "android/app/build.gradle.kts",
    "lib/main.dart",
    "lib/services/telemetry_service.dart",
]:
    path = ROOT / rel
    backup = path.with_suffix(
        path.suffix + ".step07a.bak"
    )

    if backup.exists():
        shutil.copy2(backup, path)
        print("[RESTORED]", rel)
    elif rel == "lib/services/telemetry_service.dart" and path.exists():
        path.unlink()
        print("[REMOVED]", rel)

print("[INFO] Run flutter pub get after rollback.")
