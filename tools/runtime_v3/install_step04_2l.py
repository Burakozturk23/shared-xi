from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CINKO = ROOT / "lib/controllers/cinko_controller.dart"
HYBRID = ROOT / "lib/services/runtime_v3/hybrid_gameplay_data_service.dart"

IMPORT_LINE = "import '../services/runtime_v3/hybrid_gameplay_data_service.dart';"

def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step04_2l.bak")
    if not bak.exists():
        shutil.copy2(path, bak)

def add_import(text: str, anchor: str) -> str:
    if IMPORT_LINE in text:
        return text
    if anchor not in text:
        raise RuntimeError(f"import anchor bulunamadi: {anchor}")
    return text.replace(anchor, anchor + "\n" + IMPORT_LINE, 1)

def main() -> None:
    if not CINKO.exists():
        raise SystemExit(f"[FAIL] Eksik: {CINKO}")
    if not HYBRID.exists():
        raise SystemExit("[FAIL] Hybrid runtime service yok.")

    original = CINKO.read_text(encoding="utf-8")
    text = original

    if (
        "Cinko SQLite" in text
        and "_runtimeClubIdsByPlayer" in text
        and "grid_answer" in text
    ):
        print("[PASS] cinko_controller.dart already migrated.")
        return

    required = [
        "import 'dart:async';",
        "import '../services/search_service.dart';",
        "Future<void> initialize() async {",
        "final cells = _buildGrid();",
        "List<CinkoCell> _buildGrid() {",
        "final clubs = PopularClubs.resolveAll();",
        "bool _playerMatchesCell(Player player, CinkoCell cell) {",
        "return cell.clubId != null && player.clubs.contains(cell.clubId);",
        "for (final clubId in player.clubs) {",
        "players: Repository.instance.players,",
    ]
    for marker in required:
        if marker not in text:
            raise RuntimeError(f"Cinko local shape bulunamadi: {marker}")

    text = add_import(text, "import '../services/search_service.dart';")

    field_marker = "  Timer? _feedbackTimer;"
    if field_marker not in text:
        raise RuntimeError("Cinko feedback timer field yok")

    text = text.replace(
        field_marker,
        field_marker + r"""

  bool _usingRuntimeV3 = false;
  List<Club> _runtimeClubPool = const [];
  Map<int, List<int>> _runtimeClubIdsByPlayer = const {};
  Set<int> _runtimeAnswerPlayerIds = const {};
  Map<int, String> _runtimeLeagueByClubId = const {};
""",
        1,
    )

    old_init = """  Future<void> initialize() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();
    final cells = _buildGrid();
    _state = _state.copyWith(
      cells: cells,
      isLoading: false,
      phase: CinkoPhase.enterPlayer,
    );
    notifyListeners();
  }"""

    new_init = r"""  Future<void> initialize() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      _runtimeClubPool = await hybrid.topGameplayClubs(limit: 160);

      final answerPlayers = await hybrid.playersInPool('grid_answer');
      _runtimeAnswerPlayerIds = answerPlayers.map((p) => p.id).toSet();

      _runtimeClubIdsByPlayer =
          await hybrid.playerClubIdsForPool('grid_answer');

      final clubRows = await hybrid.existingGameplayClubMetadata();
      _runtimeLeagueByClubId = {
        for (final row in clubRows)
          if ((row['exposed_club_id'] as num?) != null)
            (row['exposed_club_id'] as num).toInt():
                (row['competition']?.toString().trim() ?? ''),
      };

      if (_runtimeClubPool.length < 25 ||
          _runtimeAnswerPlayerIds.length < 5000 ||
          _runtimeClubIdsByPlayer.length < 5000) {
        debugPrint(
          '[HybridV3] Cinko SQLite pool too small; legacy fallback.',
        );
        _usingRuntimeV3 = false;
      } else {
        debugPrint(
          '[HybridV3] Cinko SQLite '
          'clubs=${_runtimeClubPool.length} '
          'answers=${_runtimeAnswerPlayerIds.length}',
        );
      }
    }

    final cells = _buildGrid();
    _state = _state.copyWith(
      cells: cells,
      isLoading: false,
      phase: CinkoPhase.enterPlayer,
    );
    notifyListeners();
  }"""

    if old_init not in text:
        raise RuntimeError("Cinko initialize exact block bulunamadi")
    text = text.replace(old_init, new_init, 1)

    # Runtime club pool + runtime league set.
    old_grid_head = """  List<CinkoCell> _buildGrid() {
    final n = gridSize * gridSize;
    // Sadece bilinen kulüp / lig / ülke — alt seviye elenir
    final clubs = PopularClubs.resolveAll();
    final countries = List<String>.from(cinkoFamousCountries);
    final leagues = List<String>.from(cinkoFamousLeagues);

    clubs.shuffle(_random);
    countries.shuffle(_random);
    leagues.shuffle(_random);"""

    new_grid_head = r"""  List<CinkoCell> _buildGrid() {
    final n = gridSize * gridSize;

    final clubs = _usingRuntimeV3
        ? List<Club>.from(_runtimeClubPool)
        : PopularClubs.resolveAll();

    final countries = List<String>.from(cinkoFamousCountries);

    final leagues = _usingRuntimeV3
        ? _runtimeLeagueByClubId.values
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
        : List<String>.from(cinkoFamousLeagues);

    clubs.shuffle(_random);
    countries.shuffle(_random);
    leagues.shuffle(_random);"""

    if old_grid_head not in text:
        raise RuntimeError("Cinko _buildGrid header bulunamadi")
    text = text.replace(old_grid_head, new_grid_head, 1)

    # Add helper before _playerMatchesCell.
    match_marker = "  bool _playerMatchesCell(Player player, CinkoCell cell) {"
    helper = r"""  List<int> _clubIdsForPlayer(Player player) {
    return _usingRuntimeV3
        ? (_runtimeClubIdsByPlayer[player.id] ?? const <int>[])
        : player.clubs;
  }

"""
    text = text.replace(match_marker, helper + match_marker, 1)

    # Club criterion.
    text = text.replace(
        "        return cell.clubId != null && player.clubs.contains(cell.clubId);",
        "        return cell.clubId != null &&\n"
        "            _clubIdsForPlayer(player).contains(cell.clubId);",
        1,
    )

    # League criterion.
    old_league = """      case CinkoCellType.league:
        for (final clubId in player.clubs) {
          final club = Repository.instance.clubById(clubId);
          if (club != null &&
              club.league.toLowerCase() == cell.label.toLowerCase()) {
            return true;
          }
        }
        return false;"""

    new_league = r"""      case CinkoCellType.league:
        for (final clubId in _clubIdsForPlayer(player)) {
          final league = _usingRuntimeV3
              ? (_runtimeLeagueByClubId[clubId] ?? '')
              : (Repository.instance.clubById(clubId)?.league ?? '');

          if (league.toLowerCase() == cell.label.toLowerCase()) {
            return true;
          }
        }
        return false;"""

    if old_league not in text:
        raise RuntimeError("Cinko league matching block bulunamadi")
    text = text.replace(old_league, new_league, 1)

    # Search suggestions: broad canonical answer player set.
    old_suggestions = """    suggestions = SearchService.suggestions(
      players: Repository.instance.players,
      query: query,
      excludedPlayerIds: _state.usedPlayerIds,
    );"""

    new_suggestions = r"""    final source = _usingRuntimeV3
        ? Repository.instance.players
            .where((p) => _runtimeAnswerPlayerIds.contains(p.id))
            .toList()
        : Repository.instance.players;

    suggestions = SearchService.suggestions(
      players: source,
      query: query,
      excludedPlayerIds: _state.usedPlayerIds,
    );"""

    if old_suggestions not in text:
        raise RuntimeError("Cinko suggestions block bulunamadi")
    text = text.replace(old_suggestions, new_suggestions, 1)

    # Free-text resolve should use same allowed answer set.
    old_resolve = """    final resolved = SearchService.resolve(
      players: Repository.instance.players,
      answer: name,
      excludedPlayerIds: _state.usedPlayerIds,
    );"""

    new_resolve = r"""    final source = _usingRuntimeV3
        ? Repository.instance.players
            .where((p) => _runtimeAnswerPlayerIds.contains(p.id))
            .toList()
        : Repository.instance.players;

    final resolved = SearchService.resolve(
      players: source,
      answer: name,
      excludedPlayerIds: _state.usedPlayerIds,
    );"""

    if old_resolve not in text:
        raise RuntimeError("Cinko resolve block bulunamadi")
    text = text.replace(old_resolve, new_resolve, 1)

    # Resolved player button must also respect broad answer pool.
    accept_marker = """  void _acceptPlayer(Player found) {
    if (_state.phase != CinkoPhase.enterPlayer) return;"""
    accept_new = r"""  void _acceptPlayer(Player found) {
    if (_state.phase != CinkoPhase.enterPlayer) return;

    if (_usingRuntimeV3 &&
        !_runtimeAnswerPlayerIds.contains(found.id)) {
      _feedback('Bu oyuncu Çinko cevap havuzunda değil.', false);
      return;
    }"""
    if accept_marker not in text:
        raise RuntimeError("Cinko acceptPlayer marker bulunamadi")
    text = text.replace(accept_marker, accept_new, 1)

    final_markers = [
        "_runtimeClubPool",
        "_runtimeClubIdsByPlayer",
        "_runtimeAnswerPlayerIds",
        "_runtimeLeagueByClubId",
        "playersInPool('grid_answer')",
        "playerClubIdsForPool('grid_answer')",
        "existingGameplayClubMetadata()",
        "_clubIdsForPlayer(player)",
        "[HybridV3] Cinko SQLite",
    ]
    for marker in final_markers:
        if marker not in text:
            raise RuntimeError(f"Cinko final marker eksik: {marker}")

    backup(CINKO)
    CINKO.write_text(text, encoding="utf-8")

    print("[OK] patched lib/controllers/cinko_controller.dart")
    print("[DONE] Step 04.2L Cinko migration installed.")
    print("[SAFE] Feature flag OFF keeps legacy behavior.")

if __name__ == "__main__":
    main()
