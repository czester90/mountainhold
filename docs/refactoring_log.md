# Mountainhold Refactoring Log

## 2026-08-05 — P0-001 Establish Baseline And Backlog

Status: DONE with full-suite blocker recorded.

Files changed:

- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Read current project structure, scripts, scenes, resources, tests, and active docs/audits.
- Recorded the current architecture map and major risk areas before further AI/navigation refactors.
- Created a prioritized incremental backlog focused on explicit states, fortress navigation, targeting/registry performance, ladders, waves, and tests.
- Selected P0-002 lifecycle/reservation diagnostics as the next implementation task.

Validation:

- `make import` passed.
- `make test` did not complete: `fortress_navigation_test.gd` passed, then execution hung on `siege_smoke_test.gd > test_scene_builds_with_core_nodes`; after manual interrupt Godot aborted with signal 11 and Make exited with error 134.

Observed warnings:

- GdUnit remote debugger attempted to use invalid port `127.0.0.1:0`.
- Deprecated `instance_reset_physics_interpolation()` warning from GdUnit.
- Duplicate UID warnings in `scenes/test/rsq_*` and `scenes/test/drum_*`.
- Case mismatch warnings for imported `Assets/...` references stored under `assets/...`.
- Import produced leak/resource warnings at exit.

Behavior changes:

- None. Documentation only.

Remaining risk:

- Full-suite smoke test must be isolated before it can be used as a reliable regression gate.
- Current baseline includes pre-existing uncommitted AI/staging gameplay changes in the working tree.

## 2026-08-05 — P0-002 Add Lifecycle And Reservation Diagnostics

Status: DONE.

Files changed:

- `scripts/enemy/enemy.gd`
- `scripts/enemy/ladder_orc_enemy.gd`
- `scripts/enemy/siege_ladder.gd`
- `test/enemy_test.gd`
- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Added `ai_debug_snapshot()` for enemies with state, objective, waypoint, attack target, wall/ladder brain summaries, ladder status, recovery counters, and last recovery reason.
- Added ladder-carrier crew diagnostics for crew id/index, carrying/deploying/deployed flags, living carrier count, deploy progress, and spawned ladder prop.
- Added `debug_unit_status()` for deployed ladders with active climber, entry reservation, queue, climb slot, foot/top, capacity, and per-unit reservation status.
- Marked P0-002 complete and selected P0-006 hardcoded fortress inventory as the next backlog task.

Validation:

- `make test-target TEST=res://test/enemy_test.gd` passed: 12 test cases, 0 failures.

Observed warnings:

- GdUnit remote debugger still attempts invalid port `127.0.0.1:0`.
- Test run still reports Godot cleanup/resource leak warnings after successful exit.

Behavior changes:

- None intended. Diagnostics are read-only helper methods and do not alter AI decisions.

Remaining risk:

- Full `make test` remains blocked by the previously recorded `siege_smoke_test.gd` hang/crash behavior.

## 2026-08-05 — P0-006 Inventory Hardcoded Fortress Data

Status: DONE.

Files changed:

- `docs/hardcoded_fortress_inventory.md`
- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Audited hardcoded fortress/world coordinates used by spawner, siege director, ladder carriers, defender targeting/positioning/orders, ally placement, fortress generation, combat registry, and traversal.
- Added coordinate inventory IDs `HF-001` through `HF-012` with owner, meaning, risk, and replacement path.
- Added tuning inventory IDs `HT-001` through `HT-010` for AI cadence, wall movement, ladder scoring, wave presentation, registry grid, and defender scoring constants.
- Marked P0-006 complete and selected P0-010 navigation architecture documentation as the next backlog task.

Validation:

- Ran grep audit over `scripts/enemy`, `scripts/ally`, `scripts/castle`, `scripts/characters`, and `scripts/core` for `Vector3`, ranges, spawn/ladder/wall/gate/keep/staging/targeting terms.

Behavior changes:

- None. Documentation only.

Remaining risk:

- The inventory is manual and should be refreshed after P0-010/P0-007 introduce semantic fortress queries.
- Full `make test` remains blocked by the previously recorded `siege_smoke_test.gd` hang/crash behavior.

## 2026-08-05 — P0-010 Document Navigation Architecture

Status: DONE.

Files changed:

- `docs/navigation_architecture.md`
- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Documented current and target ownership for fortress data, ground validation, tactical assignment, route selection, movement execution, ladder traversal, registry queries, and recovery.
- Defined navigation contracts for `FortressGenerator`, `CastleModel`, `SiegeDirector`, `WaveSpawner`, `Enemy`, `WallAssaultBrain`, `LadderAssaultBrain`, `SiegeLadder`, `TraversalController`, `UnitLocomotion`, and `CombatRegistry`.
- Captured current flows for gate/keep assault, wall assault via ladder, ladder crew deployment, and defender movement.
- Marked P0-010 complete and selected P0-003 explicit enemy state model as the next backlog task.

Validation:

- Reviewed current navigation owners in `CastleModel`, `CastlePathfinder`, `TraversalController`, `UnitLocomotion`, enemy brains, `SiegeDirector`, `WaveSpawner`, and `FortressGenerator`.

Behavior changes:

- None. Documentation only.

Remaining risk:

- The documented target contract still needs code enforcement through P0-003, P0-007, P0-008, P0-011, and P0-013.
- Full `make test` remains blocked by the previously recorded `siege_smoke_test.gd` hang/crash behavior.

## 2026-08-05 — P0-003 Introduce Explicit Enemy State Model

Status: DONE as a first safe state layer.

Files changed:

- `scripts/enemy/enemy.gd`
- `scripts/enemy/ladder_orc_enemy.gd`
- `test/enemy_test.gd`
- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Added `EnemyAIState` enum covering idle, staged, advancing, wall assault, gate/keep attacks, ladder approach/queue/climb, wall settling, on-wall fighting, ladder crew logistics, and death.
- Added `_ai_state`, `_set_ai_state()`, `_refresh_ai_state()`, `ai_state()`, and `ai_state_name()` to expose explicit state id/name.
- Updated `ai_debug_snapshot()` to report `state_id` from the enum and `state` from `ai_state_name()`.
- Wired key existing transitions into the enum: setup path, wall assault setup, staged damage, ladder approach/queue/climb, traversal completion/failure, wall unit attack, gate/keep attack, recovery-adjacent refresh, and death.
- Extended ladder-orc state reporting for carrying, deploying, helping, and queueing ladder flow without rewriting its behavior.
- Marked P0-003 complete and selected P0-014 combat registry ownership as the next performance-safe step.

Validation:

- `make test-target TEST=res://test/enemy_test.gd` passed: 12 test cases, 0 failures.

Observed warnings:

- GdUnit remote debugger still attempts invalid port `127.0.0.1:0`.
- Test run still reports Godot cleanup/resource leak warnings after successful exit.

Behavior changes:

- None intended. Existing AI branches still drive movement/combat; the enum is currently an explicit state layer and diagnostic contract.

Remaining risk:

- Some tactical decisions still read old booleans/path state directly. Later tasks should migrate decision branches to `EnemyAIState` only after targeted coverage exists.
- Full `make test` remains blocked by the previously recorded `siege_smoke_test.gd` hang/crash behavior.

## 2026-08-05 — P0-014 Complete Combat Registry Ownership

Status: DONE for current combat hotpaths.

Files changed:

- `scripts/core/combat_registry.gd`
- `scripts/enemy/enemy.gd`
- `scripts/enemy/ladder_orc_enemy.gd`
- `test/combat_registry_test.gd`
- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Added `CombatRegistry.active_enemies_in_group(group_name)` so combat code can query state-filtered role groups without broad scene scans.
- Routed ladder carrier/helper/orc crew loops in `LadderOrcEnemy` through registry-backed helpers while preserving tree-scan fallbacks when no registry exists.
- Routed base enemy active ladder lookup through `CombatRegistry.active_ladders()` with fallback for isolated scenes/tests.
- Added a focused registry test proving group-filtered enemy queries exclude staged and invalid-height units.
- Marked P0-014 complete and selected P1-001 spatial query correctness tests as the next task.

Validation:

- `make test-target TEST=res://test/combat_registry_test.gd` passed: 1 test case, 0 failures.
- `make test-target TEST=res://test/enemy_test.gd` passed: 12 test cases, 0 failures.

Observed warnings:

- GdUnit remote debugger still attempts invalid port `127.0.0.1:0`.
- `enemy_test.gd` still reports Godot cleanup/resource leak warnings after successful exit.

Behavior changes:

- None intended. Query sources changed to registry-backed filtered lists; fallback behavior remains for scenes without a registry.

Remaining risk:

- Some non-combat/fortress scans intentionally remain outside P0-014, especially castle slots/model/navigation groups.
- Full `make test` remains blocked by the previously recorded `siege_smoke_test.gd` hang/crash behavior.

## 2026-08-05 — P1-001 Add Spatial Query Correctness Tests

Status: DONE.

Files changed:

- `scripts/core/combat_registry.gd`
- `test/combat_registry_test.gd`
- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Expanded `CombatRegistry` tests to cover flat-radius enemy lookup across grid cells, enemy/allied team separation, include flags, player inclusion, staged enemy filtering, hidden filtering, invalid-height filtering, and group-filtered enemy queries.
- Added a register/unregister spatial query regression test that exposed stale grid cache after unregistering a unit in the same frame.
- Fixed stale spatial grid results by invalidating the registry grid cache on register, unregister, and tree-exit cleanup.
- Marked P1-001 complete and selected P1-002 centralized threat evaluation as the next task.

Validation:

- `make test-target TEST=res://test/combat_registry_test.gd` passed: 6 test cases, 0 failures.
- `make test-target TEST=res://test/enemy_test.gd` passed: 12 test cases, 0 failures.
- `make test-target TEST=res://test/wave_spawner_test.gd` passed: 3 test cases, 0 failures.

Observed warnings:

- GdUnit remote debugger still attempts invalid port `127.0.0.1:0`.
- `enemy_test.gd` still reports Godot cleanup/resource leak warnings after successful exit.

Behavior changes:

- Fixed a stale registry grid cache edge case: same-frame spatial queries now reflect manual register/unregister/tree-exit changes.

Remaining risk:

- Full `make test` remains blocked by the previously recorded `siege_smoke_test.gd` hang/crash behavior.
- Target priority itself is not centralized yet; it belongs to P1-002.

## 2026-08-05 — P1-002 Centralize Threat Evaluation

Status: DONE for defender targeting.

Files changed:

- `scripts/core/threat_evaluator.gd`
- `scripts/ally/defender_targeting.gd`
- `test/threat_evaluator_test.gd`
- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Added a pure `ThreatEvaluator` helper for distance scoring, ram/ladder role weights, flat XZ distance, gate threat scoring, and priority-zone scoring.
- Routed defender candidate scoring, gate threat scoring, blocked threat scoring, and gate-threat checks through the shared helper.
- Preserved previous defender weights exactly: ram `0.4`, ladder `0.55`, blocked ladder `0.35`, gate threat `0.45`, and forced-gate ladder `0.5`.
- Added deterministic scoring tests so future AI simplification can change heuristics intentionally instead of accidentally.
- Marked P1-002 complete. P1-003 decision scheduling budgets remains the next performance-safe task.

Validation:

- `make test-target TEST=res://test/threat_evaluator_test.gd` passed: 5 test cases, 0 failures.
- `make test-target TEST=res://test/components_test.gd` passed: 5 test cases, 0 failures.
- `make test-target TEST=res://test/ally_test.gd` passed all 16 test cases, then exited `101` because of the existing Godot cleanup/resource leak issue.
- `make import` passed with existing duplicate UID, missing UID, asset case mismatch, and cleanup/resource leak warnings.

Behavior changes:

- None intended. Defender target ranking now calls a shared scorer but uses the same formulas and weights as before.

Remaining risk:

- `TargetingComponent` and `ArcherEnemy` still have local scoring loops; migrate them after this helper is stable.
- Full `make test` remains blocked by the previously recorded `siege_smoke_test.gd` hang/crash behavior.

## 2026-08-05 — P1-003 Add Decision Scheduling Budgets

Status: DONE for first hotpaths.

Files changed:

- `scripts/core/decision_scheduler.gd`
- `scenes/play.tscn`
- `scripts/ally/ally_archer.gd`
- `scripts/enemy/enemy.gd`
- `test/decision_scheduler_test.gd`
- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Added a `DecisionScheduler` scene node that caps expensive decisions per frame and tracks per-owner intervals by decision key.
- Routed allied archer target refresh through the scheduler with a `12` per-frame cap.
- Routed enemy separation refresh through the scheduler with a `32` per-frame cap.
- Kept movement and combat continuous: if a unit is denied a decision budget, it keeps using its previous cached target/separation state and retries next physics frame.
- Preserved fallback behavior for isolated tests/scenes without a scheduler.
- Marked P1-003 complete. P1-013 performance instrumentation is the next best step to measure remaining targeting/raycast/AI costs before further tuning.

Validation:

- `make test-target TEST=res://test/decision_scheduler_test.gd` passed: 3 test cases, 0 failures.
- `make test-target TEST=res://test/enemy_test.gd` passed: 12 test cases, 0 failures.
- `make test-target TEST=res://test/ally_test.gd` passed all 16 test cases, then exited `101` because of the existing Godot cleanup/resource leak issue.
- `make import` passed with existing duplicate UID, missing UID, asset case mismatch, and cleanup/resource leak warnings.

Behavior changes:

- AI decision spikes are now capped in the main play scene. Units still move every physics frame and reuse cached decisions when over budget.

Remaining risk:

- The scheduler currently gates only allied target refresh and enemy separation refresh. Archer enemy LOS targeting, wall defender acquisition, ladder choice, and path replanning still need measurement before deeper throttling.
- Full `make test` remains blocked by the previously recorded `siege_smoke_test.gd` hang/crash behavior.

## 2026-08-05 — P1-013 Add Performance Instrumentation

Status: DONE for first AI/registry probes.

Files changed:

- `scripts/core/perf_monitor.gd`
- `scenes/play.tscn`
- `scripts/ui/developer_panel.gd`
- `scripts/core/combat_registry.gd`
- `scripts/core/decision_scheduler.gd`
- `scripts/ally/ally_archer.gd`
- `scripts/enemy/enemy.gd`
- `test/perf_monitor_test.gd`
- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Added a scene-level `PerfMonitor` that records count, total microseconds, average milliseconds, and max milliseconds by named hotpath.
- Added compact F3 developer panel lines prefixed with `Perf`, sorted by total measured cost.
- Instrumented registry spatial queries: `registry_enemies_near`, `registry_allies_near`, and `registry_units_near`.
- Instrumented decision scheduler counters for allowed, interval-denied, and budget-denied decisions.
- Instrumented allied archer target acquisition and enemy separation refresh timing.
- Kept instrumentation passive and non-spamming: metrics are visible in the debug overlay and do not print every frame.
- Marked P1-013 complete. P1-015 scan/raycast audit is now the next direct performance task.

Validation:

- `make test-target TEST=res://test/perf_monitor_test.gd` passed: 3 test cases, 0 failures.
- `make test-target TEST=res://test/decision_scheduler_test.gd` passed: 3 test cases, 0 failures.
- `make test-target TEST=res://test/combat_registry_test.gd` passed: 6 test cases, 0 failures.
- `make test-target TEST=res://test/dev_panel_test.gd` passed: 1 test case, 0 failures.
- `make test-target TEST=res://test/enemy_test.gd` passed: 12 test cases, 0 failures.
- `make test-target TEST=res://test/ally_test.gd` passed all 16 test cases, then exited `101` because of the existing Godot cleanup/resource leak issue.
- `make import` passed with existing duplicate UID, missing UID, asset case mismatch, and cleanup/resource leak warnings.

Behavior changes:

- None intended for gameplay. Only debug/perf metrics were added.

Remaining risk:

- Raycast-heavy paths are visible indirectly through target acquisition cost, but individual LOS/projectile raycasts are not split out yet.
- Full `make test` remains blocked by the previously recorded `siege_smoke_test.gd` hang/crash behavior.

## 2026-08-05 — P1-015 Audit Scans And Raycasts

Status: DONE for measurement coverage.

Files changed:

- `scripts/characters/components/targeting_component.gd`
- `scripts/enemy/archer_enemy.gd`
- `scripts/ally/archer_shooting.gd`
- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Added `PerfMonitor` timings around generic target acquisition and individual `TargetingComponent` LOS rays.
- Split enemy archer cost into defender search, central LOS rays, exposure scoring, and exposure rays.
- Split allied ballistic firing checks into total launch validation and per-segment world raycasts.
- Kept behavior unchanged: this task measures the remaining raycast/scan hotpaths before altering caps, intervals, or targeting rules.
- Marked P1-015 complete. P1-014 projectile lifecycle audit is the next adjacent performance task.

Validation:

- `make test-target TEST=res://test/components_test.gd` passed: 5 test cases, 0 failures.
- `make test-target TEST=res://test/archer_scene_test.gd` passed all 2 test cases, then exited `101` because of the existing Godot cleanup/resource leak issue.
- `make test-target TEST=res://test/ally_test.gd` passed all 16 test cases, then exited `101` because of the existing Godot cleanup/resource leak issue.
- `make test-target TEST=res://test/enemy_test.gd` passed: 12 test cases, 0 failures.
- `make import` passed with existing duplicate UID, missing UID, asset case mismatch, and cleanup/resource leak warnings.

Behavior changes:

- None intended. Only passive perf metrics were added.

Remaining risk:

- Raycast counts are now visible, but thresholds and scheduling for these paths still need tuning after a manual high-unit-count run.
- Full `make test` remains blocked by the previously recorded `siege_smoke_test.gd` hang/crash behavior.

## 2026-08-05 — P1-014 Audit Projectile Lifecycle

Status: DONE for pooled projectile lifecycle.

Files changed:

- `scripts/core/projectile_pool.gd`
- `scripts/player/arrow.gd`
- `scripts/enemy/enemy_arrow.gd`
- `scripts/enemy/archer_enemy.gd`
- `test/projectile_pool_test.gd`
- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Added pooled enemy archer arrows so enemy volleys no longer instantiate/free `enemy_arrow.tscn` per shot.
- Added double-despawn guards to player and enemy arrows so repeated hit/timeout paths cannot enqueue the same projectile twice.
- Deferred player-arrow collision/body/process disabling during recycle, fixing Godot physics-callback warnings during arrow hits.
- Made pool enqueue wait until a projectile is detached from the tree before reuse, preserving the safe deferred-removal behavior.
- Added lifecycle tests for enemy-arrow reuse and player-arrow duplicate despawn protection.
- Marked P1-014 complete. P1-004 ladder state machine is the next visible AI-stall task.

Validation:

- `make test-target TEST=res://test/projectile_pool_test.gd` passed: 2 test cases, 0 failures, 0 orphans.
- `make test-target TEST=res://test/ally_test.gd` passed all 16 test cases, then exited `101` because of the existing Godot cleanup/resource leak issue; no physics-callback collision warning remained after the deferred recycle fix.
- `make test-target TEST=res://test/enemy_test.gd` passed: 12 test cases, 0 failures.
- `make import` passed with existing duplicate UID, missing UID, asset case mismatch, and cleanup/resource leak warnings.

Behavior changes:

- Enemy archers still fire the same projectile script with the same setup inputs, but arrows are reused through the pool after despawn.

Remaining risk:

- The pool now reduces projectile churn, but manual high-volume volleys should still be profiled with F3 perf lines to confirm projectile churn is no longer the dominant spike.
- Full `make test` remains blocked by the previously recorded `siege_smoke_test.gd` hang/crash behavior.

## 2026-08-05 — P1-004 Formalize Ladder State Machine

Status: DONE for state visibility and diagnostics.

Files changed:

- `scripts/enemy/siege_ladder.gd`
- `scripts/enemy/ladder_orc_enemy.gd`
- `test/enemy_test.gd`
- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Added `SiegeLadder.LadderState` with named states for carried, deploying, deployed, occupied, destroyed, and released.
- Routed deployed ladder debug through `ladder_state()` / `ladder_state_name()` so F3 snapshots can show whether a ladder is deployed or occupied.
- Updated climb reservation/release/pruning to refresh deployed vs occupied state without changing queue capacity behavior.
- Added `ladder_state` to ladder-orc crew debug so carried/deploying/deployed state is visible before the physical ladder node exists.
- Marked P1-004 complete. P1-005 cleanup hardening is next because stale refs/reservations are now easier to observe.

Validation:

- `make test-target TEST=res://test/enemy_test.gd` passed: 12 test cases, 0 failures.

Behavior changes:

- None intended for movement or queueing. This is a state/diagnostic layer first.

Remaining risk:

- Cleanup paths can still leave stale reservations after carrier death or ladder destruction; P1-005 should make those releases explicit.
- Full `make test` remains blocked by the previously recorded `siege_smoke_test.gd` hang/crash behavior.

## 2026-08-05 — P1-005 Harden Ladder Cleanup

Status: DONE for stale reservation cleanup.

Files changed:

- `scripts/enemy/siege_ladder.gd`
- `scripts/enemy/enemy.gd`
- `test/enemy_test.gd`
- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Added `SiegeLadder.release_unit()` to clear climb, entry, queue, landing, and lane reservations in one path.
- Extended ladder pruning so dead/inactive enemies are removed from entry, queue, landing, and active climber dictionaries.
- Cleared all reservations when a ladder is destroyed or marked released.
- Routed `Enemy._die()` through full ladder release when available, with the older climb-only release as fallback.
- Added tests for dead-unit reservation cleanup and destroyed-ladder reservation cleanup.
- Marked P1-005 complete. P1-006 queue/capacity rules is next.

Validation:

- `make test-target TEST=res://test/enemy_test.gd` passed: 14 test cases, 0 failures.

Behavior changes:

- Dead units no longer keep ladder reservations while their corpse/fade node is still inside the tree.

Remaining risk:

- Queue arbitration is still implicit; P1-006 should make retry/capacity/slot behavior clearer so enemies do not look idle at full ladders.
- Full `make test` remains blocked by the previously recorded `siege_smoke_test.gd` hang/crash behavior.

## 2026-08-05 — P1-006 Ladder Queue And Capacity Rules

Status: DONE for explicit queue capacity and movement.

Files changed:

- `scripts/enemy/siege_ladder.gd`
- `scripts/enemy/ladder_assault_brain.gd`
- `scripts/enemy/enemy.gd`
- `test/enemy_test.gd`
- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Added explicit ladder queue capacity via `max_queue_size`, `can_queue()`, and `reserve_queue()`.
- Made ladder brain reserve queue slots when entry/climb capacity is full.
- Changed enemy ladder approach so queued enemies move to their queue point instead of falling back to idle.
- Exposed `queue_capacity`, `queued_units`, and per-unit queue slot in ladder debug.
- Added tests for full-capacity queue reservation and queue capacity blocking.
- Marked P1-006 complete. P1-007 ladder scenario tests is next.

Validation:

- `make test-target TEST=res://test/enemy_test.gd` passed: 16 test cases, 0 failures.

Behavior changes:

- Enemies that cannot enter a full ladder now reserve and move toward a queue slot, making the “waiting at ladders” state intentional and visible.

Remaining risk:

- Scenario-level coverage still needs to verify approach, queue, climb, landing, and invalid-ladder switching together.
- Full `make test` remains blocked by the previously recorded `siege_smoke_test.gd` hang/crash behavior.

## 2026-08-05 — P1-007 Add Ladder Scenario Tests

Status: DONE for deterministic ladder scenarios.

Files changed:

- `test/enemy_test.gd`
- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Added a scenario test where an enemy reaches a full ladder, reserves a queue slot, enters `queuing_ladder`, and moves toward that queue point.
- Added a scenario test that ladder selection skips a released/invalid ladder and chooses an active deployed ladder.
- Added a scenario test that ladder traversal completion puts the enemy on the wall path/state.
- Marked P1-007 complete.

Validation:

- `make test-target TEST=res://test/enemy_test.gd` passed: 19 test cases, 0 failures.

Behavior changes:

- None; this task adds coverage for the ladder fixes from P1-004 through P1-006.

Remaining risk:

- Full-scene ladder/wall smoke coverage is still limited by the broader `siege_smoke_test.gd` hang/crash baseline.

## 2026-08-05 — P0-007 Define Fortress Markers And Regions

Status: DONE for read-only semantic regions.

Files changed:

- `scripts/castle/castle_model.gd`
- `scripts/castle/fortress_generator.gd`
- `test/fortress_navigation_test.gd`
- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Added named `CastleModel` regions with center, radius, normal, and metadata.
- Registered generated regions for `wall_front`, `staging_horizon`, `ladder_zone`, `archer_band`, `gate`, and `keep`.
- Derived wall/horizon width from generated ladder slots so future assault distribution can use semantic fortress data.
- Added fortress generation coverage asserting regions exist in the play scene.
- Marked P0-007 complete. P1-008 assault sectors is now unblocked.

Validation:

- `make test-target TEST=res://test/fortress_navigation_test.gd` passed: 1 test case, 0 failures.

Behavior changes:

- None intended. This adds read-only data for future AI/spawn routing.

Remaining risk:

- Wave spawning still uses its existing lane logic until P1-008 migrates it to sectors.

## P1-008 — Define Assault Sectors

Files changed:

- `scripts/enemy/siege_director.gd`
- `test/wave_spawner_test.gd`
- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Added cached assault sectors owned by `SiegeDirector`.
- Derived sectors from accessible wall ladder slots, with fortress-region fallback when slots are unavailable.
- Routed ladder reservations, ladder assault points, and wide spawn points through sector spread order.
- Added tests for sector creation, wall-width spawn spread, and skipping reserved ladder sectors.

Validation:

- `git diff --check` passed.
- `make test-target TEST=res://test/wave_spawner_test.gd` passed: 6 test cases, 0 failures.
- `make import` passed with existing duplicate UID, missing UID, case mismatch, and cleanup warnings.

Behavior changes:

- Waves now use named wall sectors for broad distribution instead of directly sampling ladder slots each time.

Remaining risk:

- Staging visuals still use the spawner's existing horizon point helper until the next wave/director handoff task.

## P1-009 — Expand Siege Director Responsibilities

Files changed:

- `scripts/enemy/siege_director.gd`
- `scripts/enemy/wave_spawner.gd`
- `test/wave_spawner_test.gd`
- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Added director-owned high-level roles for gate engines, archer cover, wall assault, ladder carriers, and ladder escorts.
- Added director tactical orders for normal units, ladder crew plans, carrier starts, and escort cover routes.
- Simplified `WaveSpawner` so it creates units and applies orders instead of duplicating ladder/role decisions.
- Added tests for role assignment and ladder crew order generation.

Validation:

- `git diff --check` passed.
- `make test-target TEST=res://test/wave_spawner_test.gd` passed: 8 test cases, 0 failures.
- `make import` passed with existing duplicate UID, missing UID, case mismatch, and cleanup warnings.

Behavior changes:

- Enemy roles are now assigned consistently through `SiegeDirector`, which keeps tactical decisions out of per-spawn code.

Remaining risk:

- Wall and ladder brains still own local target/ladder selection until hysteresis and routing follow-ups.

## P1-010 — Add Reassignment Hysteresis

Files changed:

- `scripts/enemy/wall_assault_brain.gd`
- `scripts/enemy/ladder_assault_brain.gd`
- `scripts/ally/defender_targeting.gd`
- `test/enemy_test.gd`
- `test/ally_test.gd`
- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Added cooldown-based sticky defender selection for wall assault units.
- Added cooldown-based sticky active ladder selection so enemies stop bouncing between nearby ladders.
- Added defender archer target stickiness while preserving order-mode changes and range checks.
- Added deterministic tests for wall defender, ladder, and ally target reassignment.

Validation:

- `git diff --check` passed.
- `make test-target TEST=res://test/enemy_test.gd` passed: 21 test cases, 0 failures.
- `make test-target TEST=res://test/ally_test.gd` passed assertions: 17 test cases, 0 failures, then exited 101 with the existing orphan/resource cleanup leak.
- `make import` passed with existing duplicate UID, missing UID, case mismatch, and cleanup warnings.

Behavior changes:

- Units now change objectives less often; they only switch quickly when the new option is meaningfully better or the current one is invalid.

Remaining risk:

- The cooldown values are conservative defaults and may need tuning after a crowded-wave playtest.

## P1-011 — Introduce WaveDefinition Resources

Files changed:

- `scripts/enemy/wave_definition.gd`
- `scripts/enemy/wave_spawner.gd`
- `data/wave_01.tres`
- `data/wave_02.tres`
- `data/wave_03.tres`
- `data/wave_04.tres`
- `scenes/play.tscn`
- `test/wave_spawner_test.gd`
- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Added resource-driven wave definitions for counts, pacing, auto-start delay, and staging layout.
- Added four default wave resources matching the previous script-generated compositions.
- Wired `scenes/play.tscn` to use the default wave resources.
- Kept the old exported `waves` array as fallback for compatibility.

Validation:

- `git diff --check` passed.
- `make test-target TEST=res://test/wave_spawner_test.gd` passed: 9 test cases, 0 failures.
- `make import` passed with existing duplicate UID, missing UID, case mismatch, and cleanup warnings.

Behavior changes:

- Wave tuning can now happen in `.tres` resources without editing `WaveSpawner`.

Remaining risk:

- The current resources intentionally preserve the old balance; future tuning can change count/pacing per wave.

## P1-012 — Normalize Unit Profile Resources

Files changed:

- `scripts/characters/unit_stats.gd`
- `scripts/enemy/enemy.gd`
- `scripts/ally/ally_archer.gd`
- `scripts/player/fps_bow_player.gd`
- `data/ally_archer.tres`
- `data/enemy_archer.tres`
- `data/enemy_bossram.tres`
- `data/enemy_infantry.tres`
- `data/enemy_ladder_orc.tres`
- `data/enemy_ram.tres`
- `data/player_hero.tres`
- `test/enemy_test.gd`
- `test/ally_test.gd`
- `test/player_progression_test.gd`
- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Added `behavior_tags` to shared unit profiles.
- Added decision/refresh intervals to `UnitStats` for target refresh, avoidance, wall pressure, and ladder search tuning.
- Wired enemies and allied archers to use profile-driven refresh values.
- Exposed behavior tags on player, ally, and enemy runtime nodes.

Validation:

- `git diff --check` passed.
- `make test-target TEST=res://test/enemy_test.gd` passed: 21 test cases, 0 failures.
- `make test-target TEST=res://test/player_progression_test.gd` passed: 1 test case, 0 failures.
- `make test-target TEST=res://test/ally_test.gd` passed assertions: 17 test cases, 0 failures, then exited 101 with the existing orphan/resource cleanup leak.
- `make import` passed with existing duplicate UID, missing UID, case mismatch, and cleanup warnings.

Behavior changes:

- No balance change intended; current resource values match the old hard-coded defaults unless a unit preset overrides them.

Remaining risk:

- Specialized enemy archers still have a small subclass-specific ranged setup and can be normalized further in a later pass.

## P1-016 — Add Fortress Validation Tool

Files changed:

- `scripts/castle/scene_validator.gd`
- `scripts/castle/fortress_generator.gd`
- `test/fortress_navigation_test.gd`
- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Extended `SceneValidator` beyond physics ray probes to validate fortress model data.
- Added checks for required semantic regions, ladder slot metadata, tactical slot kinds, navigation edge endpoints, navigation links, and navigation meshes.
- Added fortress scene coverage that fails with a concrete issue list when generated AI/navigation data is incomplete.
- Filtered generated ladder slots whose wall top is not above the field foot, so AI cannot reserve impossible ladders.

Validation:

- `git diff --check` passed.
- `make test-target TEST=res://test/scene_validator_test.gd` passed: 1 test case, 0 failures.
- `make test-target TEST=res://test/fortress_navigation_test.gd` passed: 1 test case, 0 failures.
- `make import` passed with existing duplicate UID, missing UID, case mismatch, and cleanup warnings.

Behavior changes:

- Invalid generated ladder slots are now skipped before enemies can reserve them.

Remaining risk:

- Route reachability remains graph-level work for P1-017.

## P1-017 — Add Navigation Scenario Tests

Files changed:

- `scripts/castle/fortress_generator.gd`
- `test/fortress_navigation_test.gd`
- `docs/refactoring_backlog.md`
- `docs/refactoring_log.md`

Summary:

- Added scene-backed graph route tests for ground-to-ladder, wall-to-tower, wall-to-gate, gate-to-keep, and wall-to-keep movement.
- Added explicit stair-to-wall connectors so ladder and wall-walk positions join the generated graph instead of relying on near-distance guesses.
- Added explicit courtyard connectors from outer stair feet to the causeway and from the causeway top to the keep ground entry.
- Reused the generated `CastleModel` slots as route landmarks, so the tests follow the actual fortress data used by AI.

Validation:

- `git diff --check` passed.
- `make test-target TEST=res://test/fortress_navigation_test.gd` passed: 2 test cases, 0 failures.

Behavior changes:

- Units that reach the wall now have graph routes onward to tower/gate/keep landmarks instead of receiving empty paths.

Remaining risk:

- P0 graph/API cleanup should still replace broad local graph jumps with a cleaner authored connection API.
