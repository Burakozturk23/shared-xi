from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "lib/main.dart"
WELCOME = ROOT / "lib/screens/welcome_page.dart"

def backup(path):
    bak = path.with_suffix(path.suffix + ".step07a92.bak")
    if not bak.exists():
        shutil.copy2(path, bak)
        print("[BACKUP]", bak.relative_to(ROOT))
    return bak

def write_lf(path, text):
    with path.open("w", encoding="utf-8", newline="\n") as f:
        f.write(text.replace("\r\n", "\n").replace("\r", "\n"))

def call_span(text, function_name, marker):
    marker_pos = text.find(marker)
    if marker_pos < 0:
        return None
    start = text.rfind(function_name + "(", 0, marker_pos)
    if start < 0:
        return None
    pos = start + len(function_name)
    depth = 0; in_s = False; in_d = False; esc = False
    end_paren = None
    while pos < len(text):
        ch = text[pos]
        if esc:
            esc = False; pos += 1; continue
        if ch == "\\":
            esc = True; pos += 1; continue
        if not in_d and ch == "'":
            in_s = not in_s; pos += 1; continue
        if not in_s and ch == '"':
            in_d = not in_d; pos += 1; continue
        if in_s or in_d:
            pos += 1; continue
        if ch == "(": depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                end_paren = pos; break
        pos += 1
    if end_paren is None:
        return None
    end = end_paren + 1
    while end < len(text) and text[end] in " \t": end += 1
    if end < len(text) and text[end] == ";": end += 1
    return start, end

def patch_main():
    text = MAIN.read_text(encoding="utf-8", errors="replace")
    if "STEP 07A.9.2: Auth is deferred out of startup." in text:
        print("[PASS] main.dart already patched"); return
    for marker in [
        "final authFuture = AuthService.ensureSignedIn();",
        "await authFuture;",
        "[Startup] Auth ready",
        "[Startup] RuntimeV3 ready",
        "[Startup] Welcome navigation",
    ]:
        if marker not in text:
            raise RuntimeError("main.dart marker missing: " + marker)

    text = text.replace(
        "final authFuture = AuthService.ensureSignedIn();",
        "// STEP 07A.9.2: Auth is deferred out of startup.\n"
        "      // Daily/Online prepare Auth only when entered.", 1)
    text = text.replace("      setState(() => _status = 'Oturum…');\n", "", 1)
    text = text.replace("      await authFuture;\n", "", 1)

    span = call_span(text, "debugPrint", "[Startup] Auth ready")
    if span is None: raise RuntimeError("Auth-ready debugPrint span not found")
    a,b=span
    text = text[:a] + text[b:]

    span = call_span(text, "debugPrint", "[Startup] RuntimeV3 ready")
    if span is None: raise RuntimeError("RuntimeV3 debugPrint span not found")
    _,b=span
    text = text[:b] + "\n\n      debugPrint(\n        '[Startup] Auth deferred ${startupWatch.elapsedMilliseconds}ms',\n      );" + text[b:]

    if "[Startup] Welcome navigation" not in text:
        raise RuntimeError("Safety stop: Welcome navigation marker disappeared")

    candidate = text.replace("import 'services/auth_service.dart';\n", "")
    if "AuthService." not in candidate:
        text = candidate
    write_lf(MAIN, text)
    print("[FIX] main.dart Auth removed; Welcome marker preserved.")

def matching_brace(lines, start):
    depth=0; seen=False
    for i in range(start, len(lines)):
        for ch in lines[i]:
            if ch=='{': depth+=1; seen=True
            elif ch=='}': depth-=1
        if seen and depth==0: return i
    return None

def mark_mode(lines, title):
    idx=next((i for i,x in enumerate(lines) if ("title: '"+title+"'") in x), None)
    if idx is None: raise RuntimeError("Mode not found: "+title)
    end=next((i for i in range(idx,min(len(lines),idx+30)) if lines[i].strip()=="),"), None)
    if end is None: raise RuntimeError("Mode end not found: "+title)
    if any("requiresAuth: true," in lines[i] for i in range(idx,end+1)): return
    sub=next((i for i in range(idx,end+1) if "subtitle:" in lines[i]),None)
    if sub is None: raise RuntimeError("Subtitle not found: "+title)
    indent=lines[sub][:len(lines[sub])-len(lines[sub].lstrip())]
    lines.insert(sub+1, indent+"requiresAuth: true,")

def patch_welcome():
    text=WELCOME.read_text(encoding="utf-8", errors="replace")
    if "STEP 07A.9.2: auth-required modes authenticate on demand." in text:
        print("[PASS] welcome_page.dart already patched"); return
    if "import '../services/auth_service.dart';" not in text:
        anchor="import '../repositories/repository.dart';\n"
        if anchor not in text: raise RuntimeError("Repository import missing")
        text=text.replace(anchor, anchor+"import '../services/auth_service.dart';\n",1)
    if "final bool requiresAuth;" not in text:
        anchor="  final Widget page;\n"
        if anchor not in text: raise RuntimeError("_ModeItem field anchor missing")
        text=text.replace(anchor, anchor+"\n  /// STEP 07A.9.2: auth-required modes authenticate on demand.\n  final bool requiresAuth;\n",1)
    if "this.requiresAuth = false," not in text:
        anchor="    this.accent,\n"
        if anchor not in text: raise RuntimeError("_ModeItem ctor anchor missing")
        text=text.replace(anchor, anchor+"    this.requiresAuth = false,\n",1)

    lines=text.splitlines(); mark_mode(lines,"Günün maçları"); mark_mode(lines,"Online")
    start=next((i for i,x in enumerate(lines) if "if (!Repository.instance.isInitialized) {" in x),None)
    if start is None: raise RuntimeError("Repository readiness gate missing")
    end=matching_brace(lines,start)
    if end is None: raise RuntimeError("Repository gate brace mismatch")
    j=end+1
    while j<len(lines) and not lines[j].strip(): j+=1
    if j<len(lines) and lines[j].strip()=="if (!context.mounted) return;": end=j
    indent=lines[start][:len(lines[start])-len(lines[start].lstrip())]
    B=[
      "final waits = <Future<void>>[];",
      "final needsRepository = !Repository.instance.isInitialized;",
      "",
      "if (needsRepository) {","  waits.add(Repository.instance.initialize());","}","",
      "if (item.requiresAuth) {","  waits.add(AuthService.ensureSignedIn());","}","",
      "if (waits.isNotEmpty) {",
      "  final label = item.requiresAuth && needsRepository",
      "      ? 'Veri ve oturum hazırlanıyor…'",
      "      : item.requiresAuth",
      "          ? 'Oturum hazırlanıyor…'",
      "          : 'Oyuncu verisi hazırlanıyor…';","",
      "  messenger.showSnackBar(","    SnackBar(","      duration: const Duration(minutes: 1),","      content: Row(","        children: [",
      "          const SizedBox(","            width: 18,","            height: 18,","            child: CircularProgressIndicator(strokeWidth: 2),","          ),",
      "          const SizedBox(width: 12),","          Expanded(child: Text(label)),","        ],","      ),","    ),","  );","",
      "  await Future.wait(waits);","","  if (!context.mounted) return;","  messenger.hideCurrentSnackBar();","}","","if (!context.mounted) return;"
    ]
    block=[]
    for x in B:
        block.append(indent+x if x else "")
    lines[start:end+1]=block
    write_lf(WELCOME,"\n".join(lines)+"\n")
    print("[FIX] Daily/Online Auth moved to on-demand entry.")
    print("[FIX] Repository + Auth prepare concurrently.")

def main():
    for p in [MAIN,WELCOME]:
        if not p.exists(): raise RuntimeError("Missing: "+str(p.relative_to(ROOT)))
        backup(p)
    patch_main(); patch_welcome()
    print("\n[OK] STEP 07A.9.2 source patch complete.")
if __name__=='__main__': main()
