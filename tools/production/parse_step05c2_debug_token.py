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
        r"App Check debug token.*?[':\s]\s*"
        r"([0-9A-Fa-f-]{20,})",
        re.I,
    ),
    re.compile(
        r"debug secret.*?:\s*([0-9A-Fa-f-]{20,})",
        re.I,
    ),
]

def main():
    if not LOG.exists():
        raise SystemExit("[FAIL] app_check_debug_logcat.txt missing")

    text = LOG.read_text(
        encoding="utf-8",
        errors="replace",
    )

    tokens = []
    for pattern in patterns:
        tokens.extend(pattern.findall(text))

    unique = []
    seen = set()
    for token in tokens:
        token = token.strip()
        if token not in seen:
            seen.add(token)
            unique.append(token)

    if not unique:
        print("[FAIL] App Check debug token was not found in adb logcat.")
        print("[INFO] Try launching the Android debug app once more.")
        print(
            "[INFO] Search the Flutter/adb log for: "
            "'Enter this debug secret into the allow list'"
        )
        raise SystemExit(2)

    if len(unique) > 1:
        print("[WARN] Multiple debug tokens found; using newest match.")

    token = unique[-1]

    TOKEN_FILE.write_text(
        token + "\n",
        encoding="utf-8",
        newline="\n",
    )

    print()
    print("==========================================================")
    print("APP CHECK DEBUG TOKEN")
    print("==========================================================")
    print(token)
    print("==========================================================")
    print()
    print(
        "[SECRET] Do NOT send this token to ChatGPT, GitHub, "
        "or anyone else."
    )
    print(
        "[INFO] Register it in Firebase Console > Security > "
        "App Check > Apps > Linkball Android > Manage debug tokens."
    )
    print(
        "[INFO] Local copy saved to "
        "reports/production/05c/app_check_debug_token.local.txt"
    )
    print(
        "[INFO] Delete the local token file after registration if desired."
    )

if __name__ == "__main__":
    main()
