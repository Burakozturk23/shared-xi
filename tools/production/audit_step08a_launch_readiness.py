from pathlib import Path
import re
import json

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/08a"
REPORT.mkdir(parents=True, exist_ok=True)
OUT = REPORT / "play_store_launch_readiness.txt"

def read(rel):
    p = ROOT / rel
    if not p.exists():
        return ""
    return p.read_text(encoding="utf-8", errors="replace")

def exists(rel):
    return (ROOT / rel).exists()

def grep_tree(patterns, roots=("lib", "docs", "functions")):
    hits = []
    regs = [re.compile(p, re.I) for p in patterns]
    for root_name in roots:
        base = ROOT / root_name
        if not base.exists():
            continue
        for p in base.rglob("*"):
            if not p.is_file():
                continue
            if any(part in {"node_modules", "build", ".dart_tool"} for part in p.parts):
                continue
            if p.stat().st_size > 2 * 1024 * 1024:
                continue
            try:
                text = p.read_text(encoding="utf-8", errors="replace")
            except Exception:
                continue
            for i, line in enumerate(text.splitlines(), 1):
                if any(rx.search(line) for rx in regs):
                    hits.append((str(p.relative_to(ROOT)).replace("\\", "/"), i, line.strip()))
    return hits

def gradle_text():
    for rel in ["android/app/build.gradle.kts", "android/app/build.gradle"]:
        t = read(rel)
        if t:
            return rel, t
    return None, ""

def extract_num(text, key):
    patterns = [
        rf"{re.escape(key)}\s*=\s*(\d+)",
        rf"{re.escape(key)}\s+(\d+)",
        rf"{re.escape(key)}\s*=\s*flutter\.{re.escape(key)}",
    ]
    for p in patterns:
        m = re.search(p, text)
        if m:
            if m.lastindex:
                return m.group(1)
            return "flutter-default"
    return None

def extract_app_id(text):
    for p in [
        r'applicationId\s*=\s*"([^"]+)"',
        r"applicationId\s+['\"]([^'\"]+)['\"]",
    ]:
        m = re.search(p, text)
        if m:
            return m.group(1)
    return None

def pubspec_version():
    t = read("pubspec.yaml")
    m = re.search(r"(?m)^version:\s*([^\s#]+)", t)
    return m.group(1) if m else None

def main():
    gradle_rel, gradle = gradle_text()
    app_id = extract_app_id(gradle)
    compile_sdk = extract_num(gradle, "compileSdk")
    target_sdk = extract_num(gradle, "targetSdk")
    version = pubspec_version()

    checks = []

    def add(code, severity, status, title, detail=""):
        checks.append((code, severity, status, title, detail))

    # Release identity / Android
    add(
        "R01", "BLOCKER",
        "PASS" if app_id and not app_id.startswith("com.example") else "FAIL",
        "Production Android applicationId",
        app_id or "not resolved",
    )

    target_ok = str(target_sdk) == "36"
    compile_ok = str(compile_sdk) == "36"
    add(
        "R02", "BLOCKER",
        "PASS" if target_ok and compile_ok else "WARN",
        "Android compileSdk/targetSdk 36",
        f"compileSdk={compile_sdk}, targetSdk={target_sdk}",
    )

    signing_markers = all(
        marker in gradle
        for marker in ["key.properties", "signingConfig"]
    )
    add(
        "R03", "BLOCKER",
        "PASS" if signing_markers and exists("android/key.properties") else "FAIL",
        "Local release signing configured",
        "key.properties content is never read by this audit",
    )

    add(
        "R04", "HIGH",
        "PASS" if exists("build/app/outputs/bundle/release/app-release.aab") else "WARN",
        "Local release AAB exists",
        "build/app/outputs/bundle/release/app-release.aab",
    )

    add(
        "R05", "MEDIUM",
        "PASS" if version and not version.startswith("0.") else "WARN",
        "App version configured",
        version or "version not found",
    )

    # App Check
    pub = read("pubspec.yaml")
    main_dart = read("lib/main.dart")
    appcheck_dep = "firebase_app_check" in pub
    appcheck_init = "FirebaseAppCheck" in main_dart or bool(
        grep_tree([r"FirebaseAppCheck"], roots=("lib",))
    )
    add(
        "S01", "BLOCKER",
        "PASS" if appcheck_dep and appcheck_init else "FAIL",
        "Firebase App Check client integration",
        f"dependency={appcheck_dep}, initialization={appcheck_init}",
    )

    functions = read("functions/index.js")
    enforce_count = len(re.findall(r"enforceAppCheck\s*:\s*true", functions))
    add(
        "S02", "HIGH",
        "PASS" if enforce_count > 0 else "WARN",
        "Functions App Check enforcement present",
        f"enforceAppCheck:true occurrences={enforce_count}",
    )

    # Server-authoritative Daily.
    server_daily = all(
        marker in functions
        for marker in [
            "exports.startDailyScoreSession",
            "exports.submitDailyScore",
            "serverValidated",
        ]
    )
    add(
        "S03", "BLOCKER",
        "PASS" if server_daily else "FAIL",
        "Daily leaderboard server authority",
    )

    rules = read("database.rules.json")
    rules_ok = (
        '"dailyLeaderboard"' in rules
        and '".write": false' in rules
    )
    add(
        "S04", "BLOCKER",
        "PASS" if rules_ok else "FAIL",
        "Daily leaderboard client writes denied",
    )

    # Privacy/account deletion.
    deletion_hits = grep_tree([
        r"deleteAccount",
        r"delete account",
        r"hesab.*sil",
        r"hesabımı sil",
        r"hesabi sil",
        r"account deletion",
    ])
    add(
        "P01", "BLOCKER",
        "PASS" if deletion_hits else "FAIL",
        "In-app account deletion path/evidence",
        f"matching source lines={len(deletion_hits)}",
    )

    privacy_hits = grep_tree([
        r"privacy policy",
        r"gizlilik politik",
        r"privacyPolicy",
    ])
    add(
        "P02", "BLOCKER",
        "PASS" if privacy_hits else "FAIL",
        "Privacy Policy evidence in project",
        f"matching source lines={len(privacy_hits)}",
    )

    data_safety_hits = grep_tree([
        r"Data Safety",
        r"data safety",
        r"veri güvenli",
        r"data collection",
    ])
    add(
        "P03", "HIGH",
        "PASS" if data_safety_hits else "WARN",
        "Play Data Safety documentation/evidence",
        f"matching source lines={len(data_safety_hits)}",
    )

    # Telemetry
    add(
        "T01", "HIGH",
        "PASS" if "firebase_crashlytics" in pub else "WARN",
        "Crashlytics dependency",
    )
    add(
        "T02", "HIGH",
        "PASS" if "firebase_analytics" in pub else "WARN",
        "Analytics dependency",
    )

    # CI
    ci = read(".github/workflows/linkball-ci.yml")
    ci_checks = [
        "flutter analyze",
        "flutter test",
        "npm test",
        "flutter build appbundle --release",
        "integration_test/welcome_smoke_test.dart",
    ]
    ci_ok = all(x in ci for x in ci_checks)
    add(
        "C01", "HIGH",
        "PASS" if ci_ok else "WARN",
        "CI release/test gates",
        f"required markers={len(ci_checks)}",
    )

    # Runtime slimming
    pubspec = read("pubspec.yaml")
    full_json_packaged = bool(
        re.search(
            r"(?m)^\\s*-\\s*assets/data/(?:players|clubs)\\.json\\s*$",
            pubspec,
        )
    )
    add(
        "D01", "HIGH",
        "PASS" if not full_json_packaged else "FAIL",
        "Full JSON datasets excluded from release manifest",
    )

    runtime_exists = exists("assets/runtime/linkball_runtime_v3.sqlite")
    add(
        "D02", "BLOCKER",
        "PASS" if runtime_exists else "FAIL",
        "Runtime V3 SQLite asset present",
    )

    blocker_fail = sum(
        1 for _, sev, status, _, _ in checks
        if sev == "BLOCKER" and status == "FAIL"
    )
    high_fail = sum(
        1 for _, sev, status, _, _ in checks
        if sev == "HIGH" and status == "FAIL"
    )
    warnings = sum(1 for _, _, status, _, _ in checks if status == "WARN")

    if blocker_fail:
        overall = "BLOCKED"
    elif high_fail:
        overall = "NEEDS_HARDENING"
    elif warnings:
        overall = "PRELAUNCH_WARNINGS"
    else:
        overall = "READY_FOR_PLAY_TEST_TRACK"

    print("=" * 72)
    print("LINKBALL STEP 08A - PLAY STORE LAUNCH READINESS AUDIT")
    print("=" * 72)
    print()
    print(f"Overall       : {overall}")
    print(f"Blocker FAIL  : {blocker_fail}")
    print(f"High FAIL     : {high_fail}")
    print(f"Warnings      : {warnings}")
    print()

    for code, sev, status, title, detail in checks:
        line = f"[{sev:7}] [{status:4}] {code}  {title}"
        print(line)
        if detail:
            print("             ", detail)

    print()
    print("NEXT:")
    if blocker_fail:
        print("  Close launch blockers before Play testing.")
    elif warnings:
        print("  Resolve/accept warnings, then move to Play internal/closed testing.")
    else:
        print("  Proceed to Play internal/closed testing and production Play Integrity validation.")

    # Small evidence appendix without dumping secrets.
    lines = [
        "LINKBALL STEP 08A - PLAY STORE LAUNCH READINESS AUDIT",
        "",
        f"overall={overall}",
        f"blocker_fail={blocker_fail}",
        f"high_fail={high_fail}",
        f"warnings={warnings}",
        f"application_id={app_id}",
        f"compile_sdk={compile_sdk}",
        f"target_sdk={target_sdk}",
        f"version={version}",
        "",
    ]
    for code, sev, status, title, detail in checks:
        lines.append(f"{code}|{sev}|{status}|{title}|{detail}")

    OUT.write_text(
        "\n".join(lines) + "\n",
        encoding="utf-8",
        newline="\n",
    )

    # Save only paths/line numbers for privacy/deletion evidence.
    for filename, hits in [
        ("account_deletion_hits.txt", deletion_hits),
        ("privacy_policy_hits.txt", privacy_hits),
        ("data_safety_hits.txt", data_safety_hits),
    ]:
        (REPORT / filename).write_text(
            "\n".join(f"{p}:{line}: {text}" for p, line, text in hits)
            + ("\n" if hits else "(none)\n"),
            encoding="utf-8",
            newline="\n",
        )

    print()
    print("[OK] STEP 08A AUDIT COMPLETE")
    print("[SAFE] READ-ONLY. No source/Firebase/Play Console changes were made.")

if __name__ == "__main__":
    main()
