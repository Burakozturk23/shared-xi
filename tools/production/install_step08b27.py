from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
PAGE = ROOT / "lib/screens/privacy_account_page.dart"

OLD = """  bool get _deletePhraseMatches {
    return _deleteController.text.trim().toUpperCase() == 'SİL';
  }
"""

NEW = """  bool get _deletePhraseMatches {
    var normalized = _deleteController.text.trim();
    normalized = normalized.replaceAll('İ', 'I').replaceAll('ı', 'i');
    return normalized.toLowerCase() == 'sil';
  }
"""

def main():
    if not PAGE.exists():
        raise RuntimeError("lib/screens/privacy_account_page.dart missing")

    text = PAGE.read_text(encoding="utf-8", errors="replace")

    if NEW in text:
        print("[PASS] STEP 08B.2.7 already installed.")
        return

    if OLD not in text:
        raise RuntimeError(
            "Expected STEP 08B.2.6 delete phrase block was not found."
        )

    bak = PAGE.with_suffix(PAGE.suffix + ".step08b27.bak")
    if not bak.exists():
        shutil.copy2(PAGE, bak)
        print("[BACKUP]", PAGE.relative_to(ROOT))

    text = text.replace(OLD, NEW, 1)

    with PAGE.open("w", encoding="utf-8", newline="\n") as f:
        f.write(text.replace("\r\n", "\n").replace("\r", "\n"))

    print("[FIX] Delete confirmation accepts Turkish/English keyboard variants.")
    print("[OK] STEP 08B.2.7 source patch complete.")

if __name__ == "__main__":
    main()
