# World collision and falling units research

Date: 2026-07-28

## Problem

Units sometimes fall through the world, disappear from view while still being counted by the HUD/minimap, or recover only after already dropping far below the terrain. This is not a single enemy AI bug. The current world-ground contract is inconsistent:

- Spawning and lane validation often use terrain height data.
- Runtime movement depends on physics collision.
- Some terrain positions have height data but no world-layer collision hit.
- Enemy subclasses can override `_physics_process`, which risks bypassing shared safety checks.

## External findings

Official Godot guidance points to this model:

- `CharacterBody3D` should be moved with `move_and_slide()` using velocity in units per second; floor classification depends on `up_direction`, `floor_max_angle`, `floor_snap_length`, and recovery depends on `safe_margin`.
- Collision only works when physics bodies own direct `CollisionShape3D` children. Indirect collision shapes are ignored.
- Dynamic bodies such as `CharacterBody3D` should use primitive collision shapes for reliability and performance.
- Concave/trimesh collision is suitable for static level collision, but not for `CharacterBody3D`/`RigidBody3D`.
- Navigation agents do not move characters and do not replace physics. The parent must move each physics frame, and avoidance is separate from world collision/navigation.
- Terrain3D dynamic collision can generate collision only around the camera, so off-camera/spawn-side terrain must be explicitly verified if units spawn or walk there.

Sources:

- Godot `CharacterBody3D`: https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html
- Godot physics introduction: https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html
- Godot 3D collision shapes: https://docs.godotengine.org/en/latest/tutorials/physics/collision_shapes_3d.html
- Godot NavigationAgents: https://docs.godotengine.org/en/latest/tutorials/navigation/navigation_using_navigationagents.html
- Terrain3D dynamic collision overview: https://80.lv/articles/godot-engine-s-terrain3d-received-dynamic-collision-mode

## Local evidence

### Terrain height does not equal physics ground

Runtime probe against `res://scenes/play.tscn` using a world-layer raycast (`1 << 0`) found:

```text
p=(248, 0, 500) terrain_h=14.54 ray_hit=true  hit_y=14.54
p=(248, 0, 524) terrain_h=14.14 ray_hit=true  hit_y=14.14
p=(253, 0, 536) terrain_h=14.23 ray_hit=false hit_y=none
p=(252, 0, 532) terrain_h=14.34 ray_hit=false hit_y=none
p=(252, 0, 528) terrain_h=14.55 ray_hit=true  hit_y=14.55
p=(320, 0, 549) terrain_h=37.75 ray_hit=false hit_y=none
```

This proves the main failure: a valid terrain height can exist where physics has no floor. If an enemy spawns or gets assigned a ladder lane there, `CharacterBody3D` will fall. The later recovery code can hide the failure, but it does not make the lane valid.

### Current code paths

- `scripts/enemy/wave_spawner.gd` uses `_ground()` as `_terrain.base()` for all normal enemy spawns.
- `scripts/enemy/wave_spawner.gd` validates ladder lanes using `TerrainModule.height()` samples, not physics raycasts.
- `scripts/enemy/wave_spawner.gd` clamps ladder spawn anchors to wide `z` lanes, including areas where physics collision is missing.
- `scripts/enemy/enemy.gd` has a shared fall recovery based on world-layer raycasts.
- `scripts/enemy/ladder_orc_enemy.gd` duplicates `_physics_process`, so shared movement safety must either be repeated or centralized.
- `scripts/castle/modules/castle_module.gd` already uses proper static ramp collision for generated ramps.
- `scripts/castle/modules/castle_module.gd` uses `create_trimesh_collision()` for static castle meshes; this is acceptable for static level collision but should not be used on dynamic actors.

## Root causes

1. **Spawn placement trusts height data instead of physics.** Units can be created above locations where the physics world has no floor.
2. **Ladder slot accessibility ignores world collision.** A lane can pass height checks while still being physically invalid.
3. **Terrain3D collision coverage is not guaranteed across attack lanes.** The current scene uses Terrain3D collision, but probes show missing collision near some north/far-side lane coordinates.
4. **Safety checks are fragmented.** `Enemy` has fall recovery, but specialized enemies with their own `_physics_process` can drift from the base safety contract.
5. **Navigation/AI is mixed with manual transforms.** Teleports, direct `global_position` edits, and height snapping should be limited to explicit state transitions, never used as normal movement.

## Correct architecture

### Ground contract

Create one authoritative `GroundResolver` service or spawner helper:

- `raycast_ground(x, z)` checks world-layer collision from above.
- `find_nearest_valid_ground(point)` searches nearby offsets if the requested point has no physics floor.
- `spawn_position(point, height_offset)` returns only a physically valid spawn point.
- `is_walkable_world_sample(point)` validates lane samples by physics raycast, not only by height data.

Rules:

- Spawns fail over to the nearest valid physics ground, not to `TerrainModule.height()` alone.
- Ladder lanes are reserved only if all approach samples have physics ground.
- Terrain height can remain a visual/helper fallback, but never the primary proof that a unit can stand there.

### Character movement contract

All characters should follow the same structure:

- `CharacterBody3D` owns primitive collision shapes.
- Movement happens through `velocity` + `move_and_slide()`.
- Gravity and floor snap are applied consistently.
- Shared fall/burial recovery runs before specialized AI logic.
- Specialized enemies override a virtual tick method, not raw `_physics_process`.

### World collision contract

- Terrain uses Terrain3D collision where it is actually present.
- Castle walls, stairs, ramps, gate, tower floors, and walkable bridges use explicit `StaticBody3D` collision.
- Concave/trimesh collision stays static-only and should be simplified for gameplay-critical paths.
- Debug tooling should flag every active unit with no world raycast below it.

## Implementation plan

1. Add a physics-ground resolver in `WaveSpawner` or a dedicated script.
2. Replace `_ground()`-based enemy spawns with validated raycast spawn positions.
3. Update ladder lane reservation to reject slots whose approach samples have no world collision.
4. Clamp/search ladder spawn anchors to nearby valid physical ground instead of broad fixed `z` clamps.
5. Centralize enemy fall/burial checks so ladder orcs and future enemy types cannot bypass them.
6. Add a dev-only collision audit print/probe for alive enemies, inactive enemies, and “no floor below” units.
7. Later, audit/generated castle modules for missing explicit `StaticBody3D` walk surfaces on stairs, towers, walls, and keep paths.

## Acceptance checks

- No alive enemy has `global_position.y < -8`.
- No alive enemy is counted by HUD/minimap while inactive or below terrain.
- Every spawned enemy starts above a world-layer raycast hit.
- Every ladder crew target lane has valid physics ground along approach samples.
- No normal unit movement uses `global_position +=` except controlled scripted transitions such as ladder climbing or death animation.
