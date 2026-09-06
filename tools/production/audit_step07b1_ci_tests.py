from pathlib import Path
import json
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/07b1"
REPORT.mkdir(parents=True, exist_ok=True)
OUT = REPORT / "ci_test_audit.txt"

def run(cmd):
    try:
        r = subprocess.run(
            cmd,
            cwd=ROOT,
            capture_output=True,
            text=True,
            shell=False,
        )
        return r.returncode, (r.stdout or "") + (r.stderr or "")
    except Exception as e:
        return 999, str(e)

def read(path):
    p = ROOT / path
    if not p.exists():
        return ""
    return p.read_text(encoding="utf-8", errors="replace")

def main():
    findings = []
    blockers = []
    warnings = []

    pubspec = read("pubspec.yaml")
    analysis_options = read("analysis_options.yaml")

    workflows = []
    wf_dir = ROOT / ".github" / "workflows"
    if wf_dir.exists():
        workflows = sorted(
            str(p.relative_to(ROOT)).replace("\\", "/")
            for p in wf_dir.glob("*.y*ml")
        )

    tests = []
    test_dir = ROOT / "test"
    if test_dir.exists():
        tests = sorted(
            str(p.relative_to(ROOT)).replace("\\", "/")
            for p in test_dir.rglob("*_test.dart")
        )

    integration_tests = []
    it_dir = ROOT / "integration_test"
    if it_dir.exists():
        integration_tests = sorted(
            str(p.relative_to(ROOT)).replace("\\", "/")
            for p in it_dir.rglob("*.dart")
        )

    golden_tests = []
    for rel in tests:
        text = read(rel)
        if "matchesGoldenFile" in text or "golden" in rel.lower():
            golden_tests.append(rel)

    # Detect current Flutter/Dart constraints.
    sdk_line = None
    for line in pubspec.splitlines():
        if line.strip().startswith("sdk:"):
            sdk_line = line.strip()
            break

    # Existing CI capabilities.
    ci_text = "\n".join(read(wf) for wf in workflows)

    gates = {
        "flutter_analyze": "flutter analyze" in ci_text,
        "flutter_test": "flutter test" in ci_text,
        "apk_build": "flutter build apk" in ci_text,
        "aab_build": "flutter build appbundle" in ci_text,
        "pub_get": "flutter pub get" in ci_text,
        "functions_lint": (
            "npm --prefix functions run lint" in ci_text
            or "npm run lint" in ci_text
        ),
        "functions_test": (
            "npm --prefix functions test" in ci_text
            or "npm test" in ci_text
        ),
    }

    # Functions package.
    functions_pkg = {}
    pkg_path = ROOT / "functions" / "package.json"
    if pkg_path.exists():
        try:
            functions_pkg = json.loads(
                pkg_path.read_text(encoding="utf-8")
            )
        except Exception:
            functions_pkg = {}

    scripts = functions_pkg.get("scripts", {}) if isinstance(functions_pkg, dict) else {}
    has_functions_lint = "lint" in scripts
    has_functions_test = "test" in scripts

    # Run lightweight discovery commands only.
    flutter_rc, flutter_out = run(["flutter", "--version"])
    dart_rc, dart_out = run(["dart", "--version"])

    # Do NOT run full analyze/test here; installer will run dedicated gates after report.
    findings.append(f"workflow_count={len(workflows)}")
    findings.append(f"unit_test_files={len(tests)}")
    findings.append(f"integration_test_files={len(integration_tests)}")
    findings.append(f"golden_test_files={len(golden_tests)}")

    if not workflows:
        blockers.append("No GitHub Actions workflow exists.")
    if not gates["flutter_analyze"]:
        blockers.append("CI does not run flutter analyze.")
    if not gates["flutter_test"]:
        blockers.append("CI does not run flutter test.")
    if not gates["aab_build"]:
        warnings.append("CI does not build a release AAB.")
    if len(tests) == 0:
        blockers.append("No unit/widget test files found.")
    if len(integration_tests) == 0:
        warnings.append("No integration_test suite found.")
    if has_functions_lint and not gates["functions_lint"]:
        warnings.append("Functions lint exists locally but is not enforced in CI.")
    if has_functions_test and not gates["functions_test"]:
        warnings.append("Functions tests exist locally but are not enforced in CI.")
    if not has_functions_test:
        warnings.append("functions/package.json has no test script.")

    print("=" * 66)
    print("LINKBALL STEP 07B.1 - CI / TEST GATE AUDIT")
    print("=" * 66)
    print()

    print("Toolchain:")
    print(f"  Flutter detected: {'YES' if flutter_rc == 0 else 'NO'}")
    if flutter_rc == 0:
        first = flutter_out.splitlines()[0] if flutter_out.splitlines() else ""
        print("   ", first)
    print(f"  Dart detected:    {'YES' if dart_rc == 0 else 'NO'}")
    print(f"  pubspec SDK:      {sdk_line or '(not found)'}")
    print()

    print("Existing test surface:")
    print(f"  test/*_test.dart:         {len(tests)}")
    print(f"  integration_test/*.dart:  {len(integration_tests)}")
    print(f"  golden tests:             {len(golden_tests)}")
    if tests:
        print("  Unit/widget tests:")
        for x in tests[:20]:
            print("   -", x)
    if integration_tests:
        print("  Integration tests:")
        for x in integration_tests[:20]:
            print("   -", x)
    print()

    print("Existing CI workflows:")
    if workflows:
        for wf in workflows:
            print("  -", wf)
    else:
        print("  (none)")
    print()

    print("Gate coverage:")
    for key, value in gates.items():
        print(f"  {key:18}: {'PASS' if value else 'MISS'}")
    print()

    print("Functions:")
    print(f"  package.json: {'YES' if pkg_path.exists() else 'NO'}")
    print(f"  lint script:  {'YES' if has_functions_lint else 'NO'}")
    print(f"  test script:  {'YES' if has_functions_test else 'NO'}")
    print()

    print("Blockers:")
    if blockers:
        for item in blockers:
            print("  [FAIL]", item)
    else:
        print("  (none)")
    print()

    print("Warnings:")
    if warnings:
        for item in warnings:
            print("  [WARN]", item)
    else:
        print("  (none)")
    print()

    if blockers:
        overall = "NEEDS_07B_2"
    else:
        overall = "PASS"

    print("Overall:", overall)
    print()
    print("[NEXT]")
    if overall == "PASS":
        print("  CI/test baseline already exists; strengthen release gates only.")
    else:
        print("  STEP 07B.2 will install the missing CI/test baseline.")

    OUT.write_text(
        "\n".join([
            f"overall={overall}",
            *findings,
            *["blocker=" + x for x in blockers],
            *["warning=" + x for x in warnings],
        ]) + "\n",
        encoding="utf-8",
        newline="\n",
    )

if __name__ == "__main__":
    main()
