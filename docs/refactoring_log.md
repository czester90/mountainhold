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
