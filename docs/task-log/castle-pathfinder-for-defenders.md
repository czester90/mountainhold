# Castle pathfinder for defenders

Date: 2026-07-28

## Summary

Added `CastlePathfinder`, a shared helper that routes between castle navigation edges from `CastleModel`.

Friendly archers now use this helper for dynamic routes and for movement toward scored firing slots, instead of relying only on direct local surface walking.

## Problem

`AllyArcher` had its own embedded mini pathfinder over `castle_navigation_edge` groups. That kept navigation logic inside the archer monolith and made firing-slot repositioning too local: when a good slot was far away or on a different height, the archer tried to surface-walk directly toward it.

## Implementation

### Files modified

1. `scripts/castle/castle_pathfinder.gd` — new helper that reads `CastleModel.navigation_edges` first and falls back to edge groups.
2. `scripts/ally/ally_archer.gd` — creates `CastlePathfinder`, delegates `_dynamic_route_to()`, and routes long/high firing-slot repositioning through `_reposition_path`.

## Key details

- This does not enable full native `NavigationAgent3D` for all archers.
- The existing local surface walker remains as fallback for short moves and final corrections.
- Routes are based on generated castle edges, so they adapt better when the castle model changes.
- Firing-slot movement now uses route waypoints when the slot is far away or on a different height.
- Existing hardcoded emergency route methods still remain and should be removed only after more probes/manual testing.

## Validation

Full `make test` intentionally not run during this step; the user wants it only at the end.

Controlled scene smoke:

```text
/opt/homebrew/bin/godot --headless --path . -s /tmp/mountainhold_smoke_quit.gd
controlled smoke ok
```

Castle path probe:

```text
/opt/homebrew/bin/godot --headless --path . -s /tmp/mountainhold_castle_path_probe.gd
castle_path checked=8 routed=8
castle path probe ok
```

Defender debug probe:

```text
/opt/homebrew/bin/godot --headless --path . -s /tmp/mountainhold_defender_debug_probe.gd
DefAI target:19 los:14 slot:12 | no_los:4, cooldown:15, no_target:1
defender debug probe ok snapshots=20
```

Order route probe:

```text
/opt/homebrew/bin/godot --headless --path . -s /tmp/mountainhold_order_route_probe.gd
order_route allies=20 pathfinder=20 moving_states=6 bad_y=0
order route probe ok
```

Known Godot shutdown ObjectDB/RID leak warnings still appear in headless runs and are not new to this change.
