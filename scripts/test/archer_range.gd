extends Node3D

## Isolated combat-loop scene: a flat floor, one ally archer, and a stationary target enemy in
## range with clear line of sight. Exercises targeting -> ballistic arrow -> enemy HealthComponent
## end-to-end without building the whole fortress. Tests load this via scene_runner and assert the
## enemy dies. `spawn_target(pos)` lets a test add more targets.

const Ally := preload("res://scenes/ally/ally_archer.tscn")
const Enemy := preload("res://scenes/enemy/enemy.tscn")

func _ready() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1                       # world
	floor_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	floor_body.add_child(cs)
	add_child(floor_body)
	var ally := Ally.instantiate()
	add_child(ally)
	ally.global_position = Vector3.ZERO
	ally.arrow_damage = 55.0
	ally.spread_deg = 0.0
	spawn_target(Vector3(22, 0, 0))

func spawn_target(pos: Vector3) -> Node:
	var e := Enemy.instantiate()
	add_child(e)
	e.global_position = pos
	e.setup(Vector3(9999, pos.y, pos.z))                 # far target so it never "breaches"
	e.speed = 0.0                                        # stand still to make it a clean archery target
	return e

func enemies_alive() -> int:
	return _count_enemies(self)

func _count_enemies(node: Node) -> int:
	var count := 1 if node.is_in_group("enemy") else 0
	for child in node.get_children():
		count += _count_enemies(child)
	return count
