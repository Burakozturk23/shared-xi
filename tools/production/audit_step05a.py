from __future__ import annotations

import csv
import json
import re
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "reports/production/05a"
OUT.mkdir(parents=True, exist_ok=True)

@dataclass
class Finding:
    id: str
    severity: str
    status: str
    area: str
    title: str
    detail: str
    evidence: str = ""
    recommendation: str = ""

findings: list[Finding] = []

def add(
    id: str,
    severity: str,
    status: str,
    area: str,
    title: str,
    detail: str,
    evidence: str = "",
    recommendation: str = "",
) -> None:
    findings.append(
        Finding(
            id=id,
            severity=severity,
            status=status,
            area=area,
            title=title,
            detail=detail,
            evidence=evidence,
            recommendation=recommendation,
        )
    )

def read(rel: str) -> str:
    p = ROOT / rel
    if not p.exists():
        return ""
    try:
        return p.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return p.read_text(encoding="utf-8", errors="replace")

def exists(rel: str) -> bool:
    return (ROOT / rel).exists()

def clip(s: str, n: int = 220) -> str:
    s = re.sub(r"\s+", " ", s).strip()
    return s if len(s) <= n else s[: n - 3] + "..."

def find_gradle() -> tuple[str, str]:
    for rel in (
        "android/app/build.gradle.kts",
        "android/app/build.gradle",
    ):
        if exists(rel):
            return rel, read(rel)
    return "", ""

def check_secret_config() -> None:
    rel = "functions/index.js"
    text = read(rel)

    if not text:
        add(
            "B01",
            "BLOCKER",
            "FAIL",
            "functions",
            "functions/index.js bulunamadı",
            "Cloud Functions güvenliği taranamadı.",
            recommendation="functions klasörünü doğrula.",
        )
        return

    matches = re.findall(
        r"defineSecret\s*\(\s*['\"]([^'\"]+)['\"]\s*\)",
        text,
    )

    if not matches:
        add(
            "B01",
            "HIGH",
            "WARN",
            "functions",
            "Secret declaration bulunamadı",
            "API anahtarı farklı yöntemle yönetiliyor olabilir.",
            recommendation=(
                "API_FOOTBALL_KEY için Secret Manager kullanımını doğrula."
            ),
        )
        return

    suspicious = [
        value
        for value in matches
        if value != "API_FOOTBALL_KEY"
    ]

    if suspicious:
        masked = []
        for value in suspicious:
            if len(value) <= 8:
                masked.append("***")
            else:
                masked.append(value[:4] + "..." + value[-4:])

        add(
            "B01",
            "BLOCKER",
            "FAIL",
            "functions",
            "Secret Manager adı yerine secret değerine benzeyen literal var",
            (
                "defineSecret() içine secret NAME verilmelidir. "
                "Yerelde eski key literal'i kalmış olabilir."
            ),
            evidence=", ".join(masked),
            recommendation=(
                'defineSecret("API_FOOTBALL_KEY") kullan; key değerini '
                "Firebase Secret Manager'da tut ve compromised key'i rotate et."
            ),
        )
    else:
        add(
            "B01",
            "BLOCKER",
            "PASS",
            "functions",
            "Secret declaration güvenli isim kullanıyor",
            'defineSecret("API_FOOTBALL_KEY") bulundu.',
        )

def extract_export_block(text: str, export_name: str) -> str:
    marker = f"exports.{export_name}"
    start = text.find(marker)
    if start < 0:
        return ""

    rest = text[start:]
    next_m = re.search(r"\nexports\.[A-Za-z0-9_]+\s*=", rest[1:])
    if next_m:
        end = 1 + next_m.start()
        return rest[:end]

    return rest

def check_manual_refresh_endpoint() -> None:
    text = read("functions/index.js")
    block = extract_export_block(text, "refreshDailyFixtures")

    if not block:
        add(
            "B02",
            "MEDIUM",
            "PASS",
            "functions",
            "Public manual refresh endpoint bulunmadı",
            "refreshDailyFixtures export edilmemiş.",
        )
        return

    auth_indicators = (
        "verifyIdToken",
        "authorization",
        "Authorization",
        "x-admin",
        "adminToken",
        "req.auth",
    )

    if any(token in block for token in auth_indicators):
        add(
            "B02",
            "HIGH",
            "PASS",
            "functions",
            "Manual fixture refresh endpoint auth kontrolü içeriyor",
            "Endpoint için bir auth/admin guard göstergesi bulundu.",
        )
    else:
        add(
            "B02",
            "HIGH",
            "FAIL",
            "functions",
            "Manual fixture refresh endpoint public görünüyor",
            (
                "HTTP endpoint auth/admin guard olmadan fixture API çağrısı "
                "ve RTDB write tetikleyebilir."
            ),
            evidence=clip(block),
            recommendation=(
                "Endpoint'i kaldır veya Firebase Auth + admin claim / "
                "özel admin secret guard ile koru."
            ),
        )

def check_daily_leaderboard_authority() -> None:
    rel = "lib/services/daily_leaderboard_service.dart"
    text = read(rel)

    if not text:
        add(
            "B03",
            "BLOCKER",
            "WARN",
            "leaderboard",
            "Daily leaderboard service bulunamadı",
            "Leaderboard authority taranamadı.",
        )
        return

    direct_path = "dailyLeaderboard/" in text
    has_set = bool(re.search(r"\bref\.set\s*\(", text))
    has_update = bool(re.search(r"\bref\.update\s*\(", text))
    direct_write = direct_path and (has_set or has_update)

    callable_markers = (
        "FirebaseFunctions",
        "httpsCallable",
        "cloud_functions",
    )
    uses_callable = any(m in text for m in callable_markers)

    if direct_write and not uses_callable:
        add(
            "B03",
            "BLOCKER",
            "FAIL",
            "leaderboard",
            "Daily leaderboard client-authoritative",
            (
                "Flutter client score/successRate/secondsLeft değerlerini "
                "doğrudan RTDB'ye yazabiliyor."
            ),
            evidence=(
                "dailyLeaderboard path + ref.set/ref.update bulundu; "
                "callable function kullanımı bulunmadı."
            ),
            recommendation=(
                "Client write'ı kaldır. Skor submission callable HTTPS "
                "function üzerinden olsun; server skor/tie-break doğrulasın."
            ),
        )
    elif uses_callable and not direct_write:
        add(
            "B03",
            "BLOCKER",
            "PASS",
            "leaderboard",
            "Daily leaderboard server submission yolunda",
            "Client direct RTDB write bulunmadı; callable function kullanılıyor.",
        )
    else:
        add(
            "B03",
            "HIGH",
            "WARN",
            "leaderboard",
            "Daily leaderboard authority belirsiz",
            (
                "Service shape otomatik olarak net sınıflandırılamadı."
            ),
            evidence=(
                f"direct_path={direct_path}, direct_write={direct_write}, "
                f"uses_callable={uses_callable}"
            ),
        )

    functions = read("functions/index.js")
    server_score_markers = (
        "submitDailyScore",
        "submitDailyResult",
        "dailyScore",
    )

    has_server_submit = any(
        marker in functions for marker in server_score_markers
    ) and ("onCall" in functions or "onRequest" in functions)

    if has_server_submit:
        add(
            "B04",
            "BLOCKER",
            "PASS",
            "leaderboard",
            "Server-side daily score function bulundu",
            "Cloud Functions içinde score submission export'u bulunuyor.",
        )
    else:
        add(
            "B04",
            "BLOCKER",
            "FAIL",
            "leaderboard",
            "Server-side daily score authority bulunamadı",
            (
                "Cloud Functions içinde daily result submission function "
                "tespit edilmedi."
            ),
            recommendation=(
                "05B'de callable submitDailyScore function + validation "
                "protokolü ekle."
            ),
        )

def check_database_rules() -> None:
    firebase_rel = "firebase.json"
    firebase_text = read(firebase_rel)
    config = {}

    try:
        config = json.loads(firebase_text) if firebase_text else {}
    except Exception:
        add(
            "B05",
            "BLOCKER",
            "FAIL",
            "firebase",
            "firebase.json parse edilemiyor",
            "Firebase deploy config güvenilir değil.",
        )
        return

    database_cfg = config.get("database")
    rules_path = None

    if isinstance(database_cfg, dict):
        raw = database_cfg.get("rules")
        if isinstance(raw, str):
            rules_path = raw
    elif isinstance(database_cfg, list):
        for item in database_cfg:
            if isinstance(item, dict) and isinstance(item.get("rules"), str):
                rules_path = item["rules"]
                break

    fallback_candidates = [
        "database.rules.json",
        "database.rules",
        "database.rules.json5",
    ]
    existing_fallback = next(
        (rel for rel in fallback_candidates if exists(rel)),
        None,
    )

    if not rules_path:
        rules_path = existing_fallback

    if not rules_path:
        add(
            "B05",
            "BLOCKER",
            "FAIL",
            "firebase",
            "Realtime Database rules repo/deploy config içinde yok",
            (
                "Production RTDB kuralları source control + firebase deploy "
                "akışında görünmüyor."
            ),
            recommendation=(
                "database.rules.json ekle ve firebase.json içinde "
                '"database": {"rules": "database.rules.json"} tanımla.'
            ),
        )
        return

    rules_text = read(rules_path)

    if not rules_text:
        add(
            "B05",
            "BLOCKER",
            "FAIL",
            "firebase",
            "RTDB rules path tanımlı ama dosya okunamıyor",
            rules_path,
        )
        return

    add(
        "B05",
        "BLOCKER",
        "PASS",
        "firebase",
        "Realtime Database rules version-controlled",
        f"Rules file: {rules_path}",
    )

    # Loose but useful checks.
    leaderboard_pos = rules_text.find("dailyLeaderboard")
    if leaderboard_pos < 0:
        add(
            "B06",
            "BLOCKER",
            "WARN",
            "firebase",
            "dailyLeaderboard için explicit write-deny bulunamadı",
            (
                "Rules dosyasında dailyLeaderboard path'i görünmüyor. "
                "Inherited rules güvenli olabilir ama explicit policy önerilir."
            ),
            recommendation=(
                "Client leaderboard write'ını kapat; yalnız Admin SDK "
                "Cloud Function yazabilsin."
            ),
        )
        return

    window = rules_text[
        max(0, leaderboard_pos - 300):
        leaderboard_pos + 1200
    ]

    deny_patterns = (
        '" .write": false',
        '".write": false',
        "'.write': false",
    )

    if any(p in window for p in deny_patterns):
        add(
            "B06",
            "BLOCKER",
            "PASS",
            "firebase",
            "dailyLeaderboard client write deny göstergesi bulundu",
            "Rules içinde .write=false bulundu.",
        )
    else:
        add(
            "B06",
            "BLOCKER",
            "WARN",
            "firebase",
            "dailyLeaderboard client write policy doğrulanamadı",
            clip(window, 300),
            recommendation=(
                "05B sonrası dailyLeaderboard client write kesin olarak false olmalı."
            ),
        )

def check_app_check() -> None:
    pubspec = read("pubspec.yaml")
    main = read("lib/main.dart")
    functions = read("functions/index.js")

    dep = "firebase_app_check:" in pubspec
    activate = (
        "FirebaseAppCheck.instance.activate" in main
        or "FirebaseAppCheck.instance" in main
        and ".activate(" in main
    )
    enforce = (
        "enforceAppCheck" in functions
        and re.search(r"enforceAppCheck\s*:\s*true", functions) is not None
    )

    if dep and activate:
        add(
            "B07",
            "HIGH",
            "PASS",
            "app_check",
            "Flutter App Check activation bulundu",
            "firebase_app_check dependency + activate() bulundu.",
        )
    else:
        missing = []
        if not dep:
            missing.append("firebase_app_check dependency")
        if not activate:
            missing.append("FirebaseAppCheck.activate")
        add(
            "B07",
            "HIGH",
            "FAIL",
            "app_check",
            "Firebase App Check client entegrasyonu eksik",
            "Eksik: " + ", ".join(missing),
            recommendation=(
                "Android Play Integrity + debug provider geliştirme akışı ekle."
            ),
        )

    if enforce:
        add(
            "B08",
            "HIGH",
            "PASS",
            "app_check",
            "Callable Functions App Check enforcement bulundu",
            "enforceAppCheck: true bulundu.",
        )
    else:
        add(
            "B08",
            "HIGH",
            "WARN",
            "app_check",
            "Functions App Check enforcement bulunamadı",
            (
                "Callable score endpoint eklendiğinde enforceAppCheck=true "
                "zorunlu olmalı."
            ),
        )

def check_android_release() -> None:
    rel, gradle = find_gradle()

    if not gradle:
        add(
            "R01",
            "BLOCKER",
            "FAIL",
            "android",
            "Android app Gradle dosyası bulunamadı",
            "applicationId / SDK / signing taranamadı.",
        )
        return

    app_id_match = re.search(
        r'applicationId\s*[= ]\s*["\']([^"\']+)["\']',
        gradle,
    )
    app_id = app_id_match.group(1) if app_id_match else ""

    if not app_id:
        add(
            "R01",
            "BLOCKER",
            "WARN",
            "android",
            "applicationId otomatik bulunamadı",
            rel,
        )
    elif app_id.startswith("com.example"):
        add(
            "R01",
            "BLOCKER",
            "FAIL",
            "android",
            "Placeholder Android applicationId kullanılıyor",
            app_id,
            recommendation=(
                "Play Store öncesi kalıcı package id belirle "
                "(ör. com.<brand>.linkball) ve Firebase Android app'i güncelle."
            ),
        )
    else:
        add(
            "R01",
            "BLOCKER",
            "PASS",
            "android",
            "Android applicationId placeholder değil",
            app_id,
        )

    # Target SDK.
    explicit_sdk = re.search(
        r"targetSdk(?:Version)?\s*[= ]\s*(\d+)",
        gradle,
    )

    if explicit_sdk:
        target = int(explicit_sdk.group(1))
        if target >= 36:
            add(
                "R02",
                "BLOCKER",
                "PASS",
                "android",
                "Android target SDK 36+",
                f"targetSdk={target}",
            )
        else:
            add(
                "R02",
                "BLOCKER",
                "FAIL",
                "android",
                "Android target SDK 36 altında",
                f"targetSdk={target}",
                recommendation="compile/target SDK 36+ yap.",
            )
    elif "flutter.targetSdkVersion" in gradle:
        add(
            "R02",
            "BLOCKER",
            "WARN",
            "android",
            "targetSdk Flutter default üzerinden geliyor",
            "flutter.targetSdkVersion",
            recommendation=(
                "flutter --version / Gradle resolved target ile 36 olduğunu "
                "release preflight'ta doğrula."
            ),
        )
    else:
        add(
            "R02",
            "BLOCKER",
            "WARN",
            "android",
            "targetSdk otomatik bulunamadı",
            rel,
        )

    # Release signing.
    release_match = re.search(
        r"release\s*\{(?P<body>.*?)\n\s*\}",
        gradle,
        flags=re.S,
    )
    release_body = release_match.group("body") if release_match else ""

    debug_signing = (
        "signingConfigs.debug" in release_body
        or "signingConfig signingConfigs.debug" in release_body
        or "signingConfig = signingConfigs.getByName(\"debug\")" in release_body
    )

    if debug_signing:
        add(
            "R03",
            "BLOCKER",
            "FAIL",
            "android",
            "Release build debug signing kullanıyor",
            clip(release_body),
            recommendation=(
                "Upload keystore + key.properties/env secrets ile release signing kur."
            ),
        )
    elif release_body and "signingConfig" in release_body:
        add(
            "R03",
            "BLOCKER",
            "PASS",
            "android",
            "Release signing config tanımlı",
            "Debug signing göstergesi bulunmadı.",
        )
    else:
        add(
            "R03",
            "BLOCKER",
            "WARN",
            "android",
            "Release signing otomatik doğrulanamadı",
            rel,
        )

def check_observability() -> None:
    pubspec = read("pubspec.yaml")

    deps = {
        "R04": ("firebase_crashlytics:", "Crashlytics"),
        "R05": ("firebase_analytics:", "Analytics"),
        "R06": ("firebase_remote_config:", "Remote Config"),
    }

    for id, (needle, label) in deps.items():
        if needle in pubspec:
            add(
                id,
                "MEDIUM",
                "PASS",
                "observability",
                f"{label} dependency bulundu",
                needle.rstrip(":"),
            )
        else:
            add(
                id,
                "MEDIUM",
                "WARN",
                "observability",
                f"{label} dependency bulunamadı",
                "Launch telemetry için önerilir.",
            )

def check_tests_ci() -> None:
    workflow_dir = ROOT / ".github/workflows"
    workflows = list(workflow_dir.glob("*.yml")) + list(
        workflow_dir.glob("*.yaml")
    ) if workflow_dir.exists() else []

    flutter_ci = False
    for p in workflows:
        t = p.read_text(encoding="utf-8", errors="replace")
        if "flutter analyze" in t and (
            "flutter test" in t or "dart test" in t
        ):
            flutter_ci = True
            break

    if flutter_ci:
        add(
            "R07",
            "HIGH",
            "PASS",
            "ci",
            "CI analyze + tests gate bulundu",
            f"{len(workflows)} workflow tarandı.",
        )
    else:
        add(
            "R07",
            "HIGH",
            "WARN",
            "ci",
            "CI analyze + test release gate bulunamadı",
            f"{len(workflows)} workflow tarandı.",
            recommendation=(
                "PR/push için flutter analyze + flutter test + build smoke gate ekle."
            ),
        )

def write_outputs() -> None:
    severity_order = {
        "BLOCKER": 0,
        "HIGH": 1,
        "MEDIUM": 2,
        "LOW": 3,
    }
    status_order = {
        "FAIL": 0,
        "WARN": 1,
        "PASS": 2,
    }

    ordered = sorted(
        findings,
        key=lambda f: (
            severity_order.get(f.severity, 99),
            status_order.get(f.status, 99),
            f.id,
        ),
    )

    counts = {}
    for f in ordered:
        counts[(f.severity, f.status)] = (
            counts.get((f.severity, f.status), 0) + 1
        )

    blocker_fails = [
        f for f in ordered
        if f.severity == "BLOCKER" and f.status == "FAIL"
    ]

    high_fails = [
        f for f in ordered
        if f.severity == "HIGH" and f.status == "FAIL"
    ]

    overall = (
        "BLOCKED"
        if blocker_fails
        else "HARDENING_REQUIRED"
        if high_fails
        else "PRECHECK_PASS"
    )

    summary = {
        "overall": overall,
        "findingCount": len(ordered),
        "blockerFails": len(blocker_fails),
        "highFails": len(high_fails),
        "counts": {
            f"{severity}_{status}": count
            for (severity, status), count in sorted(counts.items())
        },
        "nextRecommendedStep": (
            "05B_SERVER_AUTHORITY"
            if any(f.id in {"B03", "B04", "B05", "B06"} and f.status != "PASS"
                   for f in ordered)
            else "05C_APP_CHECK"
            if any(f.id in {"B07", "B08"} and f.status != "PASS"
                   for f in ordered)
            else "06_ANDROID_RELEASE"
        ),
    }

    (OUT / "summary.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    (OUT / "findings.json").write_text(
        json.dumps(
            [asdict(f) for f in ordered],
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )

    with (OUT / "findings.csv").open(
        "w",
        newline="",
        encoding="utf-8-sig",
    ) as fh:
        writer = csv.DictWriter(
            fh,
            fieldnames=[
                "id",
                "severity",
                "status",
                "area",
                "title",
                "detail",
                "evidence",
                "recommendation",
            ],
        )
        writer.writeheader()
        for f in ordered:
            writer.writerow(asdict(f))

    lines = [
        "# Linkball Step 05A — Production Security Audit",
        "",
        f"**Overall:** `{overall}`",
        "",
        f"- Findings: {len(ordered)}",
        f"- Blocker FAIL: {len(blocker_fails)}",
        f"- High FAIL: {len(high_fails)}",
        f"- Next: `{summary['nextRecommendedStep']}`",
        "",
        "## Findings",
        "",
    ]

    for f in ordered:
        lines.extend(
            [
                f"### {f.id} — {f.severity} / {f.status}",
                "",
                f"**{f.title}**",
                "",
                f"{f.detail}",
                "",
            ]
        )
        if f.evidence:
            lines.extend(
                [
                    f"Evidence: `{f.evidence}`",
                    "",
                ]
            )
        if f.recommendation:
            lines.extend(
                [
                    f"Recommendation: {f.recommendation}",
                    "",
                ]
            )

    lines.extend(
        [
            "## Safety",
            "",
            "Bu audit READ-ONLY'dir. Kaynak dosya değiştirmez.",
            "",
        ]
    )

    (OUT / "report.md").write_text(
        "\n".join(lines),
        encoding="utf-8",
    )

    print("=" * 62)
    print("LINKBALL STEP 05A — PRODUCTION SECURITY AUDIT")
    print("=" * 62)
    print(f"Overall      : {overall}")
    print(f"Findings     : {len(ordered)}")
    print(f"Blocker FAIL : {len(blocker_fails)}")
    print(f"High FAIL    : {len(high_fails)}")
    print(f"Next         : {summary['nextRecommendedStep']}")
    print()
    for f in ordered:
        print(f"[{f.severity:7}] [{f.status:4}] {f.id}  {f.title}")
    print()
    print(f"Report: {OUT.relative_to(ROOT)}")
    print("[SAFE] READ-ONLY. Source files were not modified.")

def main() -> None:
    check_secret_config()
    check_manual_refresh_endpoint()
    check_daily_leaderboard_authority()
    check_database_rules()
    check_app_check()
    check_android_release()
    check_observability()
    check_tests_ci()
    write_outputs()

if __name__ == "__main__":
    main()
