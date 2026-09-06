# Step 03C — Trusted Career + Club Source Resolver

03B.1 proved that overlapping player integers can refer to different people. The current dataset builder also merged transfer-derived club relationships by raw numeric player ID, so relationship fields must be rebuilt through a verified player source map.

03C therefore does **not** edit `players_min.json` or `clubs_min.json`.

It reads:

- `reports/data_platform_v3/03b1/player_source_map.csv`
- `assets/data/players_min.json`
- `assets/data/clubs_min.json`
- a private Transfermarkt-derived source ZIP placed under `tools/data_platform_v3/input/`

It produces a trusted, namespace-qualified relationship layer and conservative club mapping proposals.

Only `AUTO_MAP_HIGH` mappings are eligible for automatic use later. Review candidates, unresolved clubs, pseudo-clubs, and current collision-player clubIds remain quarantined.
