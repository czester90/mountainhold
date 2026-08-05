# Mountainhold Refactoring Backlog

Last updated: 2026-08-05
Scope: current working tree, not clean `main`. This backlog is for incremental refactoring only; it must preserve current gameplay unless a task explicitly changes behavior.

## Architecture Snapshot

- Project entry and autoloads: `project.godot` defines `GameSettings` and `Audio` autoloads, input actions, and boot flow through menu/play scenes.
- Main gameplay scene: `scenes/play.tscn` wires fortress generation, player, combat registry, wave spawner, defender orders, ally archers, HUD, pause/game-over UI, minimap, and developer tooling.
- Fortress domain: `scripts/castle/fortress_generator.gd` builds wall/gate/towers/keep modules and registers tactical slots, ladder slots, navigation points, and links in `CastleModel` / `CastlePathfinder`.
- Unit domain: shared resources and components include `UnitStats`, `HealthComponent`, `AttackComponent`, `TargetingComponent`, `UnitLocomotion`, and `TraversalController`.
- Enemy domain: `Enemy` is still a broad base class; specialized behavior is layered through `InfantryEnemy`, `ArcherEnemy`, `RamEnemy`, `BossRamEnemy`, `LadderOrcEnemy`, `SiegeLadder`, `WallAssaultBrain`, `LadderAssaultBrain`, `SiegeDirector`, and `WaveSpawner`.
- Defender domain: allied behavior is split across `AllyArcher`, `ArcherShooting`, `DefenderTargeting`, `DefenderPositioning`, `DefenderOrders`, and `AllyPlacer`.
- Global querying: `CombatRegistry` is the current shared registry for player/allies/enemies/projectiles and local candidate lookups, but some code still falls back to direct tree scans, hardcoded positions, or local ownership lists.
- Tests and docs: GdUnit tests cover enemies, waves, fortress navigation, full wave smoke, settings, and systems; docs already contain useful audits but several older docs may lag behind playable code.

## Baseline Results

Commands run on 2026-08-05:

- `make import` — passed with warnings.
- `make test` — blocked: `fortress_navigation_test.gd` passed, then suite hung on `siege_smoke_test.gd > test_scene_builds_with_core_nodes`; after manual interrupt Godot aborted with signal 11 / exit 134.

Observed warnings and issues:

- GdUnit remote debugger warning: `127.0.0.1:0` invalid remote port.
- Deprecated `instance_reset_physics_interpolation()` warning from GdUnit scene runner.
- Duplicate scene UID warnings in `scenes/test/rsq_*` and `scenes/test/drum_*`.
- Asset case mismatch warnings between `Assets/...` paths and stored `assets/...` paths.
- Import exit leak warnings: `CanvasItem`, `ObjectDB`, resource still in use, dummy texture RID.
- Full suite is not a reliable baseline until smoke timeout/crash behavior is isolated.

## Current Risks

- Working tree already contains uncommitted gameplay fixes for AI/staging; baseline reflects that state, not clean remote state.
- Enemy behavior mixes explicit brain classes with booleans/meta flags on units, making state transitions hard to reason about.
- Fortress navigation uses generated graph data plus direct movement, manual step-up, stuck recovery, and special ladder traversal paths.
- Hardcoded coordinates/ranges remain in wave spawn, defender routing, targeting heuristics, and fortress tactical areas.
- Registry use is improving but not universal; direct scans and per-unit searches can still become O(n²) under hundreds of actors.
- Staged enemies are intentionally hidden from active targeting; this may affect minimap/HUD/tests if not formalized as a state.
- Ladder ownership/reservation is fragile because carrier team, deployed ladder, queue, climb slot, and cleanup lifecycle cross several scripts.

## Backlog

### P0-001 — Establish Baseline

- Problem: Refactoring without a recorded baseline risks confusing new regressions with pre-existing test/environment issues.
- Affected files: `Makefile`, `project.godot`, `test/*.gd`, `addons/gdUnit4/**`, `docs/refactoring_backlog.md`, `docs/refactoring_log.md`.
- Expected result: Current import/test status is documented with exact blockers and warnings.
- Implementation notes: Run import and full test suite before major refactors; record command outputs and distinguish passing targeted tests from blocked full-suite status.
- Dependencies: none.
- Risk: low; documentation only.
- Test strategy: `make import`, `make test`.
- Status: DONE.

### P0-002 — Add Lifecycle And Reservation Diagnostics

- Problem: Enemies can appear idle around ladders or after wall capture because reservations, ladder ownership, and current objective are not visible enough.
- Affected files: `scripts/enemy/enemy.gd`, `scripts/enemy/ladder_orc_enemy.gd`, `scripts/enemy/siege_ladder.gd`, `scripts/enemy/wall_assault_brain.gd`, `scripts/enemy/ladder_assault_brain.gd`, `scripts/enemy/siege_director.gd`, `scripts/core/combat_registry.gd`.
- Expected result: Debug output or inspector-friendly metadata exposes enemy state, objective, ladder id, queue position, reservation target, and stuck reason without changing gameplay.
- Implementation notes: Add guarded diagnostics behind exported flags or existing debug paths; do not spam logs during normal play.
- Dependencies: P0-001.
- Risk: low; poor throttling could hurt performance or clutter output.
- Test strategy: targeted enemy/ladder tests plus manual run with debug flag enabled.
- Status: DONE.

### P0-003 — Introduce Explicit Enemy State Model

- Problem: Enemy AI currently relies on scattered booleans, meta flags, timers, and brain side effects.
- Affected files: `scripts/enemy/enemy.gd`, `scripts/enemy/infantry_enemy.gd`, `scripts/enemy/archer_enemy.gd`, `scripts/enemy/ladder_orc_enemy.gd`, `scripts/enemy/wall_assault_brain.gd`, `scripts/enemy/ladder_assault_brain.gd`, `scripts/enemy/wave_spawner.gd`.
- Expected result: Enemy has clear states such as `STAGED`, `ADVANCING`, `ESCORTING`, `QUEUING_LADDER`, `CLIMBING`, `ON_WALL`, `ATTACKING_GATE`, `ATTACKING_KEEP`, `DEAD`.
- Implementation notes: Added enum and transition helpers first; existing behavior still uses the old execution flow while debug snapshots now expose explicit state id/name. Future tasks can migrate decisions to the enum safely.
- Dependencies: P0-002.
- Risk: high; state migration can break current fixes if done broadly.
- Test strategy: unit tests for transitions, staged assault tests, ladder tests, smoke scene.
- Status: DONE.

### P0-004 — Introduce Explicit Defender State Model

- Problem: Allied archers choose targets/positions through distributed logic that is hard to tune for hundreds of enemies.
- Affected files: `scripts/ally/ally_archer.gd`, `scripts/ally/archer_shooting.gd`, `scripts/ally/defender_targeting.gd`, `scripts/ally/defender_positioning.gd`, `scripts/ally/defender_orders.gd`.
- Expected result: Defender states such as `HOLDING_SLOT`, `AIMING`, `REPOSITIONING`, `RETREATING`, `DOWNED` make behavior predictable.
- Implementation notes: Added `DefenderState` with explicit idle, moving, holding, engaging, repositioning, retreating, stuck, and dead states; wired order/movement/combat transitions into `AllyArcher` debug reporting.
- Dependencies: P0-001, P0-014.
- Risk: medium.
- Test strategy: defender positioning/targeting tests and manual wall defense scenario.
- Status: DONE.

### P0-005 — Reduce Large Unit Responsibilities

- Problem: `Enemy` and `AllyArcher` still own movement, combat, state, animation, diagnostics, and registration glue.
- Affected files: `scripts/enemy/enemy.gd`, `scripts/ally/ally_archer.gd`, `scripts/characters/**`, `scripts/core/**`.
- Expected result: Movement, targeting, state, and damage are delegated to reusable components with stable public methods.
- Implementation notes: Extract only after state models and diagnostics prove current flows.
- Dependencies: P0-003, P0-004.
- Risk: high.
- Test strategy: existing unit tests plus focused component tests.
- Status: TODO.

### P0-006 — Inventory Hardcoded Fortress Data

- Problem: AI and spawning still depend on map-specific coordinates and magic ranges.
- Affected files: `scripts/enemy/wave_spawner.gd`, `scripts/enemy/siege_director.gd`, `scripts/ally/defender_orders.gd`, `scripts/castle/fortress_generator.gd`, `scripts/characters/targeting_component.gd`, `scenes/play.tscn`.
- Expected result: All hardcoded fortress positions/ranges are listed with owners and replacement strategy.
- Implementation notes: Create a small audit table before changing code; prefer data from `CastleModel` and scene markers.
- Dependencies: P0-001.
- Risk: low.
- Test strategy: docs-only plus grep verification.
- Status: DONE.

### P0-007 — Define Fortress Markers And Regions

- Problem: Systems need shared names for wall front, towers, gate, keep, ladder zones, archer bands, staging horizon, and assault sectors.
- Affected files: `scripts/castle/castle_model.gd`, `scripts/castle/fortress_generator.gd`, `scenes/play.tscn`, possible new resource/script for fortress regions.
- Expected result: AI queries semantic regions instead of relying on raw coordinates.
- Implementation notes: Added read-only named regions to `CastleModel` and registered generated `wall_front`, `staging_horizon`, `ladder_zone`, `archer_band`, `gate`, and `keep` regions from fortress geometry/slots. Consumers can now migrate off raw coordinates incrementally.
- Dependencies: P0-006.
- Risk: medium.
- Test strategy: fortress generation tests validating required markers.
- Status: DONE.

### P0-008 — Formalize Fortress Navigation Graph

- Problem: Pathing uses generated links but enemy objectives still sometimes bypass them with direct movement.
- Affected files: `scripts/castle/castle_pathfinder.gd`, `scripts/castle/castle_model.gd`, `scripts/enemy/wall_assault_brain.gd`, `scripts/characters/unit_locomotion.gd`.
- Expected result: All castle traversal decisions can request named graph routes.
- Implementation notes: Keep current graph and add validation/diagnostics before replacing movement behavior.
- Dependencies: P0-007, P0-010.
- Risk: high.
- Test strategy: graph connectivity tests for gate, wall, tower, keep, ladder top.
- Status: TODO.

### P0-009 — Remove Map-Specific Defender Routing

- Problem: Defender movement and targeting can drift when fortress shape changes.
- Affected files: `scripts/ally/defender_orders.gd`, `scripts/ally/defender_positioning.gd`, `scripts/castle/castle_model.gd`.
- Expected result: Defenders request slots/sectors from fortress data, not coordinates.
- Implementation notes: Migrate one order mode at a time.
- Dependencies: P0-007.
- Risk: medium.
- Test strategy: defender slot assignment tests across generated fortress variants.
- Status: TODO.

### P0-010 — Document Navigation Architecture

- Problem: There is no single source of truth for enemy ground, ladder, wall, tower, and keep navigation responsibilities.
- Affected files: `docs/refactoring_backlog.md`, `docs/navigation_architecture.md`, `scripts/castle/**`, `scripts/enemy/**`, `scripts/characters/**`.
- Expected result: A short architecture doc defines which system owns route selection, movement execution, ladder traversal, stuck recovery, and fallback.
- Implementation notes: Document before refactoring navigation code.
- Dependencies: P0-001.
- Risk: low.
- Test strategy: docs-only review against code.
- Status: DONE.

### P0-011 — Consolidate Local Pathfinding API

- Problem: Unit movement code has several ad hoc movement/fallback paths.
- Affected files: `scripts/characters/unit_locomotion.gd`, `scripts/characters/traversal_controller.gd`, `scripts/enemy/enemy.gd`, `scripts/enemy/wall_assault_brain.gd`.
- Expected result: Callers use one movement API for goal setting, arrival, fallback, and stuck reporting.
- Implementation notes: Keep behavior identical and wrap existing code first.
- Dependencies: P0-010.
- Risk: high.
- Test strategy: movement unit tests plus smoke scene.
- Status: TODO.

### P0-012 — Make Step-Up Rules Explicit

- Problem: Manual step-up helps movement but can cause weird vertical behavior or falling if applied in unsafe places.
- Affected files: `scripts/characters/unit_locomotion.gd`, `scripts/enemy/enemy.gd`, `scripts/enemy/wall_assault_brain.gd`.
- Expected result: Step-up checks only apply on approved surfaces and never at wall edges/ladders without floor confirmation.
- Implementation notes: Promote floor-ahead and max-drop checks into named helpers.
- Dependencies: P0-011.
- Risk: medium.
- Test strategy: focused movement tests and manual wall-edge scenario.
- Status: TODO.

### P0-013 — Formalize Stuck Recovery

- Problem: Stuck recovery exists but enemy objectives can still stall in staging, ladder, or post-wall states.
- Affected files: `scripts/enemy/enemy.gd`, `scripts/enemy/wall_assault_brain.gd`, `scripts/enemy/ladder_assault_brain.gd`, `scripts/enemy/wave_spawner.gd`.
- Expected result: Every recovery path records reason, target, retry count, and final fallback objective.
- Implementation notes: Build on diagnostics from P0-002; avoid teleporting unless explicitly allowed.
- Dependencies: P0-002, P0-010.
- Risk: medium.
- Test strategy: stuck simulation tests with known blockers.
- Status: TODO.

### P0-014 — Complete Combat Registry Ownership

- Problem: Some targeting/search logic still bypasses `CombatRegistry`, which risks scaling issues and inconsistent staged/dead filtering.
- Affected files: `scripts/core/combat_registry.gd`, `scripts/characters/targeting_component.gd`, `scripts/ally/defender_targeting.gd`, `scripts/enemy/archer_enemy.gd`, `scripts/enemy/enemy.gd`.
- Expected result: All common combat queries go through registry APIs with state-aware filters.
- Implementation notes: Added group-filtered enemy registry API and routed ladder crew/ladders hotpaths through registry while keeping tree-scan fallbacks for missing registry/test contexts. Broader non-combat fortress/model scans remain intentionally outside this task.
- Dependencies: P0-003.
- Risk: medium.
- Test strategy: registry unit tests for alive/dead/staged/allied/enemy filters.
- Status: DONE.

### P1-001 — Add Spatial Query Correctness Tests

- Problem: Performance optimizations can silently drop valid targets or include invalid units.
- Affected files: `scripts/core/combat_registry.gd`, `test/*`.
- Expected result: Tests cover local radius, caps, team filters, staged enemies, dead enemies, and target priority.
- Implementation notes: Added deterministic fake-node tests for flat-radius lookup across grid cells, team filters, staged/hidden/invalid units, include flags, player inclusion, group-filtered enemies, and register/unregister grid invalidation.
- Dependencies: P0-014.
- Risk: low.
- Test strategy: new focused GdUnit tests.
- Status: DONE.

### P1-002 — Centralize Threat Evaluation

- Problem: Enemy archers, defenders, and assault brains have separate target heuristics.
- Affected files: `scripts/characters/targeting_component.gd`, `scripts/ally/defender_targeting.gd`, `scripts/enemy/archer_enemy.gd`, `scripts/core/combat_registry.gd`.
- Expected result: One threat scoring API ranks visible, reachable, high-value targets.
- Implementation notes: Added pure `ThreatEvaluator` distance/role/gate/priority scoring helper and routed `DefenderTargeting` through it while preserving previous weights.
- Dependencies: P0-014, P1-001.
- Risk: medium.
- Test strategy: deterministic scoring tests.
- Status: DONE.

### P1-003 — Add Decision Scheduling Budgets

- Problem: Hundreds of actors cannot all run targeting/path decisions every frame.
- Affected files: `scripts/enemy/**`, `scripts/ally/**`, `scripts/core/combat_registry.gd`.
- Expected result: AI decisions are staggered and capped per frame while movement remains smooth.
- Implementation notes: Added scene-level `DecisionScheduler` with per-key frame caps and per-owner intervals. Routed allied archer target refresh and enemy separation refresh through it while preserving fallback behavior when no scheduler exists.
- Dependencies: P0-003, P0-004, P0-014.
- Risk: medium.
- Test strategy: performance probe and target acquisition latency checks.
- Status: DONE.

### P1-004 — Formalize Ladder State Machine

- Problem: Ladder flow crosses carriers, deployed ladder, queue, climb, top landing, and cleanup without one authoritative state.
- Affected files: `scripts/enemy/ladder_orc_enemy.gd`, `scripts/enemy/siege_ladder.gd`, `scripts/enemy/ladder_assault_brain.gd`, `scripts/enemy/siege_director.gd`.
- Expected result: Ladders expose states such as `CARRIED`, `DEPLOYING`, `DEPLOYED`, `OCCUPIED`, `DESTROYED`, `RELEASED`.
- Implementation notes: Added `SiegeLadder.LadderState` with `carried`, `deploying`, `deployed`, `occupied`, `destroyed`, and `released` names. Deployed ladder debug now reports `state`/`state_id`, and ladder-carrier crew debug reports `ladder_state` before the deployed node exists.
- Dependencies: P0-002, P0-003.
- Risk: high.
- Test strategy: ladder carrier death/deploy/climb tests.
- Status: DONE.

### P1-005 — Harden Ladder Cleanup

- Problem: Dead carriers, destroyed ladders, and climbed units can leave stale references/reservations.
- Affected files: `scripts/enemy/ladder_orc_enemy.gd`, `scripts/enemy/siege_ladder.gd`, `scripts/enemy/ladder_assault_brain.gd`, `scripts/core/combat_registry.gd`.
- Expected result: All ladder reservations are released exactly once and stale refs are ignored.
- Implementation notes: Added `release_unit()` to clear climb, entry, queue, landing, and lane slots together. Dead/inactive units are now pruned from all ladder reservation dictionaries, destroyed/released ladders clear every reservation, and `Enemy._die()` uses full ladder release when available.
- Dependencies: P1-004.
- Risk: medium.
- Test strategy: kill one carrier, kill both carriers, destroy deployed ladder, climb complete.
- Status: DONE.

### P1-006 — Ladder Queue And Capacity Rules

- Problem: Enemies can bunch near ladders or look idle if queue/capacity behavior is implicit.
- Affected files: `scripts/enemy/siege_ladder.gd`, `scripts/enemy/ladder_assault_brain.gd`, `scripts/enemy/wall_assault_brain.gd`.
- Expected result: Queue position, max climbers, retry delay, and fallback objective are explicit.
- Implementation notes: Added explicit `max_queue_size`, `can_queue()`, and `reserve_queue()` on ladders. Ladder brain now reserves a queue slot when entry/climb capacity is full, and enemies move toward their queue point instead of returning to idle.
- Dependencies: P1-004, P1-005.
- Risk: medium.
- Test strategy: multi-enemy/multi-ladder queue tests.
- Status: DONE.

### P1-007 — Add Ladder Scenario Tests

- Problem: Screenshot-reported ladder bugs need reproducible coverage.
- Affected files: `test/*`, `scripts/enemy/**`.
- Expected result: Tests cover enemies approaching ladders, entering queues, climbing, landing on wall, and switching when ladder is invalid.
- Implementation notes: Added deterministic enemy tests for queued movement when ladder entry is full, invalid/released ladder selection, and post-climb wall landing state. These extend cleanup and queue coverage without requiring the full smoke scene.
- Dependencies: P1-004, P1-006.
- Risk: low.
- Test strategy: new GdUnit tests.
- Status: DONE.

### P1-008 — Define Assault Sectors

- Problem: Waves currently look like groups instead of an organized assault across the wall width.
- Affected files: `scripts/enemy/wave_spawner.gd`, `scripts/enemy/siege_director.gd`, `scripts/castle/castle_model.gd`.
- Expected result: Spawn/staging/advance points are distributed by named wall sectors.
- Implementation notes: Added cached assault sectors in `SiegeDirector`; sectors are derived from accessible ladder slots, fall back to fortress regions, and drive ladder reservation plus wide spawn/assault point selection.
- Dependencies: P0-007.
- Risk: medium.
- Test strategy: wave distribution tests and manual horizon visual check.
- Status: DONE.

### P1-009 — Expand Siege Director Responsibilities

- Problem: Tactical assignment is split between spawner, individual enemies, ladder logic, and brains.
- Affected files: `scripts/enemy/siege_director.gd`, `scripts/enemy/wave_spawner.gd`, `scripts/enemy/wall_assault_brain.gd`, `scripts/enemy/ladder_assault_brain.gd`.
- Expected result: `SiegeDirector` owns high-level role allocation: archers, ladder carriers, escorts, ram, wall assault, keep pressure.
- Implementation notes: Added `SiegeDirector` tactical order APIs for unit roles, wall assault orders, ladder crew plans, carrier orders, and escort orders. `WaveSpawner` now instantiates/stages units and executes director-owned orders.
- Dependencies: P0-003, P1-008.
- Risk: high.
- Test strategy: role assignment tests and wave smoke.
- Status: DONE.

### P1-010 — Add Reassignment Hysteresis

- Problem: Units can thrash between objectives if targets/ladders become briefly invalid.
- Affected files: `scripts/enemy/siege_director.gd`, `scripts/enemy/wall_assault_brain.gd`, `scripts/ally/defender_targeting.gd`.
- Expected result: Objective changes have cooldowns, confidence thresholds, and clear fallback order.
- Implementation notes: Added short-lived sticky assignments in wall target selection, ladder selection, and defender targeting. Units keep recent objectives unless the alternative is clearly better, unavailable, out of range, or the order mode changes.
- Dependencies: P1-009.
- Risk: medium.
- Test strategy: deterministic reassignment tests.
- Status: DONE.

### P1-011 — Introduce WaveDefinition Resources

- Problem: Wave composition, staging, delay, spawn width, and escalation are still too script-driven.
- Affected files: `scripts/enemy/wave_spawner.gd`, `data/**`, `scenes/play.tscn`.
- Expected result: Waves can be configured as resources with counts, roles, staging behavior, and pacing.
- Implementation notes: Added `WaveDefinition` resources for wave composition, pacing, and staging values. `WaveSpawner` now uses configured resources when present and keeps the old exported `waves` array as fallback.
- Dependencies: P1-008, P1-009.
- Risk: medium.
- Test strategy: resource loading and spawn count tests.
- Status: DONE.

### P1-012 — Normalize Unit Profile Resources

- Problem: Unit tuning is spread across `.tres` stats and script exports.
- Affected files: `data/*.tres`, `scripts/characters/unit_stats.gd`, enemy/ally scenes/scripts.
- Expected result: Speed, role, attack range, decision interval, armor/defense, and behavior tags live in consistent profiles.
- Implementation notes: Extended `UnitStats` with behavior tags plus decision/refresh intervals and wired enemy, ally, and player runtime fields to read those profile values while preserving previous defaults.
- Dependencies: P0-003, P0-004.
- Risk: medium.
- Test strategy: stat resource tests and scene load tests.
- Status: DONE.

### P1-013 — Add Performance Instrumentation

- Problem: AI lag is suspected, but hot paths need repeatable measurements while scaling to hundreds of units.
- Affected files: `scripts/enemy/**`, `scripts/ally/**`, `scripts/core/combat_registry.gd`, `scripts/core/projectile_pool.gd`, `docs/audit/**`.
- Expected result: Debug probes report targeting, movement, raycast, spawn, ladder, projectile, and UI costs.
- Implementation notes: Added `PerfMonitor` and F3 `Perf` lines for aggregated count/avg/max metrics. Current probes cover registry spatial queries, decision scheduler allow/deny counters, allied target acquisition, and enemy separation.
- Dependencies: P0-014.
- Risk: low.
- Test strategy: manual perf run and log sanity checks.
- Status: DONE.

### P1-014 — Audit Projectile Lifecycle

- Problem: Arrow pooling exists, but projectile lifecycle must stay safe under high volume.
- Affected files: `scripts/core/projectile_pool.gd`, `scripts/player/arrow.gd`, `scripts/ally/archer_shooting.gd`, `scripts/enemy/archer_enemy.gd`, `scripts/enemy/enemy_arrow.gd`.
- Expected result: No allocation spikes, no physics-callback removals, no stale collision state.
- Implementation notes: Enemy archer arrows now use `ProjectilePool` instead of per-shot instantiate/free. Player and enemy arrows guard against double despawn, deferred removal waits until arrows are detached before reuse, and player-arrow collision/rigid-body disabling is deferred to stay safe inside physics callbacks.
- Dependencies: P1-013.
- Risk: medium.
- Test strategy: projectile pool tests and high-volume firing smoke.
- Status: DONE.

### P1-015 — Audit Scans And Raycasts

- Problem: Targeting and LOS checks can dominate frame time as actors scale.
- Affected files: `scripts/characters/targeting_component.gd`, `scripts/ally/defender_targeting.gd`, `scripts/enemy/archer_enemy.gd`, `scripts/core/combat_registry.gd`.
- Expected result: All scans/raycasts have frequency limits, caps, and cached candidate lists.
- Implementation notes: Added split `PerfMonitor` timings for `TargetingComponent` acquisition/LOS rays, enemy archer defender scan/LOS/exposure rays, and allied ballistic launch rays. Existing registry caches and decision budgets remain the behavior-preserving caps while these costs are measured.
- Dependencies: P1-013.
- Risk: medium.
- Test strategy: perf probes and correctness tests.
- Status: DONE.

### P1-016 — Add Fortress Validation Tool

- Problem: Generated fortress data can be incomplete without obvious editor feedback.
- Affected files: `scripts/castle/**`, possible `tools/**`, `test/*`.
- Expected result: Validator reports missing ladder slots, unreachable towers, disconnected wall nodes, and invalid tactical slots.
- Implementation notes: Extended `SceneValidator` with headless model validation for required fortress regions, ladder slot metadata, tactical slot kinds, navigation edge endpoints, links, and navigation meshes.
- Dependencies: P0-008.
- Risk: low.
- Test strategy: fortress validation tests.
- Status: DONE.

### P1-017 — Add Navigation Scenario Tests

- Problem: Wall/tower/keep movement regressions are currently caught mostly by manual play.
- Affected files: `test/*`, `scripts/castle/**`, `scripts/enemy/**`.
- Expected result: Tests cover ground-to-ladder, ladder-to-wall, wall-to-tower, wall-to-gate, and wall-to-keep routes.
- Implementation notes: Added scene-backed graph route coverage for ground-to-ladder, wall-to-tower, wall-to-gate, gate-to-keep, and wall-to-keep, and connected generated stair/wall/courtyard graph gaps.
- Dependencies: P0-008, P0-011.
- Risk: medium.
- Test strategy: deterministic graph route tests plus limited scene tests.
- Status: DONE.

### P2-001 — Add Defender Sector Orders

- Problem: Player/AI control over defenders is coarse.
- Affected files: `scripts/ally/defender_orders.gd`, `scripts/ally/defender_positioning.gd`, UI scripts.
- Expected result: Defenders can hold or reinforce named wall sectors.
- Implementation notes: Requires fortress sectors and defender states.
- Dependencies: P0-004, P1-008.
- Risk: medium.
- Test strategy: order assignment tests and manual UI check.
- Status: TODO.

### P2-002 — Add Ladder Counterplay Hooks

- Problem: Ladders are mostly enemy logistics; defenders need clearer interactions later.
- Affected files: `scripts/enemy/siege_ladder.gd`, defender combat scripts, UI.
- Expected result: Ladders expose damage/interaction hooks for arrows, melee, or push-off mechanics.
- Implementation notes: Do not tune gameplay until ladder lifecycle is stable.
- Dependencies: P1-004, P1-005.
- Risk: medium.
- Test strategy: ladder damage and cleanup tests.
- Status: TODO.

### P2-003 — Add Ammo Logistics

- Problem: Unlimited or unclear ammo can hide pacing and performance issues.
- Affected files: `scripts/ally/**`, `scripts/enemy/archer_enemy.gd`, `data/*.tres`, UI.
- Expected result: Ammo/reload behavior is data-driven and visible.
- Implementation notes: Not part of P0 performance/AI simplification.
- Dependencies: P1-012.
- Risk: medium.
- Test strategy: firing cadence tests.
- Status: TODO.

### P2-004 — Add Defender Cover Semantics

- Problem: Wall defenders do not reason about safe firing positions or cover quality.
- Affected files: `scripts/ally/defender_positioning.gd`, `scripts/castle/castle_model.gd`.
- Expected result: Tactical slots include cover/exposure metadata.
- Implementation notes: Build on fortress regions/slots.
- Dependencies: P0-007, P0-004.
- Risk: medium.
- Test strategy: tactical slot metadata tests.
- Status: TODO.

### P2-005 — Add Morale And Retreat Hooks

- Problem: Large battles will benefit from controllable panic/retreat behavior, but current AI must be stable first.
- Affected files: enemy/ally state systems, UI, data resources.
- Expected result: Morale is available as a later gameplay layer without complicating P0 AI.
- Implementation notes: Defer until explicit states are mature.
- Dependencies: P0-003, P0-004, P1-012.
- Risk: medium.
- Test strategy: state transition tests.
- Status: TODO.

## First Selected Task

Next implementation task: P1-005 — Harden Ladder Cleanup.

Reason: Ladder state is now visible; cleanup is the next likely cause of stale reservations and units standing around ladders.
