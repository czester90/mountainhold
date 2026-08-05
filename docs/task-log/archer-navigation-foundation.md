---
title: "Task: Archer navigation foundation"
type: task-history
scope: fullstack
status: completed
created: 2026-07-27
sources: [local-request]
tags: [godot, navigation, ally-ai]
---

# Archer navigation foundation

**Task:** local-request · **Type:** refactor

## Description

Start replacing brittle archer movement with a physics-aware navigation foundation. The immediate
goal is to stop moving defenders by raw position assignment and make future navmesh/link work
observable in-game.

## Implementation summary

### Files modified

1. **scenes/ally/ally_archer.tscn** — changed the root node to `CharacterBody3D`.
2. **scripts/ally/ally_archer.gd** — added character collision, `NavigationAgent3D`, debug state,
   `move_and_slide()` movement, a native navigation driver attempt, and no-surface blocking instead
   of vertical flying.
3. **scripts/ui/developer_panel.gd** — shows ally navigation state counts in the F3 debug overlay.
4. **scripts/test/archer_range.gd** — keeps archer combat tests local to their scene and
   deterministic.
5. **scripts/castle/scene_validator.gd** — validates modular walk surfaces with a small tolerance
   instead of one brittle ray point.
6. **test/ally_test.gd** — locks the new movement foundation with a regression test.
7. **test/archer_scene_test.gd** — avoids global enemy cleanup across scene-runner instances.
8. **scripts/ui/main_menu.gd** — avoids absolute-path audio lookup from a detached UI callback.
9. **scripts/ui/game_over.gd**, **scripts/ui/settings_panel.gd**, **scripts/ui/pause_menu.gd** —
   use the same safe UI click lookup.
10. **scripts/castle/fortress_generator.gd** — emits real `NavigationLink3D` nodes next to the
    existing fallback edge metadata and builds a first `NavigationRegion3D` from simple walk-strip
    polygons; also emits tactical gate/keep slots.
11. **test/fortress_navigation_test.gd** — asserts generated navigation links and the navigation
    region exist.
12. **scripts/ally/defender_orders.gd** — reserves generated tactical slots before falling back to
    legacy rally rows.
13. **test/defender_orders_test.gd** — locks slot reservation behavior.

### Key details

- The current route graph remains a temporary fallback.
- Ordered movement keeps `NavigationAgent3D` available, but uses the fallback graph/surface walker
  by default until the generated navmesh is stable enough for production movement.
- Archers now have real collision on their root body instead of a child `StaticBody3D`.
- Vertical-only movement no longer changes `global_position.y`, which prevents the worst floating
  behavior until explicit `NavigationLink3D` transitions are implemented.
- F3/Tab debug output reports states like `moving`, `blocked`, `stuck`, and `no_surface`.
- F3/Tab also reports whether archers are using the `native` or `fallback` navigation driver.
- F3/Tab reports tactical slot reservations so gate/keep command pressure is visible.
- Test helpers now avoid global group leakage between scene-runner instances.
- UI click sounds now use `get_tree().root.get_node_or_null("Audio")` only after checking
  `is_inside_tree()`.
- Castle nav edges now also produce `castle_navigation_link` nodes, which is the next bridge toward
  Godot-native navmesh/link traversal.
- The first generated `CastleNavigationRegion` is intentionally simple: it turns horizontal module
  edges into walkable strips and leaves vertical movement to explicit links.
- Gate and keep orders now prefer generated `castle_tactical_slot_*` markers, which is the bridge
  toward dynamic, module-owned defender placement.
- Follow-up audit found the gate tactical slots were using `GatehouseDefinition.thickness` as if it
  were `GateTower` local depth. That pushed defend-gate destinations into invalid/awkward places
  around the brama. Gate slots now ask `GateTower` for module-owned field-side slot depths.
- The experimental native navigation driver is disabled by default on archers, so it cannot fight
  the fallback walker and cause visible jitter until navmesh/link coverage is proven.
- Enemy gate damage is now siege-engine-only: infantry and enemy archers hold at the closed gate
  instead of damaging it, while ladder orcs always use wall-ladder routes.
- Ladder-orc pressure increased from `4 + wave * 3` to `7 + wave * 5`, and ladder spawns cycle
  through multiple lanes on both gate flanks to avoid two permanently clogged ladder points.

### 2026-07-28 ladder siege pass

- Added wall-owned `castle_ladder_slot` markers from generated wall modules, so ladder attack lanes
  follow the current castle layout instead of hardcoded gate-only points.
- Added `SiegeLadder`, a deployed ladder node with health, queue points, climb capacity, and an
  enemy-only `NavigationLink3D` between ground and wall top.
- Reworked ladder orcs into four-unit carrier crews: the leader plants one long ladder only after
  enough carriers arrive, and carriers are tougher while transporting it.
- Changed normal infantry behavior so closed gates are no longer their attack target; after a ladder
  is active, non-carrier orcs queue at it and climb onto the wall to fight defenders/player units.
- Expanded wave composition from single ladder orcs to escalating ladder crews distributed across
  available wall slots.

## Testing notes

Run:

```bash
make test-target TEST=res://test/ally_test.gd
make test
```

Manual check:

- Run `make play`.
- Press `F3` or `Tab` to show navigation state counts.
- Press `4` and `5` during a siege and confirm archers no longer fly vertically when a route is
  missing.

## Links

- Research: `docs/research/archer_navigation_research.md`
- Ladder siege research: `docs/research/ladder_siege_navigation_research.md`
