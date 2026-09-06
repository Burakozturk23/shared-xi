from pathlib import Path
import subprocess
import re

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/07b348"
REPORT.mkdir(parents=True, exist_ok=True)

SAFE_PREFIXES = (
    ".github/workflows/",
    "android/app/src/",
    "android/gradle/",
    "assets/data/",
    "assets/runtime/",
    "functions/test/",
    "integration_test/",
    "lib/",
    "test/",
    "tools/data_platform_v3/",
)

SAFE_EXACT = {
    ".gitignore",
    "pubspec.yaml",
    "pubspec.lock",
    "firebase.json",
    "database.rules.json",
    "functions/index.js",
    "functions/package.json",
    "functions/package-lock.json",
    "functions/.gitignore",
    "android/app/google-services.json",
    "android/app/build.gradle",
    "android/app/build.gradle.kts",
    "android/build.gradle",
    "android/build.gradle.kts",
    "android/settings.gradle",
    "android/settings.gradle.kts",
    "android/gradle.properties",
}

DEV_TOOL_PREFIXES = (
    "tools/data_audit/",
)

LOCAL_TOOL_PREFIXES = (
    "tools/production/",
    "tools/runtime_v3/",
)

LOCAL_TOOL_PATTERNS = [
    re.compile(r"^run_step.*\.bat$", re.I),
    re.compile(r"^run_.*repair.*\.bat$", re.I),
    re.compile(r"^run_.*audit.*\.bat$", re.I),
]

EXCLUDE_PREFIXES = (
    "reports/",
    "build/",
    ".dart_tool/",
    "node_modules/",
    "functions/node_modules/",
    ".idea/",
    ".vscode/",
)

EXCLUDE_SUFFIXES = (
    ".bak",
    ".log",
    ".tmp",
    ".created",
)

GENERATED_FLUTTER = {
    "macos/Flutter/GeneratedPluginRegistrant.swift",
    "windows/flutter/generated_plugin_registrant.cc",
    "windows/flutter/generated_plugin_registrant.h",
    "windows/flutter/generated_plugins.cmake",
    "linux/flutter/generated_plugin_registrant.cc",
    "linux/flutter/generated_plugin_registrant.h",
    "linux/flutter/generated_plugins.cmake",
}

DOC_PREFIXES = (
    "docs/data/",
    "docs/data-platform/",
    "docs/data_platform_v3/",
    "docs/production/",
)

SENSITIVE_EXACT = {
    "android/key.properties",
    "android/local.properties",
}

SENSITIVE_EXTS = {
    ".jks",
    ".keystore",
    ".p12",
    ".pfx",
    ".pem",
    ".key",
}

def git(args, check=True):
    r = subprocess.run(
        ["git", *args],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if check and r.returncode != 0:
        raise RuntimeError(
            "git " + " ".join(args) + " failed:\n" + (r.stderr or r.stdout)
        )
    return r

def norm(x):
    s = x.replace("\\", "/")
    if s.startswith("./"):
        s = s[2:]
    return s

def changed_files():
    files = set()
    for args in [
        ["diff", "--cached", "--name-only", "--diff-filter=ACMR"],
        ["diff", "--name-only", "--diff-filter=ACMR"],
        ["ls-files", "--others", "--exclude-standard"],
    ]:
        r = git(args)
        files.update(norm(x.strip()) for x in r.stdout.splitlines() if x.strip())
    return sorted(files)

def is_sensitive(rel):
    if rel.lower() in SENSITIVE_EXACT:
        return True
    return Path(rel).suffix.lower() in SENSITIVE_EXTS

def is_excluded(rel):
    if rel.startswith(EXCLUDE_PREFIXES):
        return True
    if rel.endswith(EXCLUDE_SUFFIXES):
        return True
    if rel in GENERATED_FLUTTER:
        return True
    return False

def is_local_tool(rel):
    if rel.startswith(LOCAL_TOOL_PREFIXES):
        return True
    return any(rx.search(rel) for rx in LOCAL_TOOL_PATTERNS)

def is_dev_tool(rel):
    return rel.startswith(DEV_TOOL_PREFIXES)

def is_documentation(rel):
    return rel.startswith(DOC_PREFIXES)

def is_safe(rel):
    if rel in SAFE_EXACT:
        return True
    return rel.startswith(SAFE_PREFIXES)

def main():
    files = changed_files()

    safe = []
    dev_tools = []
    docs = []
    local_tools = []
    excluded = []
    review = []
    blocked = []

    for rel in files:
        if is_sensitive(rel):
            blocked.append(rel)
        elif is_excluded(rel):
            excluded.append(rel)
        elif is_local_tool(rel):
            local_tools.append(rel)
        elif is_dev_tool(rel):
            dev_tools.append(rel)
        elif is_documentation(rel):
            docs.append(rel)
        elif is_safe(rel):
            safe.append(rel)
        else:
            review.append(rel)

    buckets = {
        "safe_release_commit.txt": safe,
        "developer_tooling_optional.txt": dev_tools,
        "optional_documentation.txt": docs,
        "local_migration_tooling_do_not_commit.txt": local_tools,
        "excluded_generated.txt": excluded,
        "manual_review.txt": review,
        "blocked_sensitive.txt": blocked,
    }

    for name, items in buckets.items():
        (REPORT / name).write_text(
            "\n".join(items) + ("\n" if items else "(none)\n"),
            encoding="utf-8",
        )

    print("=" * 72)
    print("LINKBALL STEP 07B.3.4.8 - SAFE COMMIT MANIFEST V3")
    print("=" * 72)
    print()
    print(f"Changed files        : {len(files)}")
    print(f"SAFE release         : {len(safe)}")
    print(f"Dev tooling optional : {len(dev_tools)}")
    print(f"Optional docs        : {len(docs)}")
    print(f"Local migration tools: {len(local_tools)}")
    print(f"Excluded/generated   : {len(excluded)}")
    print(f"Manual review        : {len(review)}")
    print(f"Sensitive blocked    : {len(blocked)}")
    print()

    print("SENSITIVE BLOCKED:")
    if blocked:
        for rel in blocked:
            print("  [FAIL]", rel)
    else:
        print("  (none)")
    print()

    print("MANUAL REVIEW:")
    if review:
        for rel in review[:100]:
            print("  [REVIEW]", rel)
        if len(review) > 100:
            print(
                f"  [INFO] {len(review)-100} more saved to "
                "reports\\production\\07b348\\manual_review.txt"
            )
    else:
        print("  (none)")
    print()

    print("CLASSIFICATION NOTES:")
    print("  SAFE: production source + CI + Firebase client config")
    print("        + reproducible tools/data_platform_v3 compiler source")
    print("  DEV TOOLING: tools/data_audit (optional separate commit)")
    print("  LOCAL TOOLS: historical install/repair/rollback helpers")
    print("               under tools/runtime_v3 and tools/production")
    print("  DOCS: optional separate documentation commit")
    print()

    if blocked:
        print("Overall: STOP")
        print("[STOP] Sensitive files exist. Do not stage.")
        raise SystemExit(2)

    if review:
        print("Overall: NEEDS_REVIEW")
        print("[NEXT] Send only the MANUAL REVIEW section.")
    else:
        print("Overall: READY_TO_STAGE")
        print("[PASS] No ambiguous files remain.")
        print(
            "[NEXT] Stage only reports\\production\\07b348\\"
            "safe_release_commit.txt"
        )

    print()
    print("[SAFE] Nothing was staged, committed or pushed.")

if __name__ == "__main__":
    main()
