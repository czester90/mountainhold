class_name BossRamEnemy
extends RamEnemy

## The final-wave siege engine: a great ram — much tankier and hits harder than a normal ram, and
## reads darker/heavier. Same behaviour (works the gate, holds at the breach) and same weak-point
## rule (crew under the roof), just a bigger threat that anchors the last wave. In group "ram" (via
## RamEnemy) so the HUD "TARAN" chevron points at it.

const BOSS_STATS := preload("res://data/enemy_bossram.tres")

func _ready() -> void:
	stats = BOSS_STATS
	super()

func _tune() -> void:
	pass

func _build_visual() -> Dictionary:
	var r := super()
	var bases: Array = []
	for m in r["mats"]:
		m.albedo_color = m.albedo_color.darkened(0.35)   # scorched / iron-clad great ram
		bases.append(m.albedo_color)
	r["bases"] = bases
	return r
