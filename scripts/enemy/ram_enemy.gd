class_name RamEnemy
extends Enemy

## Battering ram: slow, very tanky, hits the gate HARDEST. A heavy beam under a peaked timber roof on
## four wheels with an iron-shod head. It only works the gate — once the gate is breached it holds at
## the broken arch (it can't storm the keep like the foot soldiers).

const DEFAULT_STATS := preload("res://data/enemy_ram.tres")

func _ready() -> void:
	if stats == null or stats.resource_path == "res://data/enemy_infantry.tres":
		stats = DEFAULT_STATS
	super()
	add_to_group("ram")        # so the HUD can point a "TARAN!" chevron at the nearest ram

func _tune() -> void:
	pass

func _can_attack_gate() -> bool:
	return true

func _collision_shape() -> Shape3D:
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 1.9, 4.2)
	return box

func _collision_offset() -> Vector3:
	return Vector3(0, 1.0, 0)

func _build_visual() -> Dictionary:
	var mats: Array = []
	var bases: Array = []
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color(0.30, 0.19, 0.10); wood.roughness = 0.95
	var dark := StandardMaterial3D.new(); dark.albedo_color = Color(0.20, 0.13, 0.07); dark.roughness = 0.95
	var iron := StandardMaterial3D.new(); iron.albedo_color = Color(0.12, 0.12, 0.14); iron.metallic = 0.5
	var parts := [
		[Vector3(0, 1.1, 0.0), Vector3(0.35, 0.35, 3.6), wood],       # the ram beam
		[Vector3(0, 1.1, 2.0), Vector3(0.5, 0.5, 0.5), iron],         # iron-shod head (toward the gate, +Z local)
		[Vector3(0, 2.2, 0.0), Vector3(1.9, 0.25, 4.0), dark],        # roof ridge slab
		[Vector3(-0.85, 1.7, 0.0), Vector3(0.2, 1.4, 4.0), wood],     # roof side L
		[Vector3(0.85, 1.7, 0.0), Vector3(0.2, 1.4, 4.0), wood],      # roof side R
		[Vector3(-0.8, 0.4, 1.5), Vector3(0.5, 0.8, 0.2), dark],      # wheels
		[Vector3(0.8, 0.4, 1.5), Vector3(0.5, 0.8, 0.2), dark],
		[Vector3(-0.8, 0.4, -1.5), Vector3(0.5, 0.8, 0.2), dark],
		[Vector3(0.8, 0.4, -1.5), Vector3(0.5, 0.8, 0.2), dark],
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[1]
		mi.mesh = bm
		var m: StandardMaterial3D = (p[2] as StandardMaterial3D).duplicate()
		mi.material_override = m
		mi.position = p[0]
		add_child(mi)
		mats.append(m)
		bases.append(m.albedo_color)
	return {"mats": mats, "bases": bases}

# the ram's roof is armoured; the weak spot is the exposed crew + beam LOW under it
func _is_weak_hit(hit_y: float) -> bool:
	return hit_y < global_position.y + 1.3

func _at_gate(delta: float, dist: float) -> bool:
	if dist <= attack_range:
		if _gate_open():
			_idle(delta)               # job done — hold at the breach, don't chase the keep
		else:
			_attack(delta, "gate")
		return true
	return false
