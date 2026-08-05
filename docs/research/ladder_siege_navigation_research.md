# Ladder siege navigation research

Date: 2026-07-28

## Task summary

Replace the current single-orc scripted ladder with a proper siege ladder system:

- one long ladder reaches the wall walk;
- a ladder is carried by a crew of four ladder orcs;
- the carrying crew is harder to kill while the ladder is carried;
- ladders can target the full width of the outer wall, not only the gate flanks;
- non-carrier orcs can use placed ladders to climb onto the wall;
- the system should use Godot navigation/physics primitives instead of hardcoded teleport-like movement.

## Prior knowledge found

- `docs/research/archer_navigation_research.md` already identifies `NavigationAgent3D`,
  `NavigationRegion3D`, and `NavigationLink3D` as the correct foundation for castle movement.
- `docs/task-log/archer-navigation-foundation.md` records that the project currently has a simple
  `CastleNavigationRegion`, `castle_navigation_link` metadata, and tactical slot markers, but native
  movement is still not stable enough to be the only driver.
- The current implementation intentionally made gate damage siege-engine-only. This fits the new
  requirement: ladder orcs should be a wall breach threat, not a gate damage source.

No relevant cross-repo memory entry exists for `mountainhold`, `ladder`, `orc`, or Godot navigation.

## External documentation

Official Godot documentation points to the right model:

- `NavigationAgent3D` requires navigation data, and after setting `target_position`,
  `get_next_path_position()` must be called once per physics frame. Avoidance is computed before
  physics and can provide safe velocities for crowded movement.
- `NavigationLink3D` is explicitly intended for connections such as ladders, jump pads, and
  teleports. A link connects two navigation mesh positions, but game code must still provide the
  special movement through the link, e.g. climbing animation/motion.
- Navigation meshes must be baked/shrunk with `agent_radius` so planned paths respect agent size.
  Godot navigation is independent from physics/visual meshes; if the navmesh says a center point is
  walkable, physics collisions are still separate.
- Avoidance does not change pathfinding. It is useful for moving crowds, but narrow ladder queues
  need explicit reservations/queues.
- Navigation mesh chunk connections are fragile when edges are misaligned or overlapping; explicit
  links are safer for modular walls and ladders.
- `NavigationObstacle3D` can influence avoidance and baking, but dynamic obstacles are not reliable
  as the only way to manage crowded narrow spaces.
- `CharacterBody3D.move_and_slide()` is the correct Godot-side movement primitive for physically
  controlled characters that should collide with walls/floors.

Sources:

- https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html
- https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationlinks.html
- https://docs.godotengine.org/en/latest/tutorials/navigation/navigation_using_navigationmeshes.html
- https://docs.godotengine.org/en/latest/tutorials/navigation/navigation_using_navigationagents.html
- https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_connecting_navmesh.html
- https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationobstacles.html
- https://docs.godotengine.org/en/4.7/getting_started/first_3d_game/03.player_movement_code.html

## Online implementation patterns

### 1. Ladders are an off-mesh traversal, not ordinary walking

This pattern is consistent across Godot, Unity, and Unreal:

- Godot `NavigationLink3D` connects navigation mesh polygons over arbitrary distance and is directly
  documented as useful for gameplay shortcuts such as ladders, jump pads, and teleports.
- Unity AI Navigation describes Off-Mesh/NavMesh links as routes that cross outside the walkable
  navmesh surface, such as jumps, fences, and doors.
- Unreal Navigation Links / NavLink Proxy actors solve the same class of problem: connect areas
  that are not physically walkable as one continuous surface.

Implementation implication for Mountainhold:

- A planted ladder should create an enemy-only `NavigationLink3D` from ground to wall top.
- The link makes pathfinding aware that the wall is reachable.
- The actual climb must still be a custom movement state, because a link is not a ladder animation
  or physics constraint by itself.

Relevant sources:

- Godot NavigationLinks: https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationlinks.html
- Godot NavigationLink3D class: https://docs.godotengine.org/en/stable/classes/class_navigationlink3d.html
- Unity Off-Mesh Link: https://docs.unity3d.com/Packages/com.unity.ai.navigation@2.0/manual/CreateOffMeshLink.html
- Unreal Navigation Link Generation: https://dev.epicgames.com/documentation/unreal-engine/automatic-navigation-link-generation?lang=en-US
- Unreal Nav Link Proxy example: https://dev.epicgames.com/documentation/unreal-engine/1.2---nav-link-proxy?application_version=4.27

### 2. Custom traversal must take control at the link

Godot documentation explicitly says a navigation link does not provide specialized movement through
the link. Game code must react when the agent reaches the link and move the actor to the exit by
animation, tween, or controller logic.

Implementation implication:

- Do not let an orc "walk up" the link using normal horizontal steering.
- When an orc reserves a ladder and reaches the foot:
  - stop its `NavigationAgent3D` path steering;
  - enter `climbing_ladder`;
  - move along the ladder spline/segment at climb speed;
  - exit onto the wall navmesh;
  - restore normal `NavigationAgent3D` movement.

### 3. Queues are required; avoidance is not enough

Godot avoidance is useful for dynamic crowd motion, but the docs say avoidance does not affect
pathfinding. It is not a correctness mechanism for one-person choke points. Reynolds' steering
behavior work also separates high-level goals, steering, and locomotion, and specifically lists
path following, leader following, queuing at a doorway, and flocking/separation as separate
behaviors.

Implementation implication:

- A ladder needs explicit capacity, queue slots, and reservations.
- At most one or two orcs should be in `climbing_ladder` per ladder.
- Others wait in queue points near the foot, still using normal physics/collision.

Relevant source:

- Godot NavigationAgents avoidance: https://docs.godotengine.org/en/latest/tutorials/navigation/navigation_using_navigationagents.html
- Craig Reynolds steering behaviors: https://www.red3d.com/cwr/steer/

### 4. Four carriers should be a formation controller, not a single fake body

Online formation-control patterns generally split group movement into:

1. selecting/generating the path for the group;
2. moving members relative to a leader/formation anchor.

For games, this maps cleanly to a lightweight leader-following formation instead of trying to make
one large physics body from four orcs and a ladder.

Implementation implication:

- `LadderCrew` owns the shared target and state.
- Four carrier orcs remain normal targetable `CharacterBody3D` units.
- The ladder visual follows carrier anchor points.
- The formation leader/nav anchor moves toward the reserved wall slot.
- Each carrier follows a slot around the ladder using local steering + `move_and_slide()`.
- If the formation is damaged, degrade speed/state instead of teleporting the ladder.

Relevant source:

- Game AI Pro, formation movement overview: https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter21_Techniques_for_Formation_Movement_Using_Steering_Circles.pdf
- Craig Reynolds steering behaviors: https://www.red3d.com/cwr/steer/

### 5. Dynamic wall-wide ladders should use generated slots

The correct implementation is not random hardcoded world coordinates. The castle generator should
produce wall-module ladder slots, and the spawner should reserve among them.

Implementation implication:

- Each wall module emits `castle_ladder_slot` markers derived from its transform and outward normal.
- Slot metadata defines foot/top positions, width band, priority, and reservation.
- `WaveSpawner` asks a `LadderSlotAllocator` for slots across the wall.
- The allocator prevents all crews from choosing the gate area unless the wall genuinely has no other
  usable slots.

## Current implementation audit

### High-value files

1. `scripts/enemy/ladder_orc_enemy.gd`
   - Current ladder orc directly owns ladder placement and climbing.
   - It plants a visual `Node3D` named `SiegeLadder`, then moves itself upward with
     `global_position = _climb_from.lerp(_ladder_top, _climb_t)`.
   - This bypasses physics and navigation, so it cannot support real queues, multiple orcs using
     the same ladder, defenders knocking carriers down, or dynamic wall-wide placement.

2. `scripts/enemy/wave_spawner.gd`
   - Current spawner chooses `ladder_orc` counts and assigns lane offsets around the gate only.
   - It has no concept of a ladder crew, separate climbers, wall target slots, or active ladders.

3. `scripts/enemy/enemy.gd`
   - Base enemy movement already uses `CharacterBody3D.move_and_slide()`.
   - It still follows raw waypoint arrays, not `NavigationAgent3D` paths.
   - It has separation logic but no choke-point reservations.

4. `scripts/castle/fortress_generator.gd`
   - Already emits `castle_navigation_edge`, `NavigationLink3D`, a simple `CastleNavigationRegion`,
     and tactical slots.
   - It does not yet expose "ladder landing slots" along the full wall.

5. `scripts/ally/ally_archer.gd`
   - Ally targeting and movement will need to recognize carrier crews, placed ladders, and climbers.
   - Current native navigation is disabled by default, so enemy ladder work should not assume ally
     native navigation is production-ready.

6. `test/enemy_test.gd` and `test/wave_spawner_test.gd`
   - Existing tests already cover ladder orc stats, ladder planting, and wave composition.
   - They should be extended before implementation.

## Recommended design

### Core concept

Split "ladder orc" into three separate gameplay concepts:

1. `LadderCrew`
   - A `Node3D` coordinator, not an individual enemy.
   - Owns one long `SiegeLadder` object and four carrier orc instances.
   - Reserves a target wall landing slot.
   - Moves as a formation until the ladder reaches the wall.
   - Has state: `forming`, `carrying`, `planting`, `deployed`, `broken`.

2. `CarrierOrc`
   - A normal enemy body with `CharacterBody3D` and `NavigationAgent3D`.
   - Belongs to a crew via metadata/reference.
   - While carrying, receives defensive bonuses or damage sharing.
   - If one carrier dies, the crew slows; if two or more die, the ladder is dropped/broken unless
     replacement orcs are nearby.

3. `SiegeLadder`
   - A `Node3D` gameplay object with visual rails/rungs, collision, and one enemy-only
     `NavigationLink3D`.
   - Starts disabled while carried.
   - When planted, enables the link from ground foot to wall landing.
   - Has capacity metadata, e.g. `capacity = 1` or `2`, `reserved_by`, and `queue_points`.

### Navigation model

Use Godot's built-ins in this order:

1. `NavigationRegion3D`
   - Add a real enemy approach/ground navigation region.
   - Add wall-walk landing slots generated by fortress modules.

2. `NavigationAgent3D`
   - Carrier orcs and climber orcs should path toward reserved ladder foot or ladder queue slots.
   - Call `get_next_path_position()` once in `_physics_process()`, then move with
     `CharacterBody3D.move_and_slide()`.

3. `NavigationLink3D`
   - Each deployed ladder creates/enables one enemy navigation link:
     - `start_position`: ladder foot on the ground navmesh;
     - `end_position`: landing point on the wall-walk navmesh;
     - `bidirectional`: probably `false` for attackers initially, unless retreat/falling is desired;
     - `navigation_layers`: enemy-only layer.
   - React to `NavigationAgent3D.link_reached` or an Area trigger and run a controlled climb state.
   - Do not rely on the link alone to animate climbing. Godot docs are clear that the link only
     affects pathfinding; gameplay code must move the actor through the link.

4. `NavigationObstacle3D`
   - Optional for planted ladder/crowd avoidance, but not for queue correctness.
   - Use explicit ladder queues/reservations for correctness.

### Wall-wide ladder placement

Add generated module-owned `castle_ladder_slot` markers:

- `WallSegment`: 1-3 ladder landing slots on the outer face, spaced by segment length.
- `Tower`: optional ladder slots only if tower face is climbable; otherwise no.
- `GateTower`: lower priority than wall flanks, because gate already has other pressure.

Each slot metadata:

- `slot_kind = "ladder_landing"`;
- `foot = Vector3` ground-side foot;
- `top = Vector3` wall-walk landing;
- `normal = outward`;
- `reserved_by = 0`;
- `active_ladder = null`;
- `priority`;
- `width_band` or `wall_run_index` for distribution.

The spawner/allocator should choose ladder slots by weighted random over the whole outer wall, not
by hardcoded `z = 492/508`. Gate-adjacent slots can exist, but should not dominate.

### Carrying formation

Do not make one giant physics body for all four carriers. Use four regular `CharacterBody3D`
orcs and one non-physics visual ladder object:

- Crew leader owns the path target.
- Four carriers get formation offsets relative to the leader and follow with their own agents.
- The carried ladder visual interpolates between carrier anchor points.
- Formation speed is based on active carriers:
  - 4 carriers: normal ladder speed;
  - 3 carriers: slower;
  - 2 carriers: very slow / unstable;
  - <2 carriers: drop/break ladder.

This keeps collision, arrow hits, and deaths simple: arrows still hit orcs, not a fake combined
vehicle.

### Durability / "harder to zbic"

While a crew is carrying:

- carriers gain `carrying_ladder = true`;
- apply damage reduction or extra effective armor;
- optionally distribute a fraction of damage to the ladder object;
- targeting should prioritize carrier crews as high-value targets, but they should not die from one
  lucky low-damage arrow.

Suggested first tuning:

- `CarrierOrc.max_hp = 160`;
- `armor = 0.18`;
- `defense = 2.0`;
- `speed = 2.2` while carrying;
- ladder breaks if `ladder_hp <= 0` or active carriers < 2.

### Climber behavior

Normal melee orcs should not climb magically. They should:

1. Query active `SiegeLadder` nodes in group `siege_ladder_active`.
2. Pick a ladder with:
   - reachable queue slot;
   - available capacity;
   - reasonable distance;
   - not destroyed.
3. Navigate to queue point with `NavigationAgent3D`.
4. Reserve climb capacity.
5. Enter `climbing_ladder` state.
6. Move along ladder using a controlled kinematic climb:
   - disable horizontal path steering;
   - keep collision active if possible, but ignore crowd pushes;
   - interpolate along ladder rail at climb speed;
   - on completion, snap to the wall-walk navmesh and set next target to a defender/slot.

If no ladder exists, non-ram melee orcs should wait/pressure in the field or guard ladders, not hit
the gate.

## Implementation approach

### Phase 1: data and slots

- Add `scripts/enemy/siege_ladder.gd`.
- Add `scripts/enemy/ladder_crew.gd`.
- Add `scenes/enemy/siege_ladder.tscn`.
- Add `scenes/enemy/ladder_crew.tscn` if crew is scene-backed.
- Extend `FortressGenerator` to emit wall-wide `castle_ladder_slot` markers from actual module
  transforms.
- Add tests that count ladder slots and verify slot metadata has `foot` and `top`.

### Phase 2: spawner composition

- Change `WaveSpawner` so `ladder_crew` is a wave kind separate from loose `ladder_orc`.
- Spawn fewer crews than individual ladder orcs, e.g. wave 1 has 2 crews + loose infantry.
- Each crew consumes four carrier orcs internally.
- Existing `ladder_orc` can be repurposed as `climber_orc` or kept as carrier visual initially.

### Phase 3: planted ladder link

- `SiegeLadder.deploy(foot, top)` creates/enables:
  - visual ladder;
  - collision/targetable body;
  - `NavigationLink3D` with enemy navigation layer;
  - `Area3D` or metadata for climb entry/exit.
- Link traversal must trigger scripted climb. The link itself only tells pathfinding "this is a
  route".

### Phase 4: enemy navigation controller

- Add a reusable `EnemyNavigator` or integrate `NavigationAgent3D` into `Enemy`.
- Keep `move_and_slide()` as the movement primitive.
- Use `avoidance_enabled` only for active movers in open areas; use queue reservations at ladders.

### Phase 5: climbers use active ladders

- Add enemy states:
  - `field_moving`;
  - `waiting_for_ladder`;
  - `queued_for_ladder`;
  - `climbing_ladder`;
  - `on_wall`;
  - `attacking_defender`.
- Normal orcs choose deployed ladders instead of the gate if the gate is closed.

### Phase 6: combat hooks

- Ally target priorities:
  - ram;
  - ladder crew carrying ladder;
  - climber on ladder;
  - enemy archer;
  - nearest melee.
- Ladder damage:
  - arrows can hit carriers;
  - optionally arrows can damage ladder prop;
  - killing enough carriers drops ladder.

### Phase 7: debug and probes

- Extend dev overlay:
  - active crews;
  - carried/deployed/broken ladders;
  - climbers queued/climbing/on wall.
- Add minimap markers for ladder crews and active ladders.
- Add scene probes:
  - crew reaches wall slot;
  - ladder deploys one `NavigationLink3D`;
  - two loose orcs climb a deployed ladder;
  - killing carriers breaks/drops ladder.

## Risks and mitigations

- **Native navigation not fully stable yet:** implement the ladder system with clear states and
  keep fallback direct waypoints only as a temporary bridge, but the API should be `NavigationAgent3D`
  ready.
- **Crowding at ladders:** avoidance will not solve one-person-wide choke points. Use explicit
  queue slots and capacity reservations.
- **Wall-wide placement on generated castle:** do not hardcode global `z`; generate ladder slots
  from module transforms and outward normals.
- **NavigationLink does not animate climbing:** implement a `climbing_ladder` state that moves the
  orc along the ladder with controlled kinematic motion.
- **Performance:** bake/use simplified nav source geometry, not detailed castle visuals.

## Dev tools discovered

| Directory | Tool | Install | Lint fix | Lint check | Test | Build/Deploy |
| --- | --- | --- | --- | --- | --- | --- |
| `.` | Makefile / Godot | - | - | `make import` | `make test`, `make test-target TEST=res://test/enemy_test.gd` | `make run`, `make play`, `make editor` |

User constraint for current manual QA: do not run `make test` unless explicitly asked.

## Recommended next step

Implement Phase 1 and Phase 2 first:

1. Generate `castle_ladder_slot` markers across wall modules.
2. Add `SiegeLadder` object with visual/collision/link metadata.
3. Add `LadderCrew` coordinator with four carrier orcs.
4. Change `WaveSpawner` to spawn crews, not only independent ladder orcs.

Do not yet replace all enemy pathing in the same patch. Keep that for Phase 4 after ladder slots
and crew deployment are observable and testable.

## Confidence

Medium-high. The Godot primitives are a good fit (`CharacterBody3D`, `NavigationAgent3D`,
`NavigationLink3D`), but current project navigation is still partial. The safe path is an
incremental implementation: module-owned ladder slots first, crew/deploy state second, native
pathfinding integration third.
