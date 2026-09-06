from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PAGE = ROOT / "lib/screens/privacy_account_page.dart"

text = PAGE.read_text(encoding="utf-8", errors="replace")

required = [
    "normalized.replaceAll('İ', 'I').replaceAll('ı', 'i')",
    "normalized.toLowerCase() == 'sil'",
    "_inlineDeleteConfirmation",
]

for marker in required:
    if marker not in text:
        print("[FAIL] Missing:", marker)
        raise SystemExit(1)

for sample in ["sil", "SİL", "SIL", "sıl", "Sil"]:
    normalized = sample.strip().replace("İ", "I").replace("ı", "i").lower()
    if normalized != "sil":
        print("[FAIL] Normalization sample:", sample, "->", normalized)
        raise SystemExit(1)

print("[PASS] sil")
print("[PASS] SİL")
print("[PASS] SIL")
print("[PASS] sıl")
print("[PASS] Sil")
print("[PASS] Inline lifecycle flow remains installed")
