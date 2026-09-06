from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
LOG = ROOT / "reports/production/05c/gradle_debug_build.log"
OUT = ROOT / "reports/production/05c/gradle_first_error.txt"

def score(line: str) -> int:
    s = line.lower()
    patterns = [
        ("execution failed for task", 100),
        ("what went wrong:", 95),
        ("failure: build failed with an exception", 90),
        ("could not resolve all files", 85),
        ("could not determine the dependencies", 85),
        ("a problem occurred evaluating project", 85),
        ("error:", 80),
        ("exception", 60),
        ("failed", 40),
    ]
    best = 0
    for pattern, value in patterns:
        if pattern in s:
            best = max(best, value)
    return best

def main():
    if not LOG.exists():
        raise SystemExit("[FAIL] gradle_debug_build.log missing")

    lines = LOG.read_text(
        encoding="utf-8",
        errors="replace",
    ).splitlines()

    candidates = []
    for i, line in enumerate(lines):
        value = score(line)
        if value:
            candidates.append((value, i))

    if not candidates:
        text = "\n".join(lines[-120:])
        OUT.write_text(text + "\n", encoding="utf-8", newline="\n")
        print("[WARN] Specific error marker not found.")
        print("[INFO] Last 120 log lines written to:")
        print("  reports/production/05c/gradle_first_error.txt")
        return

    # Highest-value earliest marker.
    candidates.sort(key=lambda x: (-x[0], x[1]))
    _, index = candidates[0]

    start = max(0, index - 12)
    end = min(len(lines), index + 45)

    block = lines[start:end]
    text = "\n".join(block)

    OUT.write_text(text + "\n", encoding="utf-8", newline="\n")

    print("==========================================================")
    print("FIRST RELEVANT GRADLE ERROR BLOCK")
    print("==========================================================")
    print(text)
    print("==========================================================")
    print()
    print("[INFO] Saved to:")
    print("  reports/production/05c/gradle_first_error.txt")

if __name__ == "__main__":
    main()
