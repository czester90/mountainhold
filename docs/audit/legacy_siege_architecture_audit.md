# Legacy siege architecture audit

Date: 2026-07-28

## Verdict

The current structure is not clean enough for reliable siege gameplay. The project has useful building blocks, but too much legacy and temporary fallback logic is still active in production paths. That makes bugs look random: enemies can pick old routes, ladder units can use old solo behaviour, archers can fall back to manual movement, and large scripts hide several responsibilities in one place.

The biggest problem is not one bad line. It is that siege orchestration, navigation, combat, recovery, debug helpers, and test-era fallbacks are mixed together.

## What is already good

- `UnitStats`, `HealthComponent`, `AttackComponent`, and `TargetingComponent` are the right direction for reusable unit data and combat primitives.
- Enemy variants have separate scenes and scripts, so infantry, archers, rams, bosses, and ladder orcs can be separated further without rebuilding everything.
- Castle modules expose useful metadata such as tactical slots and module groups.
- Defender orders are split into `DefenderOrders`, which is a good boundary for player commands.
- Minimap is isolated in UI code, even though its data flow can still be improved.

## Active legacy that should be removed

### Solo ladder orc route

`scripts/enemy/ladder_orc_enemy.gd` still exposes `setup_ladder_path(...)`. This function configures a single ladder orc with internal hardcoded route state like muster, ladder foot, ladder top, and wall goal. That is the old prototype behaviour.

This conflicts with the desired design where four strong orcs carry a full ladder to a lane, deploy it, and then other orcs climb it.

### Wave spawner legacy branch

`scripts/enemy/wave_spawner.gd` still registers `"ladder_orc"` in `SCENES` and still has a branch that calls `setup_ladder_path(...)`.

Even if normal wave composition currently prefers ladder crews, this is dangerous because one spawn path can silently reintroduce the old single-orc ladder logic.

### Tests preserve the old behaviour

`test/enemy_test.gd` still tests that a single ladder orc can plant a climbable ladder. That test protects legacy behaviour instead of protecting the new crew-based design.

### Fallback defender navigation

`scripts/ally/ally_archer.gd` is still almost a whole AI system in one file. It owns orders, targeting, movement, line of sight, unstuck/recovery, shooting, navigation debug state, and fallback surface walking.

The fallback route graph was useful while building, but now it is part of the reason archers jitter, block, or choose strange paths.

### Manual enemy movement and recovery

`scripts/enemy/enemy.gd` still mixes enemy state, targeting, attack logic, gate/keep behaviour, ladder climbing, slope recovery, local avoidance, and manual movement. There are direct `global_position` movement fixes and `test_move` based recovery paths.

That kind of code is acceptable as an emergency recovery layer, but not as the primary navigation model.

### Spawner knows too much

`scripts/enemy/wave_spawner.gd` currently decides wave composition, spawn placement, lane reservation, ladder crew creation, escorts, gate/keep references, and active enemy tracking.

This should become a thin coordinator. Lane selection and siege placement should move into a separate siege director.

### Fortress generator does too much

`scripts/castle/fortress_generator.gd` builds the castle, terrain-related metadata, tactical slots, path metadata, and navigation region setup. It is still the source of truth for too many gameplay systems.

The castle should expose structured navigation and tactical metadata, but enemy and defender AI should not depend on scattered internal layout assumptions.

## Passive legacy / repo hygiene

### Archive folder is still visible to Godot

`archive_prebuilder_refactor_2026_07_14/` is an archive, but it still contains scenes, scripts, and `.uid` files. Godot can still scan those files, which can create duplicate UID warnings and noise.

It should either be moved outside the Godot project or hidden with `.gdignore`.

### Demo and test scaffolding

`demo/`, `scenes/test/`, `scripts/test/`, and `scripts/editor/` contain useful experiments and capture tools, but they should be clearly treated as non-production.

They are not the main cause of gameplay bugs, but they make audits noisy and increase the chance that old assumptions get copied back into runtime code.

## Separation assessment

Current separation is partial, not sufficient.

| Area | Current state | Desired state |
| --- | --- | --- |
| Stats | Mostly good | Keep data-driven resources |
| Health/combat primitives | Good start | Use consistently for all units |
| Enemy movement | Too mixed | Extract `EnemyLocomotion` |
| Enemy target choice | Too mixed | Extract `EnemyTargeting` or siege objective logic |
| Ladder assault | Split but legacy remains | Crew/lane/deploy/climb as one explicit system |
| Wave spawning | Too much responsibility | Spawner chooses waves only |
| Defender AI | Too much in `AllyArcher` | Split movement, targeting, shooting, orders |
| Castle metadata | Useful but crowded | Stable castle navigation/tactical API |
| Minimap | Isolated UI | Feed from cached game-state registry |

## Recommended refactor order

### Phase 0: hide non-production noise

- Add `.gdignore` to archived Godot content or move the archive outside the project.
- Keep demo/test/capture content, but avoid letting production code depend on it.

### Phase 1: remove active ladder legacy

- Remove `"ladder_orc"` from production `SCENES` in `WaveSpawner`.
- Remove the branch that calls `setup_ladder_path(...)`.
- Replace single-orc ladder tests with crew/deployed-ladder tests.
- Keep `LadderOrcEnemy` as a carrier/climber unit, not a standalone ladder planter.

### Phase 2: introduce `SiegeDirector`

Create one service responsible for:

- reading castle assault slots,
- filtering reachable wall lanes,
- reserving lane assignments,
- producing spawn, muster, ladder foot, ladder top, and climb target points,
- spreading attacks across the full wall width instead of collapsing on the gate.

`WaveSpawner` should ask `SiegeDirector` for a lane and spawn the requested units. It should not calculate castle-specific routes itself.

### Phase 3: extract enemy locomotion

Move ground movement, avoidance, stuck detection, slope handling, and recovery out of `Enemy`.

`Enemy` should decide state. `EnemyLocomotion` should execute movement.

### Phase 4: make ladders a first-class navigation link

Ladders should become deployed world objects with:

- base interaction point,
- top exit point,
- climb queue,
- occupancy limit,
- link state,
- optional `NavigationLink3D` when navmesh coverage is ready.

Enemies should not teleport or jitter into wall geometry. They should queue, climb, exit, then resume normal navigation.

### Phase 5: split defender AI

Break `AllyArcher` into smaller responsibilities:

- `DefenderOrderController`,
- `DefenderLocomotion`,
- `DefenderTargeting`,
- `ArcherShooting`,
- `DefenderPositioning`.

Archers need to select positions dynamically, but that dynamic choice should be based on castle slots and line-of-sight scoring, not random direct movement.

### Phase 6: clean minimap data flow

Minimap should consume a cached registry of known units and castle outline points rather than frequently scanning broad scene groups.

This is lower priority than movement, but it helps performance and debugging.

## Why legacy was left

The legacy pieces were left because they kept the game running while features were added quickly: first working castle, then archers, then orders, then ladder assault, then minimap. That made sense during prototyping.

Now the prototype scaffolding is hurting the game. The right move is to stop adding more behaviours on top of it and first cut the active legacy paths.

## Immediate next step

Start with Phase 1. It is the smallest safe cut and directly targets the current ladder/orc bugs:

1. remove the old single `ladder_orc` spawn path,
2. update tests so they protect ladder crews instead of solo ladder planting,
3. make every ladder assault go through the same crew/lane deployment path.

