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
