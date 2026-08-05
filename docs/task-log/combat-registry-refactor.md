# Combat registry refactor

Date: 2026-07-28

## Summary

Added a runtime `CombatRegistry` as the single active-unit source for HUD, minimap, defender commands, targeting, enemy defender selection and wave alive counts.

This reduces the “ghost enemy” class of bugs where one system still sees an old group member while another system has already hidden, killed, removed or lost the unit outside the playable world.

## Problem

Several systems independently scanned Godot groups:

- HUD counted allies/rams directly from groups.
- Minimap drew enemies/allies directly from groups.
- Developer panel counted enemies/allies directly from groups.
- Defender orders gathered all allies directly from the `ally` group.
- Ally and enemy targeting queried raw `enemy`, `ally`, `ram` and `player` groups.
- `WaveSpawner` tracked its own `_alive` list.

Groups are still useful as tags and fallback, but they should not be the primary runtime state for gameplay/UI.

## Implementation

### Files modified

1. `scripts/core/combat_registry.gd` — new registry node with active enemies, allies, rams, ladders and player.
2. `scenes/play.tscn` — adds `CombatRegistry` beside the player and spawner.
3. `scripts/enemy/wave_spawner.gd` — registers spawned enemies and uses registry for `alive_count()`.
4. `scripts/ally/ally_placer.gd` — registers placed defenders.
5. `scripts/ally/ally_archer.gd` — exposes `is_active_ally()` and uses registry-backed enemy lists for targeting.
6. `scripts/enemy/enemy.gd` — uses registry-backed defender/enemy lists for targeting and separation.
7. `scripts/enemy/ladder_orc_enemy.gd` — uses registry-backed defender lookup.
8. `scripts/enemy/archer_enemy.gd` — uses registry-backed defender lookup.
9. `scripts/characters/components/targeting_component.gd` — uses registry-backed candidates for enemy/ally/ram groups.
10. `scripts/ui/hud.gd` — uses registry for ally roster/counter and ram warning.
11. `scripts/ui/minimap.gd` — uses registry for player/enemy/ally drawing and bounds.
12. `scripts/ui/developer_panel.gd` — uses registry for active unit counts and no-floor checks.

## Key details

- `CombatRegistry` remains a scene node, not an autoload, because it represents one active match.
- Registry syncs from groups as fallback, so existing tests and isolated scenes still work.
- Active filtering removes invalid, queued, hidden, dead and out-of-world units.
- Enemy-specific filtering still respects `Enemy.is_active_enemy()`.
- Ally-specific filtering now respects `AllyArcher.is_active_ally()`.
- Raw group scans remain only as fallback/debug or for non-combat castle metadata.

## Validation

Full `make test` intentionally not run during this step; the user wants it only at the end.

Lightweight validation run:

```text
/opt/homebrew/bin/godot --headless --path . -s /tmp/mountainhold_registry_parse.gd
registry parse/load ok
```

Runtime probe:

```text
/opt/homebrew/bin/godot --headless --path . -s /tmp/mountainhold_registry_probe.gd
registry summary={ "enemies": 9, "allies": 20, "rams": 0, "ladders": 0, "player": true }
registry probe ok
```

Short scene smoke:

```text
timeout 8 /opt/homebrew/bin/godot --headless --path . scenes/play.tscn --quit-after 180
fortress: base=15.2, 124 modules
ally_placer: placed 20 archers from CastleModel + fallback
```

The known Godot shutdown ObjectDB/RID leak warnings still appear in headless runs, but these commands exit with status `0`.
