from pathlib import Path
import os
import shutil

ROOT = Path(__file__).resolve().parents[2]

def main():
    base = ROOT / ".step05c11_symlink_test"
    target = base / "target.txt"
    link = base / "link.txt"

    shutil.rmtree(base, ignore_errors=True)
    base.mkdir(parents=True, exist_ok=True)
    target.write_text("ok", encoding="utf-8")

    try:
        os.symlink(target, link)
        if not link.exists():
            raise RuntimeError("symlink created but cannot be resolved")
        print("[PASS] Windows symlink support is available.")
    except OSError as exc:
        print("[FAIL] Windows symlink support is not available.")
        print("[INFO]", exc)
        raise SystemExit(2)
    finally:
        shutil.rmtree(base, ignore_errors=True)

if __name__ == "__main__":
    main()
