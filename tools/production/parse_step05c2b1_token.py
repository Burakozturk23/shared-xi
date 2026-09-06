from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/05c"
LOG = REPORT / "app_check_debug_logcat.txt"
TOKEN_FILE = REPORT / "app_check_debug_token.local.txt"

patterns = [
    re.compile(
        r"Enter this debug secret into the allow list.*?:\s*"
        r"([0-9A-Fa-f-]{20,})",
        re.I,
    ),
    re.compile(
        r"debug secret.*?:\s*([0-9A-Fa-f-]{20,})",
        re.I,
    ),
    re.compile(
        r"App Check debug token.*?:\s*([0-9A-Fa-f-]{20,})",
        re.I,
    ),
]

def main():
    if not LOG.exists():
        raise SystemExit("[FAIL] app_check_debug_logcat.txt missing")

    text = LOG.read_text(encoding="utf-8", errors="replace")

    found = []
    for pattern in patterns:
        found.extend(pattern.findall(text))

    unique = []
    seen = set()
    for token in found:
        token = token.strip()
        if token not in seen:
            seen.add(token)
            unique.append(token)

    if not unique:
        print("[STOP] App Check debug token logcat icinde bulunamadi.")
        print("[INFO] Firebase App Check'te Android app kaydinin yapildigini kontrol et.")
        print("[INFO] Uygulamayi bir kez acip ana ekrana kadar bekle.")
        print("[INFO] Log dosyasi:")
        print("  reports/production/05c/app_check_debug_logcat.txt")
        print("[INFO] Su ifadeleri ara:")
        print("  DebugAppCheckProvider")
        print("  debug secret")
        raise SystemExit(2)

    token = unique[-1]
    TOKEN_FILE.write_text(token + "\n", encoding="utf-8", newline="\n")

    print()
    print("==========================================================")
    print("APP CHECK DEBUG TOKEN FOUND")
    print("==========================================================")
    print(token)
    print("==========================================================")
    print()
    print("[SECRET] Bu token'i ChatGPT'ye veya GitHub'a GONDERME.")
    print("[NEXT] Firebase Console > App Check > Linkball Android")
    print("       > Manage debug tokens altinda kaydet.")
    print("[SAFE] Enforcement hala OFF kalmali.")

if __name__ == "__main__":
    main()
