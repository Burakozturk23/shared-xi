from pathlib import Path
import re
from datetime import datetime, timedelta

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/07a9"
OUT = REPORT / "startup_verify_summary.txt"

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
        now.year,
        int(m.group("m")),
        int(m.group("d")),
        int(m.group("h")),
        int(m.group("mi")),
        int(m.group("s")),
        int(m.group("ms")) * 1000,
    )

def metric(text, label):
    m = re.search(rf"\[Startup\] {re.escape(label)} (\d+)ms", text)
    return int(m.group(1)) if m else None

def parse(path):
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    text = "\n".join(lines)

    welcome_ms = metric(text, "Welcome navigation")
    runtime_ms = None
    m = re.search(r"\[Startup\] RuntimeV3 ready (\d+)ms", text)
    if m:
        runtime_ms = int(m.group(1))

    repo_ms = None
    m = re.search(r"\[Startup\] Repository ready (\d+)ms", text)
    if m:
        repo_ms = int(m.group(1))

    welcome_ts = None
    for line in lines:
        if "[Startup] Welcome navigation" in line:
            welcome_ts = ts(line)
            break

    pre = []
    post = []
    all_skips = []

    for line in lines:
        m = SKIP.search(line)
        if not m:
            continue
        value = int(m.group(1))
        all_skips.append(value)
        t = ts(line)

        if welcome_ts is None or t is None or t <= welcome_ts:
            pre.append(value)
        else:
            post.append(value)

    return {
        "runtime": runtime_ms,
        "welcome": welcome_ms,
        "repo": repo_ms,
        "max_pre": max(pre) if pre else 0,
        "max_post": max(post) if post else 0,
        "max_all": max(all_skips) if all_skips else 0,
        "pre_count": len(pre),
        "post_count": len(post),
        "ready": "[RuntimeV3] READY" in text,
        "auth_deferred": "[Startup] Auth deferred" in text,
    }

def show(label, d):
    print(label)
    print(f"  Runtime V3:          {d['runtime']} ms")
    print(f"  Welcome:             {d['welcome']} ms")
    print(f"  Repository:          {d['repo']} ms")
    print(f"  Max skip PRE-Welcome:{d['max_pre']}")
    print(f"  Max skip POST-Welcome:{d['max_post']}")
    print(f"  RuntimeV3 READY:     {d['ready']}")
    print(f"  Auth deferred:       {d['auth_deferred']}")

def main():
    first = parse(REPORT / "first_install.log")
    warm = parse(REPORT / "warm_launch.log")

    print("=" * 64)
    print("LINKBALL STEP 07A.9 - AUTH-DECOUPLED STARTUP SUMMARY")
    print("=" * 64)
    print()
    show("FIRST INSTALL", first)
    print()
    show("WARM LAUNCH", warm)
    print()

    findings = []

    if first["welcome"] is None:
        findings.append("First-install Welcome marker missing.")
    elif first["welcome"] > 10000:
        findings.append(f"First-install Welcome still >10s: {first['welcome']}ms.")

    if warm["welcome"] is None:
        findings.append("Warm Welcome marker missing.")
    elif warm["welcome"] > 2000:
        findings.append(f"Warm Welcome still >2s: {warm['welcome']}ms.")

    if not first["auth_deferred"] or not warm["auth_deferred"]:
        findings.append("Auth deferred marker missing.")

    if max(first["max_pre"], warm["max_pre"]) >= 120:
        findings.append(
            "120+ frame stall occurs BEFORE Welcome; Runtime V3/Firebase bootstrap still blocks UI."
        )

    if max(first["max_post"], warm["max_post"]) >= 120:
        findings.append(
            "120+ frame stall occurs AFTER Welcome; Repository/model bridge is the next target."
        )

    if first["repo"] is not None and first["welcome"] is not None:
        if first["repo"] > first["welcome"]:
            print("[PASS] First-install Repository completes after Welcome.")

    if warm["repo"] is not None and warm["welcome"] is not None:
        if warm["repo"] > warm["welcome"]:
            print("[PASS] Warm Repository completes after Welcome.")

    print()
    if findings:
        print("[WARN] Remaining findings:")
        for f in findings:
            print("  -", f)
        overall = "NEEDS_NEXT_PERF_STEP"
    else:
        print("[PASS] Auth is removed from the startup critical path.")
        overall = "PASS"

    OUT.write_text(
        "\n".join([
            f"overall={overall}",
            f"first_runtime_ms={first['runtime']}",
            f"first_welcome_ms={first['welcome']}",
            f"first_repo_ms={first['repo']}",
            f"first_pre_skip={first['max_pre']}",
            f"first_post_skip={first['max_post']}",
            f"warm_runtime_ms={warm['runtime']}",
            f"warm_welcome_ms={warm['welcome']}",
            f"warm_repo_ms={warm['repo']}",
            f"warm_pre_skip={warm['max_pre']}",
            f"warm_post_skip={warm['max_post']}",
            *["finding=" + f for f in findings],
        ]) + "\n",
        encoding="utf-8",
        newline="\n",
    )

    print()
    print("Overall:", overall)

if __name__ == "__main__":
    main()
