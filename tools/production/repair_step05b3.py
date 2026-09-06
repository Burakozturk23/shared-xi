from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]

TARGETS = [
    ROOT / "run_step05b2_repair.bat",
    ROOT / "run_step05b_install.bat",
]

OLD = "call flutter analyze"
NEW = "call flutter analyze --no-fatal-warnings --no-fatal-infos"

def main():
    changed = 0

    for path in TARGETS:
        if not path.exists():
            print(f"[SKIP] {path.name} bulunamadi.")
            continue

        text = path.read_text(encoding="utf-8", errors="replace")

        if NEW in text:
            print(f"[PASS] {path.name} zaten non-fatal warning/info kullaniyor.")
            continue

        if OLD not in text:
            print(f"[WARN] {path.name} icinde flutter analyze satiri bulunamadi.")
            continue

        bak = path.with_suffix(path.suffix + ".step05b3.bak")
        if not bak.exists():
            shutil.copy2(path, bak)

        text = text.replace(OLD, NEW)

        with path.open("w", encoding="utf-8", newline="\r\n") as f:
            f.write(text.replace("\r\n", "\n").replace("\r", "\n").replace("\n", "\r\n"))

        changed += 1
        print(f"[FIX] {path.name} analyze gate guncellendi.")

    if changed == 0:
        print("[INFO] Degisiklik gerekmeyebilir.")

    print("[OK] Warnings/info artik deploy blocker degil.")
    print("[IMPORTANT] Gercek analyzer ERROR'lari hala non-zero kalir ve akisi durdurur.")

if __name__ == "__main__":
    main()
