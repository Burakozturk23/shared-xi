from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CTRL = ROOT / "lib/controllers/harf11_controller.dart"
HYBRID = ROOT / "lib/services/runtime_v3/hybrid_gameplay_data_service.dart"

IMPORT_LINE = "import '../services/runtime_v3/hybrid_gameplay_data_service.dart';"

FINAL_MARKERS = [
    "_runtimePlayers",
    "_runtimeFactsByPlayer",
    "playersInPool('build_xi_preview')",
    "playerFactsForPool('build_xi_preview')",
    "_runtimePlayableLetters",
    "_fitsPosition",
    "[HybridV3] Harf11 SQLite",
]

def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step04_2p.bak")
    if not bak.exists():
        shutil.copy2(path, bak)

def main() -> None:
    if not CTRL.exists():
        raise SystemExit(f"[FAIL] Eksik: {CTRL}")
    if not HYBRID.exists():
        raise SystemExit("[FAIL] Hybrid runtime service yok.")

    original = CTRL.read_text(encoding="utf-8")
    text = original

    if all(m in text for m in FINAL_MARKERS):
        print("[PASS] Harf11 already fully migrated.")
        return

    if any(m in text for m in FINAL_MARKERS):
        raise RuntimeError(
            "PARTIAL_04_2P: Harf11 kismi migration durumunda. "
            "Otomatik ustune yazilmadi."
        )

    required = [
        "import '../services/search_service.dart';",
        "String? _preChosen;",
        "void spinLetter() {",
        "void setFormation(String id) {",
        "void updateSuggestions(String query) {",
        "void placePlayer(Player player) {",
        "void placePlayerByName(String input) {",
        "var pool = Repository.instance.players;",
    ]
    for marker in required:
        if marker not in text:
            raise RuntimeError(f"Harf11 local shape bulunamadi: {marker}")

    if IMPORT_LINE not in text:
        anchor = "import '../services/search_service.dart';"
        text = text.replace(anchor, anchor + "\n" + IMPORT_LINE, 1)

    text = text.replace(
        "  String? _preChosen;",
        """  String? _preChosen;

  bool _usingRuntimeV3 = false;
  bool _runtimeReady = false;
  List<Player> _runtimePlayers = const [];
  Map<int, Map<String, Object?>> _runtimeFactsByPlayer = const {};
""",
        1,
    )

    spin_start = text.find("  void spinLetter() {")
    formation_start = text.find("  void setFormation(String id) {", spin_start)
    if spin_start < 0 or formation_start < 0:
        raise RuntimeError("Harf11 spinLetter boundary bulunamadi")

    new_spin = r"""  void spinLetter() {
    if (!_runtimeReady) {
      unawaited(_initializeRuntimeAndSpin());
      return;
    }
    _spinLetterNow();
  }

  Future<void> _initializeRuntimeAndSpin() async {
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      _runtimePlayers =
          await hybrid.playersInPool('build_xi_preview');
      _runtimeFactsByPlayer =
          await hybrid.playerFactsForPool('build_xi_preview');

      if (_runtimePlayers.length < 5000 ||
          _runtimeFactsByPlayer.length < 5000) {
        debugPrint(
          '[HybridV3] Harf11 SQLite pool too small; legacy fallback.',
        );
        _usingRuntimeV3 = false;
      } else {
        debugPrint(
          '[HybridV3] Harf11 SQLite '
          'players=${_runtimePlayers.length} '
          'facts=${_runtimeFactsByPlayer.length}',
        );
      }
    }

    _runtimeReady = true;
    _spinLetterNow();
  }

  String _positionGroup(Player player) {
    if (_usingRuntimeV3) {
      final facts = _runtimeFactsByPlayer[player.id];
      final factual =
          facts?['position_group']?.toString().trim().toUpperCase() ?? '';

      if (factual == 'GOALKEEPER' || factual == 'GK') return 'GK';
      if (factual == 'DEFENDER' || factual == 'DEF') return 'DEF';

      if (factual == 'MIDFIELD' ||
          factual == 'MIDFIELDER' ||
          factual == 'MID') {
        return 'MID';
      }

      if (factual == 'ATTACK' ||
          factual == 'ATTACKER' ||
          factual == 'FORWARD' ||
          factual == 'FWD') {
        return 'FWD';
      }
    }

    return Harf11Letter.positionGroup(player);
  }

  bool _fitsPosition(Player player, String slotLabel) {
    return _positionGroup(player) == slotLabel.toUpperCase();
  }

  List<String> _runtimePlayableLetters() {
    if (!_usingRuntimeV3) {
      return Harf11Letter.playableLetters();
    }

    final counts = <String, Map<String, int>>{};

    for (final player in _runtimePlayers) {
      final group = _positionGroup(player);
      final seen = <String>{};

      for (final part in player.name.trim().split(RegExp(r'\s+'))) {
        if (part.isEmpty) continue;

        final letter = Harf11Letter.normalizeLetter(part);
        if (!Harf11Letter.letters.contains(letter)) continue;
        if (!seen.add(letter)) continue;

        final byPosition =
            counts.putIfAbsent(letter, () => <String, int>{});
        byPosition[group] = (byPosition[group] ?? 0) + 1;
      }
    }

    final viable = <String>[];

    for (final letter in Harf11Letter.letters) {
      final c = counts[letter] ?? const <String, int>{};

      // Maximum requirement among all current formations:
      // GK=1, DEF=4, MID=5, FWD=3.
      if ((c['GK'] ?? 0) >= 1 &&
          (c['DEF'] ?? 0) >= 4 &&
          (c['MID'] ?? 0) >= 5 &&
          (c['FWD'] ?? 0) >= 3) {
        viable.add(letter);
      }
    }

    return viable.isNotEmpty
        ? viable
        : Harf11Letter.playableLetters();
  }

  void _spinLetterNow() {
    _spinTimer?.cancel();

    final letters = _runtimePlayableLetters();
    _preChosen = letters[_rng.nextInt(letters.length)];

    var ticks = 0;
    const total = 20;

    _state = _state.copyWith(
      phase: Harf11Phase.spinning,
      spinDisplay: _preChosen,
    );
    notifyListeners();

    _spinTimer = Timer.periodic(
      const Duration(milliseconds: 70),
      (t) {
        ticks++;

        if (ticks >= total) {
          t.cancel();
          final chosen = _preChosen!;

          _state = Harf11State(
            phase: Harf11Phase.playing,
            letter: chosen,
            spinDisplay: chosen,
            formationId: _state.formationId,
          );
          notifyListeners();
          return;
        }

        if (ticks >= total - 3) {
          _state = _state.copyWith(spinDisplay: _preChosen);
        } else {
          _state = _state.copyWith(
            spinDisplay: Harf11Letter.letters[
                _rng.nextInt(Harf11Letter.letters.length)],
          );
        }

        notifyListeners();
      },
    );
  }

"""
    text = text[:spin_start] + new_spin + text[formation_start:]

    # Patch suggestion source only inside updateSuggestions.
    sugg_start = text.find("  void updateSuggestions(String query) {")
    place_start = text.find("  void placePlayer(Player player) {", sugg_start)
    if sugg_start < 0 or place_start < 0:
        raise RuntimeError("Harf11 suggestion method boundary bulunamadi")

    sugg = text[sugg_start:place_start]
    old = "      players: Repository.instance.players,"
    if old not in sugg:
        raise RuntimeError("Harf11 suggestion Repository source bulunamadi")
    sugg = sugg.replace(
        old,
        """      players: _usingRuntimeV3
          ? _runtimePlayers
          : Repository.instance.players,""",
        1,
    )
    sugg = sugg.replace(
        "!Harf11Letter.fitsPosition(p, slotLabel)",
        "!_fitsPosition(p, slotLabel)",
    )
    text = text[:sugg_start] + sugg + text[place_start:]

    # Patch direct placement position authority.
    place_start = text.find("  void placePlayer(Player player) {")
    byname_start = text.find("  void placePlayerByName(String input) {", place_start)
    if place_start < 0 or byname_start < 0:
        raise RuntimeError("Harf11 placePlayer boundary bulunamadi")

    place = text[place_start:byname_start]
    place = place.replace(
        "!Harf11Letter.fitsPosition(player, slotLabel)",
        "!_fitsPosition(player, slotLabel)",
    )
    place = place.replace(
        "final got = _posTr(Harf11Letter.positionGroup(player));",
        "final got = _posTr(_positionGroup(player));",
    )
    text = text[:place_start] + place + text[byname_start:]

    # Patch free-text resolver source and position check.
    byname_start = text.find("  void placePlayerByName(String input) {")
    finish_start = text.find("  void finish() {", byname_start)
    if byname_start < 0 or finish_start < 0:
        raise RuntimeError("Harf11 placePlayerByName boundary bulunamadi")

    byname = text[byname_start:finish_start]
    if "    var pool = Repository.instance.players;" not in byname:
        raise RuntimeError("Harf11 name pool marker bulunamadi")

    byname = byname.replace(
        "    var pool = Repository.instance.players;",
        """    var pool = _usingRuntimeV3
        ? List<Player>.from(_runtimePlayers)
        : Repository.instance.players;""",
        1,
    )
    byname = byname.replace(
        "Harf11Letter.fitsPosition(p, slotLabel)",
        "_fitsPosition(p, slotLabel)",
    )
    text = text[:byname_start] + byname + text[finish_start:]

    for marker in FINAL_MARKERS:
        if marker not in text:
            raise RuntimeError(f"Harf11 final marker eksik: {marker}")

    backup(CTRL)
    CTRL.write_text(text, encoding="utf-8")

    print("[OK] patched lib/controllers/harf11_controller.dart")
    print("[DONE] Step 04.2P Harf11 migration installed.")
    print("[SAFE] Feature flag OFF keeps legacy behavior.")

if __name__ == "__main__":
    main()
