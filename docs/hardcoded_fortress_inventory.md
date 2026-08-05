# Hardcoded Fortress Inventory

Date: 2026-08-05
Backlog task: P0-006
Scope: current gameplay scripts that influence enemy spawning, ladder assault, defender targeting/positioning, fortress generation, and shared combat queries.

## Replacement Principle

AI should not know the fortress layout as raw world coordinates. The preferred replacement path is:

1. `FortressGenerator` creates semantic markers/regions while building the castle.
2. `CastleModel` owns stable queries for gate, keep, wall sectors, ladder lanes, staging horizon, defender slots, and navigation links.
3. `WaveSpawner`, `SiegeDirector`, enemies, and defenders request semantic data from `CastleModel` instead of duplicating map constants.
4. Tuning values such as ranges, cooldowns, capacities, and score weights move to named constants/resources before becoming designer-facing profiles.

## Coordinate Inventory

| ID | Owner | Current hardcode | Meaning | Risk | Replacement |
| --- | --- | --- | --- | --- | --- |
| HF-001 | `scripts/castle/fortress_generator.gd` | `CX=330`, `CZ=500`, `WALL_R=44`, `KEEP_X=360`, `APEX=PI` | Global fortress center, radius, keep axis, gate direction | Every other system copies this coordinate frame; alternate fortress layouts break AI | Export a `FortressLayoutDefinition` or publish generated center/radius/gate/keep anchors through `CastleModel` |
| HF-002 | `scripts/enemy/wave_spawner.gd` | `ROUTE` points `276/285/301/322/341/351/357, z=500` | Enemy gate-to-keep route | Enemies keep using old path after fortress geometry changes | Build route from `CastleModel.gate_entry`, `gate_exit`, `causeway_points`, `inner_gate`, `keep_attack_point` |
| HF-003 | `scripts/enemy/wave_spawner.gd`, `scripts/enemy/siege_director.gd` | `spawn_centre=Vector3(248,0,500)`, `spawn_spread=Vector3(6,0,30)` | Field spawn anchor and spread | Spawn distribution is tied to one map and may create stuck units on terrain | Generate spawn/staging bands from wall sectors and terrain-validated approach regions |
| HF-004 | `scripts/enemy/wave_spawner.gd` | fallback ladder `foot=Vector3(288, ground, z)`, `top=Vector3(294,22,z)` | Emergency ladder lane when no slot/director exists | Fallback can put ladders on invalid geometry | Remove after `CastleModel.wall_ladder_slots()` is required, or resolve fallback from nearest valid wall sector |
| HF-005 | `scripts/enemy/ladder_orc_enemy.gd` | default `_ladder_foot=Vector3(288,0,492)`, `_ladder_top=Vector3(294,22,492)` | Pre-setup placeholder ladder route | Debug/default instances imply a specific wall lane | Replace with `Vector3.INF` plus validation, or initialize only via `setup_ladder_carry()` |
| HF-006 | `scripts/ally/defender_targeting.gd` | `GATE_KILL_POINT=Vector3(285,0,500)`, `GATE_KILL_RADIUS=20`, `enemy.x>=300` | Gate threat filtering and wall-breached heuristic | Defender orders mis-prioritize if gate/bailey shifts | Use `CastleModel.gate_threat_region` and enemy semantic state/sector |
| HF-007 | `scripts/ally/defender_positioning.gd` | gate bonus uses `(285,500)`, radius `22`, bonus `24` | Slot scoring around gate | Defenders overfit to current gate location | Query `CastleModel.gate_defense_slots` with distance-to-region scoring |
| HF-008 | `scripts/ally/defender_orders.gd` | `GATE_RALLY_X=284.2`, `KEEP_RALLY_X=345`, `KEEP_RALLY_Y=32`, `CENTRE_Z=500`, manual rows `496/500/504` | Fallback rally positions for defend gate/retreat keep | Defenders can route to empty air after layout changes | Replace fallbacks with named tactical slots and keep/gate rally regions from `CastleModel` |
| HF-009 | `scripts/ally/ally_placer.gd` | `centre=Vector3(330,0,500)`, `wall_r=44`, `keep_x=360`, `avoid=Vector3(294,0,480)` | Legacy archer placement fallback | Can place archers in wrong area if generated slots fail | Prefer `CastleModel.archer_slots`; fallback should use generated fortress anchors, not literals |
| HF-010 | `scripts/castle/fortress_generator.gd` | `Vector3(290,0,CZ)` for tower facing gate | Tower/gate facing heuristic | Changes to apex/gate geometry need multiple edits | Derive gate focus point from built gate module transform |
| HF-011 | `scripts/castle/fortress_generator.gd` | causeway/inner gate points: `KEEP_X-34`, `KEEP_X-16`, `z=511`, `top_x=361` | Keep approach and sally/inner path layout | Navigation graph and AI route assumptions can diverge | Register causeway and inner-gate anchors in `CastleModel` during build |
| HF-012 | `scripts/enemy/wave_spawner.gd`, `scripts/enemy/siege_director.gd` | ladder slot validity `foot.x>312`, `abs(z-center)<10`, `abs(z-center)>46`, `foot.y>field+6` | Filters wall slots for ladder placement | Hard-coded to current west-facing crescent | Replace with slot metadata: `surface`, `sector`, `approach_clearance`, `field_accessible`, `height_delta` |

## Range And Tuning Inventory

| ID | Owner | Current hardcode | Meaning | Risk | Replacement |
| --- | --- | --- | --- | --- | --- |
| HT-001 | `scripts/enemy/enemy.gd` | `WALL_TARGET_RANGE=90`, `WALL_TARGET_REFRESH=0.42`, `WALL_PRESSURE_REFRESH=0.7`, `LADDER_SEARCH_REFRESH=0.55` | Enemy on-wall targeting/query cadence | Hundreds of units can still spike if all refresh together | Move to `EnemyProfile`/AI tuning resource and stagger through a scheduler |
| HT-002 | `scripts/enemy/enemy.gd`, `scripts/enemy/wall_assault_brain.gd` | height deltas `3.2`, `18`, safe drop `2.6`, settle timeout `2.6` | Direct vs routed wall movement and landing safety | Falling/stuck fixes are hidden in multiple constants | Centralize in `FortressNavigationTuning` and test edge cases |
| HT-003 | `scripts/enemy/ladder_assault_brain.gd` | search range `120`, climber penalty `180`, entry penalty `260`, queue penalty `22` | Active ladder choice scoring | Queue behavior is hard to reason about from screenshots | Move scoring into named ladder queue policy with diagnostics |
| HT-004 | `scripts/enemy/siege_ladder.gd` | `ENTRY_RESERVATION_TIMEOUT=6`, `CLIMB_LANE_SPACING=0.55`, queue/landing slot patterns | Ladder reservations and crowd spacing | Idle-at-ladder bugs can hide in queue math | Move into ladder state machine policy; expose queue slot occupancy |
| HT-005 | `scripts/enemy/ladder_orc_enemy.gd` | deployment radius `5.2`, durations `3.2/5.4`, speeds `2.55/1.45`, helper search `7.5` | Ladder crew logistics | Carrier behavior tuning is spread across class internals | Move to ladder crew profile/resource |
| HT-006 | `scripts/enemy/wave_spawner.gd` | staged horizon `22`, width `96`, row gap `3.2`, spawn interval `1.05`, wave counts `[14,20,30,42]` | Wave presentation and pacing | Hard to author mass attacks without code edits | Replace with `WaveDefinition` resources after sectors exist |
| HT-007 | `scripts/core/combat_registry.gd` | `GRID_CELL_SIZE=14`, alive y bounds `-20/120` | Spatial query grid and active filtering | Wrong cell size or y bounds affect targeting and perf | Move into registry config; tie active bounds to world/terrain extents |
| HT-008 | `scripts/ally/defender_targeting.gd`, `scripts/ally/defender_positioning.gd` | candidate cap `16`, gate scores `0.4/0.55/20/0.5`, slot score weights | Defender target/slot prioritization | Hard to tune allied archers for large waves | Central threat evaluator and defender profile weights |
| HT-009 | `scripts/core/traversal_controller.gd` | ladder validation min distance `1`, max landing flat distance `1.25`, progress `speed/distance` | Ladder traversal validation | Climb completion can fail if ladder geometry changes | Move to ladder traversal tuning and validate against generated top/landing slots |
| HT-010 | `scripts/ally/archer_shooting.gd` | ballistic gravity `9.8`, sample count via code, spread logic | Arrow aim/LOS approximation | High archer counts may spend too much on ballistic checks | Move cadence/caps into archer firing profile and registry-aware targeting budget |

## Migration Order

1. Add `CastleModel` query methods for current anchors without changing callers: gate point, gate threat region, keep rally, route points, staging band, wall sectors.
2. Replace read-only consumers first: HUD/dev panel/debug output and docs validation.
3. Migrate `WaveSpawner.ROUTE` and spawn/staging anchors to `CastleModel` with fallback to current constants.
4. Migrate defender gate/keep fallback positions to tactical slot queries.
5. Migrate ladder slot validity rules into generated metadata and remove duplicate filters from `WaveSpawner` / `SiegeDirector`.
6. Convert tuning groups into resources only after behavior is covered by tests.

## Validation Strategy

- Grep-based audit stays useful until all HF/HT IDs are either removed or mapped to named data.
- Add tests for `CastleModel` anchors before migrating consumers.
- Keep targeted tests cheap: enemy, wave spawner, defender targeting/positioning, fortress navigation.
- Do not rely on full `make test` as the primary gate until `siege_smoke_test.gd` hang/crash is isolated.
