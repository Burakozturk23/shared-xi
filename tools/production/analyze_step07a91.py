from pathlib import Path
import re
from datetime import datetime

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/07a91"

TIME = re.compile(
    r"^(?P<m>\d{2})-(?P<d>\d{2}) "
    r"(?P<h>\d{2}):(?P<mi>\d{2}):(?P<s>\d{2})\.(?P<ms>\d{3})"
)
SKIP = re.compile(r"Skipped\s+(\d+)\s+frames", re.I)

def ts(line):
    m = TIME.match(line)
    if not m:
        return None
    now = datetime.now()
    return datetime(
        now.year, int(m.group("m")), int(m.group("d")),
        int(m.group("h")), int(m.group("mi")), int(m.group("s")),
        int(m.group("ms")) * 1000,
    )

def metric(text, label):
    m = re.search(rf"\[Startup\] {re.escape(label)} (\d+)ms", text)
    return int(m.group(1)) if m else None

def parse(path):
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    text = "\n".join(lines)
    welcome = metric(text, "Welcome navigation")
    runtime = metric(text, "RuntimeV3 ready")
    repo = metric(text, "Repository ready")

    welcome_ts = next((ts(x) for x in lines if "[Startup] Welcome navigation" in x), None)
    pre, post = [], []
    for line in lines:
        m = SKIP.search(line)
        if not m:
            continue
        n = int(m.group(1))
        t = ts(line)
        if welcome_ts is None or t is None or t <= welcome_ts:
            pre.append(n)
        else:
            post.append(n)

    return {
        "runtime": runtime,
        "welcome": welcome,
        "repo": repo,
        "pre": max(pre) if pre else 0,
        "post": max(post) if post else 0,
        "ready": "[RuntimeV3] READY" in text,
        "deferred": "[Startup] Auth deferred" in text,
    }

def show(name, d):
    print(name)
    print(f"  Runtime V3:            {d['runtime']} ms")
    print(f"  Welcome:               {d['welcome']} ms")
    print(f"  Repository:            {d['repo']} ms")
    print(f"  Max skip PRE-Welcome:  {d['pre']}")
    print(f"  Max skip POST-Welcome: {d['post']}")
    print(f"  RuntimeV3 READY:       {d['ready']}")
    print(f"  Auth deferred:         {d['deferred']}")

def main():
    first = parse(REPORT / "first_install.log")
    warm = parse(REPORT / "warm_launch.log")

    print("=" * 64)
    print("LINKBALL STEP 07A.9.1 - AUTH-DECOUPLED STARTUP SUMMARY")
    print("=" * 64)
    print()
    show("FIRST INSTALL", first)
    print()
    show("WARM LAUNCH", warm)

    findings = []
    if first["welcome"] is None or first["welcome"] > 10000:
        findings.append(f"First-install Welcome >10s or missing: {first['welcome']}ms")
    if warm["welcome"] is None or warm["welcome"] > 2000:
        findings.append(f"Warm Welcome >2s or missing: {warm['welcome']}ms")
    if not first["deferred"] or not warm["deferred"]:
        findings.append("Auth deferred marker missing")
    if max(first["pre"], warm["pre"]) >= 120:
        findings.append("120+ skipped-frame stall occurs BEFORE Welcome")
    if max(first["post"], warm["post"]) >= 120:
        findings.append("120+ skipped-frame stall occurs AFTER Welcome")

    print()
    if first["repo"] and first["welcome"] and first["repo"] > first["welcome"]:
        print("[PASS] First-install Repository completes after Welcome.")
    if warm["repo"] and warm["welcome"] and warm["repo"] > warm["welcome"]:
        print("[PASS] Warm Repository completes after Welcome.")

    print()
    if findings:
        print("[WARN] Remaining findings:")
        for f in findings:
            print("  -", f)
        print("Overall: NEEDS_NEXT_PERF_STEP")
    else:
        print("[PASS] Auth is removed from startup critical path.")
        print("Overall: PASS")

if __name__ == "__main__":
    main()
