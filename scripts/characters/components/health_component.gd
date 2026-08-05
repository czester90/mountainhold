class_name HealthComponent
extends Node

## Reusable hit-points component. Owns hp/max_hp, applies damage, and emits `died` at 0. The host
## unit keeps its own public facade (take_damage/hp/died) and delegates here.

signal died
signal damaged(amount: float, hp: float)

@export var max_hp: float = 100.0
@export var defense: float = 0.0
@export_range(0.0, 0.85, 0.01) var armor: float = 0.0
var hp: float = 0.0

func _ready() -> void:
	if hp <= 0.0:
		hp = max_hp

func setup(p_max_hp: float, p_defense: float = 0.0, p_armor: float = 0.0) -> void:
	max_hp = p_max_hp
	defense = p_defense
	armor = p_armor
	hp = p_max_hp

func take_damage(amount: float) -> float:
	if hp <= 0.0:
		return 0.0
	var dealt := maxf(0.0, amount - defense) * (1.0 - clampf(armor, 0.0, 0.85))
	hp -= dealt
	damaged.emit(dealt, hp)
	if hp <= 0.0:
		died.emit()
	return dealt

func is_alive() -> bool:
	return hp > 0.0
