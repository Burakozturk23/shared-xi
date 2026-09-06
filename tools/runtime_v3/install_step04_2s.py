from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "lib/services/match_pair_generator.dart"
CTRL = ROOT / "lib/controllers/match_pair_controller.dart"
HYBRID = ROOT / "lib/services/runtime_v3/hybrid_gameplay_data_service.dart"

RUNTIME_IMPORT = "import 'runtime_v3/hybrid_gameplay_data_service.dart';"
FOUNDATION_IMPORT = "import 'package:flutter/foundation.dart';"
PLAYER_IMPORT = "import '../models/player.dart';"

GEN_FINAL_MARKERS = [
    "generateRuntime({",
    "playersInPool('normal_v3')",
    "playerClubIdsForPool('normal_v3')",
    "topGameplayClubs(limit: 160)",
    "[HybridV3] MatchPair SQLite",
]

CTRL_FINAL_MARKERS = [
    "MatchPairGenerator.generateRuntime(",
    "[HybridV3] MatchPair controller runtime board active",
]


def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step04_2s.bak")
    if not bak.exists():
        shutil.copy2(path, bak)


def insert_before_last_class_brace(text: str, block: str) -> str:
    idx = text.rfind("\n}")
    if idx < 0:
        raise RuntimeError("class end bulunamadi")
    return text[:idx] + block + text[idx:]


def patch_generator(text: str) -> str:
    if all(m in text for m in GEN_FINAL_MARKERS):
        return text
    if any(m in text for m in GEN_FINAL_MARKERS):
        raise RuntimeError(
            "PARTIAL_04_2S_GENERATOR: MatchPair generator kismi migration."
        )

    required = [
        "import 'dart:math';",
        "import '../models/match_pair_models.dart';",
        "import '../repositories/repository.dart';",
        "class MatchPairGenerator {",
        "static MatchBoard generate({",
        "static MatchBoard _fallback(",
    ]
    for marker in required:
        if marker not in text:
            raise RuntimeError(f"MatchPair generator local shape bulunamadi: {marker}")

    if FOUNDATION_IMPORT not in text:
        text = text.replace(
            "import 'dart:math';",
            "import 'dart:math';\n\n" + FOUNDATION_IMPORT,
            1,
        )

    if PLAYER_IMPORT not in text:
        anchor = "import '../models/match_pair_models.dart';"
        text = text.replace(anchor, anchor + "\n" + PLAYER_IMPORT, 1)

    if RUNTIME_IMPORT not in text:
        anchor = "import '../repositories/repository.dart';"
        text = text.replace(anchor, anchor + "\n" + RUNTIME_IMPORT, 1)

    runtime_block = r'''

  static Future<MatchBoard?> generateRuntime({
    MatchDifficulty difficulty = MatchDifficulty.medium,
    int? pairCount,
  }) async {
    final hybrid = HybridGameplayDataService.instance;
    if (!hybrid.isGameplayEnabled) return null;

    try {
      final n = pairCount ?? difficulty.pairCount;

      final orderedPlayers = await hybrid.playersInPool('normal_v3');
      final clubIdsByPlayer =
          await hybrid.playerClubIdsForPool('normal_v3');
      final gameplayClubs =
          await hybrid.topGameplayClubs(limit: 160);

      if (orderedPlayers.length < 1000 ||
          clubIdsByPlayer.length < 1000 ||
          gameplayClubs.length < 30) {
        debugPrint(
          '[HybridV3] MatchPair SQLite source too small; '
          'legacy fallback.',
        );
        return null;
      }

      // normal_v3 is ordered by selectionRankV3.
      // Difficulty is now a Linkball rank window, not market value.
      late final List<Player> players;

      switch (difficulty) {
        case MatchDifficulty.easy:
          players = orderedPlayers
              .take(min(1100, orderedPlayers.length))
              .toList();
          break;

        case MatchDifficulty.medium:
          final skip = min(350, max(0, orderedPlayers.length - 200));
          players = orderedPlayers
              .skip(skip)
              .take(min(2200, orderedPlayers.length - skip))
              .toList();
          break;

        case MatchDifficulty.hard:
          final skip = min(1000, max(0, orderedPlayers.length - 200));
          players = orderedPlayers
              .skip(skip)
              .take(min(4200, orderedPlayers.length - skip))
              .toList();
          break;
      }

      if (players.length < n * 2) {
        debugPrint(
          '[HybridV3] MatchPair SQLite difficulty pool too small; '
          'legacy fallback.',
        );
        return null;
      }

      final clubById = {
        for (final club in gameplayClubs) club.id: club,
      };
      final allowedClubIds = clubById.keys.toSet();

      // Canonical club -> selectionRankV3 ordered players.
      final byClub = <int, List<Player>>{};

      for (final player in players) {
        final clubIds =
            clubIdsByPlayer[player.id] ?? const <int>[];

        for (final clubId in clubIds) {
          if (!allowedClubIds.contains(clubId)) continue;

          final club = clubById[clubId];
          if (club == null || !_isSaneClubName(club.name)) continue;

          byClub.putIfAbsent(
            clubId,
            () => <Player>[],
          ).add(player);
        }
      }

      var clubCandidates = gameplayClubs
          .where((club) {
            final count = byClub[club.id]?.length ?? 0;
            return count >= 1 && _isSaneClubName(club.name);
          })
          .toList();

      if (clubCandidates.length < n) {
        debugPrint(
          '[HybridV3] MatchPair SQLite club candidate count '
          'too small=${clubCandidates.length}; legacy fallback.',
        );
        return null;
      }

      // topGameplayClubs is already popularity ordered.
      final int clubEnvelope;

      switch (difficulty) {
        case MatchDifficulty.easy:
          clubEnvelope = min(70, clubCandidates.length);
          break;
        case MatchDifficulty.medium:
          clubEnvelope = min(110, clubCandidates.length);
          break;
        case MatchDifficulty.hard:
          clubEnvelope = min(160, clubCandidates.length);
          break;
      }

      clubCandidates =
          clubCandidates.take(clubEnvelope).toList()
            ..shuffle(_rng);

      final pairs = <MatchCard>[];
      final usedPlayers = <int>{};
      final usedClubs = <int>{};
      var pairId = 0;

      for (final club in clubCandidates) {
        if (pairId >= n) break;
        if (!usedClubs.add(club.id)) continue;

        final candidates = (byClub[club.id] ?? const <Player>[])
            .where((player) => !usedPlayers.contains(player.id))
            .toList();

        if (candidates.isEmpty) continue;

        // Lists inherit selectionRankV3 order. Easy favors the first few;
        // hard can pull from the full club-specific candidate set.
        final int playerEnvelope;

        switch (difficulty) {
          case MatchDifficulty.easy:
            playerEnvelope = min(4, candidates.length);
            break;
          case MatchDifficulty.medium:
            playerEnvelope = min(10, candidates.length);
            break;
          case MatchDifficulty.hard:
            playerEnvelope = candidates.length;
            break;
        }

        final player = candidates[_rng.nextInt(max(1, playerEnvelope))];
        usedPlayers.add(player.id);

        pairs.add(
          MatchCard(
            id: 'c_${pairId}_${club.id}',
            pairId: pairId,
            kind: MatchCardKind.club,
            label: club.name,
            clubId: club.id,
          ),
        );

        pairs.add(
          MatchCard(
            id: 'p_${pairId}_${player.id}',
            pairId: pairId,
            kind: MatchCardKind.player,
            label: player.name,
            playerId: player.id,
            clubId: club.id,
          ),
        );

        pairId++;
      }

      if (pairId < n) {
        debugPrint(
          '[HybridV3] MatchPair SQLite generated only '
          '$pairId/$n pairs; legacy fallback.',
        );
        return null;
      }

      final cards = List<MatchCard>.from(pairs)..shuffle(_rng);

      debugPrint(
        '[HybridV3] MatchPair SQLite '
        'difficulty=${difficulty.name} '
        'pairs=$pairId players=${players.length} '
        'clubs=$clubEnvelope',
      );

      return MatchBoard(
        cards: cards,
        pairCount: pairId,
        difficulty: difficulty,
      );
    } catch (e) {
      debugPrint('[HybridV3] MatchPair SQLite fallback: $e');
      return null;
    }
  }
'''

    return insert_before_last_class_brace(text, runtime_block)


def patch_controller(text: str) -> str:
    if all(m in text for m in CTRL_FINAL_MARKERS):
        return text
    if any(m in text for m in CTRL_FINAL_MARKERS):
        raise RuntimeError(
            "PARTIAL_04_2S_CONTROLLER: MatchPair controller kismi migration."
        )

    required = [
        "Future<void> startNew(MatchDifficulty difficulty) async {",
        "final board = MatchPairGenerator.generate(difficulty: difficulty);",
        "_state = MatchPairState(board: board, isLoading: false);",
    ]
    for marker in required:
        if marker not in text:
            raise RuntimeError(f"MatchPair controller local shape bulunamadi: {marker}")

    old = """      final board = MatchPairGenerator.generate(difficulty: difficulty);
      _state = MatchPairState(board: board, isLoading: false);"""

    new = """      var board = await MatchPairGenerator.generateRuntime(
        difficulty: difficulty,
      );

      if (board != null) {
        debugPrint(
          '[HybridV3] MatchPair controller runtime board active '
          'pairs=${board.pairCount} difficulty=${difficulty.name}',
        );
      } else {
        board = MatchPairGenerator.generate(difficulty: difficulty);
      }

      _state = MatchPairState(board: board, isLoading: false);"""

    if old not in text:
        raise RuntimeError("MatchPair controller board block bulunamadi")

    return text.replace(old, new, 1)


def main() -> None:
    for p in (GEN, CTRL, HYBRID):
        if not p.exists():
            raise SystemExit(f"[FAIL] Eksik gerekli dosya: {p}")

    hybrid_text = HYBRID.read_text(encoding="utf-8")
    for marker in [
        "playersInPool",
        "playerClubIdsForPool",
        "topGameplayClubs",
    ]:
        if marker not in hybrid_text:
            raise SystemExit(f"[FAIL] Hybrid Runtime method eksik: {marker}")

    originals = {
        GEN: GEN.read_text(encoding="utf-8"),
        CTRL: CTRL.read_text(encoding="utf-8"),
    }

    # Atomic preparation: no file is written unless both patches are valid.
    patched = {
        GEN: patch_generator(originals[GEN]),
        CTRL: patch_controller(originals[CTRL]),
    }

    for p in (GEN, CTRL):
        backup(p)

    for p in (GEN, CTRL):
        p.write_text(patched[p], encoding="utf-8")
        print(f"[OK] patched {p.relative_to(ROOT)}")

    print("[DONE] Step 04.2S Match Pair Runtime V3 installed.")
    print("[SAFE] Runtime board kurulamazsa legacy generator fallback kalir.")


if __name__ == "__main__":
    main()
