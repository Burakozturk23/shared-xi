from pathlib import Path
import json
import shutil

ROOT = Path(__file__).resolve().parents[2]
TOOLS = Path(__file__).resolve().parent

PUBSPEC = ROOT / "pubspec.yaml"
PUBLOCK = ROOT / "pubspec.lock"
FUNCTIONS_PKG = ROOT / "functions/package.json"
FUNCTIONS_TEST = ROOT / "functions/test/security_contracts.test.js"
INTEGRATION_TEST = ROOT / "integration_test/welcome_smoke_test.dart"
WORKFLOW = ROOT / ".github/workflows/linkball-ci.yml"

FILES = [
    PUBSPEC,
    PUBLOCK,
    FUNCTIONS_PKG,
    FUNCTIONS_TEST,
    INTEGRATION_TEST,
    WORKFLOW,
]

def backup_or_mark(path):
    path.parent.mkdir(parents=True, exist_ok=True)

    bak = path.with_suffix(path.suffix + ".step07b3.bak")
    created = path.with_suffix(path.suffix + ".step07b3.created")

    if path.exists():
        if not bak.exists():
            shutil.copy2(path, bak)
            print("[BACKUP]", bak.relative_to(ROOT))
    else:
        if not created.exists():
            created.write_text("created by STEP 07B.3\n", encoding="utf-8")
        print("[NEW]", path.relative_to(ROOT))

def write_lf(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as f:
        f.write(text.replace("\r\n", "\n").replace("\r", "\n"))

def patch_pubspec():
    text = PUBSPEC.read_text(encoding="utf-8", errors="replace")

    if "integration_test:" in text:
        print("[PASS] pubspec integration_test dependency already present")
        return

    anchor = """dev_dependencies:
  flutter_test:
    sdk: flutter
"""
    if anchor not in text:
        raise RuntimeError("pubspec flutter_test dev dependency anchor missing")

    replacement = anchor + """  integration_test:
    sdk: flutter
"""
    text = text.replace(anchor, replacement, 1)
    write_lf(PUBSPEC, text)
    print("[FIX] integration_test SDK dependency added.")

def patch_functions_package():
    data = json.loads(FUNCTIONS_PKG.read_text(encoding="utf-8"))

    scripts = data.setdefault("scripts", {})
    scripts["test"] = "node --test"

    engines = data.setdefault("engines", {})
    if str(engines.get("node", "")) != "24":
        print("[WARN] functions Node engine was not 24; preserving project value.")
    else:
        print("[PASS] Functions Node engine = 24")

    write_lf(
        FUNCTIONS_PKG,
        json.dumps(data, indent=2, ensure_ascii=False) + "\n",
    )
    print("[FIX] Functions test script added.")

def install_templates():
    mapping = [
        (
            TOOLS / "security_contracts.template.test.js",
            FUNCTIONS_TEST,
        ),
        (
            TOOLS / "welcome_smoke_test.template.dart",
            INTEGRATION_TEST,
        ),
        (
            TOOLS / "linkball-ci.template.yml",
            WORKFLOW,
        ),
    ]

    for source, target in mapping:
        if not source.exists():
            raise RuntimeError("Missing STEP 07B.3 template: " + source.name)

        write_lf(target, source.read_text(encoding="utf-8"))
        print("[FIX]", target.relative_to(ROOT))

def main():
    for required in [PUBSPEC, FUNCTIONS_PKG]:
        if not required.exists():
            raise RuntimeError(
                "Required file missing: " + str(required.relative_to(ROOT))
            )

    for path in FILES:
        backup_or_mark(path)

    patch_pubspec()
    patch_functions_package()
    install_templates()

    print()
    print("[OK] STEP 07B.3 source/CI patch complete.")
    print("[SAFE] No signing password or keystore was copied into the repo.")

if __name__ == "__main__":
    main()
