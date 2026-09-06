# Step 03B.1 — Player Identity Guard

This is a corrective safety gate between 03B and 03C.

## Core rule

Numeric IDs are source-local. `players_min.id = 1` and `players_full.id = 1` are not assumed to represent the same footballer.

Canonical migration uses:

`(source namespace, source player id) -> canonical player id`

The same rule will apply to clubs in 03C.

## Runtime impact

None. This step only writes reports under `reports/data_platform_v3/03b1/`.

## Do not manually merge

Do not copy `careerTimeline`, `careerGoals`, `marketValue`, `peakMarketValue`, `nationalTeams`, `detailedPosition`, or aliases from full to min solely because their numeric IDs match. Only rows in `safe_same_id_enrichment.csv` are eligible for same-ID enrichment, and even those will be compiled later rather than edited manually.
