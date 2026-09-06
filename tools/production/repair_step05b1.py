from __future__ import annotations

from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
FUNCTIONS_DIR = ROOT / "functions"
INDEX = FUNCTIONS_DIR / "index.js"
INSTALLER = ROOT / "tools/production/install_step05b.py"

def backup(path: Path, suffix: str) -> None:
    if not path.exists():
        return
    bak = path.with_suffix(path.suffix + suffix)
    if not bak.exists():
        shutil.copy2(path, bak)

def normalize_lf(path: Path) -> bool:
    data = path.read_bytes()
    fixed = data.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    if fixed == data:
        return False
    path.write_bytes(fixed)
    return True

def patch_installer() -> bool:
    if not INSTALLER.exists():
        print("[INFO] install_step05b.py bulunamadi; current JS yine de duzeltilecek.")
        return False

    original = INSTALLER.read_text(encoding="utf-8")
    text = original

    helper_marker = "def write_lf(path: Path, text: str) -> None:"

    if helper_marker not in text:
        anchor = "def require_files() -> None:"
        if anchor not in text:
            print("[WARN] 05B installer helper anchor bulunamadi; installer patch atlandi.")
            return False

        helper = (
            "def write_lf(path: Path, text: str) -> None:\n"
            "    normalized = text.replace('\\\\r\\\\n', '\\\\n').replace('\\\\r', '\\\\n')\n"
            "    with path.open('w', encoding='utf-8', newline='\\\\n') as handle:\n"
            "        handle.write(normalized)\n\n"
        )
        text = text.replace(anchor, helper + anchor, 1)

    replacements = {
        'FUNCTIONS.write_text(patched_functions, encoding="utf-8")':
            'write_lf(FUNCTIONS, patched_functions)',
        'SERVICE.write_text(patched_service, encoding="utf-8")':
            'write_lf(SERVICE, patched_service)',
        'CONTROLLER.write_text(patched_controller, encoding="utf-8")':
            'write_lf(CONTROLLER, patched_controller)',
        'FIREBASE_JSON.write_text(patched_firebase, encoding="utf-8")':
            'write_lf(FIREBASE_JSON, patched_firebase)',
        'RULES.write_text(RULES_TEXT, encoding="utf-8")':
            'write_lf(RULES, RULES_TEXT)',
    }

    for old, new in replacements.items():
        if old in text:
            text = text.replace(old, new)

    if text == original:
        print("[INFO] 05B installer zaten LF-safe veya degisiklik gerekmiyor.")
        return False

    backup(INSTALLER, ".step05b1.bak")
    normalized = text.replace("\r\n", "\n").replace("\r", "\n")
    with INSTALLER.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(normalized)

    print("[FIX] tools/production/install_step05b.py LF-safe hale getirildi.")
    return True

def main() -> None:
    if not INDEX.exists():
        raise SystemExit(f"[FAIL] Eksik: {INDEX}")

    backup(INDEX, ".step05b1.bak")

    changed = 0
    for path in FUNCTIONS_DIR.rglob("*.js"):
        if path.is_file() and normalize_lf(path):
            changed += 1
            print(f"[LF] {path.relative_to(ROOT)}")

    patch_installer()

    bad = []
    for path in FUNCTIONS_DIR.rglob("*.js"):
        data = path.read_bytes()
        if b"\r\n" in data or b"\r" in data:
            bad.append(str(path.relative_to(ROOT)))

    if bad:
        raise RuntimeError(f"LF normalization failed: {bad}")

    print(f"[PASS] Functions JS LF normalization complete. changed={changed}")
    print("[SAFE] No Firebase deploy was performed.")

if __name__ == "__main__":
    main()
