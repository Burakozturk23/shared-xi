from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "lib/services/pyramid_generator.dart"
CTRL = ROOT / "lib/controllers/pyramid_controller.dart"
HYBRID = ROOT / "lib/services/runtime_v3/hybrid_gameplay_data_service.dart"

RUNTIME_IMPORT = "import 'runtime_v3/hybrid_gameplay_data_service.dart';"

GEN_FINAL_MARKERS = [
    "generateRuntime({",
    "playersInPool('normal_v3')",
    "playerClubIdsForPool('normal_v3')",
    "existingGameplayClubMetadata()",
    "_fromRuntimePlayer",
    "[HybridV3] Pyramid SQLite",
]

CTRL_FINAL_MARKERS = [
    "_startNewAsync",
    "PyramidGenerator.generateRuntime(",
    "[HybridV3] Pyramid controller runtime board active",
]

def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step04_2t.bak")
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
            "PARTIAL_04_2T_GENERATOR: Pyramid generator kismi migration."
        )

    required = [
        "import 'dart:math';",
        "import '../models/club.dart';",
        "import '../models/player.dart';",
        "import '../models/pyramid_models.dart';",
        "import '../repositories/repository.dart';",
        "class PyramidGenerator {",
        "static PyramidBoard generate({",
        "static PyramidEntity _fromPlayer(Player p)",
        "static PyramidEntity _fromClub(Club c)",
        "static PyramidBoard _fallback(",
    ]

    for marker in required:
        if marker not in text:
            raise RuntimeError(f"Pyramid generator local shape bulunamadi: {marker}")

    if RUNTIME_IMPORT not in text:
        anchor = "import '../repositories/repository.dart';"
        text = text.replace(anchor, anchor + "\n" + RUNTIME_IMPORT, 1)

    runtime_block = r'''

  static PyramidEntity _fromRuntimePlayer(
    Player player,
    Map<int, List<int>> clubIdsByPlayer,
  ) {
    return PyramidEntity(
      id: 'player_${player.id}',
      type: PyramidNodeType.player,
      name: player.name,
      clubIds: List<int>.from(
        clubIdsByPlayer[player.id] ?? const <int>[],
      ),
      countries: List<String>.from(player.countries),
    );
  }

  static PyramidEntity _fromRuntimeClub({
    required int clubId,
    required String name,
  }) {
    return PyramidEntity(
      id: 'club_$clubId',
      type: PyramidNodeType.club,
      name: name,
      clubIds: [clubId],
    );
  }

  static Future<PyramidBoard?> generateRuntime({
    PyramidDifficulty difficulty = PyramidDifficulty.normal,
  }) async {
    final hybrid = HybridGameplayDataService.instance;
    if (!hybrid.isGameplayEnabled) return null;

    try {
      final orderedPlayers =
          await hybrid.playersInPool('normal_v3');
      final clubIdsByPlayer =
          await hybrid.playerClubIdsForPool('normal_v3');
      final clubRows =
          await hybrid.existingGameplayClubMetadata();

      if (orderedPlayers.length < 1000 ||
          clubIdsByPlayer.length < 1000 ||
          clubRows.length < 100) {
        debugPrint(
          '[HybridV3] Pyramid SQLite source too small; '
          'legacy fallback.',
        );
        return null;
      }

      final clubNameById = <int, String>{};

      for (final row in clubRows) {
        final rawId = row['exposed_club_id'] as num?;
        if (rawId == null) continue;

        final id = rawId.toInt();
        final name = row['name']?.toString().trim() ?? '';

        if (name.isEmpty) continue;
        if (name.toLowerCase().startsWith('club ')) continue;

        clubNameById[id] = name;
      }

      if (clubNameById.length < 100) {
        debugPrint(
          '[HybridV3] Pyramid SQLite mapped clubs too small; '
          'legacy fallback.',
        );
        return null;
      }

      final existingClubIds = clubNameById.keys.toSet();

      final playersByClub = <int, List<Player>>{};

      for (final player in orderedPlayers) {
        final clubIds =
            clubIdsByPlayer[player.id] ?? const <int>[];

        for (final clubId in clubIds) {
          if (!existingClubIds.contains(clubId)) continue;

          playersByClub
              .putIfAbsent(clubId, () => <Player>[])
              .add(player);
        }
      }

      final anchorClubIds = playersByClub.entries
          .where((e) => e.value.length >= 16)
          .map((e) => e.key)
          .toList();

      if (anchorClubIds.length < 10) {
        debugPrint(
          '[HybridV3] Pyramid SQLite anchor clubs too shallow; '
          'legacy fallback.',
        );
        return null;
      }

      final List<Player> rankWindow;

      switch (difficulty) {
        case PyramidDifficulty.easy:
          rankWindow =
              orderedPlayers.take(min(900, orderedPlayers.length)).toList();
          break;

        case PyramidDifficulty.normal:
          final skip = min(
            150,
            max(0, orderedPlayers.length - 300),
          );
          rankWindow = orderedPlayers
              .skip(skip)
              .take(min(1800, orderedPlayers.length - skip))
              .toList();
          break;

        case PyramidDifficulty.hard:
          final skip = min(
            700,
            max(0, orderedPlayers.length - 400),
          );
          rankWindow = orderedPlayers
              .skip(skip)
              .take(min(3200, orderedPlayers.length - skip))
              .toList();
          break;
      }

      final anchorSet = anchorClubIds.toSet();

      final peakCandidates = rankWindow.where((player) {
        final clubs =
            clubIdsByPlayer[player.id] ?? const <int>[];

        return clubs.any(anchorSet.contains) &&
            player.name.trim().isNotEmpty;
      }).toList();

      if (peakCandidates.length < 40) {
        debugPrint(
          '[HybridV3] Pyramid SQLite peak pool too small; '
          'legacy fallback.',
        );
        return null;
      }

      final peakEnvelope = peakCandidates
          .take(min(280, peakCandidates.length))
          .toList()
        ..shuffle(_rng);

      Player? peakPlayer;
      int? anchorClubId;
      List<Player> anchorPlayers = const [];

      for (final candidate in peakEnvelope) {
        final candidateClubs =
            clubIdsByPlayer[candidate.id] ?? const <int>[];

        final deepClubs = candidateClubs
            .where(anchorSet.contains)
            .toList();

        if (deepClubs.isEmpty) continue;

        deepClubs.shuffle(_rng);

        for (final clubId in deepClubs) {
          final all =
              playersByClub[clubId] ?? const <Player>[];

          final others = all
              .where(
                (p) =>
                    p.id != candidate.id &&
                    p.name.trim().isNotEmpty,
              )
              .toList();

          if (others.length < 14) continue;

          peakPlayer = candidate;
          anchorClubId = clubId;
          anchorPlayers = others;
          break;
        }

        if (peakPlayer != null) break;
      }

      if (peakPlayer == null ||
          anchorClubId == null ||
          anchorPlayers.length < 14) {
        debugPrint(
          '[HybridV3] Pyramid SQLite could not resolve '
          'finishable anchor; legacy fallback.',
        );
        return null;
      }

      final peak = _fromRuntimePlayer(
        peakPlayer,
        clubIdsByPlayer,
      );

      final int teammateEnvelope;

      switch (difficulty) {
        case PyramidDifficulty.easy:
          teammateEnvelope = min(18, anchorPlayers.length);
          break;
        case PyramidDifficulty.normal:
          teammateEnvelope = min(30, anchorPlayers.length);
          break;
        case PyramidDifficulty.hard:
          teammateEnvelope = anchorPlayers.length;
          break;
      }

      final teammatePool =
          anchorPlayers.take(teammateEnvelope).toList()
            ..shuffle(_rng);

      if (teammatePool.length < 13) {
        debugPrint(
          '[HybridV3] Pyramid SQLite teammate pool too small; '
          'legacy fallback.',
        );
        return null;
      }

      final anchorClub = _fromRuntimeClub(
        clubId: anchorClubId,
        name: clubNameById[anchorClubId]!,
      );

      final basePlayers = teammatePool.take(4).toList();

      if (basePlayers.length < 4) return null;

      final base = <PyramidEntity>[
        for (final p in basePlayers)
          _fromRuntimePlayer(p, clubIdsByPlayer),
        anchorClub,
      ];

      final initialUsedPlayerIds = <int>{
        peakPlayer.id,
        ...basePlayers.map((p) => p.id),
      };

      final answerPool = <PyramidEntity>[];
      final seen = <String>{};

      void add(PyramidEntity entity) {
        if (seen.add(entity.id)) answerPool.add(entity);
      }

      add(peak);
      for (final entity in base) {
        add(entity);
      }

      for (final player in teammatePool) {
        if (initialUsedPlayerIds.contains(player.id)) continue;
        add(_fromRuntimePlayer(player, clubIdsByPlayer));
      }

      for (final player in anchorPlayers) {
        if (initialUsedPlayerIds.contains(player.id)) continue;
        add(_fromRuntimePlayer(player, clubIdsByPlayer));
        if (answerPool.length >= 45) break;
      }

      add(anchorClub);

      for (final clubId
          in (clubIdsByPlayer[peakPlayer.id] ?? const <int>[])) {
        final name = clubNameById[clubId];
        if (name == null || name.isEmpty) continue;

        add(
          _fromRuntimeClub(
            clubId: clubId,
            name: name,
          ),
        );
      }

      if (difficulty != PyramidDifficulty.hard) {
        for (final country in peakPlayer.countries) {
          if (country.trim().isEmpty) continue;

          add(
            PyramidEntity(
              id:
                  'country_${PyramidEntity.normalize(country)}',
              type: PyramidNodeType.country,
              name: country,
              countries: [country],
            ),
          );
        }
      }

      final remainingPlayerEntities = answerPool
          .where((e) => e.type == PyramidNodeType.player)
          .where((e) => !base.any((b) => b.id == e.id))
          .where((e) => e.id != peak.id)
          .length;

      if (remainingPlayerEntities < 9) {
        debugPrint(
          '[HybridV3] Pyramid SQLite answer pool not finishable '
          'remainingPlayers=$remainingPlayerEntities; legacy fallback.',
        );
        return null;
      }

      final filled = <int, PyramidEntity>{0: peak};
      const baseStart = 10;

      for (var i = 0; i < 5; i++) {
        filled[baseStart + i] = base[i];
      }

      debugPrint(
        '[HybridV3] Pyramid SQLite '
        'difficulty=${difficulty.name} '
        'peak=${peakPlayer.name} '
        'anchor=${clubNameById[anchorClubId]} '
        'answers=${answerPool.length}',
      );

      return PyramidBoard(
        id:
            'v3_${peakPlayer.id}_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Pyramid',
        difficulty: difficulty,
        slots: _slots,
        initialFilled: filled,
        answerPool: answerPool,
      );
    } catch (e) {
      debugPrint('[HybridV3] Pyramid SQLite fallback: $e');
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
            "PARTIAL_04_2T_CONTROLLER: Pyramid controller kismi migration."
        )

    required = [
        "import 'package:flutter/foundation.dart';",
        "void startNew() {",
        "final board = PyramidGenerator.generate(difficulty: _difficulty);",
    ]

    for marker in required:
        if marker not in text:
            raise RuntimeError(f"Pyramid controller local shape bulunamadi: {marker}")

    if "import 'dart:async';" not in text:
        text = text.replace(
            "import 'package:flutter/foundation.dart';",
            "import 'dart:async';\n\nimport 'package:flutter/foundation.dart';",
            1,
        )

    start_begin = text.find("  void startNew() {")
    select_begin = text.find("  void selectSlot(int slotId) {", start_begin)

    if start_begin < 0 or select_begin < 0:
        raise RuntimeError("Pyramid startNew boundary bulunamadi")

    new_start = r'''  void startNew() {
    unawaited(_startNewAsync());
  }

  Future<void> _startNewAsync() async {
    try {
      _state = const PyramidState(isLoading: true);
      notifyListeners();

      var board = await PyramidGenerator.generateRuntime(
        difficulty: _difficulty,
      );

      if (board != null) {
        debugPrint(
          '[HybridV3] Pyramid controller runtime board active '
          'difficulty=${_difficulty.name} '
          'answers=${board.answerPool.length}',
        );
      } else {
        board = PyramidGenerator.generate(
          difficulty: _difficulty,
        );
      }

      _state = PyramidState(
        board: board,
        filled: Map<int, PyramidEntity>.from(
          board.initialFilled,
        ),
        lives: board.lives,
        score: 0,
        isLoading: false,
      );

      notifyListeners();
    } catch (e, st) {
      debugPrint('Pyramid start error: $e\n$st');

      _state = PyramidState(
        isLoading: false,
        error: 'Tahta üretilemedi: $e',
      );

      notifyListeners();
    }
  }

'''

    return text[:start_begin] + new_start + text[select_begin:]

def main() -> None:
    for p in (GEN, CTRL, HYBRID):
        if not p.exists():
            raise SystemExit(f"[FAIL] Eksik gerekli dosya: {p}")

    hybrid_text = HYBRID.read_text(encoding="utf-8")

    for marker in [
        "playersInPool",
        "playerClubIdsForPool",
        "existingGameplayClubMetadata",
    ]:
        if marker not in hybrid_text:
            raise SystemExit(
                f"[FAIL] Hybrid Runtime method eksik: {marker}"
            )

    originals = {
        GEN: GEN.read_text(encoding="utf-8"),
        CTRL: CTRL.read_text(encoding="utf-8"),
    }

    patched = {
        GEN: patch_generator(originals[GEN]),
        CTRL: patch_controller(originals[CTRL]),
    }

    for p in (GEN, CTRL):
        backup(p)

    for p in (GEN, CTRL):
        p.write_text(patched[p], encoding="utf-8")
        print(f"[OK] patched {p.relative_to(ROOT)}")

    print("[DONE] Step 04.2T Pyramid Runtime V3 installed.")
    print("[SAFE] Legacy generator remains fallback.")

if __name__ == "__main__":
    main()
