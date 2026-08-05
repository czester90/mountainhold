# Ally unit locomotion foundation

Date: 2026-07-28

## Summary

Connected friendly archers to the shared `UnitLocomotion` component.

This keeps the existing archer AI, slot selection, fallback surface probing and LOS behavior intact, while moving the actual `CharacterBody3D` velocity/gravity/slide execution into the same component used by enemies.

## Problem

`AllyArcher` still had its own movement execution:

- write horizontal velocity;
- apply gravity/floor stickiness;
- call `move_and_slide()`;
- do local step assist and stuck tracking around that.

That meant enemies and defenders were starting to diverge again even after the enemy locomotion foundation.

## Implementation

### Files modified

1. `scripts/ally/ally_archer.gd` — creates `UnitLocomotion` and routes `_apply_character_velocity()` through it.
2. `scripts/ally/ally_archer.gd` — updates separation/overlap scoring to use `CombatRegistry` active units when available.

## Key details

- This does not enable native navigation for all archers.
- This does not rewrite archer tactical decisions.
- Existing step-assist in `_move_character()` remains as a controlled legacy fallback.
- Existing stuck/recovery counters remain unchanged.
- Separating from units now ignores dead/hidden/out-of-world units when `CombatRegistry` exists.

## Validation

Full `make test` intentionally not run during this step; the user wants it only at the end.

Short scene smoke:

```text
timeout 8 /opt/homebrew/bin/godot --headless --path . scenes/play.tscn --quit-after 180
fortress: base=15.2, 124 modules
ally_placer: placed 20 archers from CastleModel + fallback
```

Registry probe:

```text
/opt/homebrew/bin/godot --headless --path . -s /tmp/mountainhold_registry_probe.gd
registry summary={ "enemies": 7, "allies": 20, "rams": 0, "ladders": 0, "player": true }
registry probe ok
```

Ally locomotion probe:

```text
/opt/homebrew/bin/godot --headless --path . -s /tmp/mountainhold_ally_locomotion_probe.gd
allies=20 missing_locomotion=0 bad_y=0 nav_reported=19
ally locomotion probe ok
```

Known Godot shutdown ObjectDB/RID leak warnings still appear in headless runs and are not new to this change.
