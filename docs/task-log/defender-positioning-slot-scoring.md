# Defender positioning slot scoring

Date: 2026-07-28

## Summary

Added the first slice of `DefenderAI` positioning: a `DefenderPositioning` component that scores generated archer slots from `CastleModel` and picks a slot with real line of sight to the current target.

`AllyArcher` still keeps its existing tactical logic, but when it needs to reposition after blocked/no LOS shooting it now tries a scored castle slot before falling back to local offset probing.

## Problem

Archer repositioning was local and reactive:

- test small offsets around the current position;
- raycast LOS from those offsets;
- move toward the best offset.

That can work for tiny corrections, but it does not understand the castle layout. When an archer is too far from the wall, inside a gatehouse, or blocked by masonry, local offset guessing can leave them stuck or shooting into stone.

## Implementation

### Files modified

1. `scripts/ally/defender_positioning.gd` — new slot scoring component.
2. `scripts/ally/ally_archer.gd` — creates `DefenderPositioning` and tries scored `CastleModel.archer_slots()` before local offset fallback.

## Scoring rules

Current slot scoring rewards:

- real line of sight from slot muzzle to target;
- shorter travel distance from current archer position;
- reasonable distance from slot to target;
- gate-area bonus when the target is near the gate;
- unoccupied slots using active allies from `CombatRegistry`.

Current slot scoring rejects:

- slots already reserved by another unit;
- slots occupied by another active ally;
- slots farther than the initial safe search distance;
- slots with no world-raycast line of sight to the target.

## Key details

- This is not yet a full `DefenderBrain`.
- Shooting and target selection still live in `AllyArcher`.
- The local `_find_firing_position()` offset fallback remains for close corrections.
- The component reads `CastleModel.archer_slots()` first and falls back to `castle_tactical_slot_archer` group scanning only if needed.
- This moves the project away from hardcoded archer positions and toward dynamic castle-driven positioning.

## Validation

Full `make test` intentionally not run during this step; the user wants it only at the end.

Controlled scene smoke:

```text
/opt/homebrew/bin/godot --headless --path . -s /tmp/mountainhold_smoke_quit.gd
fortress: base=15.2, 124 modules
ally_placer: placed 20 archers from CastleModel + fallback
controlled smoke ok
```

Ally locomotion probe:

```text
/opt/homebrew/bin/godot --headless --path . -s /tmp/mountainhold_ally_locomotion_probe.gd
allies=20 missing_locomotion=0 bad_y=0 nav_reported=18
ally locomotion probe ok
```

Positioning probe:

```text
/opt/homebrew/bin/godot --headless --path . -s /tmp/mountainhold_positioning_probe.gd
positioning checked=8 found=8
positioning probe ok
```

Known Godot shutdown ObjectDB/RID leak warnings still appear in headless runs and are not new to this change.
