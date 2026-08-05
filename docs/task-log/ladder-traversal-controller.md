# Ladder traversal controller

Date: 2026-07-28

## Summary

Added a shared `TraversalController` for ladder climbing and moved enemy ladder traversal through that controller.

The goal is to keep ladder movement as one explicit traversal state instead of two separate hand-written interpolations in `Enemy` and `LadderOrcEnemy`.

## Problem

Ladder climbing previously existed in two places:

- `Enemy._continue_ladder_climb()` interpolated directly from `_climb_from` to `_climb_to`.
- `LadderOrcEnemy._physics_process()` had a separate `_climbing` branch that directly interpolated from `_climb_from` to `_ladder_top`.

That duplication made it easier for enemies to climb beside ladders, keep stale reservations, or finish traversal without validating that the wall-top landing was a real surface.

## Implementation

### Files modified

1. `scripts/core/traversal_controller.gd` — new shared controller for explicit traversal states.
2. `scripts/enemy/enemy.gd` — creates `TraversalController`, starts ladder traversal through it, handles completion/failure.
3. `scripts/enemy/ladder_orc_enemy.gd` — removes local climb interpolation and delegates carrier/helper climbing to the base ladder traversal.
4. `scripts/enemy/siege_ladder.gd` — updates climber pruning to understand both the legacy climb flag and the controller state.

## Key details

- `TraversalController.start_ladder()` validates the ladder segment before movement starts.
- Landing is raycast against the world collision layer near the wall-top endpoint.
- The controller owns releasing the ladder reservation on finish or failure.
- `Enemy._climbing_ladder` remains as a compatibility state for existing ladder queue/prune logic.
- `LadderOrcEnemy._climbing` remains as a local behavior flag, but no longer performs direct position interpolation.
- If a carrier cannot reserve climb capacity, it queues near the ladder and retries instead of standing forever at the deploy point.

## Validation

Full `make test` intentionally not run during this step; the user wants it only at the end.

Short scene smoke:

```text
timeout 8 /opt/homebrew/bin/godot --headless --path . scenes/play.tscn --quit-after 180
fortress: base=15.2, 124 modules
ally_placer: placed 20 archers from CastleModel + fallback
```

Scene traversal probe:

```text
/opt/homebrew/bin/godot --headless --path . -s /tmp/mountainhold_traversal_probe.gd
active_ladders=1
registry={ "enemies": 16, "allies": 20, "rams": 0, "ladders": 1, "player": true }
traversal probe ok
```

Deterministic controller probe:

```text
/opt/homebrew/bin/godot --headless --path . -s /tmp/mountainhold_traversal_unit_probe.gd
traversal unit probe ok landing=(4.0, 8.32, 0.0)
```

Known Godot shutdown ObjectDB/RID leak warnings still appear in headless runs and are not new to this change.
