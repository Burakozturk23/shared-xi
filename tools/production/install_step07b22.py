from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
TOOLS = Path(__file__).resolve().parent

TEST = ROOT / "test/widget_test.dart"
WORKFLOW = ROOT / ".github/workflows/linkball-ci.yml"

TEST_TEMPLATE = TOOLS / "widget_test.template.dart"
WF_TEMPLATE = TOOLS / "linkball-ci.template.yml"

def backup_or_mark(path: Path, suffix: str):
    path.parent.mkdir(parents=True, exist_ok=True)

    bak = path.with_suffix(path.suffix + suffix + ".bak")
    created = path.with_suffix(path.suffix + suffix + ".created")

    if path.exists():
        if not bak.exists():
            shutil.copy2(path, bak)
            print("[BACKUP]", bak.relative_to(ROOT))
    else:
        created.write_text("created\n", encoding="utf-8")
        print("[NEW]", path.relative_to(ROOT))

def write_lf(path: Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as f:
        f.write(text.replace("\r\n", "\n").replace("\r", "\n"))

def main():
    if not TEST_TEMPLATE.exists() or not WF_TEMPLATE.exists():
        raise RuntimeError("STEP 07B.2.2 template missing")

    if not TEST.exists():
        raise RuntimeError("test/widget_test.dart missing")

    current_test = TEST.read_text(encoding="utf-8", errors="replace")

    already = "STEP 07B.2.2" in current_test
    legacy = (
        "SharedXIApp launches and shows welcome screen" in current_test
        or "SHARED XI" in current_test
    )

    if not already and not legacy:
        raise RuntimeError(
            "widget_test.dart is neither the known legacy test nor "
            "the STEP 07B.2.2 test. Refusing to overwrite unknown test."
        )

    backup_or_mark(TEST, ".step07b22")
    backup_or_mark(WORKFLOW, ".step07b22")

    write_lf(TEST, TEST_TEMPLATE.read_text(encoding="utf-8"))
    write_lf(WORKFLOW, WF_TEMPLATE.read_text(encoding="utf-8"))

    print("[FIX] widget_test.dart updated to current Linkball Welcome contract.")
    print("[FIX] GitHub Actions CI baseline installed.")

if __name__ == "__main__":
    main()
