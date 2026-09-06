from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTROLLER = ROOT / "lib/controllers/blind_ranking_controller.dart"
STATE = ROOT / "lib/models/blind_ranking_state.dart"
HYBRID = ROOT / "lib/services/runtime_v3/hybrid_gameplay_data_service.dart"

IMPORT_LINE = "import '../services/runtime_v3/hybrid_gameplay_data_service.dart';"

def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step04_2i.bak")
    if not bak.exists():
        shutil.copy2(path, bak)

def patch_state(text: str) -> str:
    if "trueOrderPlayerIds" in text:
        return text

    required = [
        "final List<Player> players;",
        "final int currentIndex;",
        "final List<Player?> slots;",
        "this.players = const [],",
        "this.currentIndex = 0,",
        "this.slots = const [",
        "List<Player> get trueOrder {",
        "..sort((a, b) => careerScore(b).compareTo(careerScore(a)));",
        "List<Player>? players,",
        "int? currentIndex,",
        "List<Player?>? slots,",
        "players: players ?? this.players,",
        "currentIndex: currentIndex ?? this.currentIndex,",
        "slots: slots ?? this.slots,",
    ]
    for marker in required:
        if marker not in text:
            raise RuntimeError(f"BlindRankingState local shape bulunamadi: {marker}")

    text = text.replace(
        "  final List<Player> players; // sunuluş sırası (rastgele)\n"
        "  final int currentIndex;",
        "  final List<Player> players; // sunuluş sırası (rastgele)\n"
        "  /// Runtime V3 Linkball Rank sırası. Boşsa legacy careerScore kullanılır.\n"
        "  final List<int> trueOrderPlayerIds;\n"
        "  final int currentIndex;",
        1,
    )

    text = text.replace(
        "    this.players = const [],\n"
        "    this.currentIndex = 0,",
        "    this.players = const [],\n"
        "    this.trueOrderPlayerIds = const [],\n"
        "    this.currentIndex = 0,",
        1,
    )

    old_true_order = """  List<Player> get trueOrder {
    final sorted = List<Player>.from(players)
      ..sort((a, b) => careerScore(b).compareTo(careerScore(a)));
    return sorted;
  }"""
    new_true_order = r"""  List<Player> get trueOrder {
    if (trueOrderPlayerIds.isNotEmpty) {
      final byId = {for (final p in players) p.id: p};
      return trueOrderPlayerIds
          .map((id) => byId[id])
          .whereType<Player>()
          .toList();
    }

    final sorted = List<Player>.from(players)
      ..sort((a, b) => careerScore(b).compareTo(careerScore(a)));
    return sorted;
  }"""
    if old_true_order not in text:
        raise RuntimeError("BlindRankingState trueOrder block bulunamadi")
    text = text.replace(old_true_order, new_true_order, 1)

    text = text.replace(
        "    List<Player>? players,\n"
        "    int? currentIndex,",
        "    List<Player>? players,\n"
        "    List<int>? trueOrderPlayerIds,\n"
        "    int? currentIndex,",
        1,
    )

    text = text.replace(
        "      players: players ?? this.players,\n"
        "      currentIndex: currentIndex ?? this.currentIndex,",
        "      players: players ?? this.players,\n"
        "      trueOrderPlayerIds:\n"
        "          trueOrderPlayerIds ?? this.trueOrderPlayerIds,\n"
        "      currentIndex: currentIndex ?? this.currentIndex,",
        1,
    )

    final_markers = [
        "final List<int> trueOrderPlayerIds;",
        "this.trueOrderPlayerIds = const [],",
        "if (trueOrderPlayerIds.isNotEmpty)",
        "List<int>? trueOrderPlayerIds,",
        "trueOrderPlayerIds ?? this.trueOrderPlayerIds",
    ]
    for marker in final_markers:
        if marker not in text:
            raise RuntimeError(f"BlindRankingState final marker eksik: {marker}")

    return text

def patch_controller(text: str) -> str:
    if (
        "normal_v3" in text
        and "_initializeHybrid" in text
        and "trueOrderPlayerIds:" in text
    ):
        return text

    required = [
        "import 'dart:math';",
        "import '../repositories/repository.dart';",
        "void initialize() {",
        "p.marketValue >= 2000000",
        "..sort((a, b) => b.marketValue.compareTo(a.marketValue));",
        "final topPool = pool.take(250).toList()..shuffle(_random);",
        "players: presentationOrder,",
    ]
    for marker in required:
        if marker not in text:
            raise RuntimeError(f"BlindRankingController local shape bulunamadi: {marker}")

    if "import 'dart:async';" not in text:
        text = text.replace(
            "import 'dart:math';",
            "import 'dart:async';\nimport 'dart:math';",
            1,
        )

    if IMPORT_LINE not in text:
        anchor = "import '../repositories/repository.dart';"
        text = text.replace(anchor, anchor + "\n" + IMPORT_LINE, 1)

    init_start = text.find("  void initialize() {")
    next_method = text.find(
        "  bool isSlotFilled(",
        init_start,
    )
    if init_start < 0 or next_method < 0:
        raise RuntimeError("BlindRankingController initialize boundary bulunamadi")

    replacement = r"""  void initialize() {
    unawaited(_initializeHybrid());
  }

  Future<void> _initializeHybrid() async {
    final hybrid = HybridGameplayDataService.instance;

    if (hybrid.isGameplayEnabled) {
      final ordered = await hybrid.playersInPool('normal_v3');

      if (ordered.length >= 500) {
        // normal_v3 is already ordered by selectionRankV3.
        //
        // Pick one player from ten rank bands. This avoids getting ten almost
        // identical superstars while keeping all names recognizable.
        final envelopeSize = ordered.length.clamp(500, 1200);
        final envelope = ordered.take(envelopeSize).toList();
        final chosen = <Player>[];

        final bandSize =
            (envelope.length / BlindRankingState.slotCount).floor();

        for (var band = 0;
            band < BlindRankingState.slotCount;
            band++) {
          final start = band * bandSize;
          final end = band == BlindRankingState.slotCount - 1
              ? envelope.length
              : ((band + 1) * bandSize).clamp(0, envelope.length);

          if (start >= envelope.length || end <= start) continue;

          final slice = envelope.sublist(start, end);
          chosen.add(slice[_random.nextInt(slice.length)]);
        }

        if (chosen.length == BlindRankingState.slotCount) {
          // `chosen` is still rank-band ordered, therefore this is the
          // authoritative true order before presentation shuffle.
          final trueOrderIds = chosen.map((p) => p.id).toList();
          final presentationOrder = List<Player>.from(chosen)
            ..shuffle(_random);

          _state = BlindRankingState(
            isLoading: false,
            players: presentationOrder,
            trueOrderPlayerIds: trueOrderIds,
          );

          debugPrint(
            '[HybridV3] BlindRanking SQLite '
            'players=${chosen.length} source=normal_v3 '
            'envelope=$envelopeSize',
          );

          notifyListeners();
          return;
        }
      }

      debugPrint(
        '[HybridV3] BlindRanking SQLite pool too small; legacy fallback.',
      );
    }

    _initializeLegacy();
  }

  void _initializeLegacy() {
    final pool = Repository.instance.players
        .where((p) => p.marketValue >= 2000000)
        .toList()
      ..sort((a, b) => b.marketValue.compareTo(a.marketValue));

    final topPool = pool.take(250).toList()..shuffle(_random);
    final chosen = topPool.take(BlindRankingState.slotCount).toList();

    final presentationOrder = List<Player>.from(chosen)..shuffle(_random);

    _state = BlindRankingState(
      isLoading: false,
      players: presentationOrder,
    );
    notifyListeners();
  }

"""
    text = text[:init_start] + replacement + text[next_method:]

    final_markers = [
        "normal_v3",
        "_initializeHybrid",
        "trueOrderPlayerIds: trueOrderIds",
        "source=normal_v3",
        "_initializeLegacy",
    ]
    for marker in final_markers:
        if marker not in text:
            raise RuntimeError(f"BlindRankingController final marker eksik: {marker}")

    return text

def main() -> None:
    for path in (CONTROLLER, STATE, HYBRID):
        if not path.exists():
            raise SystemExit(f"[FAIL] Eksik gerekli dosya: {path}")

    controller_original = CONTROLLER.read_text(encoding="utf-8")
    state_original = STATE.read_text(encoding="utf-8")

    # Atomic preparation: both must patch before anything is written.
    state_patched = patch_state(state_original)
    controller_patched = patch_controller(controller_original)

    backup(STATE)
    backup(CONTROLLER)

    STATE.write_text(state_patched, encoding="utf-8")
    CONTROLLER.write_text(controller_patched, encoding="utf-8")

    print("[OK] patched lib/models/blind_ranking_state.dart")
    print("[OK] patched lib/controllers/blind_ranking_controller.dart")
    print("[DONE] Step 04.2I Blind Ranking migration installed.")
    print("[SAFE] Feature flag OFF keeps legacy market-value/careerScore behavior.")

if __name__ == "__main__":
    main()
