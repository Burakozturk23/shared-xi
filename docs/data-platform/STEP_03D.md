# Step 03D — Canonical Club + Career Preview

This step is intentionally **read-only**.

It consumes the current runtime `players_min.json` / `clubs_min.json` plus the completed 03C reports and produces the first namespace-safe club/career candidate layer under:

`reports/data_platform_v3/03d/`

Key rules:

- Integer IDs from different data sources are never identity proof.
- Existing Linkball clubs keep an `existing:<id>` candidate key.
- A Transfermarkt-derived club that cannot be safely mapped is preserved as `tm:<sourceId>` rather than discarded or forced into a wrong club.
- Pseudo clubs such as Retired / Without Club / Career break / Unknown do not enter gameplay.
- Youth/reserve/development teams are preserved for history but excluded from senior Shared XI by default.
- Current `clubIds` are only used as fallback for player identities that were not quarantined by 03B.1/03C.
- Orphan old IDs are preserved as `legacy_current:<id>` but remain outside gameplay until resolved.
- The 4,000-club gameplay pool is only a preview flag; it is not destructive pruning.
