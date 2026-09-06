from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

CONTROLLER = ROOT / "lib/controllers/higher_lower_controller.dart"
STATE = ROOT / "lib/models/higher_lower_state.dart"
PAGE = ROOT / "lib/screens/higher_lower_page.dart"
MODE = ROOT / "lib/screens/higher_lower_mode_selection_page.dart"
HYBRID = ROOT / "lib/services/runtime_v3/hybrid_gameplay_data_service.dart"
FLAGS = ROOT / "lib/services/runtime_v3/runtime_v3_flags.dart"

FILES = [CONTROLLER, STATE, PAGE, MODE]
HYBRID_IMPORT = "import '../services/runtime_v3/hybrid_gameplay_data_service.dart';"
FLAGS_IMPORT = "import '../services/runtime_v3/runtime_v3_flags.dart';"

def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step04_2j.bak")
    if not bak.exists():
        shutil.copy2(path, bak)

def patch_state(text: str) -> str:
    if "runtimeValues" in text and "runtimeV3" in text:
        return text

    required = [
        "final HigherLowerCriterion criterion;",
        "final Player? currentPlayer;",
        "final int streak;",
        "this.criterion = HigherLowerCriterion.marketValue,",
        "double valueOf(Player p) {",
        "String get criterionLabel =>",
        "HigherLowerState copyWith({",
        "criterion: criterion ?? this.criterion,",
    ]
    for marker in required:
        if marker not in text:
            raise RuntimeError(f"HigherLowerState local shape bulunamadi: {marker}")

    text = text.replace(
        "  final HigherLowerCriterion criterion;\n",
        "  final HigherLowerCriterion criterion;\n\n"
        "  /// True when values come from Runtime V3 factual player_stats.\n"
        "  final bool runtimeV3;\n"
        "  final Map<int, double> runtimeValues;\n",
        1,
    )

    text = text.replace(
        "    this.criterion = HigherLowerCriterion.marketValue,\n",
        "    this.criterion = HigherLowerCriterion.marketValue,\n"
        "    this.runtimeV3 = false,\n"
        "    this.runtimeValues = const {},\n",
        1,
    )

    old_value = """  double valueOf(Player p) {
    return criterion == HigherLowerCriterion.marketValue
        ? p.peakMarketValue
        : p.careerGoals.toDouble();
  }"""
    new_value = r"""  double valueOf(Player p) {
    if (runtimeV3) {
      return runtimeValues[p.id] ?? 0;
    }

    return criterion == HigherLowerCriterion.marketValue
        ? p.peakMarketValue
        : p.careerGoals.toDouble();
  }"""
    if old_value not in text:
        raise RuntimeError("HigherLowerState valueOf block bulunamadi")
    text = text.replace(old_value, new_value, 1)

    old_label = """  String get criterionLabel => criterion == HigherLowerCriterion.marketValue
      ? 'Zirve Piyasa Değeri'
      : 'Kariyer Golü';"""
    new_label = r"""  String get criterionLabel {
    if (runtimeV3) {
      return criterion == HigherLowerCriterion.marketValue
          ? 'Kapsanan Resmi Maç'
          : 'Kapsanan Gol';
    }

    return criterion == HigherLowerCriterion.marketValue
        ? 'Zirve Piyasa Değeri'
        : 'Kariyer Golü';
  }"""
    if old_label not in text:
        raise RuntimeError("HigherLowerState criterionLabel block bulunamadi")
    text = text.replace(old_label, new_label, 1)

    text = text.replace(
        "    HigherLowerCriterion? criterion,\n",
        "    HigherLowerCriterion? criterion,\n"
        "    bool? runtimeV3,\n"
        "    Map<int, double>? runtimeValues,\n",
        1,
    )

    text = text.replace(
        "      criterion: criterion ?? this.criterion,\n",
        "      criterion: criterion ?? this.criterion,\n"
        "      runtimeV3: runtimeV3 ?? this.runtimeV3,\n"
        "      runtimeValues: runtimeValues ?? this.runtimeValues,\n",
        1,
    )

    for marker in [
        "final bool runtimeV3;",
        "final Map<int, double> runtimeValues;",
        "if (runtimeV3)",
        "'Kapsanan Resmi Maç'",
        "'Kapsanan Gol'",
        "runtimeValues: runtimeValues ?? this.runtimeValues",
    ]:
        if marker not in text:
            raise RuntimeError(f"HigherLowerState final marker eksik: {marker}")

    return text

def patch_controller(text: str) -> str:
    if (
        "_runtimeValues" in text
        and "playerFactsForPool('normal_v3')" in text
        and "higher_lower_apps_v3_best" in text
    ):
        return text

    required = [
        "import '../services/high_score_service.dart';",
        "late List<Player> _pool;",
        "bool _poolReady = false;",
        "String get _highScoreKey =>",
        "static const double _minPeakValue = 20000000;",
        "static const int _minCareerGoals = 80;",
        "Future<void> initialize() async {",
        "final bestStreak = await HighScoreService.getHighScore(key: _highScoreKey);",
        "criterion: criterion,",
    ]
    for marker in required:
        if marker not in text:
            raise RuntimeError(f"HigherLowerController local shape bulunamadi: {marker}")

    if HYBRID_IMPORT not in text:
        anchor = "import '../services/high_score_service.dart';"
        text = text.replace(anchor, anchor + "\n" + HYBRID_IMPORT, 1)

    text = text.replace(
        "  bool _poolReady = false;\n",
        "  bool _poolReady = false;\n"
        "  bool _usingRuntimeV3 = false;\n"
        "  Map<int, double> _runtimeValues = const {};\n",
        1,
    )

    old_key = """  String get _highScoreKey => criterion == HigherLowerCriterion.marketValue
      ? 'higher_lower_value_best'
      : 'higher_lower_goals_best';"""
    new_key = r"""  String get _highScoreKey {
    if (_usingRuntimeV3) {
      return criterion == HigherLowerCriterion.marketValue
          ? 'higher_lower_apps_v3_best'
          : 'higher_lower_goals_v3_best';
    }

    return criterion == HigherLowerCriterion.marketValue
        ? 'higher_lower_value_best'
        : 'higher_lower_goals_best';
  }"""
    if old_key not in text:
        raise RuntimeError("HigherLowerController highScore key block bulunamadi")
    text = text.replace(old_key, new_key, 1)

    init_start = text.find("  Future<void> initialize() async {")
    new_game_start = text.find(
        "  void _startNewGame({required int bestStreak}) {",
        init_start,
    )
    if init_start < 0 or new_game_start < 0:
        raise RuntimeError("HigherLower initialize boundary bulunamadi")

    new_init = r"""  Future<void> initialize() async {
    if (!_poolReady) {
      final hybrid = HybridGameplayDataService.instance;
      _usingRuntimeV3 = hybrid.isGameplayEnabled;

      if (_usingRuntimeV3) {
        final players = await hybrid.playersInPool('normal_v3');
        final facts = await hybrid.playerFactsForPool('normal_v3');

        final values = <int, double>{};
        final eligible = <Player>[];

        for (final player in players) {
          final row = facts[player.id];
          if (row == null) continue;

          final raw = criterion == HigherLowerCriterion.marketValue
              ? (row['appearances'] as num?)?.toDouble()
              : (row['goals'] as num?)?.toDouble();

          if (raw == null || raw <= 0) continue;

          values[player.id] = raw;
          eligible.add(player);
        }

        // `players` is already selectionRankV3 ordered. Keep a broad,
        // recognizable envelope without market-value thresholds.
        final limit = criterion == HigherLowerCriterion.marketValue
            ? 3500
            : 3200;

        _pool = eligible.take(limit).toList();
        _runtimeValues = {
          for (final p in _pool) p.id: values[p.id]!,
        };

        if (_pool.length < 500) {
          debugPrint(
            '[HybridV3] HigherLower factual pool too small; '
            'legacy fallback.',
          );
          _usingRuntimeV3 = false;
          _runtimeValues = const {};
          _initializeLegacyPool();
        } else {
          final metric = criterion == HigherLowerCriterion.marketValue
              ? 'appearances'
              : 'goals';

          debugPrint(
            '[HybridV3] HigherLower SQLite '
            'metric=$metric players=${_pool.length}',
          );
        }
      } else {
        _initializeLegacyPool();
      }

      _poolReady = true;
    }

    final bestStreak =
        await HighScoreService.getHighScore(key: _highScoreKey);
    _startNewGame(bestStreak: bestStreak);
  }

  void _initializeLegacyPool() {
    _pool = Repository.instance.players.where((p) {
      if (criterion == HigherLowerCriterion.marketValue) {
        return p.peakMarketValue >= _minPeakValue;
      }
      return p.careerGoals >= _minCareerGoals;
    }).toList();

    if (_pool.length < 80) {
      _pool = Repository.instance.players.where((p) {
        if (criterion == HigherLowerCriterion.marketValue) {
          return p.peakMarketValue >= 10000000;
        }
        return p.careerGoals >= 50;
      }).toList();
    }

    if (_pool.isEmpty) {
      _pool = Repository.instance.players.where((p) {
        final v = criterion == HigherLowerCriterion.marketValue
            ? p.peakMarketValue
            : p.careerGoals.toDouble();
        return v > 0;
      }).toList();
    }
  }

"""
    text = text[:init_start] + new_init + text[new_game_start:]

    # State must carry the authoritative factual value map.
    state_marker = "      criterion: criterion,\n"
    if state_marker not in text:
        raise RuntimeError("HigherLower state constructor marker bulunamadi")
    text = text.replace(
        state_marker,
        state_marker
        + "      runtimeV3: _usingRuntimeV3,\n"
        + "      runtimeValues: _runtimeValues,\n",
        1,
    )

    for marker in [
        "playerFactsForPool('normal_v3')",
        "_runtimeValues",
        "higher_lower_apps_v3_best",
        "higher_lower_goals_v3_best",
        "_initializeLegacyPool",
        "metric=$metric",
        "runtimeV3: _usingRuntimeV3",
        "runtimeValues: _runtimeValues",
    ]:
        if marker not in text:
            raise RuntimeError(f"HigherLowerController final marker eksik: {marker}")

    return text

def patch_page(text: str) -> str:
    if "state.runtimeV3" in text and "maç" in text:
        return text

    old = """  String _formatValue(HigherLowerState state, Player p) {

final v = state.valueOf(p);

if (state.criterion == HigherLowerCriterion.marketValue) {

if (v >= 1000000) return '€${(v / 1000000).toStringAsFixed(1)}M';

return '€${(v / 1000).toStringAsFixed(0)}K';

}

return '${v.toInt()} gol';

}"""

    # GitHub HTML showed blank-line formatting; local file may be normally formatted.
    normal = """  String _formatValue(HigherLowerState state, Player p) {
    final v = state.valueOf(p);

    if (state.criterion == HigherLowerCriterion.marketValue) {
      if (v >= 1000000) return '€${(v / 1000000).toStringAsFixed(1)}M';
      return '€${(v / 1000).toStringAsFixed(0)}K';
    }

    return '${v.toInt()} gol';
  }"""

    replacement = r"""  String _formatValue(HigherLowerState state, Player p) {
    final v = state.valueOf(p);

    if (state.runtimeV3) {
      return state.criterion == HigherLowerCriterion.marketValue
          ? '${v.toInt()} maç'
          : '${v.toInt()} gol';
    }

    if (state.criterion == HigherLowerCriterion.marketValue) {
      if (v >= 1000000) {
        return '€${(v / 1000000).toStringAsFixed(1)}M';
      }
      return '€${(v / 1000).toStringAsFixed(0)}K';
    }

    return '${v.toInt()} gol';
  }"""

    if normal in text:
        return text.replace(normal, replacement, 1)

    # Tolerant boundary replacement.
    start = text.find("  String _formatValue(HigherLowerState state, Player p) {")
    build = text.find("  @override", start)
    if start < 0 or build < 0:
        raise RuntimeError("HigherLowerPage _formatValue boundary bulunamadi")
    return text[:start] + replacement + "\n\n" + text[build:]

def patch_mode(text: str) -> str:
    if "RuntimeV3Flags.gameplayEnabled" in text:
        return text

    required = [
        "import '../models/higher_lower_state.dart';",
        "title: const Text('Zirve Piyasa Değeri',",
        "subtitle: const Text('Kariyerinde gördüğü en yüksek bonservis'),",
        "title: const Text('Kariyer Golü',",
        "subtitle: const Text('Toplam kariyer gol sayısı'),",
    ]
    for marker in required:
        if marker not in text:
            raise RuntimeError(f"HigherLowerMode local shape bulunamadi: {marker}")

    anchor = "import '../models/higher_lower_state.dart';"
    text = text.replace(anchor, anchor + "\n" + FLAGS_IMPORT, 1)

    text = text.replace(
        "title: const Text('Zirve Piyasa Değeri',",
        "title: Text(\n"
        "RuntimeV3Flags.gameplayEnabled\n"
        "? 'Kapsanan Resmi Maç'\n"
        ": 'Zirve Piyasa Değeri',",
        1,
    )

    text = text.replace(
        "subtitle: const Text('Kariyerinde gördüğü en yüksek bonservis'),",
        "subtitle: Text(\n"
        "RuntimeV3Flags.gameplayEnabled\n"
        "? 'Veri kapsamındaki resmi maç sayısı'\n"
        ": 'Kariyerinde gördüğü en yüksek bonservis',\n"
        "),",
        1,
    )

    text = text.replace(
        "title: const Text('Kariyer Golü',",
        "title: Text(\n"
        "RuntimeV3Flags.gameplayEnabled\n"
        "? 'Kapsanan Gol'\n"
        ": 'Kariyer Golü',",
        1,
    )

    text = text.replace(
        "subtitle: const Text('Toplam kariyer gol sayısı'),",
        "subtitle: Text(\n"
        "RuntimeV3Flags.gameplayEnabled\n"
        "? 'Veri kapsamındaki gol sayısı'\n"
        ": 'Toplam kariyer gol sayısı',\n"
        "),",
        1,
    )

    for marker in [
        "RuntimeV3Flags.gameplayEnabled",
        "'Kapsanan Resmi Maç'",
        "'Veri kapsamındaki resmi maç sayısı'",
        "'Kapsanan Gol'",
        "'Veri kapsamındaki gol sayısı'",
    ]:
        if marker not in text:
            raise RuntimeError(f"HigherLowerMode final marker eksik: {marker}")

    return text

def main() -> None:
    for path in FILES + [HYBRID, FLAGS]:
        if not path.exists():
            raise SystemExit(f"[FAIL] Eksik gerekli dosya: {path}")

    hybrid_text = HYBRID.read_text(encoding="utf-8")
    if "playerFactsForPool" not in hybrid_text:
        raise SystemExit(
            "[FAIL] playerFactsForPool yok. Step 04.2D/04.2G factual "
            "runtime katmani kurulmus olmali."
        )

    originals = {p: p.read_text(encoding="utf-8") for p in FILES}

    # Atomic preparation.
    patched = {
        STATE: patch_state(originals[STATE]),
        CONTROLLER: patch_controller(originals[CONTROLLER]),
        PAGE: patch_page(originals[PAGE]),
        MODE: patch_mode(originals[MODE]),
    }

    for p in FILES:
        backup(p)
    for p in FILES:
        p.write_text(patched[p], encoding="utf-8")
        print(f"[OK] patched {p.relative_to(ROOT)}")

    print()
    print("[DONE] Step 04.2J Higher/Lower factual migration installed.")
    print("[SAFE] Flag OFF keeps legacy market-value/career-goal behavior.")

if __name__ == "__main__":
    main()
