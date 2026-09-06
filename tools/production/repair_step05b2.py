from __future__ import annotations

from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
FUNCTIONS = ROOT / "functions"
INDEX = FUNCTIONS / "index.js"

EXCLUDED_PARTS = {
    "node_modules",
    ".git",
    "build",
    "coverage",
}


def backup(path: Path, suffix: str) -> None:
    if not path.exists():
        return
    bak = path.with_suffix(path.suffix + suffix)
    if not bak.exists():
        shutil.copy2(path, bak)


def is_owned_js(path: Path) -> bool:
    try:
        rel = path.relative_to(FUNCTIONS)
    except ValueError:
        return False
    return not any(part in EXCLUDED_PARTS for part in rel.parts)


def normalize_lf(path: Path) -> bool:
    data = path.read_bytes()
    fixed = data.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    if fixed == data:
        return False
    path.write_bytes(fixed)
    return True


def main() -> None:
    if not INDEX.exists():
        raise SystemExit("[FAIL] functions/index.js bulunamadi.")

    backup(INDEX, ".step05b2.bak")

    checked = 0
    changed = 0

    for path in FUNCTIONS.rglob("*.js"):
        if not path.is_file() or not is_owned_js(path):
            continue
        checked += 1
        if normalize_lf(path):
            changed += 1
            print(f"[LF] {path.relative_to(ROOT)}")

    bad = []
    for path in FUNCTIONS.rglob("*.js"):
        if not path.is_file() or not is_owned_js(path):
            continue
        try:
            data = path.read_bytes()
        except PermissionError as exc:
            bad.append(
                f"Owned JS permission error: {path.relative_to(ROOT)}: {exc}"
            )
            continue

        if b"\r\n" in data or b"\r" in data:
            bad.append(f"CRLF remains: {path.relative_to(ROOT)}")

    if bad:
        print("[FAIL] Project-owned Functions LF verification")
        for item in bad:
            print("  -", item)
        raise SystemExit(1)

    text = INDEX.read_text(encoding="utf-8")
    for marker in [
        "exports.startDailyScoreSession",
        "exports.submitDailyScore",
        "dailyScoreSessions/",
        "serverValidated",
    ]:
        if marker not in text:
            raise RuntimeError(f"05B marker missing: {marker}")

    print(
        f"[PASS] Project-owned Functions JS checked={checked} "
        f"changed={changed}"
    )
    print("[PASS] node_modules was completely excluded.")
    print("[PASS] Step 05B server-authority markers present.")
    print("[SAFE] No Firebase deploy was performed.")


if __name__ == "__main__":
    main()
