from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "lib/main.dart"
WELCOME = ROOT / "lib/screens/welcome_page.dart"

def backup(path: Path):
    bak = path.with_suffix(path.suffix + ".step07a9.bak")
    if not bak.exists():
        shutil.copy2(path, bak)
        print("[BACKUP]", bak.relative_to(ROOT))
    else:
        print("[PASS] Backup exists:", bak.relative_to(ROOT))

def write_lf(path: Path, text: str):
    with path.open("w", encoding="utf-8", newline="\n") as f:
        f.write(text.replace("\r\n", "\n").replace("\r", "\n"))

def patch_main():
    text = MAIN.read_text(encoding="utf-8", errors="replace")

    if "STEP 07A.9: Auth is no longer a splash dependency." in text:
        print("[PASS] main.dart already patched")
        return

    required = [
        "final authFuture = AuthService.ensureSignedIn();",
        "await authFuture;",
        "[Startup] Auth ready",
        "[Startup] Welcome navigation",
        "_warmLegacyRepository(startupWatch)",
    ]
    for marker in required:
        if marker not in text:
            raise RuntimeError("main.dart expected 07A.8 marker missing: " + marker)

    # Auth is no longer started/awaited by the splash route.
    text = text.replace(
        "      final authFuture = AuthService.ensureSignedIn();\n\n",
        "      // STEP 07A.9: Auth is no longer a splash dependency.\n"
        "      // Anonymous/session auth is prepared only when an auth-required\n"
        "      // mode is entered (Daily/Online).\n\n",
        1,
    )

    old = """      if (!mounted) return;
      setState(() => _status = 'Oturum…');

      await authFuture;
      debugPrint(
        '[Startup] Auth ready ${startupWatch.elapsedMilliseconds}ms',
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
"""
    new = """      if (!mounted) return;

      debugPrint(
        '[Startup] Auth deferred ${startupWatch.elapsedMilliseconds}ms',
      );

      Navigator.of(context).pushReplacement(
"""
    if old not in text:
        raise RuntimeError("main.dart auth-await block not found")
    text = text.replace(old, new, 1)

    # main.dart no longer needs AuthService directly.
    text = text.replace("import 'services/auth_service.dart';\n", "", 1)

    write_lf(MAIN, text)
    print("[FIX] Auth removed from splash critical path.")

def patch_welcome():
    text = WELCOME.read_text(encoding="utf-8", errors="replace")

    if "STEP 07A.9: auth-required modes authenticate on demand." in text:
        print("[PASS] welcome_page.dart already patched")
        return

    # Import AuthService.
    repo_import = "import '../repositories/repository.dart';\n"
    if repo_import not in text:
        raise RuntimeError("welcome repository import missing")
    if "import '../services/auth_service.dart';" not in text:
        text = text.replace(
            repo_import,
            repo_import + "import '../services/auth_service.dart';\n",
            1,
        )

    # Add requiresAuth field to mode model.
    old_fields = """  final Color? accent;
  final Widget page;

  const _ModeItem({
"""
    new_fields = """  final Color? accent;
  final Widget page;

  /// STEP 07A.9: auth-required modes authenticate on demand.
  final bool requiresAuth;

  const _ModeItem({
"""
    if old_fields not in text:
        raise RuntimeError("_ModeItem field anchor missing")
    text = text.replace(old_fields, new_fields, 1)

    old_ctor = """    required this.page,
    this.accent,
  });
"""
    new_ctor = """    required this.page,
    this.accent,
    this.requiresAuth = false,
  });
"""
    if old_ctor not in text:
        raise RuntimeError("_ModeItem ctor anchor missing")
    text = text.replace(old_ctor, new_ctor, 1)

    # Mark Daily/calendar and Online entry cards as auth-required.
    daily_anchor = """                title: 'Günün maçları',
                subtitle: 'Her gün yeni ortak oyuncu bulmacası',
"""
    if daily_anchor not in text:
        raise RuntimeError("Günün maçları item anchor missing")
    text = text.replace(
        daily_anchor,
        daily_anchor + "                requiresAuth: true,\n",
        1,
    )

    online_anchor = """                title: 'Online',
                subtitle: 'Rastgele eşleş veya arkadaşlarınla oyna',
"""
    if online_anchor not in text:
        raise RuntimeError("Online item anchor missing")
    text = text.replace(
        online_anchor,
        online_anchor + "                requiresAuth: true,\n",
        1,
    )

    # Current STEP 07A.8 onTap waits on Repository.
    repo_wait = """            if (!Repository.instance.isInitialized) {
              messenger.showSnackBar(
                const SnackBar(
                  duration: Duration(minutes: 1),
                  content: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('Oyuncu verisi hazırlanıyor…'),
                      ),
                    ],
                  ),
                ),
              );

              await Repository.instance.initialize();

              if (!context.mounted) return;
              messenger.hideCurrentSnackBar();
            }

            if (!context.mounted) return;
"""
    if repo_wait not in text:
        raise RuntimeError("STEP 07A.8 Repository gate block not found")

    concurrent_gate = """            final waits = <Future<void>>[];
            final needsRepository = !Repository.instance.isInitialized;

            if (needsRepository) {
              waits.add(Repository.instance.initialize());
            }

            if (item.requiresAuth) {
              waits.add(AuthService.ensureSignedIn());
            }

            if (waits.isNotEmpty) {
              final label = item.requiresAuth && needsRepository
                  ? 'Veri ve oturum hazırlanıyor…'
                  : item.requiresAuth
                      ? 'Oturum hazırlanıyor…'
                      : 'Oyuncu verisi hazırlanıyor…';

              messenger.showSnackBar(
                SnackBar(
                  duration: const Duration(minutes: 1),
                  content: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(label)),
                    ],
                  ),
                ),
              );

              await Future.wait(waits);

              if (!context.mounted) return;
              messenger.hideCurrentSnackBar();
            }

            if (!context.mounted) return;
"""
    text = text.replace(repo_wait, concurrent_gate, 1)

    write_lf(WELCOME, text)
    print("[FIX] Daily/Online auth moved to on-demand mode entry.")
    print("[FIX] Repository + Auth wait concurrently when both are needed.")

def main():
    for path in [MAIN, WELCOME]:
        if not path.exists():
            raise RuntimeError("Missing: " + str(path.relative_to(ROOT)))
        backup(path)

    patch_main()
    patch_welcome()

    print()
    print("[OK] STEP 07A.9 source patch complete.")
    print("[SAFE] Runtime V3 and Repository behavior otherwise unchanged.")

if __name__ == "__main__":
    main()
