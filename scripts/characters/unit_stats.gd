@tool
class_name UnitStats
extends Resource

## Tunable combat/movement stats for a unit, kept out of the behaviour scripts so designers can
## balance from .tres presets (see data/enemy_infantry.tres, data/ally_archer.tres) without touching
## code. A single resource type serves both melee besiegers and ranged archers; each preset fills
## the fields relevant to it and leaves the rest at default.

enum Faction { PLAYER, ALLY, ENEMY }
enum Role { HERO, INFANTRY, ARCHER, RAM, BOSS_RAM, LADDER_ORC }

## identity / progression
@export var type_id: StringName = &"unit"
@export var display_name: String = "Unit"
@export var faction: int = Faction.ENEMY
@export var role: int = Role.INFANTRY
@export var level: int = 1
@export var xp: int = 0
@export var xp_value: int = 0
@export var kill_value: int = 1
@export var kills: int = 0
@export var behavior_tags: PackedStringArray = []

## shared
@export var max_hp: float = 100.0
@export var defense: float = 0.0
@export_range(0.0, 0.85, 0.01) var armor: float = 0.0
@export var armor_type: StringName = &"none"

## melee / movement (besieger)
@export var speed: float = 2.3
@export var gravity: float = 20.0
@export var step_height: float = 0.6
@export var attack_range: float = 6.0
@export var attack_damage: float = 6.0
@export var melee_attack_damage: float = 6.0
@export var attack_interval: float = 1.3
@export var decision_interval: float = 0.45
@export var avoidance_refresh: float = 0.32
@export var wall_target_refresh: float = 0.42
@export var wall_pressure_refresh: float = 0.7
@export var ladder_search_refresh: float = 0.55

## ranged (archer)
@export var ranged_attack_damage: float = 25.0
@export var fire_interval: float = 2.2
@export var arrow_speed: float = 58.0
@export var sight_range: float = 70.0
@export var spread_deg: float = 1.5
@export var muzzle_height: float = 1.6

static func bonus_levels_for_kills(kill_count: int) -> int:
	var threshold := 5
	var bonus := 0
	while kill_count >= threshold:
		bonus += 1
		threshold *= 2
	return bonus

static func level_for_kills(base_level: int, kill_count: int) -> int:
	return base_level + bonus_levels_for_kills(kill_count)

static func stat_multiplier(base_level: int, current_level: int) -> float:
	return 1.0 + 0.1 * float(maxi(0, current_level - base_level))
