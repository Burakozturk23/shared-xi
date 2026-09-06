from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]

FILES = [
    ROOT / "pubspec.yaml",
    ROOT / "pubspec.lock",
    ROOT / "functions/package.json",
    ROOT / "functions/test/security_contracts.test.js",
    ROOT / "integration_test/welcome_smoke_test.dart",
    ROOT / ".github/workflows/linkball-ci.yml",
]

for path in FILES:
    bak = path.with_suffix(path.suffix + ".step07b3.bak")
    created = path.with_suffix(path.suffix + ".step07b3.created")

    if bak.exists():
        shutil.copy2(bak, path)
        print("[RESTORED]", path.relative_to(ROOT))
    elif created.exists():
        if path.exists():
            path.unlink()
            print("[REMOVED]", path.relative_to(ROOT))

    if created.exists():
        created.unlink()

print("[INFO] STEP 07B.3 rollback completed.")
