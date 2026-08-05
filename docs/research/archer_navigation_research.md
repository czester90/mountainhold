# Archer Navigation Research

Date: 2026-07-27

## Problem

Current defender movement is not robust enough for a modular castle. The screenshots from
`screenshots/player/shot_053.png`, `screenshots/player/shot_054.png`, and
`screenshots/player/shot_055.png` show the same class of bug repeatedly:

- archers block around the gate, tower, and wall transitions;
- archers do not reliably descend from the gate or towers;
- archers do not reliably enter the keep;
- some archers float or visually detach from walkable surfaces;
- order `5` (`Wycofaj do stołpu`) does not move the full group through the castle;
- the minimap shows defenders clustered near the front instead of flowing through the route.

This is not a placement-only problem. It is a movement architecture problem.

## Current Implementation Audit

### Ally movement

`scripts/ally/ally_archer.gd` currently extends `Node3D`, not `CharacterBody3D`.
Movement is performed by assigning `global_position` in `_walk_towards_on_surfaces()`.

That means:

- Godot physics does not resolve the archer's movement against walls, floors, stairs, or other bodies.
- The child body can collide, but the parent is still effectively teleported.
- Narrow doorways and stairs have no physical queueing or reliable collision response.
- Vertical movement is guessed by downward raycasts, not by a navigation corridor.

The current route builder reads nodes in group `castle_navigation_edge`, extracts metadata
`nav_a` and `nav_b`, then runs a custom shortest-path pass. This gives a rough graph, but it
does not describe walkable areas, agent clearance, door widths, stair capacity, tower interiors,
or dynamic obstacles.

### Ally placement

`scripts/ally/ally_placer.gd` places defenders by raycasting fixed world-space candidate points
onto surfaces. It avoids direct stacking, but it does not ask the navigation system whether the
spawn point is reachable from the courtyard, the gate, the wall walk, or the keep.

This explains why a defender can be on a visually valid surface but still have no usable route.

### Orders

`scripts/ally/defender_orders.gd` has a useful command model, but it assigns raw rally points.
It does not allocate walkable tactical slots, reserve choke points, or stagger movement through
stairs and tower doors. Gate reinforcement is already batched at 30%, but retreat currently sends
everyone toward the keep target without route capacity management.

### Castle generator

`scripts/castle/fortress_generator.gd` registers module-to-module edges, including vertical
edges, but these are metadata links, not Godot navigation primitives. They are useful as debug
evidence and can be reused as module metadata, but they should not remain the primary movement
system.

## Research Findings

### Godot NavigationAgent3D

Godot's `NavigationAgent3D` is designed for 3D pathfinding with obstacle avoidance. It requires
navigation data and expects the parent actor to move using the returned next path position during
physics processing.

Key implications for Mountainhold:

- Every moving archer should own a `NavigationAgent3D`.
- The actor should call `get_next_path_position()` once per physics frame while navigating.
- Movement should be applied to a physics-aware parent, preferably `CharacterBody3D` with
  `move_and_slide()`.
- `avoidance_enabled` can produce safe velocities via `velocity_computed`, but it has a runtime
  cost and should be enabled for agents currently moving or in crowds.
- `path_desired_distance` and `target_desired_distance` must be tuned. Too small causes
  overshoot/repath loops; too large can skip path points and leave the navmesh.
- `radius`, `height`, `neighbor_distance`, and `max_neighbors` must match the defender collision
  capsule and the scale of tight castle corridors.

Source: https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html

### Godot navigation meshes

Godot navigation meshes bake walkable surfaces with an `agent_radius` margin. This is important
because the navmesh can be shrunk so agents do not plan routes through gaps narrower than their
collision body.

For generated castles, Godot can parse selected source geometry by group name. This is the right
direction for modular walls, towers, stairs, gatehouses, and keep modules: the generator should
mark simple invisible navigation source geometry, not rely on detailed visual meshes.

Runtime baking has a cost mostly in source geometry parsing. For this project, we should use
simple boxes/planes as source data or generate procedural source geometry directly instead of
parsing every visible stone mesh.

Source: https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationmeshes.html

### NavigationLink3D

`NavigationLink3D` connects two positions on one or more `NavigationRegion3D` nodes. It is meant
for movement that is not simply walking across the navmesh surface.

For Mountainhold, links should represent:

- stairs between courtyard and wall walk;
- tower interior up/down transitions;
- gatehouse roof/gallery transitions;
- keep entrances and internal stairs;
- future enemy ladders as dynamic links enabled only when a ladder is placed.

Source: https://docs.godotengine.org/en/stable/classes/class_navigationlink3d.html

### Connecting navmesh chunks

Godot can connect nearby navmesh edges using an edge connection margin, but overlapping or
slightly misaligned chunks can fail unpredictably. Modular castle pieces should therefore either
produce aligned navmesh chunk edges or use explicit `NavigationLink3D` links at module portals.

For our castle, explicit links are safer for doors, tower thresholds, stairs, and ladders.

Source: https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_connecting_navmesh.html

## Root Cause

The current system mixes tactical intent, pathfinding, movement, collision, and surface probing in
one archer script. It is too local and too geometric-guess-heavy.

The main failure is not "wrong coordinates"; it is that archers do not have a real navigation
model of the fortress.

Current behavior fails because:

- the actor is not a `CharacterBody3D`;
- movement bypasses collision resolution;
- routes are sparse edge metadata, not walkable corridors;
- raycasts cannot understand stairs, door interiors, queues, or blocked passages;
- orders target points, not reserved reachable slots;
- generated modules do not expose a complete movement contract;
- there is no stuck detector that can replan intelligently.

## Target Architecture

### 1. Character-based movement

Create a reusable defender movement root, e.g. `NavAgentCharacter`, based on `CharacterBody3D`.

Responsibilities:

- capsule collision;
- gravity;
- floor snapping;
- slope limits;
- `move_and_slide()`;
- movement speed from unit stats;
- optional acceleration instead of instant velocity changes.

`AllyArcher` can keep its combat, stats, and visual logic, but physical movement should no longer
be implemented by direct `global_position` assignment.

### 2. NavigationAgent3D controller

Each defender gets a `NavigationAgent3D`.

Responsibilities:

- accept target slot;
- call `get_next_path_position()` in `_physics_process`;
- convert next path position into desired velocity;
- use avoidance for moving crowds;
- react to `link_reached` when entering stairs, ladders, doors, or scripted transitions;
- expose debug state: idle, moving, waiting_in_queue, using_link, stuck, unreachable.

### 3. Castle navigation source

Every castle module should expose navigation metadata, not hardcoded global positions.

Each module should provide:

- walkable source volumes/surfaces;
- portals between modules;
- vertical links;
- tactical firing slots;
- queue points near narrow links;
- preferred movement direction and capacity for choke points.

Example module contracts:

- `WallSegment`: wall-walk surface, two wall portals, firing slots along outer parapet.
- `Tower`: roof/wall-walk surface, internal stair link, ground door portal, window firing slots.
- `GateTower`: roof, gallery, murder-hole slots, door portals, roof access link.
- `StoneStairs`: stair walkable surface or explicit stair link, entry queue, exit queue.
- `Keep`: ground entry, upper platform, internal vertical links, retreat slots.
- `Ladder`: dynamic enemy-only or enemy-preferred link from ground to wall top.

### 4. NavigationRegion3D generation

The fortress generator should build one or more `NavigationRegion3D` nodes from module source
geometry.

Recommended layers:

- `ground`: courtyard, approach, keep ground entry;
- `wall`: ramparts, tower roofs, gate roof;
- `interior`: gatehouse gallery, keep/tower interiors;
- `ladder`: dynamic attacker routes from ladders.

Layers can stay simple at first, but the data model should support them now.

### 5. Navigation links

Use `NavigationLink3D` for transitions that are not guaranteed to connect as a clean continuous
navmesh surface:

- stairs;
- tower up/down;
- gatehouse up/down;
- keep entry;
- ladders;
- narrow wall-to-tower thresholds where baked edges are unreliable.

Links should carry metadata:

- `kind`: stairs, ladder, door, tower_internal, keep_internal;
- `capacity`: how many units can occupy or reserve it;
- `team_mask`: ally, enemy, both;
- `bidirectional`;
- `enabled`.

### 6. Tactical slot allocator

Orders should target logical slot groups, not raw coordinates.

Examples:

- `DEFEND_GATE`: reserve gate murder-hole slots, gate edge slots, then nearby tower slots.
- `RETREAT_KEEP`: reserve keep slots, then queue archers through available stairs/doors.
- `ATTACK_RAM`: reserve high-LOS slots with visibility to ram.
- `ATTACK_CLOSEST`: keep current slot if LOS is good, otherwise request nearest better slot.

The allocator must:

- reserve one destination per archer;
- avoid two defenders choosing the same point;
- enforce queue capacity at stairs/doors;
- stagger movement batches through choke points;
- release reservations when a unit dies, reaches the slot, or receives another order.

### 7. Stuck and bad-shot recovery

Every moving archer should track:

- distance progressed over the last few seconds;
- current path index;
- current link;
- collision count / blocked direction;
- last clear line of sight;
- last bad shot reason.

If blocked:

- do not teleport;
- stop pushing into the same wall;
- ask allocator for alternate slot or wait in queue;
- if no route exists, report debug state visibly.

If shooting into wall/floor:

- verify line of sight from actual muzzle;
- if blocked, request a new firing slot with LOS;
- if no slot exists, switch to closest reachable fallback instead of firing.

## Implementation Plan

### Phase 0: freeze the current hack path

Do not add more hardcoded waypoints, podests, or special-case coordinates. Keep current gameplay
only as a temporary fallback until the new path system is ready.

### Phase 1: add navigation debug probes

Add developer debug output before changing behavior:

- draw navmesh;
- draw each archer path;
- draw `NavigationLink3D` endpoints;
- label each archer state;
- log unreachable target and stuck reason;
- add screenshot/probe command for order `4` and order `5`.

Acceptance:

- we can see why an archer stopped;
- we can prove whether a point is on the navmesh;
- we can see all links between courtyard, wall, towers, gate, and keep.

### Phase 2: prototype one CharacterBody3D archer

Create a small test scene with:

- courtyard platform;
- wall walk;
- tower;
- stair;
- keep platform;
- one archer using `CharacterBody3D` + `NavigationAgent3D`.

Acceptance:

- archer walks from courtyard to wall;
- archer walks from wall to tower;
- archer walks from tower to courtyard;
- archer walks from gate/tower to keep;
- no direct `global_position` movement except initial spawn.

### Phase 3: module navigation metadata

Extend castle modules so each generated piece declares:

- navigation source geometry;
- portals;
- tactical slots;
- navigation links;
- queue points.

Acceptance:

- changing wall/tower/gate positions still produces connected navigation data;
- no route depends on hardcoded global `x/z` values.

### Phase 4: generated NavigationRegion3D

Add a `CastleNavigationBuilder` that consumes module metadata and creates/bakes navigation data.

Acceptance:

- scene contains a `NavigationRegion3D`;
- agents can query paths across generated castle modules;
- generated navmesh uses agent radius matching the archer capsule.

### Phase 5: replace archer movement

Move archer locomotion from `_walk_towards_on_surfaces()` into a dedicated navigation controller.

Acceptance:

- archers do not float;
- archers do not move through walls;
- archers respect collision;
- archers avoid each other in open areas;
- archers wait or replan at choke points.

### Phase 6: tactical slot allocator

Replace raw rally points in `DefenderOrders` with slot requests.

Acceptance:

- pressing `4` sends only available batch slots toward gate;
- repeated `4` calls bring additional groups;
- pressing `5` queues the retreat instead of piling everyone into one stair/door;
- defenders choose nearby valid slots with LOS.

### Phase 7: ladders as dynamic enemy links

When an orc ladder reaches the wall, create or enable a ladder link from ground to wall top.

Acceptance:

- enemies can path onto the wall only through placed ladders or breached routes;
- defenders can target ladder climbers;
- destroying/removing a ladder disables the route.

## Tests And Validation

### Unit tests

- module exposes at least one walkable source surface;
- module portals have valid world transforms;
- every `NavigationLink3D` has reachable start and end positions;
- tactical slot allocator never assigns duplicate active slots;
- retreat order produces no more movers through a choke than its capacity.

### Scene probes

Add headless probes for:

- `order_4_gate_reinforcement`: 30% of archers start moving to gate slots.
- `order_4_repeated`: repeated calls fill more reserved gate slots.
- `order_5_retreat`: at least 90% of living archers reach keep slots within a time limit.
- `tower_to_courtyard`: archer descends from tower to courtyard.
- `courtyard_to_tower`: archer climbs from courtyard to tower.
- `gate_to_keep`: archer routes from gate roof/gallery to keep.
- `generated_variant_connectivity`: slightly changed castle layout still has valid nav connectivity.

### Visual validation

Use screenshots or short captured runs to verify:

- no floating archers;
- no archers inside walls;
- no pileups at stairs;
- no arrows fired into obvious nearby masonry when a better slot exists;
- minimap movement matches visible movement.

## Risks

- Navigation baking from detailed meshes can be slow. Use simplified invisible navigation source
  geometry or procedural source arrays.
- Castle corridors may be too narrow for current defender radius. Fixing navigation may reveal
  geometry that must be widened.
- Avoidance alone does not solve one-person-wide stairs. Choke points need explicit queues and
  reservations.
- Multiple navmesh chunks may not connect if edges are misaligned. Use explicit links at module
  portals rather than relying on accidental overlap.
- Converting `AllyArcher` from `Node3D` to `CharacterBody3D` may require scene/test updates.

## Immediate Decision

The correct next step is not another hardcoded waypoint fix. The next step is to implement the
navigation foundation:

1. `CharacterBody3D` archer locomotion;
2. generated castle navmesh/navigation source;
3. explicit module links;
4. tactical slot allocator;
5. stuck/LOS recovery;
6. acceptance probes based on real movement.

Only after that should we tune exact archer behavior around the gate, towers, keep, and ladders.
