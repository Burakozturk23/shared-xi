from pathlib import Path
import uuid

ROOT = Path(__file__).resolve().parents[2]
TOKEN_FILE = (
    ROOT
    / "reports/production/05c/app_check_debug_token.local.txt"
)

def main():
    if not TOKEN_FILE.exists():
        raise SystemExit("[INFO] No local token file yet.")

    value = TOKEN_FILE.read_text(
        encoding="utf-8",
        errors="replace",
    ).strip().lower()

    try:
        parsed = uuid.UUID(value)
    except ValueError:
        print("[FAIL] Existing token is not a UUID.")
        TOKEN_FILE.unlink(missing_ok=True)
        print("[FIX] Invalid local token file removed.")
        raise SystemExit(2)

    if (
        parsed.version != 4
        or parsed.variant != uuid.RFC_4122
    ):
        print("[FAIL] Existing token is not UUID v4:", value)
        TOKEN_FILE.unlink(missing_ok=True)
        print("[FIX] Invalid local token file removed.")
        raise SystemExit(2)

    print("[PASS] Existing local token is UUID v4.")

if __name__ == "__main__":
    main()
