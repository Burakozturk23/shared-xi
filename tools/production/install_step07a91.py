from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "lib/main.dart"
WELCOME = ROOT / "lib/screens/welcome_page.dart"

def backup(path):
    bak = path.with_suffix(path.suffix + ".step07a91.bak")
    if not bak.exists():
        shutil.copy2(path, bak)
        print("[BACKUP]", bak.relative_to(ROOT))
    return bak

def write_lf(path, text):
    with path.open("w", encoding="utf-8", newline="\n") as f:
        f.write(text.replace("\r\n", "\n").replace("\r", "\n"))

def remove_debug_block(lines, marker):
    marker_idx = next((i for i, x in enumerate(lines) if marker in x), None)
    if marker_idx is None:
        return False
    start = next((i for i in range(marker_idx, -1, -1) if "debugPrint(" in lines[i]), None)
    if start is None:
        return False
    end = next((i for i in range(marker_idx, len(lines)) if lines[i].strip() == ");"), None)
    if end is None:
        return False
    del lines[start:end+1]
    return True

def insert_after_debug_block(lines, marker, additions):
    marker_idx = next((i for i, x in enumerate(lines) if marker in x), None)
    if marker_idx is None:
        return False
    end = next((i for i in range(marker_idx, len(lines)) if lines[i].strip() == ");"), None)
    if end is None:
        return False
    lines[end+1:end+1] = additions
    return True

def patch_main():
    text = MAIN.read_text(encoding="utf-8", errors="replace")

    if "STEP 07A.9.1: Auth is deferred out of startup." in text:
        print("[PASS] main.dart already patched")
        return

    for marker in [
        "final authFuture = AuthService.ensureSignedIn();",
        "await authFuture;",
        "[Startup] Auth ready",
        "[Startup] RuntimeV3 ready",
        "[Startup] Welcome navigation",
    ]:
        if marker not in text:
            raise RuntimeError("main.dart marker missing: " + marker)

    lines = text.splitlines()

    idx = next(i for i, x in enumerate(lines) if "final authFuture = AuthService.ensureSignedIn();" in x)
    indent = lines[idx][:len(lines[idx]) - len(lines[idx].lstrip())]
    lines[idx:idx+1] = [
        indent + "// STEP 07A.9.1: Auth is deferred out of startup.",
        indent + "// Daily/Online prepare Auth only when entered.",
    ]

    lines = [x for x in lines if "setState(() => _status = 'Oturum…');" not in x]
    lines = [x for x in lines if "await authFuture;" not in x]

    if not remove_debug_block(lines, "[Startup] Auth ready"):
        raise RuntimeError("Could not remove Auth-ready debug block")

    if not insert_after_debug_block(
        lines,
        "[Startup] RuntimeV3 ready",
        [
            "",
            "      debugPrint(",
            "        '[Startup] Auth deferred ${startupWatch.elapsedMilliseconds}ms',",
            "      );",
        ],
    ):
        raise RuntimeError("Could not insert Auth-deferred marker")

    text = "\n".join(lines) + "\n"
    candidate = text.replace("import 'services/auth_service.dart';\n", "")
    if "AuthService." not in candidate:
        text = candidate

    write_lf(MAIN, text)
    print("[FIX] main.dart startup Auth wait removed.")

def find_matching_brace(lines, start):
    depth = 0
    seen = False
    for i in range(start, len(lines)):
        for ch in lines[i]:
            if ch == "{":
                depth += 1
                seen = True
            elif ch == "}":
                depth -= 1
        if seen and depth == 0:
            return i
    return None

def mark_mode(lines, title):
    idx = next((i for i, x in enumerate(lines) if ("title: '" + title + "'") in x), None)
    if idx is None:
        raise RuntimeError("Mode not found: " + title)

    end = next((i for i in range(idx, min(len(lines), idx + 25)) if lines[i].strip() == "),"), None)
    if end is None:
        raise RuntimeError("Mode end not found: " + title)

    if any("requiresAuth: true," in lines[i] for i in range(idx, end + 1)):
        return

    subtitle = next((i for i in range(idx, end + 1) if "subtitle:" in lines[i]), None)
    if subtitle is None:
        raise RuntimeError("Mode subtitle not found: " + title)

    indent = lines[subtitle][:len(lines[subtitle]) - len(lines[subtitle].lstrip())]
    lines.insert(subtitle + 1, indent + "requiresAuth: true,")

def patch_welcome():
    text = WELCOME.read_text(encoding="utf-8", errors="replace")

    if "STEP 07A.9.1: auth-required modes authenticate on demand." in text:
        print("[PASS] welcome_page.dart already patched")
        return

    if "import '../services/auth_service.dart';" not in text:
        anchor = "import '../repositories/repository.dart';\n"
        if anchor not in text:
            raise RuntimeError("Repository import missing")
        text = text.replace(anchor, anchor + "import '../services/auth_service.dart';\n", 1)

    if "final bool requiresAuth;" not in text:
        anchor = "  final Widget page;\n"
        if anchor not in text:
            raise RuntimeError("_ModeItem page field missing")
        text = text.replace(
            anchor,
            anchor
            + "\n"
            + "  /// STEP 07A.9.1: auth-required modes authenticate on demand.\n"
            + "  final bool requiresAuth;\n",
            1,
        )

    if "this.requiresAuth = false," not in text:
        anchor = "    this.accent,\n"
        if anchor not in text:
            raise RuntimeError("_ModeItem constructor anchor missing")
        text = text.replace(anchor, anchor + "    this.requiresAuth = false,\n", 1)

    lines = text.splitlines()
    mark_mode(lines, "Günün maçları")
    mark_mode(lines, "Online")

    repo_if = next((i for i, x in enumerate(lines) if "if (!Repository.instance.isInitialized) {" in x), None)
    if repo_if is None:
        raise RuntimeError("Repository readiness gate missing")

    repo_end = find_matching_brace(lines, repo_if)
    if repo_end is None:
        raise RuntimeError("Repository gate brace mismatch")

    replace_end = repo_end
    j = repo_end + 1
    while j < len(lines) and not lines[j].strip():
        j += 1
    if j < len(lines) and lines[j].strip() == "if (!context.mounted) return;":
        replace_end = j

    indent = lines[repo_if][:len(lines[repo_if]) - len(lines[repo_if].lstrip())]

    block = [
        indent + "final waits = <Future<void>>[];",
        indent + "final needsRepository = !Repository.instance.isInitialized;",
        "",
        indent + "if (needsRepository) {",
        indent + "  waits.add(Repository.instance.initialize());",
        indent + "}",
        "",
        indent + "if (item.requiresAuth) {",
        indent + "  waits.add(AuthService.ensureSignedIn());",
        indent + "}",
        "",
        indent + "if (waits.isNotEmpty) {",
        indent + "  final label = item.requiresAuth && needsRepository",
        indent + "      ? 'Veri ve oturum hazırlanıyor…'",
        indent + "      : item.requiresAuth",
        indent + "          ? 'Oturum hazırlanıyor…'",
        indent + "          : 'Oyuncu verisi hazırlanıyor…';",
        "",
        indent + "  messenger.showSnackBar(",
        indent + "    SnackBar(",
        indent + "      duration: const Duration(minutes: 1),",
        indent + "      content: Row(",
        indent + "        children: [",
        indent + "          const SizedBox(",
        indent + "            width: 18,",
        indent + "            height: 18,",
        indent + "            child: CircularProgressIndicator(",
        indent + "              strokeWidth: 2,",
        indent + "            ),",
        indent + "          ),",
        indent + "          const SizedBox(width: 12),",
        indent + "          Expanded(child: Text(label)),",
        indent + "        ],",
        indent + "      ),",
        indent + "    ),",
        indent + "  );",
        "",
        indent + "  await Future.wait(waits);",
        "",
        indent + "  if (!context.mounted) return;",
        indent + "  messenger.hideCurrentSnackBar();",
        indent + "}",
        "",
        indent + "if (!context.mounted) return;",
    ]

    lines[repo_if:replace_end+1] = block
    write_lf(WELCOME, "\n".join(lines) + "\n")

    print("[FIX] Daily/Online Auth moved to on-demand entry.")
    print("[FIX] Repository + Auth waits run concurrently.")

def main():
    for path in [MAIN, WELCOME]:
        if not path.exists():
            raise RuntimeError("Missing: " + str(path.relative_to(ROOT)))
        backup(path)

    patch_main()
    patch_welcome()
    print()
    print("[OK] STEP 07A.9.1 source patch complete.")

if __name__ == "__main__":
    main()
