from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTROLLERS = ROOT / "lib/controllers"

GAME = CONTROLLERS / "game_controller.dart"
ODD = CONTROLLERS / "odd_club_controller.dart"
GUESS = CONTROLLERS / "guess_the_player_controller.dart"

HYBRID_IMPORT = "import '../services/runtime_v3/hybrid_gameplay_data_service.dart';"

def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step04_2a.bak")
    if not bak.exists():
        shutil.copy2(path, bak)

def add_import(text: str, anchor: str) -> str:
    if HYBRID_IMPORT in text:
        return text
    if anchor not in text:
        raise RuntimeError(f"import anchor bulunamadi: {anchor}")
    return text.replace(anchor, anchor + "\n" + HYBRID_IMPORT, 1)

def patch_game(text: str) -> str:
    text = add_import(text, "import '../services/search_service.dart';")

    if "HybridGameplayDataService.instance.sharedXiMatchingPlayers" in text:
        return text

    method_marker = "Future<void> initialize() async"
    method_pos = text.find(method_marker)
    if method_pos < 0:
        raise RuntimeError("game_controller initialize() methodu bulunamadi")

    call_pos = text.find("GameService.matchingPlayers(", method_pos)
    if call_pos < 0:
        raise RuntimeError(
            "game_controller icinde GameService.matchingPlayers cagrisi bulunamadi"
        )

    assignment_start = text.rfind("final matchingPlayers", method_pos, call_pos)
    if assignment_start < 0:
        assignment_start = text.rfind("var matchingPlayers", method_pos, call_pos)
    if assignment_start < 0:
        assignment_start = text.rfind("matchingPlayers =", method_pos, call_pos)
    if assignment_start < 0:
        raise RuntimeError(
            "game_controller matchingPlayers assignment baslangici bulunamadi"
        )

    assignment_line_start = text.rfind("\n", method_pos, assignment_start) + 1
    indent_match = re.match(r"[ \t]*", text[assignment_line_start:assignment_start])
    indent = indent_match.group(0) if indent_match else "    "

    depth = 0
    seen_open = False
    i = call_pos
    assignment_end = -1
    while i < len(text):
        ch = text[i]
        if ch == "(":
            depth += 1
            seen_open = True
        elif ch == ")":
            if seen_open:
                depth -= 1
        elif ch == ";" and seen_open and depth == 0:
            assignment_end = i + 1
            break
        i += 1

    if assignment_end < 0:
        raise RuntimeError(
            "game_controller GameService.matchingPlayers cagrisi sonu bulunamadi"
        )

    replace_start = assignment_line_start

    # Remove a nearby `final players = Repository.instance.players;` only when
    # it is the last meaningful statement before matchingPlayers.
    method_prefix = text[method_pos:assignment_line_start]
    decls = list(re.finditer(
        r"(?m)^[ \t]*final\s+players\s*=\s*Repository\.instance\.players\s*;[ \t]*$",
        method_prefix,
    ))
    if decls:
        last = decls[-1]
        absolute_end = method_pos + last.end()
        between = text[absolute_end:assignment_line_start]
        if between.strip() == "":
            replace_start = method_pos + last.start()

    new = (
        f"{indent}// 04.2A: only OFFLINE club-vs-club Shared XI uses SQLite.\n"
        f"{indent}// Online/ranked and country criteria remain JSON for now.\n"
        f"{indent}final matchingPlayers =\n"
        f"{indent}    await HybridGameplayDataService.instance.sharedXiMatchingPlayers(\n"
        f"{indent}  entity1: entity1,\n"
        f"{indent}  entity2: entity2,\n"
        f"{indent}  allowSqlite: roomCode == null,\n"
        f"{indent});"
    )

    return text[:replace_start] + new + text[assignment_end:]

def patch_odd(text: str) -> str:
    text = add_import(text, "import '../services/high_score_service.dart';")

    if "_usingRuntimeV3" not in text:
        marker = "  bool _ready = false;"
        if marker not in text:
            raise RuntimeError("odd _ready marker bulunamadi")
        text = text.replace(
            marker,
            marker
            + "\n  bool _usingRuntimeV3 = false;"
            + "\n  Map<int, List<int>> _runtimeClubIdsByPlayer = const {};",
            1,
        )

    init_pattern = re.compile(
        r"  Future<void> initialize\(\) async \{.*?\n  \}\n\n  @override",
        re.S,
    )

    init_new = r"""  Future<void> initialize() async {
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      _pool = await hybrid.playersInPool('odd_club_normal');
      _runtimeClubIdsByPlayer =
          await hybrid.playerClubIdsForPool('odd_club_normal');
      _clubPool = await hybrid.topGameplayClubs(limit: 400);

      _pool = _pool
          .where((p) => (_runtimeClubIdsByPlayer[p.id] ?? const []).length >= 3)
          .toList();

      if (_pool.length < 60 || _clubPool.length < 20) {
        debugPrint(
          '[HybridV3] OddClub SQLite pool too small; legacy fallback.',
        );
        _usingRuntimeV3 = false;
        _runtimeClubIdsByPlayer = const {};
        _initializeLegacyPool();
      } else {
        debugPrint(
          '[HybridV3] OddClub SQLite '
          'players=${_pool.length} fakeClubs=${_clubPool.length}',
        );
      }
    } else {
      _initializeLegacyPool();
    }

    final best = await HighScoreService.getHighScore(key: _highScoreKey);
    _ready = true;
    _state = _state.copyWith(isLoading: false, bestStreak: best);
    _nextQuestion(resetLives: true);
  }

  void _initializeLegacyPool() {
    _clubPool = chainClubPool
        .map((id) => Repository.instance.clubById(id))
        .whereType<Club>()
        .toList();

    final poolClubIds = _clubPool.map((c) => c.id).toSet();

    _pool = Repository.instance.players.where((p) {
      final famous = p.clubs.where(poolClubIds.contains).length;
      if (famous < 2) return false;
      return p.peakMarketValue >= 40000000;
    }).toList();

    if (_pool.length < 60) {
      _pool = Repository.instance.players.where((p) {
        final famous = p.clubs.where(poolClubIds.contains).length;
        return famous >= 2 && p.peakMarketValue >= 25000000;
      }).toList();
    }

    _pool.sort((a, b) => b.peakMarketValue.compareTo(a.peakMarketValue));
    if (_pool.length > 250) {
      _pool = _pool.take(250).toList();
    }
  }

  @override"""

    if "void _initializeLegacyPool()" not in text:
        m = init_pattern.search(text)
        if not m:
            raise RuntimeError("odd initialize block bulunamadi")
        text = text[:m.start()] + init_new + text[m.end():]

    old_real = """    final realIds = player.clubs.toSet().intersection(poolClubIds).toList()
      ..shuffle(_random);"""
    new_real = """    final realIds = (_usingRuntimeV3
            ? List<int>.from(
                _runtimeClubIdsByPlayer[player.id] ?? const <int>[],
              )
            : player.clubs.toSet().intersection(poolClubIds).toList())
      ..shuffle(_random);"""
    if old_real in text:
        text = text.replace(old_real, new_real, 1)
    elif "_runtimeClubIdsByPlayer[player.id]" not in text:
        raise RuntimeError("odd realIds block bulunamadi")

    return text

def patch_guess(text: str) -> str:
    text = add_import(text, "import '../services/search_service.dart';")

    if "_usingRuntimeV3" not in text:
        marker = "  Timer? _feedbackTimer;"
        if marker not in text:
            raise RuntimeError("guess timer marker bulunamadi")
        text = text.replace(
            marker,
            marker + "\n  bool _usingRuntimeV3 = false;",
            1,
        )

    section_pattern = re.compile(
        r"  void initialize\(\) \{\n    _pickNewClub\(\);\n  \}.*?"
        r"  void newClub\(\) \{\n    _pickNewClub\(\);\n  \}",
        re.S,
    )
    section_new = r"""  void initialize() {
    _usingRuntimeV3 = HybridGameplayDataService.instance.isGameplayEnabled;
    _pickNewClub();
  }

  Future<void> _pickNewClub() async {
    List<Club> pool;

    if (_usingRuntimeV3) {
      pool = await HybridGameplayDataService.instance
          .clubsInPool('guess_the_player_clubs');
      if (pool.length < 20) {
        debugPrint(
          '[HybridV3] GuessThePlayer SQLite club pool too small; '
          'legacy fallback.',
        );
        _usingRuntimeV3 = false;
      } else {
        debugPrint(
          '[HybridV3] GuessThePlayer SQLite clubs=${pool.length}',
        );
      }
    } else {
      pool = const <Club>[];
    }

    if (!_usingRuntimeV3) {
      pool = chainClubPool
          .map((id) => Repository.instance.clubById(id))
          .whereType<Club>()
          .toList();
    }

    if (pool.isEmpty) return;

    final club = pool[_random.nextInt(pool.length)];
    _state = _state.copyWith(
      isLoading: false,
      club: club,
      foundPlayers: const [],
      usedPlayerIds: const {},
    );
    notifyListeners();
  }

  void newClub() {
    _pickNewClub();
  }"""
    if "Future<void> _pickNewClub() async" not in text:
        m = section_pattern.search(text)
        if not m:
            raise RuntimeError("guess initialize/pick block bulunamadi")
        text = text[:m.start()] + section_new + text[m.end():]

    submit_pattern = re.compile(
        r"  void submitGuess\(String answer\) \{.*?\n  \}\n\}",
        re.S,
    )
    submit_new = r"""  void submitGuess(String answer) {
    _submitGuessAsync(answer);
  }

  Future<void> _submitGuessAsync(String answer) async {
    final club = _state.club;
    if (club == null || answer.trim().isEmpty) return;

    final used = _state.usedPlayerIds;

    final candidates = _usingRuntimeV3
        ? (await HybridGameplayDataService.instance.playersForClub(
            club.id,
            playerPool: 'shared_xi_answer',
          ))
            .where((p) => !used.contains(p.id))
            .toList()
        : Repository.instance.players
            .where((p) => !used.contains(p.id))
            .where((p) => p.clubs.contains(club.id))
            .toList();

    final player = SearchService.findExactPlayer(
      players: candidates,
      answer: answer,
    );

    if (player == null) {
      _feedback(
        '${club.name} formasını giymiş böyle bir oyuncu bulunamadı.',
        false,
      );
      return;
    }

    final newFound = List.from(_state.foundPlayers)..add(player);
    final newUsed = Set<int>.from(_state.usedPlayerIds)..add(player.id);

    _state = _state.copyWith(
      foundPlayers: newFound.cast(),
      usedPlayerIds: newUsed,
    );
    _feedback('${player.name} doğru! (+1)', true);
  }
}"""
    if "Future<void> _submitGuessAsync" not in text:
        m = submit_pattern.search(text)
        if not m:
            raise RuntimeError("guess submit block bulunamadi")
        text = text[:m.start()] + submit_new + text[m.end():]

    return text

def main() -> None:
    for path in (GAME, ODD, GUESS):
        if not path.exists():
            raise SystemExit(f"[FAIL] Eksik controller: {path}")

    originals = {
        GAME: GAME.read_text(encoding="utf-8"),
        ODD: ODD.read_text(encoding="utf-8"),
        GUESS: GUESS.read_text(encoding="utf-8"),
    }

    # All patches are computed before any project file is written.
    patched = {
        GAME: patch_game(originals[GAME]),
        ODD: patch_odd(originals[ODD]),
        GUESS: patch_guess(originals[GUESS]),
    }

    for path in (GAME, ODD, GUESS):
        backup(path)
        path.write_text(patched[path], encoding="utf-8")
        print(f"[OK] patched {path.relative_to(ROOT)}")

    print()
    print("[DONE] Step 04.2A controller migration installed.")
    print("[SAFE] Online/ranked Shared XI is still JSON.")
    print("[SAFE] Chain is still JSON until 04.2B graph migration.")

if __name__ == "__main__":
    main()
