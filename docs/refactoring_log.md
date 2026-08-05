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
