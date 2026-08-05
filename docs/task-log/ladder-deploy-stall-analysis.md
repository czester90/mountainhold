# Ladder deploy stall analysis

Date: 2026-07-28

## Summary

Player screenshots `res://screenshots/player/shot_073.png` and `res://screenshots/player/shot_074.png` showed ladder crews apparently standing in front of the wall with long ladders visible, but no obvious wall climb happening.

The visible ladders in those screenshots can be the carried ladder visuals, not necessarily deployed `SiegeLadder` nodes. Runtime probes confirmed that before the fix the crews could reach the last path target and then never deploy.

## Root cause

`LadderOrcEnemy._physics_process()` had an exact deploy condition:

```gdscript
_wp == path.size() - 1
```

but the generic waypoint advance logic still ran near the final target:

```gdscript
elif dist <= 2.5:
    _wp += 1
```

This allowed `_wp` to grow beyond the last valid waypoint before the tighter deploy radius (`2.2`) was met. Once that happened, the exact deploy condition could never be true again.

Probe evidence before the fix:

```text
active_ladders=0
crew=1 wp=1464 target_dist=2.5 foot_dist=3.9 ready=2 carrying=true deployed=false climbing=false
crew=4 wp=1373 target_dist=2.5 foot_dist=4.0 ready=2 carrying=true deployed=false climbing=false
```

So crews had enough carriers to deploy, but the state machine had skipped past the valid final waypoint.

## Fix applied

- Treat any `_wp >= path.size() - 1` as being at the final waypoint.
- Clamp normal waypoint advancement with `mini(_wp + 1, path.size() - 1)`.
- Check ladder deploy at the final waypoint before any generic path advancement.
- Slightly loosen the deploy radius to `2.8`, because the formation target is offset from the exact ladder foot.

Probe evidence after the fix:

```text
active_ladders=4
crew=1 carrying=false deployed=true climbing=false
crew=2 carrying=false deployed=true climbing=false
crew=3 carrying=false deployed=true climbing=false
crew=4 carrying=false deployed=true climbing=false
```

At the same checkpoint, carriers had reached wall-height positions (`y ~= 21`) after climbing.

## Remaining risks

- The current carried ladder visual can look like a deployed ladder before the deploy state is actually active.
- Helpers currently work for free `LadderOrcEnemy` units, but not generic infantry. If design requires any free orc to help, a separate helper role/state should be added to `Enemy` or a proper `LadderCrew` controller.
- `LadderOrcEnemy` still owns too much state itself. Long-term, ladder deployment should move into a dedicated `LadderCrew` controller as described in `docs/research/ladder_siege_navigation_research.md`.

## Follow-up: ladder not visibly seated on the wall

Screenshots showed that even when a ladder state became active, the visible ladder did not reliably look seated on the wall. A geometry probe found the cause:

```text
top_down_hit=false at top
top - normal * 1.6 down_hit=true
```

The generated slot top was on the outer edge/air, while the actual walkable collision was slightly inward on the wall-walk. The spawner now resolves the top endpoint by raycasting candidate landing points inward from the slot.

Final probe after the fix:

```text
active_ladders=4
SiegeLadder_1 top_down_hit=true line_hits_wall=true angle=48.2
SiegeLadder_2 top_down_hit=true line_hits_wall=true angle=44.2
SiegeLadder_3 top_down_hit=true line_hits_wall=true angle=48.2
SiegeLadder_4 top_down_hit=true line_hits_wall=true angle=52.5
```

The carrying formation target was also moved several meters away from the wall. Previously carriers tried to path their capsules almost into the wall base and could stall before deployment.

## Follow-up: enemies climbing beside ladders

Screenshots `shot_075` through `shot_078` showed some enemies rising beside the ladder, as if walking through the air. The cause was that climb interpolation started from each enemy's current world position:

```gdscript
_climb_from = global_position
```

If a carrier or queued enemy stood beside the ladder foot, the climb line was from that side position directly to the wall top. The climb now starts from the active ladder foot for both ladder carriers and normal enemies using `SiegeLadder`.

Validation probe:

```text
active_ladders=4
climbers=7
max_dist_to_ladder=0.31
ally_fire=true
```

## Follow-up: ladders drifting onto towers

Some ladder crews appeared to place ladders on tower geometry. The generator was already creating ladder slots from wall modules, but two details made this unsafe:

- slots were emitted near wall segment ends, close to tower/gate junctions;
- `WaveSpawner` later applied a crew lateral offset directly to `foot` and `top`, pushing a valid wall slot sideways toward tower geometry.

Fixes:

- ladder slots are now generated inside the wall span, not at segment endpoints;
- ladder slots are marked with `ladder_surface = "wall"`;
- the spawner ignores non-wall ladder slots;
- crew lateral offsets no longer move ladder endpoints.

Validation probe:

```text
usable_slots=8
active_ladders=4
all active ladders: top_down_hit=true, line_hits_wall=true
```

## Validation

Validation was done with headless scene/probe runs only. `make test` was not run.
