from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]
REPO = ROOT / 'lib/repositories/repository.dart'
MAIN = ROOT / 'lib/main.dart'
WELCOME = ROOT / 'lib/screens/welcome_page.dart'
FLAGS = ROOT / 'lib/services/runtime_v3/runtime_v3_flags.dart'
PLATFORM = ROOT / 'lib/services/runtime_v3/runtime_v3_platform_io.dart'
FILES = [REPO, MAIN, WELCOME, FLAGS, PLATFORM]


def backup(path: Path):
    bak = path.with_suffix(path.suffix + '.step07a8.bak')
    if not bak.exists():
        shutil.copy2(path, bak)
        print('[BACKUP]', bak.relative_to(ROOT))
    else:
        print('[PASS] Backup exists:', bak.relative_to(ROOT))


def write_lf(path: Path, text: str):
    with path.open('w', encoding='utf-8', newline='\n') as f:
        f.write(text.replace('\r\n', '\n').replace('\r', '\n'))


def extract_method(text: str, signature: str):
    start = text.find(signature)
    if start < 0:
        return None
    brace = text.find('{', start)
    if brace < 0:
        return None
    depth = 0
    for i in range(brace, len(text)):
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                return start, i + 1
    return None


def patch_repository():
    text = REPO.read_text(encoding='utf-8', errors='replace')
    if 'STEP 07A.8: concurrency-safe repository initialization' in text:
        print('[PASS] repository.dart already patched')
        return

    anchor = '  bool _initialized = false;\n'
    if anchor not in text:
        raise RuntimeError('repository _initialized anchor not found')
    text = text.replace(
        anchor,
        anchor + '\n  // STEP 07A.8: concurrency-safe repository initialization.\n'
        '  Future<void>? _initializeFuture;\n',
        1,
    )

    method = extract_method(text, '  Future<void> initialize() async')
    if method is None:
        raise RuntimeError('Repository.initialize method not found')
    start, end = method
    replacement = """  Future<void> initialize() async {
    if (_initialized) return;

    final inFlight = _initializeFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = _initializeInternal();
    _initializeFuture = future;

    try {
      await future;
    } finally {
      if (identical(_initializeFuture, future)) {
        _initializeFuture = null;
      }
    }
  }

  Future<void> _initializeInternal() async {
    final meta = await DatabaseService.loadMeta();
    _dataVersion = meta['dataVersion']?.toString() ?? 'legacy';

    final results = await Future.wait([
      DatabaseService.loadClubs(),
      DatabaseService.loadPlayers(),
      DatabaseService.loadFamousTransfers(),
      DatabaseService.loadCoaches(),
    ]);

    _clubs = results[0] as List<Club>;
    final rawPlayers = results[1] as List<Player>;
    _famousTransfers = results[2] as List<FamousTransfer>;
    _coaches = results[3] as List<Coach>;

    _rawPlayerCount = rawPlayers.length;
    _playerById = {for (final p in rawPlayers) p.id: p};
    _players = PlayerDedupe.dedupe(rawPlayers);
    _clubById = {for (final c in _clubs) c.id: c};

    SearchService.buildIndex(_players);
    _initialized = true;
  }
"""
    text = text[:start] + replacement + text[end:]

    getter_anchor = '  bool get isInitialized => _initialized;\n'
    if getter_anchor not in text:
        raise RuntimeError('Repository getter anchor not found')
    text = text.replace(
        getter_anchor,
        getter_anchor + '  bool get isInitializing => _initializeFuture != null;\n',
        1,
    )
    write_lf(REPO, text)
    print('[FIX] Repository initialization is concurrency-safe.')


def patch_main():
    text = MAIN.read_text(encoding='utf-8', errors='replace')
    if 'STEP 07A.8: keep legacy JSON outside the splash critical path.' in text:
        print('[PASS] main.dart already patched')
        return

    if "import 'dart:async';" not in text:
        text = "import 'dart:async';\n\n" + text

    method = extract_method(text, '  Future<void> _boot() async')
    if method is None:
        raise RuntimeError('_BootstrapPageState._boot not found')
    start, end = method
    replacement = """  Future<void> _boot() async {
    final startupWatch = Stopwatch()..start();

    try {
      setState(() {
        _error = null;
        _status = 'Hızlı veri motoru…';
      });

      // STEP 07A.8: keep legacy JSON outside the splash critical path.
      // Runtime V3 gets first priority. Auth runs in parallel. The large
      // legacy player JSON warms only after Welcome paints its first frame.
      final authFuture = AuthService.ensureSignedIn();

      await RuntimeV3Service.instance.initializeIfEnabled();
      debugPrint(
        '[Startup] RuntimeV3 ready '
        '${startupWatch.elapsedMilliseconds}ms '
        'status=${RuntimeV3Service.instance.status.name}',
      );

      if (!mounted) return;
      setState(() => _status = 'Oturum…');

      await authFuture;
      debugPrint(
        '[Startup] Auth ready ${startupWatch.elapsedMilliseconds}ms',
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomePage()),
      );

      debugPrint(
        '[Startup] Welcome navigation '
        '${startupWatch.elapsedMilliseconds}ms',
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          Future<void>.delayed(
            const Duration(milliseconds: 750),
            () => _warmLegacyRepository(startupWatch),
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _warmLegacyRepository(Stopwatch startupWatch) async {
    try {
      await Repository.instance.initialize();

      debugPrint(
        '[Startup] Repository ready '
        '${startupWatch.elapsedMilliseconds}ms '
        'players=${Repository.instance.playerCount}',
      );

      await RuntimeV3Service.instance.runParityAudit(
        Repository.instance,
      );
    } catch (e, st) {
      debugPrint('[Startup] Repository background warmup failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }
"""
    text = text[:start] + replacement + text[end:]
    write_lf(MAIN, text)
    print('[FIX] Splash critical path now prioritizes Runtime V3 + Auth.')


def patch_welcome():
    text = WELCOME.read_text(encoding='utf-8', errors='replace')
    if 'STEP 07A.8: gate mode navigation on Repository readiness.' in text:
        print('[PASS] welcome_page.dart already patched')
        return

    class_anchor = 'class _ModeCard extends StatelessWidget {\n  final _ModeItem item;\n'
    if class_anchor not in text:
        raise RuntimeError('_ModeCard class anchor not found')
    text = text.replace(
        class_anchor,
        class_anchor + '\n  // STEP 07A.8: gate mode navigation on Repository readiness.\n'
        '  static bool _navigationLocked = false;\n',
        1,
    )

    old = """        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => item.page),
          );
        },"""
    if old not in text:
        raise RuntimeError('Welcome _ModeCard onTap anchor not found')

    new = """        onTap: () async {
          if (_navigationLocked) return;
          _navigationLocked = true;

          final messenger = ScaffoldMessenger.of(context);

          try {
            if (!Repository.instance.isInitialized) {
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

            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => item.page),
            );
          } catch (e) {
            if (!context.mounted) return;

            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(
              SnackBar(
                content: Text('Veri hazırlanamadı: $e'),
              ),
            );
          } finally {
            _navigationLocked = false;
          }
        },"""
    text = text.replace(old, new, 1)
    write_lf(WELCOME, text)
    print('[FIX] Welcome mode navigation waits safely for Repository if needed.')


def patch_flags():
    text = FLAGS.read_text(encoding='utf-8', errors='replace')
    text = text.replace('  /// Opens the SQLite V3 sidecar. Default OFF.\n',
                        '  /// Production default: Runtime V3 is ON.\n')
    text = text.replace("'LINKBALL_SQLITE_V3',\n    defaultValue: false,",
                        "'LINKBALL_SQLITE_V3',\n    defaultValue: true,", 1)
    text = text.replace(
        '  /// 04.2A: allows selected offline gameplay controllers to use SQLite\n'
        '  /// relationships/pools while Player/Club UI models still come from Repository.\n',
        '  /// Production default: migrated gameplay controllers use Runtime V3.\n'
        '  /// Player/Club UI models still come from Repository until the V3 model bridge.\n')
    text = text.replace("'LINKBALL_SQLITE_GAMEPLAY_V3',\n    defaultValue: false,",
                        "'LINKBALL_SQLITE_GAMEPLAY_V3',\n    defaultValue: true,", 1)
    text = text.replace("'LINKBALL_SQLITE_PARITY',\n    defaultValue: true,",
                        "'LINKBALL_SQLITE_PARITY',\n    defaultValue: false,", 1)
    write_lf(FLAGS, text)
    print('[FIX] Runtime V3/gameplay defaults ON; parity default OFF.')


def patch_platform():
    text = PLATFORM.read_text(encoding='utf-8', errors='replace')
    text = text.replace('      await temp.writeAsBytes(bytes, flush: true);',
                        '      await temp.writeAsBytes(bytes);', 1)

    old = """    final integrity = await _database.rawQuery('PRAGMA integrity_check');
    final value =
        integrity.isEmpty ? '' : integrity.first.values.first?.toString();
    if (value != 'ok') {
      await close();
      throw StateError('Runtime V3 integrity_check failed: $value');
    }

    final meta = await metadata();"""

    if old not in text:
        if 'PRAGMA quick_check' in text:
            print('[PASS] runtime_v3_platform_io.dart already optimized')
            return
        raise RuntimeError('Runtime V3 integrity block not found')

    new = """    // STEP 07A.8: full integrity_check cost ~2.8s in the measured
    // release profile. Validate only a freshly copied/version-changed DB and
    // use SQLite quick_check. Cached DBs go straight to schema metadata.
    if (mustCopy) {
      final integrity = await _database.rawQuery('PRAGMA quick_check');
      final value =
          integrity.isEmpty ? '' : integrity.first.values.first?.toString();

      if (value != 'ok') {
        await close();
        try {
          if (await target.exists()) {
            await target.delete();
          }
        } catch (_) {}

        throw StateError('Runtime V3 quick_check failed: $value');
      }
    }

    final meta = await metadata();"""
    text = text.replace(old, new, 1)
    write_lf(PLATFORM, text)
    print('[FIX] Cached SQLite no longer runs full integrity_check.')
    print('[FIX] Fresh copy uses quick_check; forced fsync flush removed.')


def main():
    for path in FILES:
        if not path.exists():
            raise RuntimeError(f'Required file missing: {path.relative_to(ROOT)}')
    for path in FILES:
        backup(path)
    patch_repository()
    patch_main()
    patch_welcome()
    patch_flags()
    patch_platform()
    print()
    print('[OK] STEP 07A.8 source patch complete.')
    print('[SAFE] Legacy Player semantics/data remain unchanged.')
    print('[SAFE] players_min.json remains available as compatibility data.')


if __name__ == '__main__':
    main()
