# Enemy unit locomotion foundation

Date: 2026-07-28

## Summary

Added a minimal `UnitLocomotion` component and connected enemy movement to it without changing the higher-level AI state machine.

This is the first safe slice of the broader locomotion refactor: movement execution is shared, while targeting, waypoint choices, stuck recovery and step assist remain in `Enemy`.

## Problem

Enemy movement had repeated local blocks:

- set `velocity.x/z`;
- apply gravity/floor stickiness;
- call `move_and_slide()`;
- rotate toward movement direction.

The same pattern existed in normal path following, wall movement, ladder queue movement and combat idle states. That makes future fixes to jitter/collision/recovery risky because every local block needs to be changed consistently.

## Implementation

### Files modified

1. `scripts/core/unit_locomotion.gd` — new shared component for directional movement, idle movement and stop.
2. `scripts/enemy/enemy.gd` — creates `UnitLocomotion`, routes normal movement/idle/attack-idle through it.
3. `scripts/enemy/ladder_orc_enemy.gd` — routes ladder crew walking and ladder queue movement through inherited locomotion methods.

## Key details

- This does not enable full `NavigationAgent3D`.
- This does not change waypoint selection or siege strategy.
- Stuck recovery stays in `Enemy` for now, using pre/post movement around the component call.
- Fallback movement remains in `_move_direction()` if the component is missing in an isolated test scene.
- The step-assist nudge for gate/causeway thresholds remains untouched because it needs a separate pass; it is still visible as a controlled legacy path.

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
registry summary={ "enemies": 9, "allies": 20, "rams": 0, "ladders": 0, "player": true }
registry probe ok
```

Traversal probe after locomotion change:

```text
/opt/homebrew/bin/godot --headless --path . -s /tmp/mountainhold_traversal_probe.gd
active_ladders=1
registry={ "enemies": 18, "allies": 20, "rams": 0, "ladders": 1, "player": true }
traversal probe ok
```

Known Godot shutdown ObjectDB/RID leak warnings still appear in headless runs and are not new to this change.
