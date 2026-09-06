# Linkball Data Platform v3 — Canonical Contract (03B)

This document is the migration contract. Step 03B does **not** switch the Flutter app to new data.

## Core rules

- Current production player IDs remain stable during migration.
- Club IDs from player history are treated as **source references** until resolved.
- Never solve orphan IDs by permanently exposing thousands of `Club {id}` placeholders.
- A canonical club can have many source IDs and aliases.
- Gameplay pools only use `valid` entities.
- `partial` entities may preserve historical relationships but are not generated as questions by default.
- `unresolved` entities are relationship evidence only.
- Market-value fields are quarantined as legacy compatibility data and will be removed from game dependencies.
- Player portraits and club marks are a separate visual-asset system.

## Planned canonical tables

- `players`
- `clubs`
- `club_source_refs`
- `player_club_spells`
- `competitions`
- `player_stats`
- `national_stats`
- `transfers`
- `game_pool_flags`

## Migration order

03B contract -> 03C club identity resolver -> 03D player enrichment/popularity -> 03E runtime compilation.
