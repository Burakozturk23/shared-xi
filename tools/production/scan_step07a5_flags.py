from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / "lib"
REPORT = ROOT / "reports/production/07a5"
REPORT.mkdir(parents=True, exist_ok=True)
OUT = REPORT / "runtime_v3_flag_scan.txt"

FLAGS = [
    "LINKBALL_SQLITE_V3",
    "LINKBALL_SQLITE_GAMEPLAY_V3",
    "LINKBALL_SQLITE_PARITY",
]

CALL_RE = re.compile(
    r"bool\.fromEnvironment\(\s*['\"](?P<flag>"
    + "|".join(re.escape(x) for x in FLAGS)
    + r")['\"]\s*(?:,\s*defaultValue\s*:\s*(?P<default>true|false)\s*)?\)",
    re.S,
)

def line_no(text, pos):
    return text.count("\n", 0, pos) + 1

def main():
    findings = []

    for path in LIB.rglob("*.dart"):
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue

        for m in CALL_RE.finditer(text):
            findings.append({
                "flag": m.group("flag"),
                "default": m.group("default") or "(implicit false)",
                "file": str(path.relative_to(ROOT)),
                "line": line_no(text, m.start()),
            })

    print("==========================================================")
    print("STEP 07A.5 - RUNTIME V3 FLAG SCAN")
    print("==========================================================")

    for flag in FLAGS:
        hits = [x for x in findings if x["flag"] == flag]
        if not hits:
            print(f"[WARN] {flag}: declaration not found by static scan")
            continue
        for hit in hits:
            print(
                f"[INFO] {hit['flag']} default={hit['default']} "
                f"at {hit['file']}:{hit['line']}"
            )

    if not findings:
        print("[WARN] No bool.fromEnvironment Runtime V3 declarations found.")
        print("[INFO] The runtime may wrap dart-defines in another helper.")

    lines = []
    for hit in findings:
        lines.append(
            f"{hit['flag']}|{hit['default']}|{hit['file']}|{hit['line']}"
        )

    OUT.write_text(
        "\n".join(lines) + ("\n" if lines else ""),
        encoding="utf-8",
        newline="\n",
    )

    print()
    print("[INFO] This step does NOT change defaults.")
    print("[INFO] The release probe below supplies the production V3 defines explicitly.")

if __name__ == "__main__":
    main()
