from pathlib import Path
import re
import uuid

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/05c"
LOG = REPORT / "app_check_debug_logcat.txt"
TOKEN_FILE = REPORT / "app_check_debug_token.local.txt"

# Strict UUID pattern, then validate version==4 and RFC4122 variant.
UUID_CANDIDATE = re.compile(
    r"\b[0-9a-fA-F]{8}-"
    r"[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{12}\b"
)

DEBUG_LINE_HINTS = (
    "DebugAppCheckProvider",
    "debug secret",
    "App Check debug token",
)

def is_uuid_v4(value: str) -> bool:
    try:
        parsed = uuid.UUID(value)
    except ValueError:
        return False
    return (
        parsed.version == 4
        and parsed.variant == uuid.RFC_4122
        and str(parsed) == value.lower()
    )

def main():
    if not LOG.exists():
        raise SystemExit("[FAIL] app_check_debug_logcat.txt missing")

    text = LOG.read_text(
        encoding="utf-8",
        errors="replace",
    )

    candidates = []

    for line in text.splitlines():
        if not any(hint.lower() in line.lower() for hint in DEBUG_LINE_HINTS):
            continue
        for raw in UUID_CANDIDATE.findall(line):
            value = raw.lower()
            candidates.append((value, line))

    valid = []
    seen = set()

    for value, line in candidates:
        if not is_uuid_v4(value):
            print("[SKIP] Non-v4 UUID candidate ignored:", value)
            continue
        if value in seen:
            continue
        seen.add(value)
        valid.append((value, line))

    if not valid:
        print("[STOP] Gercek UUID v4 App Check debug token bulunamadi.")
        print()
        print("Firebase Console artik UUID v4 istiyor.")
        print("Dogru token logcat'te su satira benzer:")
        print(
            "D DebugAppCheckProvider: Enter this debug secret into "
            "the allow list ...: xxxxxxxx-xxxx-4xxx-8xxx-xxxxxxxxxxxx"
        )
        print()
        print("NOT:")
        print(
            "123a4567-b89c-12d3-e456-789012345678 gibi ornek/test "
            "degerlerini Firebase'e girme."
        )
        print()
        print("Log:")
        print("  reports/production/05c/app_check_debug_logcat.txt")
        raise SystemExit(2)

    token, source_line = valid[-1]

    TOKEN_FILE.write_text(
        token + "\n",
        encoding="utf-8",
        newline="\n",
    )

    print()
    print("==========================================================")
    print("VALID APP CHECK DEBUG TOKEN (UUID v4)")
    print("==========================================================")
    print(token)
    print("==========================================================")
    print()
    print("[PASS] UUID version = 4")
    print("[PASS] RFC 4122 variant")
    print("[PASS] Source = Android DebugAppCheckProvider log")
    print()
    print("[SECRET] Bu token'i ChatGPT/GitHub'a GONDERME.")
    print(
        "[NEXT] Firebase Console > App Check > Linkball Android "
        "> Manage debug tokens altinda kaydet."
    )
    print("[SAFE] Enforcement OFF kalmali.")

if __name__ == "__main__":
    main()
