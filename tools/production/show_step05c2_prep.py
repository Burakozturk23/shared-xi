from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
FINGERPRINTS = (
    ROOT
    / "reports/production/06a/upload_key_fingerprints.txt"
)

print("==========================================================")
print("STEP 05C.1 -> 05C.2 CONSOLE PREP")
print("==========================================================")
print()
print("Firebase Android package:")
print("  com.burakozturk.linkball")
print()

if FINGERPRINTS.exists():
    text = FINGERPRINTS.read_text(
        encoding="utf-8",
        errors="replace",
    )

    sha256 = []
    for line in text.splitlines():
        if "SHA256:" in line.upper():
            sha256.append(line.strip())

    if sha256:
        print("Local upload certificate SHA-256:")
        for line in sha256:
            print(" ", line)
        print()
        print(
            "NOTE: This is the UPLOAD certificate. "
            "After Play App Signing is enabled, also register the "
            "Google Play APP SIGNING certificate SHA-256."
        )
    else:
        print(
            "[WARN] upload certificate report exists but SHA-256 "
            "was not parsed."
        )
else:
    print(
        "[WARN] reports/production/06a/upload_key_fingerprints.txt "
        "not found."
    )

print()
print("Next console phase will:")
print("1) Link Play Integrity API to Firebase/Cloud project sharedix")
print("2) Register com.burakozturk.linkball in Firebase App Check")
print("3) Register Play app-signing SHA-256 when available")
print("4) Run DEBUG build and register its App Check debug token")
print("5) Test Daily Challenge with enforcement still OFF")
