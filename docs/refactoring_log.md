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
