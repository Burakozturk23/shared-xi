from pathlib import Path
import argparse
import html
import json
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]
TOOLS = Path(__file__).resolve().parent
TEMPLATES = TOOLS / "step08b2_templates"

WELCOME = ROOT / "lib/screens/welcome_page.dart"
FUNCTIONS = ROOT / "functions/index.js"
FIREBASE_JSON = ROOT / "firebase.json"
AUDIT_08A = ROOT / "tools/production/audit_step08a_launch_readiness.py"

NEW_FILES = [
    ROOT / "lib/config/privacy_config.dart",
    ROOT / "lib/services/account_deletion_service.dart",
    ROOT / "lib/screens/privacy_account_page.dart",
    ROOT / "functions/test/account_deletion_contracts.test.js",
    ROOT / "play_store_web/index.html",
    ROOT / "play_store_web/privacy.html",
    ROOT / "play_store_web/account-deletion.html",
    ROOT / "docs/production/PRIVACY_POLICY.md",
    ROOT / "docs/production/DATA_SAFETY_DRAFT.md",
    ROOT / "docs/production/ACCOUNT_DELETION.md",
]

PATCHED_FILES = [
    WELCOME,
    FUNCTIONS,
    FIREBASE_JSON,
    AUDIT_08A,
]

def backup_or_mark(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    bak = path.with_suffix(path.suffix + ".step08b2.bak")
    created = path.with_suffix(path.suffix + ".step08b2.created")

    if path.exists():
        if not bak.exists():
            shutil.copy2(path, bak)
            print("[BACKUP]", path.relative_to(ROOT))
    else:
        if not created.exists():
            created.write_text("created by STEP 08B.2\n", encoding="utf-8")
        print("[NEW]", path.relative_to(ROOT))

def write_lf(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as f:
        f.write(text.replace("\r\n", "\n").replace("\r", "\n"))

def validate_email(value):
    value = value.strip()
    pattern = r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"
    if not re.match(pattern, value):
        raise RuntimeError("A valid public privacy contact email is required.")
    return value

def project_id():
    data = json.loads(FIREBASE_JSON.read_text(encoding="utf-8"))
    try:
        return data["flutter"]["platforms"]["android"]["default"]["projectId"]
    except Exception:
        return "sharedix"

def render_template(name, replacements):
    text = (TEMPLATES / name).read_text(encoding="utf-8")
    for key, value in replacements.items():
        text = text.replace(key, value)
    return text

def patch_welcome():
    text = WELCOME.read_text(encoding="utf-8", errors="replace")

    if "LINKBALL_08B_PRIVACY_ENTRY" in text:
        print("[PASS] Welcome privacy entry already installed.")
        return

    import_anchor = "import 'coach_xi_difficulty_page.dart';"
    if import_anchor not in text:
        raise RuntimeError("welcome_page.dart import anchor not found")

    text = text.replace(
        import_anchor,
        import_anchor + "\nimport 'privacy_account_page.dart';",
        1,
    )

    anchor = """                    Text(
                      'Ortak oyuncu evreni',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.hintColor, fontSize: 14),
                    ),
"""
    if anchor not in text:
        raise RuntimeError("welcome_page.dart hero subtitle anchor not found")

    addition = anchor + """                    const SizedBox(height: 8),
                    // LINKBALL_08B_PRIVACY_ENTRY
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PrivacyAccountPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                      label: const Text('Gizlilik & Hesap'),
                    ),
"""

    text = text.replace(anchor, addition, 1)
    write_lf(WELCOME, text)
    print("[FIX] Welcome -> Gizlilik & Hesap entry added.")

def patch_functions():
    text = FUNCTIONS.read_text(encoding="utf-8", errors="replace")

    start = "// LINKBALL_08B_ACCOUNT_DELETION_START"
    end = "// LINKBALL_08B_ACCOUNT_DELETION_END"

    if start in text and end in text:
        print("[PASS] deleteMyAccount Function already installed.")
        return
    if start in text or end in text:
        raise RuntimeError("Partial STEP 08B account-deletion Function detected")

    block = (TEMPLATES / "functions_account_deletion.js.tmpl").read_text(
        encoding="utf-8"
    )
    write_lf(FUNCTIONS, text.rstrip() + "\n\n" + block.rstrip() + "\n")
    print("[FIX] Server-authoritative deleteMyAccount Function added.")

def patch_firebase_json():
    data = json.loads(FIREBASE_JSON.read_text(encoding="utf-8"))

    desired = {
        "public": "play_store_web",
        "ignore": [
            "firebase.json",
            "**/.*",
            "**/node_modules/**",
        ],
        "cleanUrls": True,
    }

    existing = data.get("hosting")
    if existing and existing != desired:
        raise RuntimeError(
            "firebase.json already has a different Hosting configuration. "
            "Refusing to overwrite it automatically."
        )

    data["hosting"] = desired
    write_lf(
        FIREBASE_JSON,
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
    )
    print("[FIX] Firebase Hosting -> play_store_web configured.")

def patch_08a_false_positive():
    if not AUDIT_08A.exists():
        print("[INFO] STEP 08A audit helper not present; skip local audit fix.")
        return

    text = AUDIT_08A.read_text(encoding="utf-8", errors="replace")
    old = """    full_json_packaged = (
        "    - assets/data/players.json" in pubspec
        or "    - assets/data/clubs.json" in pubspec
        or "    - assets/data/" in pubspec
    )
"""
    new = """    full_json_packaged = bool(
        re.search(
            r"(?m)^\\\\s*-\\\\s*assets/data/(?:players|clubs)\\\\.json\\\\s*$",
            pubspec,
        )
    )
"""

    if old in text:
        write_lf(AUDIT_08A, text.replace(old, new, 1))
        print("[FIX] STEP 08A D01 full-JSON false positive corrected.")
    elif "assets/data/(?:players|clubs)" in text:
        print("[PASS] STEP 08A D01 fix already present.")
    else:
        print("[WARN] STEP 08A D01 block not recognized; audit helper unchanged.")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--privacy-email", required=True)
    args = parser.parse_args()

    email = validate_email(args.privacy_email)

    if not WELCOME.exists() or not FUNCTIONS.exists() or not FIREBASE_JSON.exists():
        raise RuntimeError("Required Linkball source files are missing.")

    for path in PATCHED_FILES + NEW_FILES:
        backup_or_mark(path)

    pid = project_id()
    privacy_url = f"https://{pid}.web.app/privacy.html"
    delete_url = f"https://{pid}.web.app/account-deletion.html"

    dart_repl = {
        "__CONTACT_EMAIL__": email.replace("\\", "\\\\").replace("'", "\\'"),
        "__PRIVACY_URL__": privacy_url,
        "__DELETE_URL__": delete_url,
    }
    html_repl = {
        "__CONTACT_EMAIL__": html.escape(email, quote=True),
        "__PRIVACY_URL__": html.escape(privacy_url, quote=True),
        "__DELETE_URL__": html.escape(delete_url, quote=True),
    }
    md_repl = {
        "__CONTACT_EMAIL__": email,
        "__PRIVACY_URL__": privacy_url,
        "__DELETE_URL__": delete_url,
    }

    write_lf(
        ROOT / "lib/config/privacy_config.dart",
        render_template("privacy_config.dart.tmpl", dart_repl),
    )
    write_lf(
        ROOT / "lib/services/account_deletion_service.dart",
        render_template("account_deletion_service.dart.tmpl", {}),
    )
    write_lf(
        ROOT / "lib/screens/privacy_account_page.dart",
        render_template("privacy_account_page.dart.tmpl", {}),
    )
    write_lf(
        ROOT / "functions/test/account_deletion_contracts.test.js",
        render_template("account_deletion_contracts.test.js.tmpl", {}),
    )
    write_lf(
        ROOT / "play_store_web/index.html",
        render_template("index.html.tmpl", html_repl),
    )
    write_lf(
        ROOT / "play_store_web/privacy.html",
        render_template("privacy.html.tmpl", html_repl),
    )
    write_lf(
        ROOT / "play_store_web/account-deletion.html",
        render_template("account-deletion.html.tmpl", html_repl),
    )
    write_lf(
        ROOT / "docs/production/PRIVACY_POLICY.md",
        render_template("PRIVACY_POLICY.md.tmpl", md_repl),
    )
    write_lf(
        ROOT / "docs/production/DATA_SAFETY_DRAFT.md",
        render_template("DATA_SAFETY_DRAFT.md.tmpl", md_repl),
    )
    write_lf(
        ROOT / "docs/production/ACCOUNT_DELETION.md",
        render_template("ACCOUNT_DELETION.md.tmpl", md_repl),
    )

    patch_welcome()
    patch_functions()
    patch_firebase_json()
    patch_08a_false_positive()

    print()
    print("[OK] STEP 08B.2 source/privacy patch complete.")
    print("[PUBLIC] Privacy contact:", email)
    print("[PUBLIC] Privacy URL:", privacy_url)
    print("[PUBLIC] Account deletion URL:", delete_url)
    print("[SAFE] No signing secret or private credential was added.")

if __name__ == "__main__":
    main()
