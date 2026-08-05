class_name AttackComponent
extends Node

## Reusable cooldown attack. The host calls tick(delta) while engaged; the component emits
## `attacked(damage)` each time the interval elapses (first hit fires immediately).

signal attacked(damage: float)

@export var damage: float = 6.0
@export var interval: float = 1.3
var _cd: float = 0.0

func setup(p_damage: float, p_interval: float) -> void:
	damage = p_damage
	interval = p_interval

func tick(delta: float) -> void:
	_cd -= delta
	if _cd <= 0.0:
		_cd = interval
		attacked.emit(damage)

func reset() -> void:
	_cd = 0.0
