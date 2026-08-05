# Navigation Architecture

Date: 2026-08-05
Backlog task: P0-010
Scope: current navigation ownership for fortress, enemies, ladders, and defenders. This is a refactoring contract, not a behavior change.

## Goal

Mountainhold needs hundreds of units without AI becoming unreadable. Navigation should be split into stable layers:

1. **Fortress data** describes where things are.
2. **Tactical assignment** decides which objective a unit should pursue.
3. **Route selection** turns objectives into waypoints.
4. **Movement execution** moves a body along the next local direction.
5. **Special traversal** handles ladders and other non-standard transitions.
6. **Recovery** detects and reports failure without silently changing strategic intent.

## Current Owners

| Layer | Current owner | Current responsibility | Main issue |
| --- | --- | --- | --- |
| Fortress data | `FortressGenerator`, `CastleModel` | Generate tactical slots, ladder slots, navigation edges, regions/links | `CastleModel` stores lists but does not yet expose semantic anchors/regions for gate, keep, sectors, route points |
| Ground validation | `GroundResolver`, `WaveSpawner`, `SiegeDirector`, enemies | Raycast terrain/physics ground for spawn, ladder foot, landing, recovery | Validation is duplicated and mixed with spawn/tactical logic |
| Tactical assignment | `WaveSpawner`, `SiegeDirector`, `DefenderOrders` | Pick wave roles, ladder slots, assault points, defender rally slots | Assignment still uses hardcoded coordinates and local heuristics |
| Enemy objective state | `Enemy`, `LadderOrcEnemy`, `WallAssaultBrain`, `LadderAssaultBrain` | Decide gate/wall/ladder/keep pressure and target defenders | State is spread across booleans, path arrays, cached targets, meta flags, and helper brains |
| Route selection | `CastlePathfinder`, `WallAssaultBrain`, `Enemy` | Route from unit to defender/pressure point using registered edges; otherwise direct movement | Callers decide when to route vs move directly; no single route contract |
| Movement execution | `UnitLocomotion`, `Enemy`, `LadderOrcEnemy` | Apply horizontal velocity, gravity, rotation, move_and_slide | Direct movement, step-up, stuck handling, and wall floor checks remain partly in `Enemy` |
| Ladder traversal | `SiegeLadder`, `TraversalController`, `LadderAssaultBrain`, `Enemy` | Reserve entry/climb, animate ladder climb, release reservations, settle on landing | Queue/reservation/landing state crosses multiple classes |
| Recovery/diagnostics | `Enemy`, `TraversalController`, `SiegeLadder` | Ground recovery, stuck unstick, traversal failure, debug snapshots | Diagnostics now exist, but recovery policy is not centralized |

## Target Ownership Contract

### FortressGenerator

- Builds geometry and registers raw generated data only.
- Owns physical creation of tactical slots, ladder slots, nav edges, nav links, and regions.
- Should not be queried directly by AI once `CastleModel` exposes semantic methods.

### CastleModel

- Owns semantic fortress queries.
- Should expose stable methods for:
  - `gate_entry_point()` and `gate_exit_point()`;
  - `keep_attack_point()` and `keep_rally_slots()`;
  - `main_route_points()` from field to keep;
  - `wall_sectors()` and `sector_for_point()`;
  - `staging_band()` / `spawn_band()`;
  - `wall_ladder_slots()` with approach metadata;
  - `defender_slots(kind, sector)`.
- Should remain read-only during combat except slot reservations where explicit.

### SiegeDirector

- Owns high-level enemy assignment, not physical movement.
- Chooses assault sectors, ladder slots, spawn/staging anchors, role mix, and fallback objectives.
- Should consume `CastleModel` queries instead of scanning groups or duplicating slot filters.
- Should not call `move_and_slide`, mutate enemy velocity, or own climb reservations.

### WaveSpawner

- Owns wave lifecycle and unit instantiation.
- Assigns initial orders returned by `SiegeDirector`.
- Should not own fortress route constants long term.
- Should remain the owner for gate/keep HP until a separate siege objective model exists.

### Enemy / LadderOrcEnemy

- Owns current unit intent and short-term execution state.
- May ask brains/director/model for targets and routes.
- Should eventually expose one explicit state enum instead of scattered booleans.
- Should not scan broad scene groups when `CombatRegistry` or `CastleModel` can answer the query.

### WallAssaultBrain

- Owns wall-combat target/pressure choice and route request policy.
- Should return decisions, not mutate physics directly.
- Should use a central threat evaluator once P1 targeting work begins.

### LadderAssaultBrain

- Owns active ladder selection and queue/entry decision policy.
- Should score ladders from `CombatRegistry.active_ladders()` and `SiegeLadder` capacity diagnostics.
- Should not own climb animation or ladder lifecycle cleanup.

### SiegeLadder

- Owns ladder state, entry reservations, climb slots, queue slots, landing slots, health, and cleanup.
- Should be the only source of truth for whether a unit is queued, reserved, climbing, or released.
- Should expose read-only diagnostics and safe reservation methods.

### TraversalController

- Owns non-standard traversal execution, currently ladder climbing.
- Validates traversal segment, advances body, resolves landing, and emits completion/failure.
- Should not choose which ladder to use.

### UnitLocomotion

- Owns ordinary movement primitives: idle, move direction, gravity, facing, and `move_and_slide`.
- Should gradually absorb safe step-up/floor-ahead movement helpers once behavior is characterized.
- Should not choose strategic objectives.

### CombatRegistry

- Owns live unit/projectile/ladders lookup and spatial queries.
- Should enforce active/dead/staged filters centrally.
- Should be the default source for target candidates and nearby units.

## Current Navigation Flows

### Ground Gate/Keep Assault

1. `WaveSpawner` instantiates unit and currently gives `Enemy.setup_path(ROUTE, spawner, GATE_WP)`.
2. `Enemy._physics_process()` advances through path waypoints.
3. At closed gate, only rams/boss rams attack; other enemies may try active ladders or idle.
4. After breach, route continues to keep and enemy attacks keep when in range.

Target state: route points should come from `CastleModel.main_route_points()` and objective state should say whether the unit is marching to gate, waiting, attacking gate, or marching to keep.

### Wall Assault Via Existing Ladder

1. Infantry in wall assault calls `_try_use_active_ladder()`.
2. `LadderAssaultBrain.choose_active_ladder()` scores active ladders.
3. Enemy moves to entry point, reserves entry, reserves climb, then starts `TraversalController.start_ladder()`.
4. On completion, enemy marks `_on_wall`, settles, then attacks defenders or pressure points.

Target state: `SiegeLadder` owns queue/reservation truth, `Enemy` owns state, and `TraversalController` owns climb execution only.

### Ladder Crew Deployment

1. `WaveSpawner` / `SiegeDirector` pick ladder slot, foot/top/normal, and crew spawn.
2. Two `LadderOrcEnemy` carriers move to deploy zone.
3. Leader checks nearby carriers, deploys `SiegeLadder`, assigns carrier/helper units to queue.
4. Carriers climb through the same reservation/traversal path as other enemies.

Target state: `SiegeDirector` chooses slot/sector; `LadderOrcEnemy` owns crew intent; `SiegeLadder` owns deployed lifecycle and queue.

### Defender Movement/Positioning

1. `DefenderOrders` picks order mode and rally slot.
2. `DefenderPositioning` scores tactical slots, including gate-specific bonuses.
3. `AllyArcher` moves/repositions and `DefenderTargeting` chooses enemies.

Target state: defender order uses `CastleModel.defender_slots(kind, sector)` and centralized threat/sector scoring.

## Recovery Contract

- Recovery must not silently change high-level objective unless the current objective is proven invalid.
- Ground recovery owns falling/buried/skying correction and records `last_recovery`.
- Stuck recovery owns short local unstick nudges and retry counters.
- Traversal failure owns ladder climb cancellation reason.
- P0-013 should centralize retry/fallback policy after states are explicit.

## Refactoring Sequence

1. Add semantic `CastleModel` query methods while preserving existing constants as fallback data.
2. Add tests for generated gate/keep/route/staging/ladder-sector queries.
3. Route `WaveSpawner.ROUTE` and spawn/staging anchors through `CastleModel`.
4. Route defender gate/keep rally logic through `CastleModel`.
5. Define explicit enemy states and wire debug snapshots to those states.
6. Move safe step-up/floor-ahead helpers toward `UnitLocomotion` only after movement tests exist.
7. Formalize ladder lifecycle state machine and make `SiegeLadder` the single reservation source.

## Validation Gates

- Docs-only architecture changes require grep/code review only.
- Any movement code change requires at least targeted enemy/ladder tests.
- Any fortress query change requires fortress navigation/model tests.
- Any wave route change requires wave spawner tests and a manual play check.
- Full `make test` remains non-authoritative until the current smoke hang/crash is fixed.
