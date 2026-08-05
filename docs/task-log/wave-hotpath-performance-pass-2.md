---
title: "Task: Wave hotpath performance pass 2"
type: task-history
scope: fullstack
status: completed
created: 2026-07-28
sources: [manual-gameplay-audit]
tags: [godot, performance, ai, projectiles, ladders]
---

# Wave hotpath performance pass 2

**Task:** manual-gameplay-audit · **Type:** fix

## Description

The game still stuttered when a wave approached the wall. Prior probes showed that disabling allied fire improved frame stability, but the remaining live battle still had spikes from projectile churn, ladder deployment visuals, and per-unit crowd scans near the wall.

## Implementation summary

### Files modified

1. **scripts/core/projectile_pool.gd** — added a resettable player-arrow pool so player and allied arrows are reused instead of repeatedly instantiated/freed during salvos.
2. **scripts/player/arrow.gd** — made arrows pool-aware, reset launch state, clear old hit listeners, and recycle instead of freeing when pooled.
3. **scripts/ally/archer_shooting.gd** — routes allied archer shots through the shared projectile pool.
4. **scripts/player/fps_bow_player.gd** — routes player bow shots through the same projectile pool.
5. **scripts/enemy/siege_ladder.gd** — reuses shared ladder beam mesh and material for deployed ladders; individual beams now scale a unit `BoxMesh` instead of allocating a new mesh resource.
6. **scripts/enemy/ladder_orc_enemy.gd** — reuses shared carried-ladder mesh/material resources for ladder-carrier visuals.
7. **scripts/enemy/enemy.gd** — caps separation sampling per enemy so crowd avoidance has a fixed per-unit budget instead of scanning the whole battlefield in dense wall contact.
8. **scripts/core/combat_registry.gd** — adds a lightweight XZ spatial index used by local crowd separation queries.

### Key details

- Pool recycling is deferred when removing arrows from the scene tree, avoiding Godot physics-callback removal errors.
- Pooled arrows only re-enter the active scene after they have no parent, preventing reuse during deferred removal.
- Arrow collision exceptions now clear only the previous shooter exception; `get_collision_exceptions()` can return unusable entries for `remove_collision_exception_with()` in this flow.
- Ladder visuals keep the same procedural look, but no longer create one `BoxMesh`/material per beam at deployment time.
- Separation still exists, but samples local registry cells and then caps the scan to 24 candidates per refresh. CharacterBody3D collision remains the hard physical blocker.
- A trial wiring of archer targeting into the spatial index was reverted because the current small-wave probe got slower; wide-radius targeting should get a purpose-built broadphase later, not reuse the small-radius separation grid blindly.

## Testing notes

- `godot --headless --path . -s /tmp/mountainhold_hotpath_probe.gd` loads the changed scripts successfully.
- `godot --headless --path . -s /tmp/mountainhold_approach_perf_compare.gd` after the final fixes: `approach_perf fire=true samples=2075 avg=101.0 min=2 low=427 enemies=28 ladders=1 climbing=0`.
- No `SCRIPT ERROR`, `Parse Error`, physics-callback removal, or arrow collision-exception errors were present in the final probe logs.
- Known headless exit leak warnings still appear in this project and were not treated as new gameplay regressions.

## Remaining work

- The probe is better than the broken run, but still has low-frame spikes. The next high-value pass should move defender/enemy targeting and minimap queries toward cached spatial buckets instead of repeated full-list scoring.
- Full `make test` was intentionally not run here because the current workflow is to run it at the end of the larger performance batch.
